// Where something is playing from: a Space, a content list, home, a
// profile, search or recommendations. Kept with the queue so "Playing from
// Tobi's Studio" survives the app being closed.
class PlaySource {
  const PlaySource({required this.kind, this.id, required this.label});

  /// One of: space, list, home, profile, search, library, recommendation, other.
  final String kind;
  final String? id;
  final String label;

  static const home = PlaySource(kind: 'home', label: 'Home');

  Map<String, dynamic> toJson() => {'kind': kind, if (id != null) 'id': id, 'label': label};

  factory PlaySource.fromJson(Map<String, dynamic>? j) => j == null
      ? home
      : PlaySource(kind: (j['kind'] ?? 'other') as String, id: j['id'] as String?, label: (j['label'] ?? '') as String);

  @override
  bool operator ==(Object other) => other is PlaySource && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}
