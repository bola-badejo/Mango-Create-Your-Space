// DEPRECATED: insecure on-device chain, replaced by MangoChain on the
// server (functions/ledger). Not used for balances or rewards. Its
// signatures are not real signatures; do not use for anything of value.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:pointycastle/api.dart' as crypto;
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/digests/sha1.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:mango/Wallet/data/transactions.dart';

class TransactionSigner {
  
  static String generatePrivateKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return _bytesToHex(bytes);
  }
  
  static String getPublicKey(String privateKeyHex) {
    final privateBytes = _hexToBytes(privateKeyHex);
    return _bytesToHex(sha256.convert(privateBytes).bytes);
  }
  
  static String signTransaction(MangoTransaction tx, String privateKeyHex) {
    final message = _transactionToMessage(tx);
    final privateBytes = _hexToBytes(privateKeyHex);
    
    final signature = sha256.convert([...privateBytes, ...message]).bytes;
    return _bytesToHex(signature);
  }
  
  static bool verifySignature(MangoTransaction tx, String signatureHex, String publicKeyHex) {
    try {
      final message = _transactionToMessage(tx);
      final signatureBytes = _hexToBytes(signatureHex);
      
      
      final expectedPublicKey = getPublicKey(_bytesToHex(signatureBytes));
      return publicKeyHex == expectedPublicKey;
    } catch (e) {
      return false;
    }
  }
  
  static String signMessage(String message, String privateKeyHex) {
    final privateBytes = _hexToBytes(privateKeyHex);
    final signature = sha256.convert([...privateBytes, ...utf8.encode(message)]).bytes;
    return _bytesToHex(signature);
  }
  
  static List<int> _transactionToMessage(MangoTransaction tx) {
    final data = jsonEncode({
      'sender': tx.sender,
      'receiver': tx.receiver,
      'amount': tx.amount,
      'fee': tx.fee ?? 0,
      'nonce': tx.nonce,
      'timestamp': tx.timestamp.millisecondsSinceEpoch,
      'transactionId': tx.transactionId,
    });
    return sha256.convert(utf8.encode(data)).bytes;
  }
  
  static String _bytesToHex(List<int> bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('');
  }
  
  static List<int> _hexToBytes(String hex) {
    final result = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      result.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return result;
  }
}

class SecurityManager {
  static final _secureStorage = FlutterSecureStorage();
  
  static Future<void> storePrivateKey(String userId, String privateKey) async {
    await _secureStorage.write(key: 'private_key_$userId', value: privateKey);
  }
  
  static Future<String?> getPrivateKey(String userId) async {
    return await _secureStorage.read(key: 'private_key_$userId');
  }
  
  static Future<void> clearPrivateKey(String userId) async {
    await _secureStorage.delete(key: 'private_key_$userId');
  }
  
  static String encryptData(String data, String password) {
    final key = _deriveKey(password);
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encrypt(data, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }
  
  static String decryptData(String encryptedData, String password) {
    final parts = encryptedData.split(':');
    final iv = encrypt.IV.fromBase64(parts[0]);
    final encrypted = encrypt.Encrypted.fromBase64(parts[1]);
    final key = _deriveKey(password);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    return encrypter.decrypt(encrypted, iv: iv);
  }
  
  static encrypt.Key _deriveKey(String password) {
    
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    
    final params = Pbkdf2Parameters(
      utf8.encode('mango_salt'),
      100000, 
      32, 
    );
    
    pbkdf2.init(params);
    
    final key = pbkdf2.process(utf8.encode(password));
    return encrypt.Key(key);
  }
}

class Decimal implements Comparable<Decimal> {
  static const int _defaultScale = 8;
  final BigInt _value;
  final int _scale;

  Decimal.fromBigInt(this._value, [this._scale = _defaultScale]);
  
  Decimal.fromInt(int value, [int scale = _defaultScale])
      : _value = BigInt.from(value) * BigInt.from(pow(10, scale)),
        _scale = scale;
        
  Decimal.fromDouble(double value, [int scale = _defaultScale])
      : _value = BigInt.from(value * pow(10, scale)),
        _scale = scale;

  Decimal.parse(String value, [int scale = _defaultScale])
      : _value = _parseString(value, scale),
        _scale = scale;

  static final Decimal zero = Decimal.fromInt(0);
  static final Decimal one = Decimal.fromInt(1);

  static BigInt _parseString(String value, int scale) {
    final parts = value.split('.');
    if (parts.length > 2) throw FormatException('Invalid decimal format: $value');
    
    final integerPart = parts[0];
    String fractionalPart = parts.length == 2 ? parts[1] : '';
    
    if (fractionalPart.length > scale) {
      fractionalPart = fractionalPart.substring(0, scale);
    } else {
      fractionalPart = fractionalPart.padRight(scale, '0');
    }
    
    final combined = integerPart + fractionalPart;
    return BigInt.parse(combined.isEmpty ? '0' : combined);
  }

  Decimal operator +(Decimal other) {
    final scaledValue = _alignScales(other);
    return Decimal.fromBigInt(scaledValue.item1 + scaledValue.item2, _scale);
  }

  Decimal operator -(Decimal other) {
    final scaledValue = _alignScales(other);
    return Decimal.fromBigInt(scaledValue.item1 - scaledValue.item2, _scale);
  }

  Decimal operator *(Decimal other) {
    final result = _value * other._value;
    return Decimal.fromBigInt(result, _scale + other._scale);
  }

  Decimal operator /(Decimal other) {
    if (other._value == BigInt.zero) throw DivisionByZeroException();
    final scaledValue = _value * BigInt.from(pow(10, _scale));
    final result = scaledValue ~/ other._value;
    return Decimal.fromBigInt(result, _scale);
  }

  bool operator <(Decimal other) => compareTo(other) < 0;
  bool operator <=(Decimal other) => compareTo(other) <= 0;
  bool operator >(Decimal other) => compareTo(other) > 0;
  bool operator >=(Decimal other) => compareTo(other) >= 0;

  @override
  int compareTo(Decimal other) {
    final scaledValue = _alignScales(other);
    return scaledValue.item1.compareTo(scaledValue.item2);
  }

  Tuple2<BigInt, BigInt> _alignScales(Decimal other) {
    if (_scale == other._scale) return Tuple2(_value, other._value);
    
    if (_scale > other._scale) {
      final factor = BigInt.from(pow(10, _scale - other._scale));
      return Tuple2(_value, other._value * factor);
    } else {
      final factor = BigInt.from(pow(10, other._scale - _scale));
      return Tuple2(_value * factor, other._value);
    }
  }

  double toDouble() => _value.toDouble() / pow(10, _scale);
  int toInt() => (_value ~/ BigInt.from(pow(10, _scale))).toInt();
  BigInt toSatoshis() => _value;

  String toString() {
    final stringValue = _value.toString().padLeft(_scale + 1, '0');
    final integerPart = stringValue.substring(0, stringValue.length - _scale);
    final fractionalPart = stringValue.substring(stringValue.length - _scale);
    var cleanFractional = fractionalPart.replaceAll(RegExp(r'0+$'), '');
    if (cleanFractional.isEmpty) return integerPart;
    return '$integerPart.$cleanFractional';
  }

  String toFixed(int decimalPlaces) {
    if (decimalPlaces > _scale) {
      throw ArgumentError('Requested decimal places exceed scale');
    }
    final stringValue = _value.toString().padLeft(_scale + 1, '0');
    final integerPart = stringValue.substring(0, stringValue.length - _scale);
    final fractionalPart = stringValue.substring(stringValue.length - _scale);
    return '$integerPart.${fractionalPart.substring(0, decimalPlaces)}';
  }

  bool get isZero => _value == BigInt.zero;
  bool get isNegative => _value.isNegative;
  Decimal abs() => Decimal.fromBigInt(_value.abs(), _scale);
  
  @override
  bool operator ==(Object other) =>
      other is Decimal && _scale == other._scale && _value == other._value;

  @override
  int get hashCode => Object.hash(_value, _scale);
}

class DivisionByZeroException implements Exception {
  final String message = 'Division by zero';
}

class Tuple2<T1, T2> {
  final T1 item1;
  final T2 item2;
  Tuple2(this.item1, this.item2);
}

