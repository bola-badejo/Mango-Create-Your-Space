import 'package:cloud_firestore/cloud_firestore.dart';

class SpaceModel {
  final String id;
  final String title;
  final String category;
  final String iconUrl;
  final String description;
  final String postCreator;
  final String price;
  final int members;
  final String rating;
  final String image;
  final bool isPrivate;
  final String? spaceBackground;
  final bool hasMusic;
  final bool hasMovies;
  final bool hasBooks;
  final bool hasVines;
  final bool hasShop;
  final bool hasLounge;
  final bool hasPodcast;
  final List<dynamic> collaborators;

  SpaceModel({
    required this.id,
    required this.title,
    required this.hasBooks,
    required this.description,
    required this.hasVines,
    required this.hasShop,
    required this.spaceBackground,
    required this.category,
    required this.iconUrl,
    required this.price,
    required this.postCreator,
    required this.members,
    required this.rating,
    required this.image,
    required this.isPrivate,
    required this.hasMusic,
    required this.hasMovies,
    required this.hasLounge,
    required this.hasPodcast,
    required this.collaborators,
  });

  // NEW: Copy with method to create a new instance with updated values
  SpaceModel copyWith({
    String? id,
    String? title,
    String? category,
    String? iconUrl,
    String? description,
    String? postCreator,
    String? price,
    int? members,
    String? spaceBackground,
    String? rating,
    String? image,
    bool? isPrivate,
    bool? hasMusic,
    bool? hasMovies,
    bool? hasBooks,
    bool? hasVines,
    bool? hasShop,
    bool? hasLounge,
    bool? hasPodcast,
    List<dynamic>? collaborators,
  }) {
    return SpaceModel(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      iconUrl: iconUrl ?? this.iconUrl,
      description: description ?? this.description,
      postCreator: postCreator ?? this.postCreator,
      price: price ?? this.price,
      members: members ?? this.members,
      rating: rating ?? this.rating,
      image: image ?? this.image,
      isPrivate: isPrivate ?? this.isPrivate,
      spaceBackground: spaceBackground ?? this.spaceBackground,
      hasMusic: hasMusic ?? this.hasMusic,
      hasMovies: hasMovies ?? this.hasMovies,
      hasBooks: hasBooks ?? this.hasBooks,
      hasVines: hasVines ?? this.hasVines,
      hasShop: hasShop ?? this.hasShop,
      hasLounge: hasLounge ?? this.hasLounge,
      hasPodcast: hasPodcast ?? this.hasPodcast,
      collaborators: collaborators ?? this.collaborators,
    );
  }

  factory SpaceModel.fromDocumentSnapshot(DocumentSnapshot snapshot) {
    print(snapshot.data);
    return SpaceModel(
      id: snapshot.id,
      title: snapshot['title'],
      category: snapshot['category'] ?? '',
      description: snapshot['description'] ?? '',
      price: snapshot['price'] ?? '',
      members: snapshot['members'] ?? 0,
      rating: snapshot['rating'] ?? '',
      iconUrl: snapshot['iconUrl'] ?? '',
      image: snapshot['image'] ?? '',
      postCreator: snapshot['postCreator'] ?? '',
      isPrivate: snapshot['isPrivate'] ?? false,
      hasMusic: snapshot['hasMusic'] ?? false,
      spaceBackground: snapshot['spaceBackground'] ?? '',
      hasShop: snapshot['hasShop'] ?? false,
      hasBooks: snapshot['hasBooks'] ?? false,
      hasVines: snapshot['hasVines'] ?? false,
      hasMovies: snapshot['hasMovies'] ?? false,
      hasLounge: snapshot['hasLounge'] ?? false,
      hasPodcast: snapshot['hasPodcast'] ?? false,
      collaborators: snapshot['collaborators'] ?? [],
    );
  }
  
  // Optional: Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'iconUrl': iconUrl,
      'description': description,
      'postCreator': postCreator,
      'price': price,
      'members': members,
      'rating': rating,
      'spaceBackground': spaceBackground,
      'image': image,
      'isPrivate': isPrivate,
      'hasMusic': hasMusic,
      'hasMovies': hasMovies,
      'hasBooks': hasBooks,
      'hasVines': hasVines,
      'hasShop': hasShop,
      'hasLounge': hasLounge,
      'hasPodcast': hasPodcast,
      'collaborators': collaborators,
    };
  }
}