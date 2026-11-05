// Space item catalog (skins, icons, objects), loaded from the bundled
// asset/space_catalog.json. The server holds an identical copy and is the
// only authority on prices and ownership; this copy is for display.
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum SpaceItemKind { skin, icon, object }

class SpaceItem {
  SpaceItem({
    required this.id,
    required this.kind,
    required this.name,
    required this.price,
    required this.rarity,
    required this.render,
  });

  final String id;
  final SpaceItemKind kind;
  final String name;

  /// Price in MNG as a decimal string, for display.
  final String price;
  final String rarity;
  final Map<String, dynamic> render;

  bool get isFree => price == '0';
  String get glyph => (render['glyph'] ?? '✨') as String;
  double get size => ((render['size'] ?? 1.0) as num).toDouble();
  List<Color> get colors => ((render['colors'] ?? const ['#E4F1E8', '#C6E3D0']) as List)
      .map((c) => _hex(c as String))
      .toList();
  String get pattern => (render['pattern'] ?? 'none') as String;
  bool get isDark => render['dark'] == true;

  static Color _hex(String hex) => Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));

  factory SpaceItem.fromJson(Map<String, dynamic> j) => SpaceItem(
        id: j['id'] as String,
        kind: SpaceItemKind.values.byName(j['kind'] as String),
        name: j['name'] as String,
        price: j['price'] as String,
        rarity: j['rarity'] as String,
        render: Map<String, dynamic>.from(j['render'] as Map),
      );
}

class SpaceCatalog {
  SpaceCatalog._(this.items);

  final Map<String, SpaceItem> items;

  static SpaceCatalog? _instance;

  static Future<SpaceCatalog> load() async {
    if (_instance != null) return _instance!;
    final raw = await rootBundle.loadString('asset/space_catalog.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final list = (data['items'] as List).map((e) => SpaceItem.fromJson(Map<String, dynamic>.from(e as Map)));
    _instance = SpaceCatalog._({for (final i in list) i.id: i});
    return _instance!;
  }

  SpaceItem? operator [](String? id) => id == null ? null : items[id];

  Iterable<SpaceItem> ofKind(SpaceItemKind kind) => items.values.where((i) => i.kind == kind);
}

/// The Space background: the skin's gradient plus a subtle pattern.
class SpaceSkinBackground extends StatelessWidget {
  const SpaceSkinBackground({super.key, required this.skin, this.child});

  final SpaceItem? skin;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colors = skin?.colors ?? const [Color(0xFFE4F1E8), Color(0xFFC6E3D0)];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: CustomPaint(
        painter: _PatternPainter(skin?.pattern ?? 'none', (skin?.isDark ?? false)),
        child: child ?? const SizedBox.expand(),
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  _PatternPainter(this.pattern, this.dark);

  final String pattern;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (dark ? Colors.white : Colors.black).withValues(alpha: 0.06)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    switch (pattern) {
      case 'dots':
        final dot = Paint()..color = paint.color;
        for (double x = 12; x < size.width; x += 28) {
          for (double y = 12; y < size.height; y += 28) {
            canvas.drawCircle(Offset(x, y), 1.6, dot);
          }
        }
      case 'grid':
        for (double x = 0; x < size.width; x += 40) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        }
        for (double y = 0; y < size.height; y += 40) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
      case 'waves':
        for (double y = 20; y < size.height; y += 36) {
          final path = Path()..moveTo(0, y);
          for (double x = 0; x <= size.width; x += 12) {
            path.lineTo(x, y + math.sin(x / 24) * 6);
          }
          canvas.drawPath(path, paint);
        }
      case 'rays':
        final c = Offset(size.width / 2, 0);
        for (int i = 0; i < 18; i++) {
          final a = math.pi * i / 17;
          canvas.drawLine(c, c + Offset(math.cos(a), math.sin(a)) * size.longestSide, paint);
        }
      case 'aurora':
        final glow = Paint()
          ..shader = LinearGradient(colors: [
            const Color(0xFF5FBF8A).withValues(alpha: 0.25),
            const Color(0xFF7F5AF0).withValues(alpha: 0.18),
            Colors.transparent,
          ]).createShader(Offset.zero & size);
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.55), glow);
      default:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter old) => old.pattern != pattern || old.dark != dark;
}

/// An icon or object glyph, sized and labelled for screen readers.
class SpaceGlyph extends StatelessWidget {
  const SpaceGlyph({super.key, required this.item, this.size = 40, this.label});

  final SpaceItem? item;
  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label ?? item?.name,
      image: true,
      child: ExcludeSemantics(
        child: Text(item?.glyph ?? '✨', style: TextStyle(fontSize: size, height: 1.1)),
      ),
    );
  }
}
