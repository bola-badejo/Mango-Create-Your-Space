// Pure-Dart play queue used by every Mango player (music, podcasts, video).
//
// Model: history <- current -> upcoming. Upcoming always starts with what
// the listener queued themselves ("Up next"), then the rest of the context
// (an album, playlist, Space list), then autoplay recommendations.
import 'dart:math';

import 'play_source.dart';

enum RepeatMode { off, all, one }

enum QueueOrigin { context, user, recommended, autoplay }

class QueueEntry<T> {
  const QueueEntry(this.item, this.origin, [this.contextIndex]);

  final T item;
  final QueueOrigin origin;

  /// Position in the context, for restoring order when shuffle is turned off.
  final int? contextIndex;

  QueueEntry<T> copyWith({QueueOrigin? origin}) => QueueEntry(item, origin ?? this.origin, contextIndex);
}

class PlayQueue<T> {
  PlayQueue({required this.idOf, Random? random, this.maxHistory = 200}) : _random = random ?? Random();

  final String Function(T) idOf;
  final Random _random;
  final int maxHistory;

  List<T> _context = const [];
  final List<QueueEntry<T>> _history = [];
  QueueEntry<T>? _current;
  final List<QueueEntry<T>> _upcoming = [];
  final List<T> _autoplay = [];

  RepeatMode repeat = RepeatMode.off;
  bool _shuffle = false;
  PlaySource source = PlaySource.home;

  T? get current => _current?.item;
  QueueEntry<T>? get currentEntry => _current;
  bool get shuffle => _shuffle;
  List<T> get context => List.unmodifiable(_context);
  List<QueueEntry<T>> get upcoming => List.unmodifiable(_upcoming);
  List<T> get upNext => _upcoming.where((e) => e.origin == QueueOrigin.user).map((e) => e.item).toList();
  List<T> get history => _history.map((e) => e.item).toList();
  bool get hasNext => _upcoming.isNotEmpty || (repeat == RepeatMode.all && _context.isNotEmpty) || _autoplay.isNotEmpty;
  bool get hasPrevious => _history.isNotEmpty;
  bool get isEmpty => _current == null && _upcoming.isEmpty;

  /// Starts playing [items] from [startIndex].
  void setContext(List<T> items, {int startIndex = 0, bool? shuffle, PlaySource? source}) {
    if (items.isEmpty) {
      clear();
      return;
    }
    final start = startIndex < 0 ? 0 : (startIndex >= items.length ? items.length - 1 : startIndex);
    _context = List.of(items);
    _history.clear();
    _upcoming.removeWhere((e) => e.origin != QueueOrigin.user); // keep the listener's own queue
    _autoplay.clear();
    if (shuffle != null) _shuffle = shuffle;
    if (source != null) this.source = source;
    _current = QueueEntry(_context[start], QueueOrigin.context, start);
    // Shuffled play covers every other item; ordered play continues forward.
    _upcoming.addAll(_contextAfter(start, wrap: _shuffle));
  }

  List<QueueEntry<T>> _contextAfter(int index, {bool wrap = false}) {
    final idx = <int>[
      for (var i = index + 1; i < _context.length; i++) i,
      if (wrap) for (var i = 0; i < index; i++) i,
    ];
    final entries = idx.map((i) => QueueEntry(_context[i], QueueOrigin.context, i)).toList();
    if (_shuffle) entries.shuffle(_random);
    return entries;
  }

  int get _userCount {
    var n = 0;
    while (n < _upcoming.length && _upcoming[n].origin == QueueOrigin.user) {
      n++;
    }
    return n;
  }

  /// Plays [item] right after the current one.
  void playNext(T item) {
    if (_current == null) {
      _current = QueueEntry(item, QueueOrigin.user);
      return;
    }
    _upcoming.insert(0, QueueEntry(item, QueueOrigin.user));
  }

  /// Adds [item] to the end of "Up next" (still before the rest of the context).
  void addToQueue(T item) {
    if (_current == null) {
      _current = QueueEntry(item, QueueOrigin.user);
      return;
    }
    _upcoming.insert(_userCount, QueueEntry(item, QueueOrigin.user));
  }

  /// Recommendations to continue with when the context runs out.
  void setAutoplay(List<T> items) {
    final known = {...?(_current == null ? null : [idOf(_current!.item)]), ..._upcoming.map((e) => idOf(e.item)), ..._history.map((e) => idOf(e.item))};
    _autoplay
      ..clear()
      ..addAll(items.where((i) => !known.contains(idOf(i))));
  }

  List<T> get autoplay => List.unmodifiable(_autoplay);

  /// Advances. [auto] is true when the current item finished by itself.
  /// Returns the new current item, or null at the end of everything.
  T? next({bool auto = false}) {
    if (_current != null && repeat == RepeatMode.one && auto) return _current!.item;
    if (_upcoming.isEmpty) {
      if (repeat == RepeatMode.all && _context.isNotEmpty) {
        _upcoming.addAll(_contextAfter(-1));
        if (_shuffle && _upcoming.length > 1 && _current != null && idOf(_upcoming.first.item) == idOf(_current!.item)) {
          _upcoming.add(_upcoming.removeAt(0)); // don't repeat the same item straight away
        }
      } else if (_autoplay.isNotEmpty) {
        _upcoming.addAll(_autoplay.map((i) => QueueEntry(i, QueueOrigin.autoplay)));
        _autoplay.clear();
      } else {
        return null;
      }
    }
    if (_current != null) _pushHistory(_current!);
    _current = _upcoming.removeAt(0);
    return _current!.item;
  }

  void _pushHistory(QueueEntry<T> e) {
    _history.add(e);
    if (_history.length > maxHistory) _history.removeAt(0);
  }

  /// Goes back one item. Returns the new current item (the same one if there
  /// is no history, so the caller can restart it).
  T? previous() {
    if (_history.isEmpty) return _current?.item;
    if (_current != null) _upcoming.insert(0, _current!);
    _current = _history.removeLast();
    return _current!.item;
  }

  /// Jumps to upcoming[index]; anything before it is skipped.
  T? jumpTo(int index) {
    if (index < 0 || index >= _upcoming.length) return null;
    if (_current != null) _pushHistory(_current!);
    final target = _upcoming[index];
    _upcoming.removeRange(0, index + 1);
    _current = target;
    return target.item;
  }

  void removeAt(int index) {
    if (index >= 0 && index < _upcoming.length) _upcoming.removeAt(index);
  }

  void move(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _upcoming.length) return;
    final e = _upcoming.removeAt(oldIndex);
    final to = newIndex < 0 ? 0 : (newIndex > _upcoming.length ? _upcoming.length : newIndex);
    _upcoming.insert(to, e);
  }

  /// Turns shuffle on or off. The current item keeps playing; "Up next" is
  /// never shuffled. Turning it off resumes context order from the current item.
  void setShuffle(bool on) {
    _shuffle = on;
    final user = _upcoming.sublist(0, _userCount);
    final others = _upcoming.sublist(_userCount).where((e) => e.origin != QueueOrigin.context).toList();
    final pivot = _current?.contextIndex ?? -1;
    // On: every other context item, shuffled. Off: continue in order from
    // the current item (as if the album had been played from here).
    final ctx = on ? _contextAfter(pivot, wrap: true) : _contextAfterOrdered(pivot);
    if (on && _current != null && _current!.origin != QueueOrigin.context) {
      ctx.removeWhere((e) => idOf(e.item) == idOf(_current!.item));
    }
    _upcoming
      ..clear()
      ..addAll(user)
      ..addAll(ctx)
      ..addAll(others);
  }

  List<QueueEntry<T>> _contextAfterOrdered(int index) =>
      [for (var i = index + 1; i < _context.length; i++) QueueEntry(_context[i], QueueOrigin.context, i)];

  /// Applies an AI-shuffled order. [ordered] holds (item, isRecommendation)
  /// pairs; queued items not mentioned keep their relative order at the end.
  void applySmartOrder(List<(T, bool)> ordered) {
    _shuffle = true;
    final user = _upcoming.sublist(0, _userCount);
    final rest = _upcoming.sublist(_userCount);
    final byId = {for (final e in rest) idOf(e.item): e};
    final out = <QueueEntry<T>>[];
    final used = <String>{};
    final currentId = _current == null ? null : idOf(_current!.item);
    for (final (item, recommended) in ordered) {
      final id = idOf(item);
      if (id == currentId || used.contains(id)) continue;
      used.add(id);
      out.add(recommended ? QueueEntry(item, QueueOrigin.recommended) : (byId[id] ?? QueueEntry(item, QueueOrigin.context)));
    }
    out.addAll(rest.where((e) => !used.contains(idOf(e.item))));
    _upcoming
      ..clear()
      ..addAll(user)
      ..addAll(out);
  }

  RepeatMode cycleRepeat() {
    repeat = RepeatMode.values[(repeat.index + 1) % RepeatMode.values.length];
    return repeat;
  }

  void clear() {
    _context = const [];
    _history.clear();
    _upcoming.clear();
    _autoplay.clear();
    _current = null;
  }

  // ------------------------------------------------------- persistence
  Map<String, dynamic> toJson(Map<String, dynamic> Function(T) itemToJson) {
    Map<String, dynamic> entry(QueueEntry<T> e) => {'item': itemToJson(e.item), 'origin': e.origin.name, if (e.contextIndex != null) 'ctx': e.contextIndex};
    return {
      'v': 1,
      'context': _context.map(itemToJson).toList(),
      'history': _history.skip(_history.length > 50 ? _history.length - 50 : 0).map(entry).toList(),
      if (_current != null) 'current': entry(_current!),
      'upcoming': _upcoming.map(entry).toList(),
      'autoplay': _autoplay.map(itemToJson).toList(),
      'repeat': repeat.name,
      'shuffle': _shuffle,
      'source': source.toJson(),
    };
  }

  void restore(Map<String, dynamic> json, T Function(Map<String, dynamic>) itemFromJson) {
    QueueEntry<T> entry(dynamic raw) {
      final m = Map<String, dynamic>.from(raw as Map);
      return QueueEntry(itemFromJson(Map<String, dynamic>.from(m['item'] as Map)),
          QueueOrigin.values.firstWhere((o) => o.name == m['origin'], orElse: () => QueueOrigin.context), m['ctx'] as int?);
    }

    clear();
    _context = ((json['context'] as List?) ?? const []).map((e) => itemFromJson(Map<String, dynamic>.from(e as Map))).toList();
    _history.addAll(((json['history'] as List?) ?? const []).map(entry));
    if (json['current'] != null) _current = entry(json['current']);
    _upcoming.addAll(((json['upcoming'] as List?) ?? const []).map(entry));
    _autoplay.addAll(((json['autoplay'] as List?) ?? const []).map((e) => itemFromJson(Map<String, dynamic>.from(e as Map))));
    repeat = RepeatMode.values.firstWhere((r) => r.name == json['repeat'], orElse: () => RepeatMode.off);
    _shuffle = json['shuffle'] == true;
    source = PlaySource.fromJson(json['source'] == null ? null : Map<String, dynamic>.from(json['source'] as Map));
  }
}
