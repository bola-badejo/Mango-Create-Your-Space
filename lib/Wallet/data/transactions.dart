
import 'package:mango/Wallet/data/coin_helper.dart';

class MangoTransaction {
  final String sender;
  final String receiver;
  final int amount;
  final DateTime timestamp;
  final String? transactionId;
  final int? fee;
  final int nonce;
  final String signature;
  final String? data;

  MangoTransaction({
    required this.sender,
    required this.receiver,
    required this.amount,
    DateTime? timestamp,
    this.transactionId,
    this.fee = 0,
    this.nonce = 0,
    this.signature = '',
    this.data,
  }) : timestamp = timestamp ?? DateTime.now();

  factory MangoTransaction.fromJson(Map<String, dynamic> json) {
    return MangoTransaction(
      sender: json['sender'] ?? '',
      receiver: json['receiver'] ?? '',
      amount: json['amount'] ?? 0,
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      transactionId: json['transactionId'],
      fee: json['fee'] ?? 0,
      nonce: json['nonce'] ?? 0,
      signature: json['signature'] ?? '',
      data: json['data'],
    );
  }

  Map<String, dynamic> toJson() => {
    'sender': sender,
    'receiver': receiver,
    'amount': amount,
    'timestamp': timestamp.toIso8601String(),
    'transactionId': transactionId,
    'fee': fee,
    'nonce': nonce,
    'signature': signature,
    'data': data,
  };

  @override
  String toString() => 'MangoTransaction(sender: $sender, receiver: $receiver, amount: ${EuniceHelper.toCoin(amount)} MNG, fee: ${fee != null ? EuniceHelper.toCoin(fee!) : 0} MNG)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MangoTransaction &&
          runtimeType == other.runtimeType &&
          sender == other.sender &&
          receiver == other.receiver &&
          amount == other.amount &&
          nonce == other.nonce;

  @override
  int get hashCode => sender.hashCode ^ receiver.hashCode ^ amount.hashCode ^ nonce.hashCode;
}

