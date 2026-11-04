import 'dart:math';

import 'package:mango/Wallet/data/block.dart';
import 'package:mango/Wallet/data/coin_helper.dart';
import 'package:mango/Wallet/data/transactions.dart';

class Blockchain {
  List<Block> chain;
  List<MangoTransaction> pendingTransactions;
  int difficulty;

  Blockchain({int difficultyValue = 2})
    : difficulty = difficultyValue,
      chain = [],
      pendingTransactions = [] {
    createGenesisBlock();
  }

  void createGenesisBlock() {
    final genesisBlock = Block(
      index: 0,
      transactions: [],
      previousHash: '0',
      signedBy: '',
      signature: '',
    );
    chain.add(genesisBlock);
  }

  Block getLatestBlock() {
    return chain.last;
  }

  void addTransaction(MangoTransaction transaction) {
    pendingTransactions.add(transaction);
  }

  void minePendingTransactions(String miningRewardAddress) {
    
    final rewardTransaction = MangoTransaction(
      sender: 'MINING_REWARD',
      receiver: miningRewardAddress,
      amount: EuniceHelper.toEunice(0.01),
    );
    pendingTransactions.add(rewardTransaction);

    final block = Block(
      index: chain.length,
      transactions: List.from(pendingTransactions),
      previousHash: getLatestBlock().hash,
      signedBy: miningRewardAddress, 
      signature: _generateBlockSignature(), 
    );

    block.mineBlock();
    chain.add(block);

    pendingTransactions = [];
  }

  String _generateBlockSignature() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999);
    return 'block_sig_${timestamp}_$random';
  }

  bool isValidChain() {
    for (int i = 1; i < chain.length; i++) {
      final currentBlock = chain[i];
      final previousBlock = chain[i - 1];

      if (currentBlock.hash != currentBlock.calculateHash()) {
        return false;
      }

      if (currentBlock.previousHash != previousBlock.hash) {
        return false;
      }
    }
    return true;
  }

  void printChain() {
    for (final block in chain) {
      print('Block ${block.index}');
      print('Hash: ${block.hash}');
      print('Previous Hash: ${block.previousHash}');
      print('Transactions: ${block.transactions.length}');
      print('Nonce: ${block.nonce}');
      print('---');
    }
  }
}


