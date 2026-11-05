import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class ContributorProfile {
  final String contributorId; 
  final String userId;        
  final String fullName;
  final String email;
  final String phone;
  final String address;
  final String skill;
  final List<String> tags;
  final String portfolio;
  final String bio;
  final String socialMedia;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String type;          
  final bool isActive;

  // Image fields
  final String? profileImageUrl;
  final String? logoImageUrl;
  final String? bannerImageUrl; 

  // Stats
  final int followers;
  final int monthlyListeners; 
  final bool isVerified;
  final bool isPremium;

  // Location
  final String? location;

  // Enhanced fields for categories
  final List<String> categories;      // Main content categories
  final List<String> subCategories;    // Specializations

  // Creator-specific fields
  final String? stageName;
  final String? creatorType;           // 'Freelance' or 'Signed'
  final String? companyName;
  final String? companyAddress;

  // Distributor-specific fields
  final String? distributorLabel;

  // Vendor-specific fields
  final String? storeName;

  // Social links
  final Map<String, String>? socialLinks;  // Instagram, Twitter, TikTok, etc.

  // Achievements
  final List<String>? achievements;
  final double rating;
  final int totalReviews;

  // Content statistics
  final int totalProducts;
  final int totalEarnings;
  final int totalSales;

  ContributorProfile({
    required this.contributorId,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.address,
    required this.skill,
    required this.tags,
    required this.portfolio,
    required this.bio,
    required this.socialMedia,
    required this.createdAt,
    this.updatedAt,
    required this.type,
    this.isActive = true,
    this.profileImageUrl,
    this.logoImageUrl,
    this.bannerImageUrl,
    this.followers = 0,
    this.monthlyListeners = 0,
    this.isVerified = false,
    this.isPremium = false,
    this.location,
    this.categories = const [],
    this.subCategories = const [],
    this.stageName,
    this.creatorType,
    this.companyName,
    this.companyAddress,
    this.distributorLabel,
    this.storeName,
    this.socialLinks,
    this.achievements,
    this.rating = 0.0,
    this.totalReviews = 0,
    this.totalProducts = 0,
    this.totalEarnings = 0,
    this.totalSales = 0,
  });

  factory ContributorProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return ContributorProfile(
      contributorId: doc.id,
      userId: data['userId'] ?? '',
      fullName: data['fullName'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      address: data['address'] ?? '',
      skill: data['skill'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      portfolio: data['portfolio'] ?? '',
      bio: data['bio'] ?? '',
      socialMedia: data['socialMedia'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      type: data['type'] ?? '',
      isActive: data['isActive'] ?? true,
      profileImageUrl: data['profileImageUrl'],
      logoImageUrl: data['logoImageUrl'],
      bannerImageUrl: data['bannerImageUrl'],
      followers: data['followers'] ?? 0,
      monthlyListeners: data['monthlyListeners'] ?? 0,
      isVerified: data['isVerified'] ?? false,
      isPremium: data['isPremium'] ?? false,
      location: data['location'],
      categories: List<String>.from(data['categories'] ?? []),
      subCategories: List<String>.from(data['subCategories'] ?? []),
      stageName: data['stageName'],
      creatorType: data['creatorType'],
      companyName: data['companyName'],
      companyAddress: data['companyAddress'],
      distributorLabel: data['distributorLabel'],
      storeName: data['storeName'],
      socialLinks: Map<String, String>.from(data['socialLinks'] ?? {}),
      achievements: List<String>.from(data['achievements'] ?? []),
      rating: (data['rating'] ?? 0.0).toDouble(),
      totalReviews: data['totalReviews'] ?? 0,
      totalProducts: data['totalProducts'] ?? 0,
      totalEarnings: data['totalEarnings'] ?? 0,
      totalSales: data['totalSales'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'contributorId': contributorId,
      'userId': userId,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'address': address,
      'skill': skill,
      'tags': tags,
      'portfolio': portfolio,
      'bio': bio,
      'socialMedia': socialMedia,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      'type': type,
      'isActive': isActive,
      'categories': categories,
      'subCategories': subCategories,
      'followers': followers,
      'monthlyListeners': monthlyListeners,
      'isVerified': isVerified,
      'isPremium': isPremium,
      'rating': rating,
      'totalReviews': totalReviews,
      'totalProducts': totalProducts,
      'totalEarnings': totalEarnings,
      'totalSales': totalSales,
    };

    // Optional fields
    if (profileImageUrl != null) map['profileImageUrl'] = profileImageUrl;
    if (logoImageUrl != null) map['logoImageUrl'] = logoImageUrl;
    if (bannerImageUrl != null) map['bannerImageUrl'] = bannerImageUrl;
    if (location != null) map['location'] = location;
    if (stageName != null) map['stageName'] = stageName;
    if (creatorType != null) map['creatorType'] = creatorType;
    if (companyName != null) map['companyName'] = companyName;
    if (companyAddress != null) map['companyAddress'] = companyAddress;
    if (distributorLabel != null) map['distributorLabel'] = distributorLabel;
    if (storeName != null) map['storeName'] = storeName;
    if (socialLinks != null && socialLinks!.isNotEmpty) map['socialLinks'] = socialLinks;
    if (achievements != null && achievements!.isNotEmpty) map['achievements'] = achievements;

    return map;
  }

  // Helper getters
  bool get isCreator => type.toLowerCase() == 'creator';
  bool get isDistributor => type.toLowerCase() == 'distributor';
  bool get isVendor => type.toLowerCase() == 'vendor';

  String get displayName {
    if (isCreator && (stageName?.isNotEmpty ?? false)) return stageName!;
    if (isDistributor && (distributorLabel?.isNotEmpty ?? false)) return distributorLabel!;
    if (isVendor && (storeName?.isNotEmpty ?? false)) return storeName!;
    return fullName.isNotEmpty ? fullName : 'Contributor';
  }

  String get roleTitle {
    switch (type.toLowerCase()) {
      case 'creator':
        return 'Content Creator';
      case 'distributor':
        return 'Distributor';
      case 'vendor':
        return 'Vendor';
      default:
        return 'Contributor';
    }
  }

  String get profileImage => profileImageUrl ?? '';
  String get bannerImage => bannerImageUrl ?? '';

  // Format earnings
  String get formattedEarnings {
    if (totalEarnings >= 1000000) {
      return '\$${(totalEarnings / 1000000).toStringAsFixed(1)}M';
    } else if (totalEarnings >= 1000) {
      return '\$${(totalEarnings / 1000).toStringAsFixed(1)}K';
    }
    return '\$$totalEarnings';
  }

  // Format followers count
  String get formattedFollowers {
    if (followers >= 1000000) {
      return '${(followers / 1000000).toStringAsFixed(1)}M';
    } else if (followers >= 1000) {
      return '${(followers / 1000).toStringAsFixed(1)}K';
    }
    return followers.toString();
  }

  // Get primary color based on role
  Color get roleColor {
    switch (type.toLowerCase()) {
      case 'creator':
        return Colors.blue;
      case 'distributor':
        return MangoPalette.green500;
      case 'vendor':
        return MangoPalette.green500;
      default:
        return MangoPalette.grey500;
    }
  }

  // Get role icon
  IconData get roleIcon {
    switch (type.toLowerCase()) {
      case 'creator':
        return Icons.brush;
      case 'distributor':
        return Icons.share;
      case 'vendor':
        return Icons.store;
      default:
        return Icons.person;
    }
  }
}