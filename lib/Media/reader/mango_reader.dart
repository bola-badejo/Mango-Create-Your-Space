// Mango Reader.
//
//   Themes         Paper, Sepia and Night (pages are tinted, not just the UI)
//   Focus mode     hides everything but the page; an optional reading guide
//                  dims the page around a band you can move
//   Read aloud     reads the page with the device voice, at your speed, and
//                  turns pages by itself; sleep timer
//   Navigation     contents, search, bookmarks, page slider, single-page or
//                  continuous scrolling
//   Progress       resumes on any device, shows time left in the book
import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:mango/Core/design_system/mango_ui.dart';
import 'package:mango/Media/lists/content_list_sheet.dart';
import 'package:mango/MusicPlayer/controllers/global_music_controller.dart';
import 'package:mango/Wallet/ledger/mango_ledger_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

enum ReaderTheme { paper, sepia, night }

class MangoReaderScreen extends StatefulWidget {
  const MangoReaderScreen({super.key, required this.bookId, this.fileUrl, this.title});

  final String bookId;

  /// Optional, when the caller already has them (saves a lookup).
  final String? fileUrl;
  final String? title;

  @override
  State<MangoReaderScreen> createState() => _MangoReaderScreenState();
}

class _MangoReaderScreenState extends State<MangoReaderScreen> {
  final PdfViewerController _pdf = PdfViewerController();
  final GlobalKey<SfPdfViewerState> _viewerKey = GlobalKey();
  final FlutterTts _tts = FlutterTts();
  Uint8List? _bytes;
  PdfDocument? _document;
  String? _resolvedUrl;
  String _title = '';
  String? _error;

  int _page = 1;
  int _pageCount = 0;
  List<int> _bookmarks = [];
  ReaderTheme _theme = ReaderTheme.paper;
  bool _continuous = true;
  bool _focus = false;
  bool _guide = false;
  double _guideY = 0.4;
  bool _chrome = true;
  bool _searching = false;
  PdfTextSearchResult? _search;
  final _searchCtrl = TextEditingController();

  bool _reading = false;
  double _speechRate = 0.5;
  Timer? _sleep;
  Timer? _saveDebounce;
  DateTime _pageOpenedAt = DateTime.now();
  final List<int> _secondsPerPage = [];

  String get _key => 'book_${widget.bookId}';

  @override
  void initState() {
    super.initState();
    // Reading and listening don't compete: pause music.
    final music = Get.isRegistered<GlobalMusicController>() ? Get.find<GlobalMusicController>() : null;
    if (music != null && music.isPlaying.value) unawaited(music.togglePlayPause());
    _restorePrefs();
    _load();
    _tts.setCompletionHandler(_onSpeechDone);
  }

  // ------------------------------------------------------------- loading
  Future<void> _load() async {
    try {
      String url = widget.fileUrl ?? '';
      _title = widget.title ?? '';
      if (url.isEmpty || _title.isEmpty) {
        final doc = await FirebaseFirestore.instance.collection('books').doc(widget.bookId).get();
        final d = doc.data() ?? const <String, dynamic>{};
        url = url.isNotEmpty ? url : '${d['fileUrl'] ?? d['bookFileUrl'] ?? ''}';
        _title = _title.isNotEmpty ? _title : '${d['title'] ?? 'Book'}';
      }
      if (url.isEmpty) throw Exception('This book has no file yet.');
      if (!url.startsWith('http')) url = await FirebaseStorage.instance.ref(url).getDownloadURL();
      _resolvedUrl = url;
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) throw Exception("Couldn't download this book (${res.statusCode}).");
      final progress = await _loadProgress();
      if (!mounted) return;
      setState(() {
        _bytes = res.bodyBytes;
        if (progress != null) {
          _page = (progress['page'] ?? 1) as int;
          _bookmarks = ((progress['bookmarks'] as List?) ?? const []).map((e) => e as int).toList();
        }
      });
      _record('start');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<Map<String, dynamic>?> _loadProgress() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    try {
      return (await FirebaseFirestore.instance.collection('media_progress').doc(uid).collection('items').doc(_key).get()).data();
    } catch (_) {
      return null;
    }
  }

  void _saveProgress() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 2), () async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || _pageCount == 0) return;
      try {
        await FirebaseFirestore.instance.collection('media_progress').doc(uid).collection('items').doc(_key).set({
          'type': 'book',
          'id': widget.bookId,
          'title': _title.length > 120 ? _title.substring(0, 120) : _title,
          'page': _page,
          'pageCount': _pageCount,
          'bookmarks': _bookmarks.take(200).toList(),
          'completed': _page >= _pageCount,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    });
  }

  Future<void> _restorePrefs() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _theme = ReaderTheme.values[(p.getInt('reader.theme') ?? 0).clamp(0, 2).toInt()];
      _continuous = p.getBool('reader.continuous') ?? true;
      _speechRate = p.getDouble('reader.rate') ?? 0.5;
    });
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('reader.theme', _theme.index);
    await p.setBool('reader.continuous', _continuous);
    await p.setDouble('reader.rate', _speechRate);
  }

  void _record(String event) {
    if (FirebaseAuth.instance.currentUser == null) return;
    unawaited(MangoLedgerClient.instance.call('mediaRecord', {'type': 'book', 'id': widget.bookId, 'event': event}).catchError((_) => <String, dynamic>{}));
  }

  // ---------------------------------------------------------- page events
  void _onLoaded(PdfDocumentLoadedDetails d) {
    _document = d.document;
    setState(() => _pageCount = d.document.pages.count);
    if (_page > 1 && _page <= _pageCount) {
      _pdf.jumpToPage(_page);
      MangoToast.show(context, message: 'Back to page $_page', actionLabel: 'Start over', onAction: () => _pdf.jumpToPage(1));
    }
  }

  void _onPageChanged(PdfPageChangedDetails d) {
    final spent = DateTime.now().difference(_pageOpenedAt).inSeconds;
    if (spent >= 5 && spent <= 600) _secondsPerPage.add(spent);
    _pageOpenedAt = DateTime.now();
    setState(() => _page = d.newPageNumber);
    if (_page == _pageCount) _record('complete');
    _saveProgress();
  }

  String get _timeLeft {
    if (_pageCount == 0) return '';
    final pagesLeft = _pageCount - _page;
    final recent = _secondsPerPage.length > 20 ? _secondsPerPage.sublist(_secondsPerPage.length - 20) : _secondsPerPage;
    final avg = recent.isEmpty ? 60 : recent.reduce((a, b) => a + b) / recent.length;
    final minutes = (pagesLeft * avg / 60).round();
    if (pagesLeft <= 0) return 'Last page';
    if (minutes < 60) return '$minutes min left';
    return '${minutes ~/ 60} h ${minutes % 60} min left';
  }

  // ----------------------------------------------------------- read aloud
  Future<void> _toggleReadAloud() async {
    if (_reading) {
      await _tts.stop();
      setState(() => _reading = false);
      MangoAnnounce.polite(context, 'Stopped reading');
      return;
    }
    setState(() => _reading = true);
    await _readCurrentPage();
  }

  Future<void> _readCurrentPage() async {
    final doc = _document;
    if (doc == null || !_reading) return;
    String text = '';
    try {
      text = PdfTextExtractor(doc).extractText(startPageIndex: _page - 1, endPageIndex: _page - 1).trim();
    } catch (_) {}
    if (text.isEmpty) {
      // A scanned page or an image: move on rather than stall.
      if (_page < _pageCount) {
        _pdf.nextPage();
        await Future<void>.delayed(const Duration(milliseconds: 400));
        return _readCurrentPage();
      }
      if (mounted) setState(() => _reading = false);
      return;
    }
    await _tts.setSpeechRate(_speechRate);
    await _tts.speak(text);
  }

  void _onSpeechDone() {
    if (!_reading || !mounted) return;
    if (_page < _pageCount) {
      _pdf.nextPage();
      Future<void>.delayed(const Duration(milliseconds: 400), _readCurrentPage);
    } else {
      setState(() => _reading = false);
      MangoAnnounce.polite(context, 'Finished the book');
    }
  }

  void _setSleep(int minutes) {
    _sleep?.cancel();
    if (minutes <= 0) return;
    _sleep = Timer(Duration(minutes: minutes), () async {
      await _tts.stop();
      if (mounted) setState(() => _reading = false);
    });
    MangoToast.show(context, message: 'Reading stops in $minutes minutes');
  }

  // ------------------------------------------------------------ actions
  void _toggleBookmark() {
    setState(() {
      if (_bookmarks.contains(_page)) {
        _bookmarks.remove(_page);
      } else {
        _bookmarks = [..._bookmarks, _page]..sort();
      }
    });
    MangoAnnounce.polite(context, _bookmarks.contains(_page) ? 'Bookmarked page $_page' : 'Bookmark removed');
    _saveProgress();
  }

  Future<void> _setFocus(bool on) async {
    setState(() {
      _focus = on;
      _chrome = !on;
    });
    await SystemChrome.setEnabledSystemUIMode(on ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
    if (mounted) MangoAnnounce.polite(context, on ? 'Focus mode on. Tap the page to show controls.' : 'Focus mode off');
  }

  Future<void> _runSearch(String text) async {
    _search?.clear();
    if (text.trim().isEmpty) return;
    final result = _pdf.searchText(text.trim());
    result.addListener(() {
      if (mounted) setState(() {});
      if (result.isSearchCompleted && mounted) {
        MangoAnnounce.polite(context, result.totalInstanceCount == 0 ? 'No matches' : '${result.totalInstanceCount} matches');
      }
    });
    setState(() => _search = result);
  }

  @override
  void dispose() {
    _tts.stop();
    _sleep?.cancel();
    _saveDebounce?.cancel();
    _searchCtrl.dispose();
    if (_focus) SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // Save one last time, immediately.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && _pageCount > 0) {
      FirebaseFirestore.instance.collection('media_progress').doc(uid).collection('items').doc(_key).set({
        'type': 'book', 'id': widget.bookId, 'title': _title.length > 120 ? _title.substring(0, 120) : _title,
        'page': _page, 'pageCount': _pageCount, 'bookmarks': _bookmarks.take(200).toList(),
        'completed': _page >= _pageCount, 'updatedAt': FieldValue.serverTimestamp(),
      }).catchError((_) {});
    }
    super.dispose();
  }

  // ----------------------------------------------------------------- UI
  ColorFilter? get _filter => switch (_theme) {
        ReaderTheme.paper => null,
        ReaderTheme.sepia => const ColorFilter.matrix(<double>[
            0.393, 0.769, 0.189, 0, 0,
            0.349, 0.686, 0.168, 0, 0,
            0.272, 0.534, 0.131, 0, 0,
            0, 0, 0, 1, 0,
          ]),
        // Inverts brightness for comfortable night reading.
        ReaderTheme.night => const ColorFilter.matrix(<double>[
            -0.9, 0, 0, 0, 235,
            0, -0.9, 0, 0, 235,
            0, 0, -0.9, 0, 225,
            0, 0, 0, 1, 0,
          ]),
      };

  Color get _bg => switch (_theme) {
        ReaderTheme.paper => const Color(0xFFF5F6F3),
        ReaderTheme.sepia => const Color(0xFFF1E7D0),
        ReaderTheme.night => const Color(0xFF0B0F0C),
      };

  @override
  Widget build(BuildContext context) {
    final onBg = _theme == ReaderTheme.night ? Colors.white : const Color(0xFF101310);
    return Scaffold(
      backgroundColor: _bg,
      appBar: _chrome ? _appBar(context, onBg) : null,
      body: SafeArea(
        top: _chrome,
        child: _error != null
            ? MangoStateView(
                kind: MangoStateKind.error,
                title: "Can't open this book",
                message: _error!,
                actionLabel: kIsWeb && _resolvedUrl != null ? 'Open in browser' : 'Try again',
                onAction: () {
                  if (kIsWeb && _resolvedUrl != null) {
                    launchUrl(Uri.parse(_resolvedUrl!));
                  } else {
                    setState(() => _error = null);
                    _load();
                  }
                },
              )
            : _bytes == null
                ? const MangoLoadingRegion(label: 'Opening book', child: Center(child: CircularProgressIndicator(semanticsLabel: 'Loading')))
                : Stack(children: [
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: _focus ? () => setState(() => _chrome = !_chrome) : null,
                        child: _themed(SfPdfViewer.memory(
                          _bytes!,
                          key: _viewerKey,
                          controller: _pdf,
                          pageLayoutMode: _continuous ? PdfPageLayoutMode.continuous : PdfPageLayoutMode.single,
                          scrollDirection: _continuous ? PdfScrollDirection.vertical : PdfScrollDirection.horizontal,
                          canShowScrollHead: !_focus,
                          canShowPaginationDialog: true,
                          enableTextSelection: true,
                          onDocumentLoaded: _onLoaded,
                          onPageChanged: _onPageChanged,
                          onDocumentLoadFailed: (d) => setState(() => _error = d.description),
                        )),
                      ),
                    ),
                    if (_guide) _readingGuide(context),
                    if (_chrome) Positioned(left: 0, right: 0, bottom: 0, child: _bottomBar(context, onBg)),
                  ]),
      ),
    );
  }

  Widget _themed(Widget child) {
    final f = _filter;
    return f == null ? child : ColorFiltered(colorFilter: f, child: child);
  }

  PreferredSizeWidget _appBar(BuildContext context, Color onBg) {
    if (_searching) {
      return AppBar(
        backgroundColor: _bg,
        foregroundColor: onBg,
        leading: MangoIconButton(icon: Icons.close_rounded, semanticLabel: 'Close search', onPressed: () {
          _search?.clear();
          setState(() {
            _searching = false;
            _search = null;
          });
        }),
        title: TextField(
          controller: _searchCtrl,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(hintText: 'Search in book', border: InputBorder.none, filled: false),
          onSubmitted: _runSearch,
        ),
        actions: [
          if (_search != null && _search!.hasResult)
            Center(child: Text('${_search!.currentInstanceIndex}/${_search!.totalInstanceCount}', style: TextStyle(color: onBg))),
          MangoIconButton(icon: Icons.keyboard_arrow_up_rounded, semanticLabel: 'Previous match', onPressed: _search?.hasResult == true ? () => _search!.previousInstance() : null),
          MangoIconButton(icon: Icons.keyboard_arrow_down_rounded, semanticLabel: 'Next match', onPressed: _search?.hasResult == true ? () => _search!.nextInstance() : null),
        ],
      );
    }
    final marked = _bookmarks.contains(_page);
    return AppBar(
      backgroundColor: _bg,
      foregroundColor: onBg,
      title: Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        MangoIconButton(icon: Icons.search_rounded, semanticLabel: 'Search in book', onPressed: () => setState(() => _searching = true)),
        MangoIconButton(icon: Icons.list_alt_rounded, semanticLabel: 'Contents', onPressed: () => _viewerKey.currentState?.openBookmarkView()),
        MangoIconButton(
          icon: marked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          semanticLabel: marked ? 'Remove bookmark from page $_page' : 'Bookmark page $_page',
          selected: marked,
          onPressed: _toggleBookmark,
        ),
        PopupMenuButton<String>(
          tooltip: 'More reading options',
          onSelected: (v) {
            switch (v) {
              case 'bookmarks':
                _showBookmarks();
              case 'layout':
                setState(() => _continuous = !_continuous);
                _savePrefs();
              case 'guide':
                setState(() => _guide = !_guide);
              case 'list':
                showAddToListSheet(context, type: 'book', id: widget.bookId, title: _title);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'bookmarks', child: Text('Bookmarks')),
            PopupMenuItem(value: 'layout', child: Text(_continuous ? 'Page by page' : 'Continuous scrolling')),
            PopupMenuItem(value: 'guide', child: Text(_guide ? 'Hide reading guide' : 'Show reading guide')),
            const PopupMenuItem(value: 'list', child: Text('Add to a list')),
          ],
        ),
      ],
    );
  }

  Widget _bottomBar(BuildContext context, Color onBg) {
    return Material(
      color: _bg.withValues(alpha: 0.96),
      elevation: 4,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(MangoSpace.s3, MangoSpace.s1, MangoSpace.s3, MangoSpace.s2),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_pageCount > 1)
              Semantics(
                label: 'Page',
                value: '$_page of $_pageCount',
                child: Slider(
                  value: _page.toDouble().clamp(1, _pageCount.toDouble()).toDouble(),
                  min: 1,
                  max: _pageCount.toDouble(),
                  divisions: _pageCount - 1,
                  label: 'Page $_page',
                  onChanged: (v) => setState(() => _page = v.round()),
                  onChangeEnd: (v) => _pdf.jumpToPage(v.round()),
                ),
              ),
            Row(children: [
              Expanded(
                child: Text(
                  _pageCount == 0 ? '' : 'Page $_page of $_pageCount · $_timeLeft',
                  style: context.type.bodySmall?.copyWith(color: onBg),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              MangoIconButton(
                icon: _reading ? Icons.stop_circle_rounded : Icons.record_voice_over_rounded,
                semanticLabel: _reading ? 'Stop reading aloud' : 'Read aloud',
                selected: _reading,
                onPressed: _toggleReadAloud,
              ),
              PopupMenuButton<String>(
                tooltip: 'Reading settings',
                icon: Icon(Icons.text_format_rounded, color: onBg),
                onSelected: (v) {
                  if (v.startsWith('theme:')) {
                    setState(() => _theme = ReaderTheme.values.byName(v.substring(6)));
                    _savePrefs();
                  } else if (v.startsWith('rate:')) {
                    setState(() => _speechRate = double.parse(v.substring(5)));
                    _savePrefs();
                  } else if (v.startsWith('sleep:')) {
                    _setSleep(int.parse(v.substring(6)));
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(enabled: false, child: Text('Theme')),
                  for (final t in ReaderTheme.values) CheckedPopupMenuItem(value: 'theme:${t.name}', checked: _theme == t, child: Text(t.name[0].toUpperCase() + t.name.substring(1))),
                  const PopupMenuDivider(),
                  const PopupMenuItem(enabled: false, child: Text('Reading voice speed')),
                  for (final r in const [(0.35, 'Slow'), (0.5, 'Normal'), (0.65, 'Fast')])
                    CheckedPopupMenuItem(value: 'rate:${r.$1}', checked: _speechRate == r.$1, child: Text(r.$2)),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'sleep:15', child: Text('Stop reading in 15 minutes')),
                  const PopupMenuItem(value: 'sleep:30', child: Text('Stop reading in 30 minutes')),
                ],
              ),
              MangoIconButton(
                icon: _focus ? Icons.fullscreen_exit_rounded : Icons.center_focus_strong_rounded,
                semanticLabel: _focus ? 'Leave focus mode' : 'Focus mode',
                selected: _focus,
                onPressed: () => _setFocus(!_focus),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  /// Dims the page except a band you read through; drag it or use the arrows.
  Widget _readingGuide(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final h = box.maxHeight;
      const band = 120.0;
      final top = (_guideY * h).clamp(0.0, h - band).toDouble();
      final shade = Colors.black.withValues(alpha: _theme == ReaderTheme.night ? 0.6 : 0.45);
      return Stack(children: [
        Positioned(left: 0, right: 0, top: 0, height: top, child: IgnorePointer(child: ColoredBox(color: shade))),
        Positioned(left: 0, right: 0, top: top + band, bottom: 0, child: IgnorePointer(child: ColoredBox(color: shade))),
        Positioned(
          right: MangoSpace.s2,
          top: top + band / 2 - 48,
          child: Semantics(
            label: 'Reading guide',
            child: Column(children: [
              MangoIconButton(icon: Icons.keyboard_arrow_up_rounded, semanticLabel: 'Move reading guide up', onPressed: () => setState(() => _guideY = (_guideY - 0.05).clamp(0.0, 1.0).toDouble())),
              GestureDetector(
                onVerticalDragUpdate: (d) => setState(() => _guideY = ((_guideY * h + d.delta.dy) / h).clamp(0.0, 1.0).toDouble()),
                child: const Icon(Icons.drag_indicator_rounded, color: Colors.white),
              ),
              MangoIconButton(icon: Icons.keyboard_arrow_down_rounded, semanticLabel: 'Move reading guide down', onPressed: () => setState(() => _guideY = (_guideY + 0.05).clamp(0.0, 1.0).toDouble())),
            ]),
          ),
        ),
      ]);
    });
  }

  void _showBookmarks() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: _bookmarks.isEmpty
            ? const Padding(padding: EdgeInsets.all(MangoSpace.s6), child: Text('No bookmarks yet. Tap the bookmark icon on any page.'))
            : ListView(shrinkWrap: true, children: [
                for (final p in _bookmarks)
                  ListTile(
                    leading: const Icon(Icons.bookmark_rounded),
                    title: Text('Page $p'),
                    onTap: () {
                      Navigator.pop(sheet);
                      _pdf.jumpToPage(p);
                    },
                    trailing: MangoIconButton(icon: Icons.delete_outline_rounded, semanticLabel: 'Remove bookmark from page $p', onPressed: () {
                      setState(() => _bookmarks.remove(p));
                      _saveProgress();
                      Navigator.pop(sheet);
                    }),
                  ),
              ]),
      ),
    );
  }
}
