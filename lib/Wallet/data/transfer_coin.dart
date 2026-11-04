import 'package:cloud_firestore/cloud_firestore.dart';


Future<void> transferMangoCoins({
  required String senderId,
  required String receiverId,
  required int amount,
  
}) async {
  final senderWalletRef = FirebaseFirestore.instance.collection('wallets').doc(senderId);
  final receiverWalletRef = FirebaseFirestore.instance.collection('wallets').doc(receiverId);


  final senderWallet = await senderWalletRef.get();
  final receiverWallet = await receiverWalletRef.get();


  if (!senderWallet.exists || !receiverWallet.exists) {
    throw Exception("Wallet does not exist for one of the users.");
  }


  int senderBalance = senderWallet['balance'];
  int receiverBalance = receiverWallet['balance'];


  if (senderBalance < amount) {
    throw Exception("Insufficient balance.");
  }


  await FirebaseFirestore.instance.runTransaction((transaction) async {
    transaction.update(senderWalletRef, {'balance': senderBalance - amount});
    transaction.update(receiverWalletRef, {'balance': receiverBalance + amount});
  });


  
  
}


