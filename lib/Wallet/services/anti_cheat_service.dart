
import 'dart:math';

import 'package:get/get.dart';
import 'package:mango/Wallet/services/backend_api_service.dart';

class AntiCheatService extends GetxService {
  final BackendAPIService _apiService = Get.find<BackendAPIService>();
  
  
  final Map<String, Map<String, DateTime>> _userActivityTimestamps = {};
  final Map<String, Map<String, int>> _userActivityCounts = {};
  
  
  final Map<String, List<DateTime>> _userRewardPatterns = {};
  
  Future<AntiCheatService> init() async {
    print('✅ Anti-Cheat Service Initialized');
    return this;
  }
  
  bool checkActivityRateLimit({
    required String userId,
    required String activityType,
    required int maxPerMinute,
    required int maxPerHour,
  }) {
    final now = DateTime.now();
    final userKey = '$userId-$activityType';
    
    
    _userActivityTimestamps[userKey] ??= {};
    _userActivityCounts[userKey] ??= {'minute': 0, 'hour': 0};
    
    
    _userActivityTimestamps[userKey]!.removeWhere((_, timestamp) => 
        now.difference(timestamp) > Duration(hours: 1));
    
    
    final minuteCount = _userActivityTimestamps[userKey]!.values
        .where((timestamp) => now.difference(timestamp) < Duration(minutes: 1))
        .length;
    
    final hourCount = _userActivityTimestamps[userKey]!.values
        .where((timestamp) => now.difference(timestamp) < Duration(hours: 1))
        .length;
    
    
    if (minuteCount >= maxPerMinute || hourCount >= maxPerHour) {
      _reportSuspiciousActivity(
        userId: userId,
        activityType: activityType,
        reason: 'Rate limit exceeded',
        metadata: {
          'minute_count': minuteCount,
          'hour_count': hourCount,
          'max_per_minute': maxPerMinute,
          'max_per_hour': maxPerHour,
        },
      );
      return false;
    }
    
    
    _userActivityTimestamps[userKey]![now.millisecondsSinceEpoch.toString()] = now;
    return true;
  }
  
  bool detectRewardFarmingPatterns({
    required String userId,
    required String activityType,
    required double rewardAmount,
  }) {
    final now = DateTime.now();
    _userRewardPatterns[userId] ??= [];
    
    
    _userRewardPatterns[userId]!.add(now);
    
    
    _userRewardPatterns[userId]!.removeWhere((timestamp) => 
        now.difference(timestamp) > Duration(hours: 24));
    
    
    final recentRewards = _userRewardPatterns[userId]!;
    
    
    if (recentRewards.length >= 50) {
      final first = recentRewards.first;
      final last = recentRewards.last;
      final duration = last.difference(first);
      
      if (duration.inMinutes < 60) { 
        _reportSuspiciousActivity(
          userId: userId,
          activityType: activityType,
          reason: 'High frequency reward pattern detected',
          metadata: {
            'rewards_count': recentRewards.length,
            'time_span_minutes': duration.inMinutes,
            'reward_amount': rewardAmount,
          },
        );
        return false;
      }
    }
    
    
    if (recentRewards.length >= 10) {
      final intervals = <int>[];
      for (int i = 1; i < recentRewards.length; i++) {
        intervals.add(recentRewards[i].difference(recentRewards[i-1]).inSeconds);
      }
      
      
      final avgInterval = intervals.reduce((a, b) => a + b) / intervals.length;
      final variance = intervals.map((i) => (i - avgInterval) * (i - avgInterval))
          .reduce((a, b) => a + b) / intervals.length;
      final stdDev = sqrt(variance);
      
      if (stdDev < 5.0) { 
        _reportSuspiciousActivity(
          userId: userId,
          activityType: activityType,
          reason: 'Regular interval pattern detected (possible bot)',
          metadata: {
            'average_interval': avgInterval,
            'standard_deviation': stdDev,
            'reward_amount': rewardAmount,
          },
        );
        return false;
      }
    }
    
    return true;
  }
  
  
  bool validateContentConsumption({
    required String contentType,
    required int durationSeconds,
    required int fileSize,
  }) {
    
    final minDurations = {
      'song': 30, 
      'movie': 300, 
      'book': 60, 
      'podcast': 60, 
    };
    
    final minDuration = minDurations[contentType] ?? 30;
    
    if (durationSeconds < minDuration) {
      return false; 
    }
    
    
    if (fileSize > 0) {
      final bytesPerSecond = fileSize / durationSeconds;
      if (bytesPerSecond < 1000) { 
        return false;
      }
    }
    
    return true;
  }
  
  Future<void> _reportSuspiciousActivity({
    required String userId,
    required String activityType,
    required String reason,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      await _apiService.reportSuspiciousActivity(
        userId: userId,
        activityType: activityType,
        reason: reason,
        metadata: metadata,
      );
    } catch (e) {
      
      print('🚨 SUSPICIOUS ACTIVITY: User $userId - $reason');
    }
  }
}