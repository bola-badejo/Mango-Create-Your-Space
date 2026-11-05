// DEPRECATED: insecure on-device chain, replaced by MangoChain on the
// server (functions/ledger). Not used for balances or rewards. Its
// signatures are not real signatures; do not use for anything of value.
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:mango/Wallet/data/transaction_signer.dart';
import 'package:mango/Wallet/data/transactions.dart';
import 'package:http/http.dart';

class Block {
  final int index;
  final DateTime timestamp;
  final List<MangoTransaction> transactions;
  final String previousHash;
  final String merkleRoot;
  String hash;
  int nonce;
  final int difficulty;
  final String signedBy;
  final String signature;

  Block({
    required this.index,
    required this.transactions,
    required this.previousHash,
    required this.signedBy,
    required this.signature,
    this.nonce = 0,
    this.difficulty = 2,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now(),
       merkleRoot = _calculateMerkleRoot(transactions),
       hash = '' {
    hash = calculateHash();
  }

  String calculateHash() {
    final blockData = jsonEncode({
      'index': index,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'transactions': transactions.map((t) => t.toJson()).toList(),
      'previousHash': previousHash,
      'merkleRoot': merkleRoot,
      'nonce': nonce,
      'difficulty': difficulty,
      'signedBy': signedBy,
    });
    return sha256.convert(utf8.encode(blockData)).toString();
  }

  static String _calculateMerkleRoot(List<MangoTransaction> transactions) {
    if (transactions.isEmpty) return sha256.convert(utf8.encode('')).toString();
    List<String> transactionHashes = transactions.map((tx) {
      return sha256.convert(utf8.encode(jsonEncode(tx.toJson()))).toString();
    }).toList();
    while (transactionHashes.length > 1) {
      final newHashes = <String>[];
      for (int i = 0; i < transactionHashes.length; i += 2) {
        if (i + 1 < transactionHashes.length) {
          newHashes.add(
            sha256
                .convert(
                  utf8.encode(transactionHashes[i] + transactionHashes[i + 1]),
                )
                .toString(),
          );
        } else {
          newHashes.add(transactionHashes[i]);
        }
      }
      transactionHashes = newHashes;
    }
    return transactionHashes.first;
  }

  void mineBlock() {
    final target = '0' * difficulty;
    int attempts = 0;
    const maxAttempts = 1000000;

    while (hash.substring(0, difficulty) != target && attempts < maxAttempts) {
      nonce++;
      hash = calculateHash();
      attempts++;
    }

    if (attempts >= maxAttempts) {
      throw Exception('Mining timeout - difficulty too high');
    }
  }

  bool validate() {
    if (hash != calculateHash()) return false;
    if (merkleRoot != _calculateMerkleRoot(transactions)) return false;
    final target = '0' * difficulty;
    if (hash.substring(0, difficulty) != target) return false;
    return true;
  }

  Map<String, dynamic> toJson() => {
    'index': index,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'transactions': transactions.map((t) => t.toJson()).toList(),
    'previousHash': previousHash,
    'hash': hash,
    'merkleRoot': merkleRoot,
    'nonce': nonce,
    'difficulty': difficulty,
    'signedBy': signedBy,
    'signature': signature,
  };

  factory Block.fromJson(Map<String, dynamic> json) {
    final block = Block(
      index: json['index'],
      transactions: (json['transactions'] as List)
          .map((t) => MangoTransaction.fromJson(t))
          .toList(),
      previousHash: json['previousHash'],
      signedBy: json['signedBy'],
      signature: json['signature'],
      nonce: json['nonce'],
      difficulty: json['difficulty'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
    );
    block.hash = json['hash'];
    return block;
  }
}

class ProductionBlockchain {
  List<Block> chain;
  List<MangoTransaction> pendingTransactions;
  List<MangoTransaction> transactionPool;
  int difficulty;
  final String networkId;
  final Map<String, int> accountNonces;

  ProductionBlockchain({
    int difficultyValue = 2,
    this.networkId = 'mango-mainnet-1',
  }) : difficulty = difficultyValue,
       chain = [],
       pendingTransactions = [],
       transactionPool = [],
       accountNonces = {} {
    _createGenesisBlock();
  }

  void _createGenesisBlock() {
    final genesisBlock = Block(
      index: 0,
      transactions: [],
      previousHash: '0',
      signedBy: 'genesis',
      signature: 'genesis',
    );
    genesisBlock.hash = genesisBlock.calculateHash();
    chain.add(genesisBlock);
  }

  Block getLatestBlock() => chain.last;

  void addTransaction(MangoTransaction transaction) {
    if (!_validateTransaction(transaction)) {
      throw Exception('Invalid transaction');
    }

    final expectedNonce = (accountNonces[transaction.sender] ?? 0) + 1;
    if (transaction.nonce != expectedNonce) {
      throw Exception('Invalid nonce');
    }

    accountNonces[transaction.sender] = transaction.nonce;
    pendingTransactions.add(transaction);
    transactionPool.add(transaction);
  }

  bool _validateTransaction(MangoTransaction tx) {
    if (tx.sender.isEmpty || tx.receiver.isEmpty) return false;
    if (tx.amount <= 0) return false;
    if (tx.fee! < 0) return false;
    if (tx.timestamp.isAfter(DateTime.now())) return false;

    if (tx.sender != 'ACTIVITY_REWARD' && tx.sender != 'MINING_REWARD') {
      if (tx.signature.isEmpty) return false;
    }

    return true;
  }

  Block minePendingTransactions(String miningRewardAddress, String privateKey) {
    if (pendingTransactions.isEmpty) {
      throw Exception('No transactions to mine');
    }

    final rewardTransaction = MangoTransaction(
      sender: 'MINING_REWARD',
      receiver: miningRewardAddress,
      amount: 1000000,
      fee: 0,
      nonce: 0,
      transactionId: _generateTransactionId(),
    );

    final transactionsToMine = [rewardTransaction, ...pendingTransactions];

    final block = Block(
      index: chain.length,
      transactions: transactionsToMine,
      previousHash: getLatestBlock().hash,
      signedBy: miningRewardAddress,
      signature: _signBlock(miningRewardAddress, privateKey),
    );

    block.mineBlock();

    if (!block.validate()) {
      throw Exception('Mined block failed validation');
    }

    chain.add(block);
    pendingTransactions.clear();

    _cleanTransactionPool(block);

    return block;
  }

  String _signBlock(String address, String privateKey) {
    final signer = TransactionSigner();
    final blockData = chain.length.toString() + getLatestBlock().hash;
    return TransactionSigner.signMessage(blockData, privateKey);
  }

  void _cleanTransactionPool(Block minedBlock) {
    final minedTxIds = minedBlock.transactions
        .map((tx) => tx.transactionId)
        .toSet();
    transactionPool.removeWhere((tx) => minedTxIds.contains(tx.transactionId));
  }

  bool isValidChain() {
    for (int i = 1; i < chain.length; i++) {
      final currentBlock = chain[i];
      final previousBlock = chain[i - 1];

      if (!currentBlock.validate()) return false;
      if (currentBlock.previousHash != previousBlock.hash) return false;
      if (currentBlock.index != previousBlock.index + 1) return false;
    }
    return true;
  }

  bool replaceChain(List<Block> newChain) {
    if (newChain.length > chain.length && _isValidChain(newChain)) {
      chain = newChain;
      _rebuildTransactionPool();
      return true;
    }
    return false;
  }

  bool _isValidChain(List<Block> chain) {
    for (int i = 1; i < chain.length; i++) {
      if (!chain[i].validate()) return false;
      if (chain[i].previousHash != chain[i - 1].hash) return false;
    }
    return true;
  }

  void _rebuildTransactionPool() {
    final minedTxIds = <String>{};
    for (final block in chain) {
      for (final tx in block.transactions) {
        minedTxIds.add(tx.transactionId!);
      }
    }
    transactionPool.removeWhere((tx) => minedTxIds.contains(tx.transactionId));
  }

  int getBalance(String address) {
    int balance = 0;
    for (final block in chain) {
      for (final tx in block.transactions) {
        if (tx.receiver == address) {
          balance += tx.amount;
        }
        if (tx.sender == address && tx.sender != 'MINING_REWARD') {
          balance -= (tx.amount + (tx.fee ?? 0));
        }
      }
    }
    return balance;
  }

  String _generateTransactionId() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return sha256.convert(bytes).toString();
  }
}


