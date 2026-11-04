
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:mango/Wallet/services/wallet_services.dart';
import 'package:mango/Wallet/data/decimal.dart';

class PremiumFeatureManager extends GetxService {
  final WalletService _walletService = Get.find<WalletService>();
  
  
  final Map<String, Decimal> _premiumFeatures = {
    'ad_free_experience': Decimal.fromDouble(50.0),
    'hd_streaming': Decimal.fromDouble(25.0),
    'early_access_content': Decimal.fromDouble(30.0),
    'creator_verification_badge': Decimal.fromDouble(100.0),
    'custom_profile_themes': Decimal.fromDouble(15.0),
    'extended_upload_limit': Decimal.fromDouble(75.0),
    'priority_support': Decimal.fromDouble(40.0),
  };

  
  final Map<String, Set<String>> _userPurchases = {};

  Future<PremiumFeatureManager> init() async {
    print('✅ Premium Feature Manager Initialized');
    return this;
  }

  Future<PurchaseResult> purchaseFeature({
    required String userId,
    required String featureId,
  }) async {
    try {
      final featureCost = _premiumFeatures[featureId];
      if (featureCost == null) {
        return PurchaseResult(
          success: false,
          error: 'Feature not found: $featureId',
        );
      }

      
      final userBalance = await _walletService.getUserBalance();
      if (userBalance.balance < featureCost) {
        return PurchaseResult(
          success: false,
          error: 'Insufficient balance. Need ${featureCost.toFixed(6)} MNG',
        );
      }

      
      await _walletService.transferMangoCoins(
        receiverAddress: 'mango_premium_store', 
        amount: featureCost,
        memo: 'Premium feature: $featureId',
      );

      
      _userPurchases[userId] ??= {};
      _userPurchases[userId]!.add(featureId);

      
      await _recordFeaturePurchase(userId, featureId, featureCost);

      return PurchaseResult(
        success: true,
        featureId: featureId,
        cost: featureCost,
        purchaseDate: DateTime.now(),
      );
    } catch (e) {
      return PurchaseResult(
        success: false,
        error: 'Purchase failed: $e',
      );
    }
  }

  Future<void> _recordFeaturePurchase(
    String userId, 
    String featureId, 
    Decimal cost,
  ) async {
    final firestore = FirebaseFirestore.instance;
    
    await firestore.collection('premium_purchases').add({
      'user_id': userId,
      'feature_id': featureId,
      'cost': cost.toSatoshis().toInt(),
      'purchase_date': FieldValue.serverTimestamp(),
      'status': 'active',
    });
  }

  bool hasFeature(String userId, String featureId) {
    return _userPurchases[userId]?.contains(featureId) ?? false;
  }

  List<String> getUserFeatures(String userId) {
    return _userPurchases[userId]?.toList() ?? [];
  }

  Map<String, Decimal> getAvailableFeatures() {
    return Map.from(_premiumFeatures);
  }

  
  Future<void> grantTrialFeature(String userId, String featureId, Duration trialDuration) async {
    _userPurchases[userId] ??= {};
    _userPurchases[userId]!.add(featureId);

    
    Future.delayed(trialDuration, () {
      _userPurchases[userId]?.remove(featureId);
      print('⏰ Trial expired for user $userId: $featureId');
    });

    print('🎁 Trial granted: $featureId for user $userId');
  }
}

class PurchaseResult {
  final bool success;
  final String? featureId;
  final Decimal? cost;
  final DateTime? purchaseDate;
  final String? error;

  PurchaseResult({
    required this.success,
    this.featureId,
    this.cost,
    this.purchaseDate,
    this.error,
  });
}