// WalletService backed by MangoChain.
//
// Balances live in `ledger_accounts/{uid}` and are written only by Cloud
// Functions. This service reads them and asks the server to act: open an
// account, check in, transfer. Activity rewards are earned automatically
// when the server sees real activity, and minted into MNG when each hourly
// epoch closes, so nothing here can award coins directly.
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:mango/Wallet/data/currency_service.dart';
import 'package:mango/Wallet/data/decimal.dart';
import 'package:mango/Wallet/ledger/mango_ledger_client.dart';

class WalletService extends GetxService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MangoLedgerClient _ledger = MangoLedgerClient.instance;
  late final CurrencyService _currencyService;

  static final Decimal initialBalance = Decimal.zero;
  static final Decimal minTransactionAmount = Decimal.fromBigInt(BigInt.from(100)); // 0.000001 MNG
  static final Decimal transactionFee = Decimal.fromBigInt(BigInt.from(100000)); // 0.001 MNG, burned
  static final Decimal dailyLoginReward = Decimal.fromBigInt(BigInt.from(1000000)); // up to 0.01 MNG

  /// What each activity can earn the person doing it, in points (1 point
  /// is worth at most 0.01 MNG once its epoch closes). Creators earn the
  /// larger share of engagement with their work.
  static const Map<ActivityType, int> actorPointsUpTo = {
    ActivityType.dailyLogin: 2000,
    ActivityType.createPost: 5000,
    ActivityType.likeContent: 200,
    ActivityType.followUser: 400,
    ActivityType.watchVideo: 2500,
    ActivityType.contentEngagement: 1000,
    ActivityType.spaceVisit: 200,
    ActivityType.joinSpace: 200,
    ActivityType.streakBonus: 1000,
  };

  String _address = '';
  int _streak = 0;

  @override
  Future<void> onInit() async {
    _currencyService = Get.find<CurrencyService>();
    super.onInit();
    // Open the account in the background; the wallet screen retries.
    if (_auth.currentUser != null) {
      createWallet().catchError((_) {});
    }
  }

  DocumentReference<Map<String, dynamic>> _accountRef(String uid) =>
      _firestore.collection('ledger_accounts').doc(uid);

  Decimal _units(dynamic value) {
    final text = value?.toString() ?? '0';
    return Decimal.fromBigInt(BigInt.tryParse(text) ?? BigInt.zero);
  }

  Future<WalletData> getUserBalance() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    var snap = await _accountRef(user.uid).get();
    if (!snap.exists) {
      await createWallet();
      snap = await _accountRef(user.uid).get();
    }
    final data = snap.data() ?? const <String, dynamic>{};
    final balance = _units(data['balance']);
    _address = (data['address'] ?? '') as String;
    _streak = (data['streak'] ?? 0) as int;
    return WalletData(
      balance: balance,
      address: _address,
      currencyValues: _currencyService.getCurrencyValues(balance),
      lockedBalance: Decimal.zero,
    );
  }

  /// Opens the account on the server (idempotent).
  Future<void> createWallet() async {
    final account = await _ledger.openAccount();
    _address = (account['address'] ?? '') as String;
  }

  Future<bool> walletExists() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    return (await _accountRef(user.uid).get()).exists;
  }

  /// Daily check-in is the only reward the app can ask for. Everything else
  /// is credited by the server when the activity really happens.
  Future<TransactionResult> rewardForActivity(
    ActivityType activity, {
    String? contentId,
  }) async {
    if (activity != ActivityType.dailyLogin) {
      throw Exception(
        '${_describe(activity)} is rewarded automatically when you do it in '
        'the app. Your points become MNG when the current hour closes.',
      );
    }
    final res = await _ledger.checkIn();
    if (res['credited'] != true) {
      throw Exception(_reason(res['reason']?.toString()));
    }
    _streak = (res['streak'] ?? _streak) as int;
    final points = (res['points'] is Map) ? (res['points'] as Map).values.fold<int>(0, (a, b) => a + (b as int)) : 0;
    return TransactionResult(
      success: true,
      transactionId: (res['eventId'] ?? '') as String,
      amount: Decimal.zero,
      fee: Decimal.zero,
      total: Decimal.zero,
      points: points,
      message: 'Checked in: +${(points / 1000).toStringAsFixed(1)} points '
          '(day $_streak streak). They become MNG when this hour closes.',
    );
  }

  String _reason(String? reason) {
    switch (reason) {
      case 'duplicate':
        return "You've already checked in today. Come back tomorrow.";
      case 'not_eligible':
        return 'Rewards start once your account is verified and at least a day old.';
      case 'daily_cap':
        return "You've reached today's limit for this activity.";
      default:
        return 'No reward this time.';
    }
  }

  int getUserStreak(String userId) => _streak;

  Map<String, dynamic> getRewardInfo(ActivityType activity) {
    final points = actorPointsUpTo[activity] ?? 0;
    // Ceiling value: 1 point is worth at most 0.01 MNG (1,000,000 units).
    final upTo = Decimal.fromBigInt(BigInt.from(points) * BigInt.from(1000));
    return {
      'amount': upTo,
      'points': points,
      'cooldown': Duration.zero,
      'dailyLimit': 0,
      'description': _describe(activity),
      'automatic': activity != ActivityType.dailyLogin,
    };
  }

  String _describe(ActivityType activity) {
    switch (activity) {
      case ActivityType.dailyLogin:
        return 'Daily check-in';
      case ActivityType.createPost:
        return 'Posting';
      case ActivityType.likeContent:
        return 'Liking posts';
      case ActivityType.followUser:
        return 'Following creators';
      case ActivityType.watchVideo:
        return 'Watching films';
      case ActivityType.readArticle:
        return 'Reading';
      case ActivityType.shareContent:
        return 'Sharing';
      case ActivityType.spaceVisit:
      case ActivityType.joinSpace:
        return 'Spending time in Spaces';
      case ActivityType.contentEngagement:
        return 'Listening and watching';
      default:
        return 'This activity';
    }
  }

  // Kept for existing callers. Posts, likes and follows are observed by the
  // server directly, so these do nothing except the daily check-in.
  Future<void> onDailyLogin() async {
    try {
      await rewardForActivity(ActivityType.dailyLogin);
    } catch (_) {}
  }

  Future<void> onCreatePost() async {}
  Future<void> onSendMessage() async {}
  Future<void> onLikeContent() async {}
  Future<void> onShareContent() async {}
  Future<void> onUploadMusic() async {}
  Future<void> onUploadVideo() async {}

  Future<List<TransactionRecord>> getTransactionHistory() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    if (_address.isEmpty) {
      final snap = await _accountRef(user.uid).get();
      _address = (snap.data()?['address'] ?? '') as String;
    }
    if (_address.isEmpty) return [];
    try {
      final col = _firestore.collection('ledger_tx');
      final results = await Future.wait([
        col.where('from', isEqualTo: _address).orderBy('seq', descending: true).limit(50).get(),
        col.where('to', isEqualTo: _address).orderBy('seq', descending: true).limit(50).get(),
      ]);
      final docs = {for (final q in results) for (final d in q.docs) d.id: d.data()};
      final records = docs.entries.map((e) => _toRecord(e.key, e.value)).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return records.take(50).toList();
    } catch (e) {
      // ignore: avoid_print
      print('Error fetching transaction history: $e');
      return [];
    }
  }

  TransactionRecord _toRecord(String id, Map<String, dynamic> d) {
    final amount = _units(d['amount']);
    final fee = _units(d['fee']);
    final outgoing = d['from'] == _address;
    final type = d['type'] == 'reward'
        ? TransactionType.reward
        : outgoing
            ? TransactionType.outgoing
            : TransactionType.incoming;
    final sealed = d['sealed'] == true;
    final memo = d['type'] == 'reward'
        ? 'Activity reward (epoch ${d['epoch']})'
        : (d['memo'] ?? (outgoing ? 'Sent' : 'Received')) as String;
    return TransactionRecord(
      id: id,
      transactionId: id,
      type: type,
      amount: outgoing ? Decimal.zero - amount : amount,
      fee: outgoing ? fee : Decimal.zero,
      fromAddress: d['from'] as String?,
      toAddress: d['to'] as String?,
      memo: memo,
      status: sealed ? 'confirmed in block ${d['height']}' : 'pending',
      timestamp: DateTime.fromMillisecondsSinceEpoch((d['ts'] ?? 0) as int),
      currency: 'MNG',
    );
  }

  String _newIdempotencyKey() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  /// Sends MNG. [receiverAddress] is an mng1… address or a user id.
  Future<TransactionResult> transferMangoCoins({
    required String receiverAddress,
    required Decimal amount,
    String? memo,
  }) async {
    if (_auth.currentUser == null) throw Exception('User not logged in');
    if (amount < minTransactionAmount) {
      throw Exception('Amount below minimum: ${minTransactionAmount.toFixed(6)} MNG');
    }
    if (receiverAddress.trim().isEmpty) throw Exception('Receiver address is required');
    final res = await _ledger.transfer(
      to: receiverAddress.trim(),
      amountUnits: amount.toSatoshis(),
      memo: memo,
      idempotencyKey: _newIdempotencyKey(),
    );
    final fee = _units(res['fee']);
    return TransactionResult(
      success: true,
      transactionId: (res['txId'] ?? '') as String,
      amount: amount,
      fee: fee,
      total: amount + fee,
    );
  }

  Future<String> getWalletAddress() async {
    if (_address.isNotEmpty) return _address;
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    final snap = await _accountRef(user.uid).get();
    if (!snap.exists) await createWallet();
    _address = ((await _accountRef(user.uid).get()).data()?['address'] ?? '') as String;
    if (_address.isEmpty) throw Exception('Wallet not found');
    return _address;
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

  /// Points credited (for activity), which become MNG when the epoch closes.
  final int points;

  /// A message suitable to show the user, when the result needs explaining.
  final String? message;

  TransactionResult({
    required this.success,
    required this.transactionId,
    required this.amount,
    required this.fee,
    required this.total,
    this.points = 0,
    this.message,
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
