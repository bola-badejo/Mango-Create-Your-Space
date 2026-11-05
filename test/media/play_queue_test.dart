import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mango/Media/core/play_queue.dart';
import 'package:mango/Media/core/play_source.dart';

PlayQueue<String> q() => PlayQueue<String>(idOf: (s) => s, random: Random(7));

List<String> ids(PlayQueue<String> p) => p.upcoming.map((e) => e.item).toList();

void main() {
  test('plays a context in order from the chosen start', () {
    final p = q()..setContext(['a', 'b', 'c', 'd'], startIndex: 1);
    expect(p.current, 'b');
    expect(ids(p), ['c', 'd']);
    expect(p.next(), 'c');
    expect(p.next(), 'd');
    expect(p.next(), isNull, reason: 'end of context with repeat off');
    expect(p.current, 'd');
  });

  test('play next goes first; add to queue goes after other queued items but before the context', () {
    final p = q()..setContext(['a', 'b', 'c']);
    p.addToQueue('x');
    p.addToQueue('y');
    p.playNext('z');
    expect(ids(p), ['z', 'x', 'y', 'b', 'c']);
    expect(p.upNext, ['z', 'x', 'y']);
  });

  test('a new context keeps what the listener queued', () {
    final p = q()..setContext(['a', 'b']);
    p.addToQueue('mine');
    p.setContext(['k', 'l', 'm']);
    expect(p.current, 'k');
    expect(ids(p), ['mine', 'l', 'm']);
  });

  test('previous returns through history and next returns forward again', () {
    final p = q()..setContext(['a', 'b', 'c']);
    p.next();
    p.next();
    expect(p.previous(), 'b');
    expect(p.previous(), 'a');
    expect(p.previous(), 'a', reason: 'no history: same item, caller restarts it');
    expect(p.next(), 'b');
    expect(p.next(), 'c');
  });

  test('repeat one repeats only when the item finishes by itself', () {
    final p = q()..setContext(['a', 'b']);
    p.repeat = RepeatMode.one;
    expect(p.next(auto: true), 'a');
    expect(p.next(), 'b', reason: 'pressing next still moves on');
  });

  test('repeat all wraps around to the start of the context', () {
    final p = q()..setContext(['a', 'b']);
    p.repeat = RepeatMode.all;
    expect(p.next(), 'b');
    expect(p.next(), 'a');
    expect(p.next(), 'b');
  });

  test('cycleRepeat goes off, all, one, off', () {
    final p = q();
    expect([p.cycleRepeat(), p.cycleRepeat(), p.cycleRepeat()], [RepeatMode.all, RepeatMode.one, RepeatMode.off]);
  });

  test('shuffle keeps the current item, never shuffles Up next, and unshuffle resumes in order', () {
    final items = List.generate(12, (i) => 't$i');
    final p = q()..setContext(items, startIndex: 3);
    p.addToQueue('mine');
    p.setShuffle(true);
    expect(p.current, 't3');
    expect(ids(p).first, 'mine');
    expect(ids(p).toSet(), {'mine', ...items.where((t) => t != 't3')});
    p.setShuffle(false);
    expect(ids(p), ['mine', 't4', 't5', 't6', 't7', 't8', 't9', 't10', 't11']);
  });

  test('starting shuffled plays every other item once', () {
    final items = List.generate(8, (i) => 's$i');
    final p = q()..setContext(items, startIndex: 5, shuffle: true);
    expect(p.current, 's5');
    expect(ids(p).toSet(), items.toSet()..remove('s5'));
    expect(ids(p).length, 7);
  });

  test('autoplay continues after the context, skipping anything already queued or played', () {
    final p = q()..setContext(['a', 'b']);
    p.setAutoplay(['b', 'r1', 'r2']);
    expect(p.autoplay, ['r1', 'r2']);
    p.next();
    expect(p.next(), 'r1');
    expect(p.currentEntry!.origin, QueueOrigin.autoplay);
    expect(p.next(), 'r2');
    expect(p.next(), isNull);
  });

  test('jump, remove and move work on the upcoming list', () {
    final p = q()..setContext(['a', 'b', 'c', 'd', 'e']);
    p.move(3, 0); // e to front
    expect(ids(p), ['e', 'b', 'c', 'd']);
    p.removeAt(1);
    expect(ids(p), ['e', 'c', 'd']);
    expect(p.jumpTo(1), 'c');
    expect(ids(p), ['d']);
    expect(p.history, ['a']);
  });

  test('AI shuffle applies the server order and marks recommendations', () {
    final p = q()..setContext(['a', 'b', 'c', 'd']);
    p.addToQueue('mine');
    p.applySmartOrder([('a', false), ('d', false), ('rec', true), ('b', false)]);
    expect(p.shuffle, isTrue);
    expect(ids(p), ['mine', 'd', 'rec', 'b', 'c'], reason: 'current skipped, unmentioned c kept at the end');
    expect(p.upcoming[2].origin, QueueOrigin.recommended);
  });

  test('the whole queue survives a save and restore', () {
    final p = q()..setContext(['a', 'b', 'c'], source: const PlaySource(kind: 'space', id: 's1', label: "Tobi's Studio"));
    p.addToQueue('mine');
    p.next();
    p.repeat = RepeatMode.all;
    final json = p.toJson((s) => {'id': s});
    final r = q()..restore(json, (m) => m['id'] as String);
    expect(r.current, p.current);
    expect(ids(r), ids(p));
    expect(r.history, p.history);
    expect(r.repeat, RepeatMode.all);
    expect(r.source, const PlaySource(kind: 'space', id: 's1', label: "Tobi's Studio"));
  });
}
