class Wallet {
  final String userId;
  int balance;


  Wallet({
    required this.userId,
    this.balance = 0,
  });


  void deposit(int amount) {
    balance += amount;
  }


  void withdraw(int amount) {
    if (balance >= amount) {
      balance -= amount;
    } else {
      throw Exception("Insufficient balance");
    }
  }
}

