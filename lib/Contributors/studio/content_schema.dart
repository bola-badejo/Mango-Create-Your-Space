// What each kind of creator content looks like: its fields, its files and
// how it is stored, in the app's existing data model, so new uploads and
// old ones live side by side.
import 'package:mango/Media/compose/mango_composer.dart';

enum FieldKind { text, multiline, number, choice, toggle, tags }

class FieldSpec {
  const FieldSpec(this.key, this.label, this.kind, {this.required = false, this.choices = const [], this.max = 120, this.help});

  final String key;
  final String label;
  final FieldKind kind;
  final bool required;
  final List<String> choices;
  final int max;
  final String? help;
}

class FileSpec {
  const FileSpec(this.key, this.label, this.allow, {this.required = false, this.crop, this.help});

  /// Document field that receives the download URL.
  final String key;
  final String label;
  final Set<ComposeKind> allow;
  final bool required;
  final CropShape? crop;
  final String? help;
}

class ContentType {
  const ContentType({
    required this.id,
    required this.label,
    required this.collection,
    required this.titleKey,
    required this.imageKey,
    required this.ownerFields,
    required this.nameField,
    required this.fields,
    required this.files,
    required this.statKey,
    required this.statLabel,
    this.defaults = const {},
  });

  final String id;
  final String label;
  final String collection;
  final String titleKey;
  final String imageKey;

  /// Fields set to the creator's uid (new and legacy owner fields).
  final List<String> ownerFields;

  /// Field set to the creator's display name, if any.
  final String? nameField;
  final List<FieldSpec> fields;
  final List<FileSpec> files;
  final String statKey;
  final String statLabel;
  final Map<String, dynamic> defaults;

  /// Field used to list a creator's items.
  String get queryField => ownerFields.firstWhere((f) => f != 'ownerId', orElse: () => 'ownerId');
}

const _musicGenres = ['Afrobeats', 'Amapiano', 'Hip-Hop', 'R&B', 'Pop', 'Gospel', 'Highlife', 'Jazz', 'Rock', 'Electronic', 'Reggae', 'Classical', 'Other'];
const _bookGenres = ['Fiction', 'Non-fiction', 'Romance', 'Fantasy', 'Thriller', 'Business', 'Self-help', 'Poetry', 'Children', 'Education', 'Other'];
const _filmGenres = ['Drama', 'Comedy', 'Action', 'Thriller', 'Romance', 'Documentary', 'Animation', 'Horror', 'Short film', 'Other'];

const contentTypes = <String, ContentType>{
  'song': ContentType(
    id: 'song', label: 'Song', collection: 'music', titleKey: 'title', imageKey: 'artworkUrl',
    ownerFields: ['ownerId', 'artistId'], nameField: 'artistName', statKey: 'plays', statLabel: 'plays',
    fields: [
      FieldSpec('title', 'Title', FieldKind.text, required: true, max: 100),
      FieldSpec('genre', 'Genre', FieldKind.choice, required: true, choices: _musicGenres),
      FieldSpec('description', 'Description', FieldKind.multiline, max: 1000),
      FieldSpec('releaseYear', 'Release year', FieldKind.number, max: 4),
      FieldSpec('isExplicit', 'Explicit lyrics', FieldKind.toggle),
      FieldSpec('lyrics', 'Lyrics', FieldKind.multiline, max: 10000, help: 'Optional. Shown on the lyrics screen.'),
    ],
    files: [
      FileSpec('trackUrl', 'Audio file', {ComposeKind.audio}, required: true, help: 'MP3, M4A, WAV or AAC'),
      FileSpec('artworkUrl', 'Cover art', {ComposeKind.image}, required: true, crop: CropShape.square),
    ],
    defaults: {'plays': 0, 'likes': 0, 'credits': [], 'fileSize': 0},
  ),
  'podcast': ContentType(
    id: 'podcast', label: 'Podcast episode', collection: 'podcasts', titleKey: 'title', imageKey: 'artworkUrl',
    ownerFields: ['ownerId', 'userId'], nameField: 'userDisplayName', statKey: 'plays', statLabel: 'plays',
    fields: [
      FieldSpec('title', 'Episode title', FieldKind.text, required: true, max: 120),
      FieldSpec('category', 'Category', FieldKind.choice, required: true, choices: ['Business', 'Comedy', 'Culture', 'Education', 'Faith', 'Health', 'Music', 'News', 'Sports', 'Technology', 'Other']),
      FieldSpec('host', 'Host', FieldKind.text, max: 60),
      FieldSpec('description', 'Show notes', FieldKind.multiline, max: 4000),
      FieldSpec('language', 'Language', FieldKind.text, max: 30),
      FieldSpec('explicitContent', 'Explicit', FieldKind.toggle),
    ],
    files: [
      FileSpec('audioUrl', 'Episode audio', {ComposeKind.audio}, required: true),
      FileSpec('artworkUrl', 'Cover art', {ComposeKind.image}, required: true, crop: CropShape.square),
    ],
    defaults: {'plays': 0, 'likes': 0, 'favorites': 0, 'shares': 0, 'downloads': 0, 'fileSize': 0, 'duration': 0},
  ),
  'movie': ContentType(
    id: 'movie', label: 'Film', collection: 'movies', titleKey: 'title', imageKey: 'posterUrl',
    ownerFields: ['ownerId', 'userId'], nameField: 'userDisplayName', statKey: 'views', statLabel: 'views',
    fields: [
      FieldSpec('title', 'Title', FieldKind.text, required: true, max: 120),
      FieldSpec('genre', 'Genre', FieldKind.choice, required: true, choices: _filmGenres),
      FieldSpec('description', 'Synopsis', FieldKind.multiline, max: 2000),
      FieldSpec('director', 'Director', FieldKind.text, max: 60),
      FieldSpec('releaseYear', 'Release year', FieldKind.number, max: 4),
      FieldSpec('runtime', 'Runtime (minutes)', FieldKind.number, max: 4),
      FieldSpec('language', 'Language', FieldKind.text, max: 30),
    ],
    files: [
      FileSpec('videoUrl', 'Film', {ComposeKind.video}, required: true),
      FileSpec('posterUrl', 'Poster', {ComposeKind.image}, required: true, crop: CropShape.portrait),
      FileSpec('backdropUrl', 'Backdrop', {ComposeKind.image}, crop: CropShape.landscape),
      FileSpec('trailerUrl', 'Trailer', {ComposeKind.video}),
    ],
    defaults: {'views': 0, 'likes': 0, 'favorites': 0, 'shares': 0, 'downloads': 0, 'isPublished': true},
  ),
  'book': ContentType(
    id: 'book', label: 'Book', collection: 'books', titleKey: 'title', imageKey: 'coverUrl',
    ownerFields: ['ownerId', 'userId', 'uploaderId'], nameField: null, statKey: 'reads', statLabel: 'reads',
    fields: [
      FieldSpec('title', 'Title', FieldKind.text, required: true, max: 120),
      FieldSpec('author', 'Author', FieldKind.text, required: true, max: 80),
      FieldSpec('genre', 'Genre', FieldKind.choice, required: true, choices: _bookGenres),
      FieldSpec('description', 'Description', FieldKind.multiline, max: 3000),
      FieldSpec('pages', 'Pages', FieldKind.number, max: 5),
      FieldSpec('language', 'Language', FieldKind.text, max: 30),
      FieldSpec('isbn', 'ISBN', FieldKind.text, max: 20),
      FieldSpec('publisher', 'Publisher', FieldKind.text, max: 80),
      FieldSpec('releaseYear', 'Year', FieldKind.number, max: 4),
    ],
    files: [
      FileSpec('fileUrl', 'Book file', {ComposeKind.document}, required: true, help: 'PDF'),
      FileSpec('coverUrl', 'Cover', {ComposeKind.image}, required: true, crop: CropShape.portrait),
    ],
    defaults: {'reads': 0, 'likes': 0},
  ),
  'product': ContentType(
    id: 'product', label: 'Product', collection: 'products', titleKey: 'title', imageKey: 'imageUrl',
    ownerFields: ['ownerId', 'userId'], nameField: 'vendorName', statKey: 'viewCount', statLabel: 'views',
    fields: [
      FieldSpec('title', 'Product name', FieldKind.text, required: true, max: 100),
      FieldSpec('description', 'Description', FieldKind.multiline, required: true, max: 3000),
      FieldSpec('category', 'Category', FieldKind.choice, required: true, choices: ['Fashion', 'Beauty', 'Art', 'Books', 'Music gear', 'Electronics', 'Home', 'Food', 'Services', 'Other']),
      FieldSpec('price', 'Price (₦)', FieldKind.number, required: true, max: 10),
      FieldSpec('stockQuantity', 'In stock', FieldKind.number, max: 6),
      FieldSpec('tags', 'Tags', FieldKind.tags, max: 200, help: 'Separate with commas'),
    ],
    files: [
      FileSpec('imageUrl', 'Main photo', {ComposeKind.image}, required: true, crop: CropShape.square),
    ],
    defaults: {'isActive': true, 'rating': 0, 'reviewCount': 0, 'viewCount': 0, 'soldCount': 0, 'variants': [], 'attributes': {}, 'likedBy': [], 'comments': []},
  ),
  'vine': ContentType(
    id: 'vine', label: 'Vine', collection: 'vines', titleKey: 'caption', imageKey: 'thumbnailUrl',
    ownerFields: ['ownerId', 'postCreator'], nameField: null, statKey: 'views', statLabel: 'views',
    fields: [FieldSpec('caption', 'Caption', FieldKind.multiline, max: 500)],
    files: [
      FileSpec('videoUrl', 'Video', {ComposeKind.video}, required: true),
      FileSpec('thumbnailUrl', 'Cover', {ComposeKind.image}, crop: CropShape.story),
    ],
    defaults: {'views': 0, 'likes': 0},
  ),
};

/// Which content each contributor role works with.
const roleContent = <String, List<String>>{
  'creator': ['song', 'podcast', 'movie', 'book', 'vine'],
  'distributor': ['song', 'movie', 'book'],
  'vendor': ['product'],
};
