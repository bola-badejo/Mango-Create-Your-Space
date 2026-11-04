import 'package:flutter/material.dart';
import 'package:mango/Utils/optimized_lists.dart';
import 'package:mango/Wallet/data/user_transaction.dart';


class TransactionHistoryScreen extends StatelessWidget {
  final String userId;


  TransactionHistoryScreen({required this.userId});


  Future<List<UserTransaction>> _fetchTransactionHistory() async {
    
    return [];
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Transaction History")),
      body: FutureBuilder<List<UserTransaction>>(
        future: _fetchTransactionHistory(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          final transactions = snapshot.data!;
          return OptimizedListView(
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final transaction = transactions[index];
              return ListTile(
                title: Text("${transaction.amount} Mango Coins"),
                subtitle: Text("To: ${transaction.receiver}"),
                trailing: Text(transaction.timestamp.toLocal().toString()),
              );
            },
          );
        },
      ),
    );
  }
}


class TransactionHistoryWidget extends StatelessWidget {
  final List<UserTransaction> transactions;


  TransactionHistoryWidget({required this.transactions});


  @override
  Widget build(BuildContext context) {
    return OptimizedListView(
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        return ListTile(
          title: Text("${transaction.amount} Mango Coins"),
          subtitle: Text("To: ${transaction.receiver}, From: ${transaction.sender}"),
          trailing: Text(transaction.timestamp.toLocal().toString()),
        );
      },
    );
  }
}

