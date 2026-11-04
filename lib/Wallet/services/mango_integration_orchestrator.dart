
import 'package:get/get.dart';
import 'package:mango/Wallet/services/content_consumption_verification.dart';
import 'package:mango/Wallet/services/creator_pay_out_orchestrator.dart';
import 'package:mango/Wallet/services/internal_dex_integrator.dart';
import 'package:mango/Wallet/services/premium_feature_manager.dart';
import 'package:mango/Wallet/services/social_reward_integrator.dart';

class MangoIntegrationOrchestrator extends GetxService {
  late SocialRewardIntegrator _socialRewardIntegrator;
  late CreatorPayoutOrchestrator _creatorPayoutOrchestrator;
  late PremiumFeatureManager _premiumFeatureManager;
  late ContentVerificationService _contentVerificationService;
  late DEXTradingIntegrator _dexTradingIntegrator;

  Future<MangoIntegrationOrchestrator> init() async {
    print('🚀 Initializing Mango Integration Orchestrator...');
    
    
    _socialRewardIntegrator = await Get.putAsync(() => SocialRewardIntegrator().init());
    _creatorPayoutOrchestrator = await Get.putAsync(() => CreatorPayoutOrchestrator().init());
    _premiumFeatureManager = await Get.putAsync(() => PremiumFeatureManager().init());
    _contentVerificationService = await Get.putAsync(() => ContentVerificationService().init());
    _dexTradingIntegrator = await Get.putAsync(() => DEXTradingIntegrator().init());

    print('✅ All Mango services integrated successfully!');
    return this;
  }

  
  SocialRewardIntegrator get socialRewards => _socialRewardIntegrator;
  CreatorPayoutOrchestrator get creatorPayouts => _creatorPayoutOrchestrator;
  PremiumFeatureManager get premiumFeatures => _premiumFeatureManager;
  ContentVerificationService get contentVerification => _contentVerificationService;
  DEXTradingIntegrator get dexTrading => _dexTradingIntegrator;
}