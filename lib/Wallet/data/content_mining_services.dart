
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:mango/Wallet/data/decimal.dart';
import 'package:mango/Wallet/data/transactions.dart';
import 'package:mango/Wallet/services/wallet_services.dart';

class ContentMiningService extends GetxService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late WalletService _walletService;

  
  static final Decimal songMiningRate = Decimal.fromDouble(0.02);
  static final Decimal movieMiningRate = Decimal.fromDouble(0.05);
  static final Decimal bookMiningRate = Decimal.fromDouble(0.03);
  static final Decimal productMiningRate = Decimal.fromDouble(0.10);
  static final Decimal podcastMiningRate = Decimal.fromDouble(0.015);
  static final Decimal spaceVisitRate = Decimal.fromDouble(0.008);

  
  static final double spaceMiningMultiplier = 1.5;
  static final double spaceContentMultiplier = 2.0;

  @override
  Future<void> onInit() async {
    _walletService = Get.find<WalletService>();
    super.onInit();
  }

  
  Future<MiningResult> mineContent({
    required String contentId,
    required ContentType contentType,
    required String creatorId,
    int durationSeconds = 0,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    
    if (await _isOnCooldown(user.uid, contentId)) {
      throw Exception('Content mining cooldown active');
    }

    
    Decimal baseAmount = _getMiningRate(contentType, durationSeconds);
    
    
    Decimal creatorShare = baseAmount * Decimal.fromDouble(0.8);
    Decimal minerShare = baseAmount * Decimal.fromDouble(0.2);

    
    return await _executeMiningTransaction(
      minerId: user.uid,
      creatorId: creatorId,
      contentId: contentId,
      contentType: contentType,
      minerShare: minerShare,
      creatorShare: creatorShare,
      spaceId: null,
      spaceOwnerId: null,
    );
  }

  
  Future<MiningResult> mineContentInSpace({
    required String contentId,
    required ContentType contentType,
    required String creatorId,
    required String spaceId,
    required String spaceOwnerId,
    int durationSeconds = 0,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    
    if (await _isOnCooldown(user.uid, '$spaceId-$contentId')) {
      throw Exception('Space content mining cooldown active');
    }

    
    Decimal baseAmount = _getMiningRate(contentType, durationSeconds) * 
                        Decimal.fromDouble(spaceContentMultiplier);
    
    
    Decimal creatorShare = baseAmount * Decimal.fromDouble(0.7);
    Decimal minerShare = baseAmount * Decimal.fromDouble(0.2);
    Decimal spaceOwnerShare = baseAmount * Decimal.fromDouble(0.1);

    
    return await _executeMiningTransaction(
      minerId: user.uid,
      creatorId: creatorId,
      contentId: contentId,
      contentType: contentType,
      minerShare: minerShare,
      creatorShare: creatorShare,
      spaceId: spaceId,
      spaceOwnerId: spaceOwnerId,
      spaceOwnerShare: spaceOwnerShare,
    );
  }

  
  Future<MiningResult> mineSpaceVisit({
    required String spaceId,
    required String spaceOwnerId,
    int visitDurationSeconds = 0,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    
    if (await _isOnCooldown(user.uid, 'space-visit-$spaceId')) {
      throw Exception('Space visit cooldown active');
    }

    
    Decimal baseAmount = spaceVisitRate * 
                        Decimal.fromDouble(spaceMiningMultiplier) *
                        Decimal.fromDouble(_calculateDurationMultiplier(visitDurationSeconds));
    
    
    Decimal spaceOwnerShare = baseAmount * Decimal.fromDouble(0.9);
    Decimal minerShare = baseAmount * Decimal.fromDouble(0.1);

    return await _executeMiningTransaction(
      minerId: user.uid,
      creatorId: spaceOwnerId,
      contentId: spaceId,
      contentType: ContentType.space,
      minerShare: minerShare,
      creatorShare: spaceOwnerShare,
      spaceId: spaceId,
      spaceOwnerId: spaceOwnerId,
      isSpaceVisit: true,
    );
  }

  Decimal _getMiningRate(ContentType contentType, int durationSeconds) {
    Decimal baseRate;
    
    switch (contentType) {
      case ContentType.song:
        baseRate = songMiningRate;
        break;
      case ContentType.movie:
        baseRate = movieMiningRate;
        break;
      case ContentType.book:
        baseRate = bookMiningRate;
        break;
      case ContentType.product:
        baseRate = productMiningRate;
        break;
      case ContentType.podcast:
        baseRate = podcastMiningRate;
        break;
      case ContentType.space:
        baseRate = spaceVisitRate;
        break;
      default:
        baseRate = Decimal.fromDouble(0.01);
    }

    
    if (durationSeconds > 0) {
      final durationMultiplier = _calculateDurationMultiplier(durationSeconds);
      baseRate = baseRate * Decimal.fromDouble(durationMultiplier);
    }

    return baseRate;
  }

  double _calculateDurationMultiplier(int durationSeconds) {
    
    if (durationSeconds <= 30) return 1.0;
    if (durationSeconds <= 60) return 1.2;
    if (durationSeconds <= 300) return 1.5; 
    if (durationSeconds <= 1800) return 2.0; 
    return 2.5; 
  }

  Future<MiningResult> _executeMiningTransaction({
  required String minerId,
  required String creatorId,
  required String contentId,
  required ContentType contentType,
  required Decimal minerShare,
  required Decimal creatorShare,
  String? spaceId,
  String? spaceOwnerId,
  Decimal? spaceOwnerShare,
  bool isSpaceVisit = false,
}) async {
  final batch = _firestore.batch();
  final miningId = _generateMiningId();

  
  final miningData = {
    'mining_id': miningId,
    'miner_id': minerId,
    'creator_id': creatorId,
    'content_id': contentId,
    'content_type': contentType.name,
    'miner_share': minerShare.toSatoshis().toInt(),
    'creator_share': creatorShare.toSatoshis().toInt(),
    'space_id': spaceId,
    'space_owner_id': spaceOwnerId,
    'space_owner_share': spaceOwnerShare?.toSatoshis().toInt(),
    'is_space_visit': isSpaceVisit,
    'timestamp': FieldValue.serverTimestamp(),
    'total_mined': (minerShare + creatorShare + (spaceOwnerShare ?? Decimal.zero))
                    .toSatoshis().toInt(),
  };

  try {
    final miningDoc = _firestore.collection('mining_activities').doc(miningId);
    batch.set(miningDoc, miningData);
      final minerWalletRef = _firestore.collection('wallets').doc(minerId);
      batch.update(minerWalletRef, {
        'balance': FieldValue.increment(minerShare.toSatoshis().toInt()),
        'total_mined': FieldValue.increment(minerShare.toSatoshis().toInt()),
        'last_activity': 'content_mining',
        'updated_at': FieldValue.serverTimestamp(),
      });

      
      final creatorWalletRef = _firestore.collection('wallets').doc(creatorId);
      batch.update(creatorWalletRef, {
        'balance': FieldValue.increment(creatorShare.toSatoshis().toInt()),
        'total_earned': FieldValue.increment(creatorShare.toSatoshis().toInt()),
        'updated_at': FieldValue.serverTimestamp(),
      });

      
      if (spaceOwnerId != null && spaceOwnerShare != null) {
        final spaceOwnerWalletRef = _firestore.collection('wallets').doc(spaceOwnerId);
        batch.update(spaceOwnerWalletRef, {
          'balance': FieldValue.increment(spaceOwnerShare.toSatoshis().toInt()),
          'space_earnings': FieldValue.increment(spaceOwnerShare.toSatoshis().toInt()),
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      
      await _recordMiningTransactions(
        minerId: minerId,
        creatorId: creatorId,
        spaceOwnerId: spaceOwnerId,
        minerShare: minerShare,
        creatorShare: creatorShare,
        spaceOwnerShare: spaceOwnerShare,
        contentId: contentId,
        contentType: contentType,
        spaceId: spaceId,
        miningId: miningId,
      );

      
      await _addToBlockchain(
        minerId: minerId,
        creatorId: creatorId,
        spaceOwnerId: spaceOwnerId,
        minerShare: minerShare,
        creatorShare: creatorShare,
        spaceOwnerShare: spaceOwnerShare,
        contentId: contentId,
        miningId: miningId,
      );

      
      await _sendMiningNotifications(
        minerId: minerId,
        creatorId: creatorId,
        spaceOwnerId: spaceOwnerId,
        minerShare: minerShare,
        creatorShare: creatorShare,
        spaceOwnerShare: spaceOwnerShare,
        contentId: contentId,
        contentType: contentType,
        spaceId: spaceId,
      );

      await batch.commit();

      return MiningResult(
      success: true,
      miningId: miningId,
      minerShare: minerShare,
      creatorShare: creatorShare,
      spaceOwnerShare: spaceOwnerShare,
      totalMined: minerShare + creatorShare + (spaceOwnerShare ?? Decimal.zero),
      spaceId: spaceId,
    );

  } catch (e) {
    
    await _firestore.collection('failed_mining').doc(miningId).set({
      'error': e.toString(),
      'mining_data': miningData, 
      'timestamp': FieldValue.serverTimestamp(),
    });
    rethrow;
  }
}

  Future<void> _recordMiningTransactions({
    required String minerId,
    required String creatorId,
    required String? spaceOwnerId,
    required Decimal minerShare,
    required Decimal creatorShare,
    required Decimal? spaceOwnerShare,
    required String contentId,
    required ContentType contentType,
    required String? spaceId,
    required String miningId,
  }) async {
    final transactions = <Map<String, dynamic>>[];

    
    transactions.add({
      'transaction_id': '$miningId-miner',
      'user_id': minerId,
      'type': 'mining_reward',
      'amount': minerShare.toDouble(),
      'from_address': 'CONTENT_MINING',
      'memo': 'Mining reward for ${contentType.name}',
      'content_id': contentId,
      'space_id': spaceId,
      'mining_id': miningId,
      'timestamp': FieldValue.serverTimestamp(),
      'currency': 'MNG',
    });

    
    transactions.add({
      'transaction_id': '$miningId-creator',
      'user_id': creatorId,
      'type': 'creator_earnings',
      'amount': creatorShare.toDouble(),
      'from_address': 'CONTENT_MINING',
      'memo': 'Earnings from ${contentType.name}',
      'content_id': contentId,
      'space_id': spaceId,
      'mining_id': miningId,
      'timestamp': FieldValue.serverTimestamp(),
      'currency': 'MNG',
    });

    
    if (spaceOwnerId != null && spaceOwnerShare != null) {
      transactions.add({
        'transaction_id': '$miningId-space-owner',
        'user_id': spaceOwnerId,
        'type': 'space_earnings',
        'amount': spaceOwnerShare.toDouble(),
        'from_address': 'CONTENT_MINING',
        'memo': 'Space earnings from ${contentType.name}',
        'content_id': contentId,
        'space_id': spaceId,
        'mining_id': miningId,
        'timestamp': FieldValue.serverTimestamp(),
        'currency': 'MNG',
      });
    }

    
    final batch = _firestore.batch();
    for (final tx in transactions) {
      batch.set(_firestore.collection('transactions').doc(tx['transaction_id']), tx);
    }
    await batch.commit();
  }

  Future<void> _addToBlockchain({
    required String minerId,
    required String creatorId,
    required String? spaceOwnerId,
    required Decimal minerShare,
    required Decimal creatorShare,
    required Decimal? spaceOwnerShare,
    required String contentId,
    required String miningId,
  }) async {
    try {
      
      final minerTransaction = MangoTransaction(
        sender: 'CONTENT_MINING',
        receiver: minerId,
        amount: minerShare.toSatoshis().toInt(),
        transactionId: '$miningId-miner',
        timestamp: DateTime.now(),
      );

      
      final creatorTransaction = MangoTransaction(
        sender: 'CONTENT_MINING',
        receiver: creatorId,
        amount: creatorShare.toSatoshis().toInt(),
        transactionId: '$miningId-creator',
        timestamp: DateTime.now(),
      );

      
      _walletService.blockchain.addTransaction(minerTransaction);
      _walletService.blockchain.addTransaction(creatorTransaction);

      
      if (spaceOwnerId != null && spaceOwnerShare != null) {
        final spaceOwnerTransaction = MangoTransaction(
          sender: 'CONTENT_MINING',
          receiver: spaceOwnerId,
          amount: spaceOwnerShare.toSatoshis().toInt(),
          transactionId: '$miningId-space-owner',
          timestamp: DateTime.now(),
        );
        _walletService.blockchain.addTransaction(spaceOwnerTransaction);
      }

    } catch (e) {
      print('Error adding to blockchain: $e');
      
    }
  }

  Future<void> _sendMiningNotifications({
    required String minerId,
    required String creatorId,
    required String? spaceOwnerId,
    required Decimal minerShare,
    required Decimal creatorShare,
    required Decimal? spaceOwnerShare,
    required String contentId,
    required ContentType contentType,
    required String? spaceId,
  }) async {
    final notifications = <Map<String, dynamic>>[];

    
    notifications.add({
      'user_id': minerId,
      'type': 'mining_reward',
      'title': 'Mining Reward!',
      'message': 'You mined ${minerShare.toFixed(6)} MNG from ${contentType.name}',
      'data': {
        'amount': minerShare.toDouble(),
        'content_type': contentType.name,
        'content_id': contentId,
        'space_id': spaceId,
      },
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });

    
    notifications.add({
      'user_id': creatorId,
      'type': 'creator_earnings',
      'title': 'Content Earnings!',
      'message': 'You earned ${creatorShare.toFixed(6)} MNG from your ${contentType.name}',
      'data': {
        'amount': creatorShare.toDouble(),
        'content_type': contentType.name,
        'content_id': contentId,
        'miner_id': minerId,
        'space_id': spaceId,
      },
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });

    
    if (spaceOwnerId != null && spaceOwnerShare != null) {
      notifications.add({
        'user_id': spaceOwnerId,
        'type': 'space_earnings',
        'title': 'Space Earnings!',
        'message': 'You earned ${spaceOwnerShare.toFixed(6)} MNG from space activity',
        'data': {
          'amount': spaceOwnerShare.toDouble(),
          'content_type': contentType.name,
          'content_id': contentId,
          'miner_id': minerId,
          'space_id': spaceId,
        },
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    }

    
    final batch = _firestore.batch();
    for (final notification in notifications) {
      final docId = _firestore.collection('messages').doc().id;
      batch.set(_firestore.collection('messages').doc(docId), notification);
    }
    await batch.commit();
  }

  Future<bool> _isOnCooldown(String userId, String activityKey) async {
    final lastMining = await _firestore
        .collection('mining_activities')
        .where('miner_id', isEqualTo: userId)
        .where('content_id', isEqualTo: activityKey)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (lastMining.docs.isEmpty) return false;

    final lastTimestamp = lastMining.docs.first['timestamp'] as Timestamp;
    final now = DateTime.now();
    final cooldown = _getCooldownDuration(activityKey);

    return now.difference(lastTimestamp.toDate()) < cooldown;
  }

  Duration _getCooldownDuration(String activityKey) {
    if (activityKey.startsWith('space-visit-')) {
      return Duration(minutes: 30); 
    }
    return Duration(minutes: 10); 
  }

  String _generateMiningId() {
    return 'mining_${DateTime.now().millisecondsSinceEpoch}_${_auth.currentUser?.uid}';
  }

  
  Future<MiningStats> getMiningStats(String userId) async {
    final snapshot = await _firestore
        .collection('mining_activities')
        .where('miner_id', isEqualTo: userId)
        .get();

    final totalMined = snapshot.docs.fold(Decimal.zero, (sum, doc) {
      final amount = Decimal.fromBigInt(BigInt.from(doc['miner_share'] ?? 0));
      return sum + amount;
    });

    final spaceMining = snapshot.docs.where((doc) => doc['space_id'] != null).length;
    final contentTypes = <ContentType, int>{};

    for (final doc in snapshot.docs) {
      final type = ContentType.values.firstWhere(
        (e) => e.name == doc['content_type'],
        orElse: () => ContentType.other,
      );
      contentTypes[type] = (contentTypes[type] ?? 0) + 1;
    }

    return MiningStats(
      totalMiningSessions: snapshot.docs.length,
      totalMined: totalMined,
      spaceMiningSessions: spaceMining,
      contentTypeDistribution: contentTypes,
    );
  }
}

enum ContentType {
  song,
  movie,
  book,
  product,
  podcast,
  space,
  other,
}

class MiningResult {
  final bool success;
  final String miningId;
  final Decimal minerShare;
  final Decimal creatorShare;
  final Decimal? spaceOwnerShare;
  final Decimal totalMined;
  final String? spaceId;

  MiningResult({
    required this.success,
    required this.miningId,
    required this.minerShare,
    required this.creatorShare,
    this.spaceOwnerShare,
    required this.totalMined,
    this.spaceId,
  });
}

class MiningStats {
  final int totalMiningSessions;
  final Decimal totalMined;
  final int spaceMiningSessions;
  final Map<ContentType, int> contentTypeDistribution;

  MiningStats({
    required this.totalMiningSessions,
    required this.totalMined,
    required this.spaceMiningSessions,
    required this.contentTypeDistribution,
  });
}

