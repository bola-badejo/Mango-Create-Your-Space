// Mango audio engine: songs and podcasts.
//
// One queue (see lib/Media/core/play_queue.dart) drives everything:
// "Up next" items the listener queued, the album/list/Space context, then
// recommendations. Repeat (off, all, one), shuffle and AI shuffle, play next,
// add to queue, reorder, speed, sleep timer and resume all live here. The
// queue, position and "playing from" survive the app being closed.
//
// The public members used by existing screens (currentMusic, playlist,
// upcomingTracks, playNextTrack, playPreviousTrack, togglePlayPause, seekTo,
// toggleShuffle, toggleLoop, playSpecificTrack, ...) keep working.
import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:mango/Media/core/play_queue.dart';
import 'package:mango/Media/core/play_source.dart';
import 'package:mango/MusicPlayer/music.dart';
import 'package:mango/Wallet/ledger/mango_activity_tracker.dart';
import 'package:mango/Wallet/ledger/mango_ledger_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What kind of audio an item is.
enum AudioKind { song, podcast }

class GlobalMusicController extends GetxController {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final PlayQueue<Music> queue = PlayQueue<Music>(idOf: (m) => m.id);
  final Map<String, AudioKind> _kinds = {};

  static const _prefsKey = 'mango.player.v1';

  // ----------------------------------------------------- observable state
  var isPlaying = false.obs;
  var currentMusic = Rxn<Music>();
  var currentPosition = Duration.zero.obs;
  var totalDuration = Duration.zero.obs;
  var isMiniPlayerVisible = true.obs;
  var showMiniPlayer = false.obs;
  var isLoading = false.obs;
  var isBuffering = false.obs;

  /// The context being played (album, list, Space content), in order.
  var playlist = <Music>[].obs;

  /// Everything coming up, in play order (Up next, context, recommendations).
  var upcomingTracks = <Music>[].obs;

  /// Items the listener queued themselves.
  var upNext = <Music>[].obs;

  /// "Because you're listening to..." picks, also used for autoplay.
  var recommendations = <Music>[].obs;
  var playedTrackIds = <String>[].obs;
  var currentIndex = 0.obs;
  var isShuffled = false.obs;
  var isSmartShuffled = false.obs;
  var repeatMode = RepeatMode.off.obs;
  var playbackSpeed = 1.0.obs;
  var sleepTimerEndsAt = Rxn<DateTime>();
  var sleepAtEndOfItem = false.obs;
  var source = PlaySource.home.obs;
  var currentKind = AudioKind.song.obs;

  /// True when repeat-one is on (kept for older screens).
  RxBool get isLooped => (repeatMode.value == RepeatMode.one).obs;

  var backgroundColor = Rx<Color?>(null);
  Function(Music)? onMusicChange;
  Function(Color?)? onColorChange;

  /// For the lyrics page, which follows the player position.
  AudioPlayer get audioPlayer => _audioPlayer;

  Timer? _sleepTimer;
  Timer? _saveTimer;
  bool _sourceLoaded = false;
  bool _completing = false;

  @override
  void onInit() {
    super.onInit();
    _initListeners();
    _restore();
  }

  void _initListeners() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      isPlaying.value = state == PlayerState.playing;
    });
    _audioPlayer.onPositionChanged.listen((p) => currentPosition.value = p);
    _audioPlayer.onDurationChanged.listen((d) => totalDuration.value = d);
    _audioPlayer.onPlayerComplete.listen((_) => _onComplete());
    // Save the queue and position regularly so state survives closing the app.
    _saveTimer = Timer.periodic(const Duration(seconds: 10), (_) => _persist());
  }

  // ------------------------------------------------------------- loading
  /// Opens an item by id: a song, or a podcast episode when no song matches.
  Future<void> initializePlayer(
    String musicId, {
    List<Music>? initialPlaylist,
    int initialIndex = 0,
    PlaySource? source,
    AudioKind? kind,
  }) async {
    isLoading.value = true;
    try {
      if (initialPlaylist != null && initialPlaylist.isNotEmpty) {
        await playItems(initialPlaylist, startIndex: initialIndex, source: source, kind: kind ?? AudioKind.song);
        return;
      }
      final item = await _load(musicId, kind);
      if (item == null) throw Exception('This track is no longer available.');
      await playItems([item], source: source, kind: _kinds[item.id] ?? AudioKind.song);
    } catch (e) {
      debugPrint('Error initializing player: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<Music?> _load(String id, AudioKind? kind) async {
    if (kind != AudioKind.podcast) {
      final doc = await _firestore.collection('music').doc(id).get();
      if (doc.exists) {
        _kinds[id] = AudioKind.song;
        return Music.fromFirestore(doc);
      }
    }
    final pod = await _firestore.collection('podcasts').doc(id).get();
    if (pod.exists) {
      _kinds[id] = AudioKind.podcast;
      return podcastToMusic(pod);
    }
    return null;
  }

  /// Podcast episodes play through the same engine.
  static Music podcastToMusic(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final ts = d['timestamp'];
    int asInt(dynamic v) => v is int ? v : (v is num ? v.toInt() : 0);
    return Music(
      id: doc.id,
      title: '${d['title'] ?? 'Episode'}',
      description: d['description'] as String?,
      genre: '${d['category'] ?? 'Podcast'}',
      releaseYear: '',
      isExplicit: d['explicitContent'] == true,
      credits: const [],
      artworkUrl: '${d['artworkUrl'] ?? ''}',
      trackUrl: '${d['audioUrl'] ?? ''}',
      timestamp: ts is Timestamp ? ts.toDate() : DateTime.now(),
      plays: asInt(d['plays']),
      likes: asInt(d['likes']),
      duration: asInt(d['duration']) > 0 ? Duration(seconds: asInt(d['duration'])) : null,
      artistId: '${d['userId'] ?? ''}',
      artistName: '${d['host'] ?? d['userDisplayName'] ?? ''}',
      fileSize: asInt(d['fileSize']),
      label: 'podcast',
    );
  }

  AudioKind kindOf(Music m) => _kinds[m.id] ?? (m.label == 'podcast' ? AudioKind.podcast : AudioKind.song);

  /// Plays [items] from [startIndex]. [source] is where it's playing from.
  Future<void> playItems(
    List<Music> items, {
    int startIndex = 0,
    PlaySource? source,
    AudioKind kind = AudioKind.song,
    bool? shuffle,
  }) async {
    if (items.isEmpty) return;
    for (final m in items) {
      _kinds.putIfAbsent(m.id, () => m.label == 'podcast' ? AudioKind.podcast : kind);
    }
    queue.setContext(items, startIndex: startIndex, shuffle: shuffle, source: source ?? _defaultSource());
    isSmartShuffled.value = false;
    await _playCurrent();
    unawaited(_refreshRecommendations());
  }

  /// Plays a single podcast episode, resuming where you left off.
  Future<void> playPodcast(String episodeId, {PlaySource? source}) =>
      initializePlayer(episodeId, source: source, kind: AudioKind.podcast);

  PlaySource _defaultSource() {
    final space = MangoActivityTracker.activeSpaceId;
    return space != null ? PlaySource(kind: 'space', id: space, label: 'Space') : source.value;
  }

  // ------------------------------------------------------------ playback
  Future<void> _playCurrent({Duration? from, bool autoplay = true}) async {
    final music = queue.current;
    _sync();
    if (music == null || music.trackUrl.isEmpty) return;
    try {
      isBuffering.value = true;
      await _audioPlayer.stop();
      await _audioPlayer.setPlaybackRate(playbackSpeed.value);
      final resume = from ?? await _resumePoint(music);
      if (autoplay) {
        await _audioPlayer.play(UrlSource(music.trackUrl), position: resume);
      } else {
        await _audioPlayer.setSource(UrlSource(music.trackUrl));
        if (resume != null) await _audioPlayer.seek(resume);
      }
      _sourceLoaded = true;
      showMiniPlayer.value = true;
      if (!playedTrackIds.contains(music.id)) playedTrackIds.add(music.id);
      onMusicChange?.call(music);
      if (autoplay) {
        _incrementPlays(music);
        _record(music, 'start');
      }
    } catch (e) {
      debugPrint('Error playing track: $e');
    } finally {
      isBuffering.value = false;
    }
  }

  Future<void> togglePlayPause() async {
    if (isPlaying.value) {
      await _audioPlayer.pause();
      isPlaying.value = false;
      MangoActivityTracker.stopInBackground();
      unawaited(_persist());
      unawaited(_saveProgress());
      return;
    }
    if (queue.current != null && !_sourceLoaded) {
      await _playCurrent(from: currentPosition.value);
      return;
    }
    await _audioPlayer.resume();
    isPlaying.value = true;
    final current = currentMusic.value;
    if (current != null) {
      MangoActivityTracker.startInBackground(contentType: kindOf(current).name, contentId: current.id);
    }
  }

  Future<void> seekTo(Duration position) async {
    await _audioPlayer.seek(position);
  }

  /// Skips forward or back (podcasts use 15 back and 30 forward).
  Future<void> skipBy(Duration delta) async {
    final target = currentPosition.value + delta;
    final max = totalDuration.value;
    final clamped = target < Duration.zero ? Duration.zero : (max > Duration.zero && target > max ? max : target);
    await seekTo(clamped);
  }

  Future<void> playNextTrack() async {
    final current = queue.current;
    if (current != null) _maybeRecordSkip(current);
    await _ensureAutoplay();
    final next = queue.next();
    if (next == null) {
      await _audioPlayer.stop();
      isPlaying.value = false;
      _sync();
      return;
    }
    await _playCurrent(from: Duration.zero);
  }

  /// Restarts the item if more than 3 seconds in; otherwise goes back.
  Future<void> playPreviousTrack() async {
    if (currentPosition.value > const Duration(seconds: 3) || !queue.hasPrevious) {
      await seekTo(Duration.zero);
      return;
    }
    queue.previous();
    await _playCurrent(from: Duration.zero);
  }

  Future<void> _onComplete() async {
    if (_completing) return;
    _completing = true;
    try {
      final finished = queue.current;
      if (finished != null) {
        _record(finished, 'complete');
        unawaited(_saveProgress(completed: true));
      }
      MangoActivityTracker.stopInBackground();
      if (sleepAtEndOfItem.value) {
        sleepAtEndOfItem.value = false;
        isPlaying.value = false;
        return;
      }
      if (repeatMode.value == RepeatMode.one && finished != null) {
        await _playCurrent(from: Duration.zero);
        return;
      }
      await _ensureAutoplay();
      final next = queue.next(auto: true);
      if (next == null) {
        isPlaying.value = false;
        _sync();
        return;
      }
      await _playCurrent(from: Duration.zero);
    } finally {
      _completing = false;
    }
  }

  // --------------------------------------------------------------- queue
  void _rememberKind(Music m) =>
      _kinds.putIfAbsent(m.id, () => m.label == 'podcast' ? AudioKind.podcast : AudioKind.song);

  void playNext(Music m) {
    _rememberKind(m);
    final wasEmpty = queue.current == null;
    queue.playNext(m);
    _sync();
    if (wasEmpty) unawaited(_playCurrent());
  }

  void addToQueue(Music m) {
    _rememberKind(m);
    final wasEmpty = queue.current == null;
    queue.addToQueue(m);
    _sync();
    if (wasEmpty) unawaited(_playCurrent());
  }

  void removeFromQueue(int upcomingIndex) {
    queue.removeAt(upcomingIndex);
    _sync();
  }

  void moveInQueue(int oldIndex, int newIndex) {
    queue.move(oldIndex, newIndex);
    _sync();
  }

  Future<void> jumpToQueue(int upcomingIndex) async {
    final current = queue.current;
    if (current != null) _maybeRecordSkip(current);
    if (queue.jumpTo(upcomingIndex) != null) await _playCurrent(from: Duration.zero);
  }

  /// Plays playlist[index] (used by existing track lists).
  void playSpecificTrack(int index) {
    if (index < 0 || index >= playlist.length) return;
    queue.setContext(playlist.toList(), startIndex: index, source: queue.source);
    unawaited(_playCurrent(from: Duration.zero));
  }

  int get totalTracks => playlist.length + upcomingTracks.length;

  Music getMusicAtIndex(int index) =>
      index < playlist.length ? playlist[index] : upcomingTracks[index - playlist.length];

  void toggleShuffle() {
    queue.setShuffle(!queue.shuffle);
    isSmartShuffled.value = false;
    _sync();
  }

  /// AI shuffle: orders the queue by your taste, spreads artists out and
  /// mixes in fresh picks. Falls back to a normal shuffle when offline.
  Future<void> smartShuffle() async {
    final current = queue.current;
    if (current == null) return;
    final kind = kindOf(current);
    final ids = queue.upcoming.where((e) => e.origin == QueueOrigin.context).map((e) => e.item.id).toList();
    try {
      final res = await MangoLedgerClient.instance.call('mediaSmartShuffle', {
        'type': kind.name,
        'ids': ids,
        'currentId': current.id,
      });
      final items = ((res['items'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final known = {for (final e in queue.upcoming) e.item.id: e.item};
      final ordered = <(Music, bool)>[];
      for (final it in items) {
        final id = '${it['id']}';
        final recommended = it['origin'] == 'recommended';
        final m = known[id] ?? (recommended ? await _load(id, kind) : null);
        if (m != null) ordered.add((m, recommended));
      }
      queue.applySmartOrder(ordered);
      isSmartShuffled.value = true;
    } catch (e) {
      debugPrint('Smart shuffle unavailable, using shuffle: $e');
      queue.setShuffle(true);
      isSmartShuffled.value = false;
    }
    _sync();
  }

  RepeatMode cycleRepeat() {
    final mode = queue.cycleRepeat();
    _sync();
    return mode;
  }

  /// Older screens' loop button: cycles off, all, one.
  void toggleLoop() => cycleRepeat();

  Future<void> setSpeed(double speed) async {
    playbackSpeed.value = speed < 0.5 ? 0.5 : (speed > 3.0 ? 3.0 : speed);
    await _audioPlayer.setPlaybackRate(playbackSpeed.value);
  }

  /// Sleep after [after]; null cancels; [endOfItem] stops when the item ends.
  void setSleepTimer(Duration? after, {bool endOfItem = false}) {
    _sleepTimer?.cancel();
    sleepAtEndOfItem.value = endOfItem;
    if (after == null) {
      sleepTimerEndsAt.value = null;
      return;
    }
    sleepTimerEndsAt.value = DateTime.now().add(after);
    _sleepTimer = Timer(after, () async {
      sleepTimerEndsAt.value = null;
      if (isPlaying.value) await togglePlayPause();
    });
  }

  void toggleMiniPlayer() => isMiniPlayerVisible.toggle();

  Future<void> stopMusic() async {
    MangoActivityTracker.stopInBackground();
    await _saveProgress();
    await _audioPlayer.stop();
    _sourceLoaded = false;
    isPlaying.value = false;
    queue.clear();
    _sync();
    showMiniPlayer.value = false;
    playedTrackIds.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  void setBackgroundColor(Color? color) {
    backgroundColor.value = color;
    onColorChange?.call(color);
  }

  // ----------------------------------------------------- recommendations
  Future<void> _refreshRecommendations() async {
    final current = queue.current;
    if (current == null) return;
    final kind = kindOf(current);
    try {
      final res = await MangoLedgerClient.instance.call('mediaRecommend', {
        'type': kind.name,
        'seedId': current.id,
        'exclude': [current.id, ...queue.upcoming.map((e) => e.item.id), ...queue.history.take(50).map((m) => m.id)],
        'limit': 15,
      });
      final ids = ((res['items'] as List?) ?? const []).map((e) => '${(e as Map)['id']}').toList();
      final loaded = <Music>[];
      for (final id in ids) {
        final m = await _load(id, kind);
        if (m != null) loaded.add(m);
      }
      recommendations.assignAll(loaded);
      queue.setAutoplay(loaded);
    } catch (e) {
      // Offline or not signed in: fall back to the same genre or category.
      final fallback = await _fallbackRecommendations(current, kind);
      recommendations.assignAll(fallback);
      queue.setAutoplay(fallback);
    }
  }

  Future<List<Music>> _fallbackRecommendations(Music m, AudioKind kind) async {
    try {
      final col = kind == AudioKind.podcast ? 'podcasts' : 'music';
      final field = kind == AudioKind.podcast ? 'category' : 'genre';
      final q = await _firestore.collection(col).where(field, isEqualTo: m.genre).limit(15).get();
      final played = {m.id, ...queue.history.map((h) => h.id), ...queue.upcoming.map((e) => e.item.id)};
      return q.docs
          .where((d) => !played.contains(d.id))
          .map((d) => kind == AudioKind.podcast ? podcastToMusic(d) : Music.fromFirestore(d))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _ensureAutoplay() async {
    if (!queue.hasNext && recommendations.isEmpty) await _refreshRecommendations();
  }

  // --------------------------------------------------- taste and progress
  void _record(Music m, String event) {
    if (FirebaseAuth.instance.currentUser == null) return;
    unawaited(MangoLedgerClient.instance.call('mediaRecord', {
      'type': kindOf(m).name,
      'id': m.id,
      'event': event,
      'positionSec': currentPosition.value.inSeconds,
      'durationSec': totalDuration.value.inSeconds,
    }).catchError((_) => <String, dynamic>{}));
  }

  void _maybeRecordSkip(Music m) {
    final d = totalDuration.value.inSeconds;
    final p = currentPosition.value.inSeconds;
    if (d > 0 && p / d < 0.7) _record(m, 'skip');
  }

  /// Podcasts resume where you left off (songs start from the top).
  Future<Duration?> _resumePoint(Music m) async {
    if (kindOf(m) != AudioKind.podcast) return null;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    try {
      final doc = await _firestore.collection('media_progress').doc(uid).collection('items').doc('podcast_${m.id}').get();
      final d = doc.data();
      if (d == null || d['completed'] == true) return null;
      final pos = (d['positionMs'] ?? 0) as int;
      return pos > 30000 ? Duration(milliseconds: pos - 3000) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveProgress({bool completed = false}) async {
    final m = queue.current;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (m == null || uid == null || kindOf(m) != AudioKind.podcast) return;
    try {
      await _firestore.collection('media_progress').doc(uid).collection('items').doc('podcast_${m.id}').set({
        'type': 'podcast',
        'id': m.id,
        'title': m.title.length > 120 ? m.title.substring(0, 120) : m.title,
        if (m.artworkUrl.isNotEmpty && m.artworkUrl.length <= 1000) 'imageUrl': m.artworkUrl,
        'positionMs': currentPosition.value.inMilliseconds,
        'durationMs': totalDuration.value.inMilliseconds,
        'completed': completed,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> _incrementPlays(Music music) async {
    // Open a server-timed session; the server credits real listening only.
    MangoActivityTracker.startInBackground(contentType: kindOf(music).name, contentId: music.id);
    try {
      final col = kindOf(music) == AudioKind.podcast ? 'podcasts' : 'music';
      await _firestore.collection(col).doc(music.id).update({'plays': FieldValue.increment(1)});
    } catch (e) {
      debugPrint('Error incrementing plays: $e');
    }
  }

  // ---------------------------------------------------- state and saving
  void _sync() {
    final current = queue.current;
    currentMusic.value = current;
    playlist.assignAll(queue.context);
    upcomingTracks.assignAll(queue.upcoming.map((e) => e.item));
    upNext.assignAll(queue.upNext);
    isShuffled.value = queue.shuffle;
    repeatMode.value = queue.repeat;
    source.value = queue.source;
    if (current != null) {
      currentKind.value = kindOf(current);
      final i = queue.context.indexWhere((m) => m.id == current.id);
      currentIndex.value = i < 0 ? 0 : i;
    }
  }

  Future<void> _persist() async {
    if (queue.current == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'queue': queue.toJson((m) => {...m.toJson(), if (m.label != null) 'label': m.label}),
        'kinds': {for (final e in _kinds.entries) e.key: e.value.name},
        'positionMs': currentPosition.value.inMilliseconds,
        'speed': playbackSpeed.value,
      };
      await prefs.setString(_prefsKey, jsonEncode(data));
    } catch (e) {
      debugPrint('Could not save player state: $e');
    }
  }

  /// Brings back the last queue, paused, where it was.
  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      queue.restore(Map<String, dynamic>.from(data['queue'] as Map), (j) => Music.fromJson(j));
      final kinds = Map<String, dynamic>.from((data['kinds'] as Map?) ?? const {});
      kinds.forEach((k, v) => _kinds[k] = v == 'podcast' ? AudioKind.podcast : AudioKind.song);
      playbackSpeed.value = ((data['speed'] ?? 1.0) as num).toDouble();
      _sync();
      if (queue.current != null) {
        final pos = Duration(milliseconds: (data['positionMs'] ?? 0) as int);
        currentPosition.value = pos;
        await _playCurrent(from: pos, autoplay: false);
      }
    } catch (e) {
      debugPrint('Could not restore player state: $e');
    }
  }

  @override
  void onClose() {
    _sleepTimer?.cancel();
    _saveTimer?.cancel();
    unawaited(_persist());
    _audioPlayer.dispose();
    super.onClose();
  }
}
