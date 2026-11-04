import 'dart:io';

void main() {
  final libDir = Directory('lib');

  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      final content = entity.readAsStringSync();

      final noSingleLine = content.replaceAllMapped(
        RegExp(r'(^|\s)//.*', multiLine: true),
        (m) => m.group(1) ?? '',
      );

      final noBlock = noSingleLine.replaceAll(
        RegExp(r'/\*[\s\S]*?\*/'),
        '',
      );

      entity.writeAsStringSync(noBlock);
    }
  }

  print('✅ All comments removed from lib/');
}
