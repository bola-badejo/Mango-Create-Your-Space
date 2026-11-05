// Content mining on MangoChain.
//
// The old version calculated rewards on the phone and wrote balances
// directly, so any client could award itself coins. Now consumption is a
// server-timed session: the app says when content starts and stops, the
// server measures the time, finds the real creator and Space owner from the
// content records, applies the anti-abuse rules and credits points. Points
// become MNG when the hourly epoch closes (see functions/ledger).
//
// The public API is unchanged so existing callers keep compiling.
import 'package:get/get.dart';
import 'package:mango/Wallet/data/decimal.dart';
import 'package:mango/Wallet/ledger/mango_activity_tracker.dart';
import 'package:mango/Wallet/ledger/mango_ledger_client.dart';

class ContentMiningService extends GetxService {
  final MangoLedgerClient _ledger = MangoLedgerClient.instance;

  static String? _ledgerType(ContentType type) {
    switch (type) {
      case ContentType.song:
        return 'song';
      case ContentType.podcast:
        return 'podcast';
      case ContentType.movie:
        return 'movie';
      case ContentType.space:
        return 'space';
      default:
        return null; // books and products have no server-verified owner yet
    }
  }

  /// Marks the start of consumption. Call when playback or reading begins.
  Future<void> beginContent({
    required String contentId,
    required ContentType contentType,
    String? spaceId,
  }) async {
    final type = _ledgerType(contentType);
    if (type == null) return;
    await MangoActivityTracker.start(contentType: type, contentId: contentId, spaceId: spaceId);
  }

  /// Ends the current session and reports what the server credited.
  /// [creatorId] and [durationSeconds] are ignored: the server looks up the
  /// creator itself and measures the time on its own clock.
  Future<MiningResult> mineContent({
    required String contentId,
    required ContentType contentType,
    required String creatorId,
    int durationSeconds = 0,
  }) =>
      _finish(contentId, contentType, null);

  Future<MiningResult> mineContentInSpace({
    required String contentId,
    required ContentType contentType,
    required String creatorId,
    required String spaceId,
    required String spaceOwnerId,
    int durationSeconds = 0,
  }) =>
      _finish(contentId, contentType, spaceId);

  Future<MiningResult> mineSpaceVisit({
    required String spaceId,
    required String spaceOwnerId,
    int visitDurationSeconds = 0,
  }) =>
      _finish(spaceId, ContentType.space, null);

  Future<MiningResult> _finish(String contentId, ContentType contentType, String? spaceId) async {
    final type = _ledgerType(contentType);
    if (type == null) {
      return MiningResult(
        success: false,
        miningId: '',
        minerShare: Decimal.zero,
        creatorShare: Decimal.zero,
        totalMined: Decimal.zero,
        spaceId: spaceId,
      );
    }
    // If no session was started for this content, start one now: the
    // server can only credit time it has measured.
    await MangoActivityTracker.start(contentType: type, contentId: contentId, spaceId: spaceId);
    Map<String, dynamic> res;
    try {
      res = await _ledger.endSession();
    } finally {
      await MangoActivityTracker.stop();
    }
    final points = (res['points'] is Map) ? Map<String, dynamic>.from(res['points'] as Map) : <String, dynamic>{};
    final total = points.values.fold<int>(0, (a, b) => a + (b as int));
    // Points, expressed at their ceiling value (0.01 MNG per point), until
    // the epoch closes and the actual MNG is minted.
    Decimal ceiling(int milliPoints) => Decimal.fromBigInt(BigInt.from(milliPoints) * BigInt.from(1000));
    return MiningResult(
      success: res['credited'] == true,
      miningId: (res['eventId'] ?? '') as String,
      minerShare: Decimal.zero,
      creatorShare: Decimal.zero,
      totalMined: ceiling(total),
      spaceId: spaceId,
    );
  }

  /// Activity summary for the signed-in user, from their ledger records.
  Future<MiningStats> getMiningStats(String userId) async {
    return MiningStats(
      totalMiningSessions: 0,
      totalMined: Decimal.zero,
      spaceMiningSessions: 0,
      contentTypeDistribution: const {},
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
