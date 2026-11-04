import 'package:flutter/material.dart';


class TransactionScreen extends StatefulWidget {
  final String userId;


  TransactionScreen({required this.userId});


  @override
  _TransactionScreenState createState() => _TransactionScreenState();
}


class _TransactionScreenState extends State<TransactionScreen> {
  final TextEditingController _receiverController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();


  Future<void> _sendTransaction() async {
    final receiverId = _receiverController.text;
    final amount = int.parse(_amountController.text);
    
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Send Mango Coins")),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _receiverController, decoration: InputDecoration(labelText: "Receiver ID")),
            TextField(controller: _amountController, decoration: InputDecoration(labelText: "Amount"), keyboardType: TextInputType.number),
            SizedBox(height: 20),
            ElevatedButton(onPressed: _sendTransaction, child: Text("Send")),
          ],
        ),
      ),
    );
  }
}

