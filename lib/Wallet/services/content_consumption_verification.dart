
import 'package:get/get.dart';
import 'package:mango/Wallet/services/anti_cheat_service.dart';

class ContentVerificationService extends GetxService {
  final AntiCheatService _antiCheatService = Get.find<AntiCheatService>();
  
  
  final Map<String, Map<String, DateTime>> _userContentConsumption = {};
  final Map<String, Map<String, int>> _userContentDuration = {};

  Future<ContentVerificationService> init() async {
    print('✅ Content Verification Service Initialized');
    return this;
  }

  VerificationResult verifyContentConsumption({
    required String userId,
    required String contentId,
    required String contentType,
    required int reportedDuration,
    required int fileSize,
  }) {
    final now = DateTime.now();
    
    if (!_antiCheatService.validateContentConsumption(
      contentType: contentType,
      durationSeconds: reportedDuration,
      fileSize: fileSize,
    )) {
      return VerificationResult(
        isValid: false,
        reason: 'Invalid consumption parameters',
      );
    }
    
    if (!_antiCheatService.checkActivityRateLimit(
      userId: userId,
      activityType: 'content_$contentType',
      maxPerMinute: 5,
      maxPerHour: 50,
    )) {
      return VerificationResult(
        isValid: false,
        reason: 'Content consumption rate limit exceeded',
      );
    }

    if (!_antiCheatService.detectRewardFarmingPatterns(
      userId: userId,
      activityType: 'content_consumption',
      rewardAmount: _calculateExpectedReward(contentType, reportedDuration),
    )) {
      return VerificationResult(
        isValid: false,
        reason: 'Suspicious consumption pattern detected',
      );
    }


    _trackUserConsumption(userId, contentId, contentType, reportedDuration, now);

    return VerificationResult(
      isValid: true,
      reason: 'Consumption verified',
    );
  }

  void _trackUserConsumption(
    String userId,
    String contentId,
    String contentType,
    int duration,
    DateTime timestamp,
  ) {
    _userContentConsumption[userId] ??= {};
    _userContentDuration[userId] ??= {};

    _userContentConsumption[userId]![contentId] = timestamp;
    _userContentDuration[userId]![contentId] = duration;
  }

  double _calculateExpectedReward(String contentType, int duration) {
    
    final baseRates = {
      'song': 0.02,
      'movie': 0.05,
      'book': 0.03,
      'podcast': 0.015,
    };

    final baseRate = baseRates[contentType] ?? 0.01;
    return baseRate * (duration / 60); 
  }

  
  ConsumptionAnalytics getUserConsumptionAnalytics(String userId) {
    final userConsumption = _userContentConsumption[userId] ?? {};
    final userDurations = _userContentDuration[userId] ?? {};

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    
    final todayItems = userConsumption.entries
        .where((entry) => entry.value.isAfter(todayStart))
        .length;

    final totalDuration = userDurations.values.fold(0, (sum, duration) => sum + duration);

    return ConsumptionAnalytics(
      userId: userId,
      totalContentConsumed: userConsumption.length,
      todayContentConsumed: todayItems,
      totalConsumptionTime: totalDuration,
      averageSessionDuration: userConsumption.isNotEmpty ? totalDuration ~/ userConsumption.length : 0,
    );
  }
}

class VerificationResult {
  final bool isValid;
  final String reason;

  VerificationResult({
    required this.isValid,
    required this.reason,
  });
}

class ConsumptionAnalytics {
  final String userId;
  final int totalContentConsumed;
  final int todayContentConsumed;
  final int totalConsumptionTime; 
  final int averageSessionDuration; 

  ConsumptionAnalytics({
    required this.userId,
    required this.totalContentConsumed,
    required this.todayContentConsumed,
    required this.totalConsumptionTime,
    required this.averageSessionDuration,
  });
}