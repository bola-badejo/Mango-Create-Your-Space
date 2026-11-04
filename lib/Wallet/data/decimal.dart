
import 'dart:math';

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