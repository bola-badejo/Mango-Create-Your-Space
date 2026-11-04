
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mango/Wallet/data/content_mining_services.dart';
import 'package:mango/Wallet/services/wallet_services.dart';

class CreatorPayoutOrchestrator extends GetxService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ContentMiningService _miningService = Get.find<ContentMiningService>();
  final WalletService _walletService = Get.find<WalletService>();

  Future<CreatorPayoutOrchestrator> init() async {
    print('✅ Creator Payout Orchestrator Initialized');
    
    _startDailyPayoutScheduler();
    return this;
  }

  void _startDailyPayoutScheduler() {
    
    Future.delayed(Duration(hours: 1), () {
      _checkAndProcessDailyPayouts();
      _startDailyPayoutScheduler(); 
    });
  }

  Future<void> _checkAndProcessDailyPayouts() async {
    final now = DateTime.now();
    
    if (now.hour == 2 || true) { 
      print('🔄 Starting daily creator payouts...');
      await _processCreatorPayouts();
    }
  }

  Future<void> _processCreatorPayouts() async {
    try {
      
      final twentyFourHoursAgo = DateTime.now().subtract(Duration(hours: 24));
      
      final miningActivities = await _firestore
          .collection('mining_activities')
          .where('timestamp', isGreaterThan: twentyFourHoursAgo)
          .get();

      
      final creatorEarnings = <String, int>{};
      
      for (final doc in miningActivities.docs) {
        final data = doc.data();
        final creatorId = data['creator_id'] as String? ?? '';
        final creatorShare = (data['creator_share'] as num?)?.toInt() ?? 0;
        
        if (creatorId.isNotEmpty) {
          creatorEarnings[creatorId] = (creatorEarnings[creatorId] ?? 0) + creatorShare;
        }
      }

      
      for (final entry in creatorEarnings.entries) {
        final creatorId = entry.key;
        final totalEarnings = entry.value;
        
        if (totalEarnings > 0) {
          await _processSingleCreatorPayout(creatorId, totalEarnings);
        }
      }

      print('✅ Daily creator payouts completed for ${creatorEarnings.length} creators');
    } catch (e) {
      print('❌ Creator payout error: $e');
    }
  }

  Future<void> _processSingleCreatorPayout(String creatorId, int earnings) async {
    try {
      
      await _firestore.collection('creator_payouts').add({
        'creator_id': creatorId,
        'amount': earnings,
        'timestamp': FieldValue.serverTimestamp(),
        'period': 'daily',
        'status': 'completed',
      });

      print('💰 Creator $creatorId paid: $earnings sats');
    } catch (e) {
      
      await _firestore.collection('failed_payouts').add({
        'creator_id': creatorId,
        'amount': earnings,
        'error': e.toString(),
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      print('❌ Failed payout for creator $creatorId: $e');
    }
  }

  
  Future<void> triggerManualPayout(String creatorId) async {
    print('🔧 Manual payout triggered for creator: $creatorId');
    await _processSingleCreatorPayout(creatorId, 1000000); 
  }

  
  Future<Map<String, dynamic>> getCreatorEarningsSummary(String creatorId) async {
    final weekAgo = DateTime.now().subtract(Duration(days: 7));
    
    final weeklyEarnings = await _firestore
        .collection('mining_activities')
        .where('creator_id', isEqualTo: creatorId)
        .where('timestamp', isGreaterThan: weekAgo)
        .get();

    int totalEarnings = 0;
    int contentCount = 0;
    
    for (final doc in weeklyEarnings.docs) {
      final creatorShare = (doc['creator_share'] as num?)?.toInt() ?? 0;
      totalEarnings += creatorShare;
      contentCount++;
    }

    return {
      'creator_id': creatorId,
      'weekly_earnings': totalEarnings,
      'content_count': contentCount,
      'average_per_content': contentCount > 0 ? totalEarnings ~/ contentCount : 0,
      'last_payout': await _getLastPayoutDate(creatorId),
    };
  }

  Future<DateTime?> _getLastPayoutDate(String creatorId) async {
    final lastPayout = await _firestore
        .collection('creator_payouts')
        .where('creator_id', isEqualTo: creatorId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (lastPayout.docs.isNotEmpty) {
      return (lastPayout.docs.first['timestamp'] as Timestamp).toDate();
    }
    
    return null;
  }
}