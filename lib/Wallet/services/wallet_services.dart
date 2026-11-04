
import 'dart:math';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:get/get.dart';
import 'package:mango/Wallet/data/blockchain.dart';
import 'package:mango/Wallet/data/currency_service.dart';
import 'package:mango/Wallet/data/decimal.dart';
import 'package:mango/Wallet/data/transactions.dart';

class WalletService extends GetxService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final CurrencyService _currencyService;

  Blockchain get blockchain => Get.find<Blockchain>();

  static final Decimal initialBalance = Decimal.fromDouble(0.0);
  static final Decimal minTransactionAmount = Decimal.fromDouble(0.000001);
  static final Decimal transactionFee = Decimal.fromDouble(0.001);

  static final Decimal dailyLoginReward = Decimal.fromDouble(0.01);
  static final Decimal createPostReward = Decimal.fromDouble(0.02);
  static final Decimal sendMessageReward = Decimal.fromDouble(0.001);
  static final Decimal likeContentReward = Decimal.fromDouble(0.001);
  static final Decimal shareContentReward = Decimal.fromDouble(0.002);
  static final Decimal uploadMusicReward = Decimal.fromDouble(0.05);
  static final Decimal uploadVideoReward = Decimal.fromDouble(0.10);

  static const String _dailyActivityCollection = 'daily_activities';
  static const String _userActivityCollection = 'user_activities';

  final Map<String, int> _dailyRewardCount = {};
  final Map<String, DateTime> _lastRewardDate = {};
  final Map<String, int> _loginStreaks = {};
  final Map<String, DateTime> _lastLoginDates = {};
  final Map<String, Map<ActivityType, DateTime>> _activityCooldowns = {};

  static final Map<ActivityType, Decimal> rewardAmounts = {
    ActivityType.dailyLogin: Decimal.fromDouble(0.01),
    ActivityType.createPost: Decimal.fromDouble(0.05),
    ActivityType.sendMessage: Decimal.fromDouble(0.001),
    ActivityType.likeContent: Decimal.fromDouble(0.001),
    ActivityType.shareContent: Decimal.fromDouble(0.002),
    ActivityType.uploadMusic: Decimal.fromDouble(0.10),
    ActivityType.uploadVideo: Decimal.fromDouble(0.15),
    ActivityType.uploadPodcast: Decimal.fromDouble(0.08),
    ActivityType.readArticle: Decimal.fromDouble(0.003),
    ActivityType.watchVideo: Decimal.fromDouble(0.004),
    ActivityType.joinSpace: Decimal.fromDouble(0.005),
    ActivityType.inviteFriend: Decimal.fromDouble(0.50),
    ActivityType.completeProfile: Decimal.fromDouble(0.10),
    ActivityType.streakBonus: Decimal.fromDouble(0.02),
    ActivityType.contentEngagement: Decimal.fromDouble(0.006),
    ActivityType.spaceVisit: Decimal.fromDouble(0.008),
    ActivityType.profileVisit: Decimal.fromDouble(0.002),
    ActivityType.commentPost: Decimal.fromDouble(0.003),
    ActivityType.followUser: Decimal.fromDouble(0.005),
    ActivityType.joinCommunity: Decimal.fromDouble(0.010),
    ActivityType.milestoneAchievement: Decimal.fromDouble(0.050),
    ActivityType.profileUpdate: Decimal.fromDouble(0.001),
  };

  @override
  Future<void> onInit() async {
    _currencyService = Get.find<CurrencyService>();
    await _initializeWallet();
    super.onInit();
  }

  Future<void> _initializeWallet() async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (!await walletExists()) {
      await createWallet();
    }
  }

  Future<WalletData> getUserBalance() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    final walletDoc = await _firestore
        .collection('wallets')
        .doc(user.uid)
        .get();

    if (!walletDoc.exists) {
      await createWallet();
      final newWalletDoc = await _firestore
          .collection('wallets')
          .doc(user.uid)
          .get();
      return _walletDocToWalletData(newWalletDoc);
    }

    return _walletDocToWalletData(walletDoc);
  }

  WalletData _walletDocToWalletData(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final balanceEunice = data['balance'] ?? 0;
    final balanceMNG = Decimal.fromBigInt(BigInt.from(balanceEunice));
    final lockedBalance = Decimal.fromBigInt(
      BigInt.from(data['locked_balance'] ?? 0),
    );

    return WalletData(
      balance: balanceMNG,
      address: data['address'] ?? '',
      currencyValues: _currencyService.getCurrencyValues(balanceMNG),
      lockedBalance: lockedBalance,
    );
  }

  Future<void> createWallet() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    final walletAddress = _generateWalletAddress(user.uid);

    await _firestore.collection("wallets").doc(user.uid).set({
      'address': walletAddress,
      'balance': 0,
      'locked_balance': 0,
      'created_at': FieldValue.serverTimestamp(),
      'user_id': user.uid,
      'user_email': user.email,
      'version': '2.0',
      'last_updated': FieldValue.serverTimestamp(),
    });

    print('✅ New wallet created: $walletAddress with 0 balance');
  }

  Future<TransactionResult> rewardForActivity(
    ActivityType activity, {
    String? contentId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    if (_isOnCooldown(user.uid, activity)) {
      throw Exception("Please wait before performing this activity again");
    }

    if (!_canPerformActivityToday(user.uid, activity)) {
      throw Exception("Daily limit reached for this activity");
    }

    final reward = _getActivityReward(activity);
    if (reward <= Decimal.zero) {
      throw Exception("Invalid activity reward");
    }

    Decimal finalReward = reward;
    if (activity == ActivityType.dailyLogin) {
      finalReward = _applyStreakBonus(user.uid, reward);
    }

    final result = await _mineCoins(
      user.uid,
      finalReward,
      activity.name,
      contentId: contentId,
    );

    _updateCooldown(user.uid, activity);
    _updateDailyActivity(user.uid, activity);

    return result;
  }

  bool _isOnCooldown(String userId, ActivityType activity) {
    final now = DateTime.now();
    final lastActivity = _activityCooldowns[userId]?[activity];
    if (lastActivity == null) return false;
    final Duration cooldown = _getCooldownDuration(activity);
    return now.difference(lastActivity) < cooldown;
  }

  Duration _getCooldownDuration(ActivityType activity) {
    switch (activity) {
      case ActivityType.likeContent:
      case ActivityType.sendMessage:
        return Duration(seconds: 10);
      case ActivityType.createPost:
      case ActivityType.shareContent:
        return Duration(minutes: 1);
      case ActivityType.dailyLogin:
        return Duration(hours: 22);
      default:
        return Duration(seconds: 30);
    }
  }

  void _updateCooldown(String userId, ActivityType activity) {
    if (!_activityCooldowns.containsKey(userId)) {
      _activityCooldowns[userId] = {};
    }
    _activityCooldowns[userId]![activity] = DateTime.now();
  }

  bool _canPerformActivityToday(String userId, ActivityType activity) {
    final dailyLimit = _getDailyLimit(activity);
    final todayCount = _getTodayActivityCount(userId, activity);
    return todayCount < dailyLimit;
  }

  int _getDailyLimit(ActivityType activity) {
    switch (activity) {
      case ActivityType.dailyLogin:
        return 1;
      case ActivityType.likeContent:
        return 50;
      case ActivityType.sendMessage:
        return 100;
      case ActivityType.createPost:
        return 10;
      case ActivityType.shareContent:
        return 20;
      case ActivityType.readArticle:
        return 30;
      case ActivityType.watchVideo:
        return 25;
      default:
        return 100;
    }
  }

  int _getTodayActivityCount(String userId, ActivityType activity) {
    return _dailyRewardCount['$userId-${activity.name}'] ?? 0;
  }

  void _updateDailyActivity(String userId, ActivityType activity) {
    final key = '$userId-${activity.name}';
    _dailyRewardCount[key] = (_dailyRewardCount[key] ?? 0) + 1;
  }

  Decimal _applyStreakBonus(String userId, Decimal baseReward) {
    final today = DateTime.now();
    final lastLogin = _lastLoginDates[userId];

    if (lastLogin == null) {
      _loginStreaks[userId] = 1;
      _lastLoginDates[userId] = today;
      return baseReward;
    }

    final yesterday = today.subtract(Duration(days: 1));
    final isConsecutive =
        lastLogin.day == yesterday.day &&
        lastLogin.month == yesterday.month &&
        lastLogin.year == yesterday.year;

    if (isConsecutive) {
      _loginStreaks[userId] = (_loginStreaks[userId] ?? 0) + 1;
    } else {
      _loginStreaks[userId] = 1;
    }

    _lastLoginDates[userId] = today;

    final streak = _loginStreaks[userId]!;
    final bonusMultiplier = Decimal.fromDouble(min(streak * 0.1, 1.0));
    final bonus = baseReward * bonusMultiplier;

    return baseReward + bonus;
  }

  Decimal _getActivityReward(ActivityType activity) {
    return rewardAmounts[activity] ?? Decimal.zero;
  }

  int getUserStreak(String userId) {
    return _loginStreaks[userId] ?? 0;
  }

  Map<String, dynamic> getRewardInfo(ActivityType activity) {
    final reward = rewardAmounts[activity] ?? Decimal.zero;
    final cooldown = _getCooldownDuration(activity);
    final dailyLimit = _getDailyLimit(activity);

    return {
      'amount': reward,
      'cooldown': cooldown,
      'dailyLimit': dailyLimit,
      'description': _getActivityDescription(activity),
    };
  }

  String _getActivityDescription(ActivityType activity) {
    switch (activity) {
      case ActivityType.dailyLogin:
        return 'Daily login reward';
      case ActivityType.createPost:
        return 'Create a new post';
      case ActivityType.sendMessage:
        return 'Send a message';
      case ActivityType.likeContent:
        return 'Like content';
      case ActivityType.shareContent:
        return 'Share content';
      case ActivityType.uploadMusic:
        return 'Upload music';
      case ActivityType.uploadVideo:
        return 'Upload video';
      case ActivityType.uploadPodcast:
        return 'Upload podcast';
      case ActivityType.readArticle:
        return 'Read article';
      case ActivityType.watchVideo:
        return 'Watch video';
      case ActivityType.joinSpace:
        return 'Join community space';
      case ActivityType.inviteFriend:
        return 'Invite a friend';
      case ActivityType.completeProfile:
        return 'Complete your profile';
      case ActivityType.streakBonus:
        return 'Login streak bonus';
      case ActivityType.contentEngagement:
        return 'Content engagement';
      default:
        return 'Activity reward';
    }
  }

  Future<TransactionResult> _mineCoins(
    String userId,
    Decimal amount,
    String activity, {
    String? contentId,
  }) async {
    final walletRef = _firestore.collection('wallets').doc(userId);
    final amountEunice = amount.toSatoshis().toInt();
    final transactionId = _generateTransactionId();

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(walletRef);
        if (!snapshot.exists) {
          throw Exception("Wallet not found");
        }

        final currentBalance = Decimal.fromBigInt(
          BigInt.from(snapshot['balance']),
        );
        final newBalance = currentBalance + amount;

        transaction.update(walletRef, {
          'balance': newBalance.toSatoshis().toInt(),
          'updated_at': FieldValue.serverTimestamp(),
          'last_activity': activity,
        });
      });

      await _recordTransaction(
        userId: userId,
        type: TransactionType.reward,
        amount: amount.toDouble(),
        memo: 'Reward for $activity',
        transactionId: transactionId,
        contentId: contentId,
      );

      final blockchainTransaction = MangoTransaction(
        sender: 'ACTIVITY_REWARD',
        receiver: userId,
        amount: amountEunice,
        transactionId: transactionId,
      );

      blockchain.addTransaction(blockchainTransaction);

      return TransactionResult(
        success: true,
        transactionId: transactionId,
        amount: amount,
        fee: Decimal.zero,
        total: amount,
      );
    } catch (e) {
      await _recordTransaction(
        userId: userId,
        type: TransactionType.failed,
        amount: amount.toDouble(),
        error: e.toString(),
        transactionId: transactionId,
      );
      rethrow;
    }
  }

  Future<void> _recordTransaction({
    required String userId,
    required TransactionType type,
    required double amount,
    double? fee,
    String? fromAddress,
    String? toAddress,
    String? memo,
    String? error,
    required String transactionId,
    String? contentId,
  }) async {
    try {
      await _firestore.collection('transactions').doc(transactionId).set({
        'transaction_id': transactionId,
        'user_id': userId,
        'type': type.toString().split('.').last,
        'amount': amount,
        'fee': fee,
        'from_address': fromAddress,
        'to_address': toAddress,
        'memo': memo ?? 'Transaction',
        'error': error,
        'content_id': contentId,
        'status': error == null ? 'completed' : 'failed',
        'timestamp': FieldValue.serverTimestamp(),
        'currency': 'MNG',
      });
    } catch (e) {
      print('Error recording transaction: $e');
    }
  }

  Future<void> onDailyLogin() async {
    try {
      await rewardForActivity(ActivityType.dailyLogin);
      print('✅ Daily login reward: ${dailyLoginReward.toFixed(6)} MNG');
    } catch (e) {
      print('❌ Daily login reward failed: $e');
    }
  }

  Future<void> onCreatePost() async {
    try {
      await rewardForActivity(ActivityType.createPost);
      print('✅ Create post reward: ${createPostReward.toFixed(6)} MNG');
    } catch (e) {
      print('❌ Create post reward failed: $e');
    }
  }

  Future<void> onSendMessage() async {
    try {
      await rewardForActivity(ActivityType.sendMessage);
      print('✅ Send message reward: ${sendMessageReward.toFixed(6)} MNG');
    } catch (e) {
      print('❌ Send message reward failed: $e');
    }
  }

  Future<void> onLikeContent() async {
    try {
      await rewardForActivity(ActivityType.likeContent);
      print('✅ Like content reward: ${likeContentReward.toFixed(6)} MNG');
    } catch (e) {
      print('❌ Like content reward failed: $e');
    }
  }

  Future<void> onShareContent() async {
    try {
      await rewardForActivity(ActivityType.shareContent);
      print('✅ Share content reward: ${shareContentReward.toFixed(6)} MNG');
    } catch (e) {
      print('❌ Share content reward failed: $e');
    }
  }

  Future<void> onUploadMusic() async {
    try {
      await rewardForActivity(ActivityType.uploadMusic);
      print('✅ Upload music reward: ${uploadMusicReward.toFixed(6)} MNG');
    } catch (e) {
      print('❌ Upload music reward failed: $e');
    }
  }

  Future<void> onUploadVideo() async {
    try {
      await rewardForActivity(ActivityType.uploadVideo);
      print('✅ Upload video reward: ${uploadVideoReward.toFixed(6)} MNG');
    } catch (e) {
      print('❌ Upload video reward failed: $e');
    }
  }

  Future<List<TransactionRecord>> getTransactionHistory() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    try {
      final transactionsSnapshot = await _firestore
          .collection('transactions')
          .where('user_id', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      return transactionsSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return TransactionRecord(
          id: doc.id,
          transactionId: data['transaction_id'] ?? doc.id,
          type: _parseTransactionType(data['type'] ?? ''),
          amount: data['amount'] != null
              ? Decimal.fromDouble(data['amount'].toDouble())
              : Decimal.zero,
          fee: data['fee'] != null
              ? Decimal.fromDouble(data['fee'].toDouble())
              : Decimal.zero,
          fromAddress: data['from_address'],
          toAddress: data['to_address'],
          memo: data['memo'] ?? 'Transaction',
          status: data['status'] ?? 'completed',
          timestamp: (data['timestamp'] as Timestamp).toDate(),
          currency: data['currency'] ?? 'MNG',
        );
      }).toList();
    } catch (e) {
      print('Error fetching transaction history: $e');
      return [];
    }
  }

  TransactionType _parseTransactionType(String type) {
    switch (type) {
      case 'incoming':
        return TransactionType.incoming;
      case 'outgoing':
        return TransactionType.outgoing;
      case 'reward':
        return TransactionType.reward;
      case 'failed':
        return TransactionType.failed;
      default:
        return TransactionType.incoming;
    }
  }

  String _generateWalletAddress(String userId) {
    final bytes = utf8.encode(
      userId + DateTime.now().millisecondsSinceEpoch.toString(),
    );
    final digest = sha256.convert(bytes);
    return 'mango_${digest.toString().substring(0, 32)}';
  }

  Future<bool> walletExists() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final walletDoc = await _firestore
        .collection('wallets')
        .doc(user.uid)
        .get();
    return walletDoc.exists;
  }

  Future<TransactionResult> transferMangoCoins({
    required String receiverAddress,
    required Decimal amount,
    String? memo,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    if (amount < minTransactionAmount) {
      throw Exception(
        "Amount below minimum: ${minTransactionAmount.toFixed(6)} MNG",
      );
    }

    if (receiverAddress.isEmpty) {
      throw Exception("Receiver address is required");
    }

    final totalAmount = amount + transactionFee;
    final senderId = user.uid;

    final senderWalletRef = _firestore.collection('wallets').doc(senderId);
    final receiverWalletRef = _firestore
        .collection('wallets')
        .doc(receiverAddress);

    final transactionId = _generateTransactionId();

    try {
      await _firestore.runTransaction((transaction) async {
        final senderSnapshot = await transaction.get(senderWalletRef);
        final receiverSnapshot = await transaction.get(receiverWalletRef);

        if (!senderSnapshot.exists) {
          throw Exception("Sender wallet not found");
        }

        if (!receiverSnapshot.exists) {
          throw Exception("Receiver wallet not found: $receiverAddress");
        }

        final senderBalance = Decimal.fromBigInt(
          BigInt.from(senderSnapshot['balance']),
        );
        final receiverBalance = Decimal.fromBigInt(
          BigInt.from(receiverSnapshot['balance']),
        );

        if (senderBalance < totalAmount) {
          throw Exception(
            "Insufficient balance. Need ${totalAmount.toFixed(6)} MNG (including ${transactionFee.toFixed(6)} MNG fee)",
          );
        }

        transaction.update(senderWalletRef, {
          'balance': (senderBalance - totalAmount).toSatoshis().toInt(),
          'updated_at': FieldValue.serverTimestamp(),
        });

        transaction.update(receiverWalletRef, {
          'balance': (receiverBalance + amount).toSatoshis().toInt(),
          'updated_at': FieldValue.serverTimestamp(),
        });
      });

      await _recordTransaction(
        userId: senderId,
        type: TransactionType.outgoing,
        amount: -amount.toDouble(),
        fee: transactionFee.toDouble(),
        toAddress: receiverAddress,
        memo: memo,
        transactionId: transactionId,
      );

      await _recordTransaction(
        userId: receiverAddress,
        type: TransactionType.incoming,
        amount: amount.toDouble(),
        fromAddress: senderId,
        memo: memo,
        transactionId: transactionId,
      );

      final blockchainTransaction = MangoTransaction(
        sender: senderId,
        receiver: receiverAddress,
        amount: amount.toSatoshis().toInt(),
        transactionId: transactionId,
        fee: transactionFee.toSatoshis().toInt(),
      );

      blockchain.addTransaction(blockchainTransaction);

      return TransactionResult(
        success: true,
        transactionId: transactionId,
        amount: amount,
        fee: transactionFee,
        total: totalAmount,
      );
    } catch (e) {
      await _recordTransaction(
        userId: senderId,
        type: TransactionType.failed,
        amount: -amount.toDouble(),
        error: e.toString(),
        transactionId: transactionId,
      );
      rethrow;
    }
  }

  String _generateTransactionId() {
    final time = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999);
    return 'tx_${time}_$random';
  }

  Future<String> getWalletAddress() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    final walletDoc = await _firestore
        .collection('wallets')
        .doc(user.uid)
        .get();
    if (!walletDoc.exists) {
      throw Exception("Wallet not found");
    }

    return walletDoc['address'] ?? '';
  }
}

class WalletData {
  final Decimal balance;
  final String address;
  final Map<String, String> currencyValues;
  final Decimal lockedBalance;

  WalletData({
    required this.balance,
    required this.address,
    required this.currencyValues,
    required this.lockedBalance,
  });
}

class TransactionRecord {
  final String id;
  final String transactionId;
  final TransactionType type;
  final Decimal amount;
  final Decimal fee;
  final String? fromAddress;
  final String? toAddress;
  final String? memo;
  final String status;
  final DateTime timestamp;
  final String currency;

  TransactionRecord({
    required this.id,
    required this.transactionId,
    required this.type,
    required this.amount,
    required this.fee,
    this.fromAddress,
    this.toAddress,
    this.memo,
    required this.status,
    required this.timestamp,
    required this.currency,
  });

  bool get isCredit => amount > Decimal.zero;
  String get formattedAmount =>
      '${amount > Decimal.zero ? '+' : ''}${amount.toFixed(6)}';
}

class TransactionResult {
  final bool success;
  final String transactionId;
  final Decimal amount;
  final Decimal fee;
  final Decimal total;

  TransactionResult({
    required this.success,
    required this.transactionId,
    required this.amount,
    required this.fee,
    required this.total,
  });
}

enum TransactionType {
  incoming,
  outgoing,
  reward,
  failed,
  transfer,
  mining,
  trade,
  nft,
}

enum ActivityType {
  dailyLogin,
  createPost,
  sendMessage,
  likeContent,
  shareContent,
  uploadMusic,
  uploadVideo,
  completeProfile,
  inviteFriend,
  uploadPodcast,
  readArticle,
  watchVideo,
  joinSpace,
  streakBonus,
  contentEngagement,
  spaceVisit,
  profileVisit,
  commentPost,
  followUser,
  joinCommunity,
  milestoneAchievement,
  profileUpdate,
}
