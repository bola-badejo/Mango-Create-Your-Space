
import 'package:cloud_firestore/cloud_firestore.dart';

class SpaceConversation {
  final String id;
  final String title;
  final String description;
  final String createdBy;
  final String spaceId;
  final String? image;
  final String category;
  final List<String> participants;
  final List<String> admins;
  final int participantCount;
  final bool isActive;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  SpaceConversation({
    required this.id,
    required this.title,
    required this.description,
    required this.createdBy,
    required this.spaceId,
    this.image,
    required this.category,
    required this.participants,
    required this.admins,
    required this.participantCount,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SpaceConversation.fromMap(Map<String, dynamic> data, String id) {
    return SpaceConversation(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      createdBy: data['createdBy'] ?? '',
      spaceId: data['spaceId'] ?? '',
      image: data['image'],
      category: data['category'] ?? 'General Discussion',
      participants: List<String>.from(data['participants'] ?? []),
      admins: List<String>.from(data['admins'] ?? []),
      participantCount: data['participantCount'] ?? 1,
      isActive: data['isActive'] ?? true,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'createdBy': createdBy,
      'spaceId': spaceId,
      'image': image,
      'category': category,
      'participants': participants,
      'admins': admins,
      'participants': participantCount,
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}