// Starts and ends server-timed consumption sessions (listening, watching,
// visiting a Space). The server measures the time on its own clock, so the
// app only says "started" and "stopped"; it never reports a duration.
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'mango_ledger_client.dart';

class MangoActivityTracker {
  MangoActivityTracker._();

  static String? _current;

  /// The Space the user is currently inside, if any. Content played while
  /// inside a Space credits the Space owner too.
  static String? activeSpaceId;

  /// Content types the ledger understands: song, podcast, movie, space.
  static const Set<String> supportedTypes = {'song', 'podcast', 'movie', 'space'};

  /// Begins a session; any open session is ended and credited first.
  static Future<void> start({
    required String contentType,
    required String contentId,
    String? spaceId,
  }) async {
    if (!supportedTypes.contains(contentType) || contentId.isEmpty) return;
    spaceId ??= contentType == 'space' ? null : activeSpaceId;
    final key = '$contentType:$contentId:${spaceId ?? ''}';
    if (_current == key) return;
    _current = key;
    try {
      await MangoLedgerClient.instance.startSession(
        contentType: contentType,
        contentId: contentId,
        spaceId: spaceId,
      );
    } catch (e) {
      debugPrint('MangoChain: could not start session: $e');
    }
  }

  /// Ends the open session, if any. Safe to call repeatedly.
  static Future<void> stop() async {
    if (_current == null) return;
    _current = null;
    try {
      await MangoLedgerClient.instance.endSession();
    } catch (e) {
      debugPrint('MangoChain: could not end session: $e');
    }
  }

  /// Fire-and-forget helpers for UI code.
  static void startInBackground({
    required String contentType,
    required String contentId,
    String? spaceId,
  }) =>
      unawaited(start(contentType: contentType, contentId: contentId, spaceId: spaceId));

  static void stopInBackground() => unawaited(stop());
}
