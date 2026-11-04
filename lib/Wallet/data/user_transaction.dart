class UserTransaction {
  final String sender;
  final String receiver;
  final int amount;
  final DateTime timestamp;


  UserTransaction({
    required this.sender,
    required this.receiver,
    required this.amount,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();


  Map<String, dynamic> toJson() => {
        'sender': sender,
        'receiver': receiver,
        'amount': amount,
        'timestamp': timestamp.toIso8601String(),
      };
}

