import 'package:cloud_firestore/cloud_firestore.dart';

class MangoUser {
  final String id;
  final String email;
  final String gender;
  final String password;
  final String bannerImageUrl;
  final String profileImage;
  final String bio;
  final String displayName;
  final String dob;
  final String country;
  final String city;
  final String state;
  final String profession;
  final String phone;
  final String username;
  final String fcmToken;
  String creatorID;
  String vendorID;
  String distributorID;
  final List<dynamic> hobbies;
  final bool verified;
  final bool isCreator;
  final bool isVendor;
  final bool isDistributor;

  
  final String creatorName;
  final String vendorName;
  final String distributorName;
  final String creatorImageUrl;
  final String vendorImageUrl;
  final String distributorImageUrl;
  final String creatorLogoUrl;
  final String vendorLogoUrl;
  final String distributorLogoUrl;

  MangoUser({
    required this.id,
    required this.email,
    required this.gender,
    required this.password,
    required this.bannerImageUrl,
    required this.profileImage,
    required this.bio,
    required this.displayName,
    required this.dob,
    required this.country,
    required this.city,
    required this.state,
    required this.profession,
    required this.phone,
    required this.username,
    required this.fcmToken,
    required this.creatorID,
    required this.vendorID,
    required this.distributorID,
    required this.hobbies,
    required this.verified,
    required this.isCreator,
    required this.isVendor,
    required this.isDistributor,
    
    this.creatorName = '',
    this.vendorName = '',
    this.distributorName = '',
    this.creatorImageUrl = '',
    this.vendorImageUrl = '',
    this.distributorImageUrl = '',
    this.creatorLogoUrl = '',
    this.vendorLogoUrl = '',
    this.distributorLogoUrl = '',
  });

  factory MangoUser.fromMap(Map<String, dynamic> data, [String? id]) {
    return MangoUser(
      id: id ?? data['id'] ?? data['uid'] ?? '',
      email: data['email'] ?? '',
      gender: data['gender'] ?? '',
      password: data['password'] ?? '',
      bannerImageUrl: data['bannerImageUrl'] ?? data['bannerImage'] ?? '',
      profileImage:
          data['profileImage'] ??
          data['profileImageUrl'] ??
          data['photoURL'] ??
          '',
      bio: data['bio'] ?? '',
      displayName: data['displayName'] ?? data['name'] ?? '',
      dob: data['dob'] ?? data['dateOfBirth'] ?? '',
      country: data['country'] ?? '',
      city: data['city'] ?? '',
      state: data['state'] ?? '',
      profession: data['profession'] ?? '',
      phone: data['phone'] ?? data['phoneNumber'] ?? '',
      username: data['username'] ?? data['userName'] ?? '',
      fcmToken: data['fcmToken'] ?? data['fcm'] ?? '',
      creatorID: data['creatorID'] ?? data['creatorId'] ?? '',
      vendorID: data['vendorID'] ?? data['vendorId'] ?? '',
      distributorID:
          data['distributorID'] ??
          data['distributorId'] ??
          data['contributorID'] ??
          data['contributorId'] ??
          '',
      hobbies: List<dynamic>.from(data['hobbies'] ?? data['interests'] ?? []),
      verified: data['verified'] ?? data['emailVerified'] ?? false,
      isCreator: data['isCreator'] ?? false,
      isVendor: data['isVendor'] ?? false,
      isDistributor: data['isDistributor'] ?? false,
      
      creatorName: data['creatorName'] ?? '',
      vendorName: data['vendorName'] ?? '',
      distributorName: data['distributorName'] ?? '',
      creatorImageUrl: data['creatorImageUrl'] ?? '',
      vendorImageUrl: data['vendorImageUrl'] ?? '',
      distributorImageUrl: data['distributorImageUrl'] ?? '',
      creatorLogoUrl: data['creatorLogoUrl'] ?? '',
      vendorLogoUrl: data['vendorLogoUrl'] ?? '',
      distributorLogoUrl: data['distributorLogoUrl'] ?? '',
    );
  }

  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'gender': gender,
      'password': password,
      'bannerImageUrl': bannerImageUrl,
      'profileImage': profileImage,
      'bio': bio,
      'displayName': displayName,
      'dob': dob,
      'country': country,
      'city': city,
      'state': state,
      'profession': profession,
      'phone': phone,
      'username': username,
      'fcmToken': fcmToken,
      'creatorID': creatorID,
      'vendorID': vendorID,
      'distributorID': distributorID,
      'hobbies': hobbies,
      'verified': verified,
      'isCreator': isCreator,
      'isVendor': isVendor,
      'isDistributor': isDistributor,
      
      'creatorName': creatorName,
      'vendorName': vendorName,
      'distributorName': distributorName,
      'creatorImageUrl': creatorImageUrl,
      'vendorImageUrl': vendorImageUrl,
      'distributorImageUrl': distributorImageUrl,
      'creatorLogoUrl': creatorLogoUrl,
      'vendorLogoUrl': vendorLogoUrl,
      'distributorLogoUrl': distributorLogoUrl,
    };
  }

  static MangoUser fromFirestoreData(Map<String, dynamic> data, String id) {
    return MangoUser(
      id: id,
      email: data['email'] ?? '',
      gender: data['gender'] ?? '',
      password: data['password'] ?? '',
      bannerImageUrl: data['bannerImageUrl'] ?? '',
      profileImage: data['profileImage'] ?? '',
      bio: data['bio'] ?? '',
      displayName: data['displayName'] ?? '',
      dob: data['dob'] ?? '',
      country: data['country'] ?? '',
      city: data['city'] ?? '',
      state: data['state'] ?? '',
      profession: data['profession'] ?? '',
      phone: data['phone'] ?? '',
      username: data['username'] ?? '',
      fcmToken: data['fcmToken'] ?? '',
      creatorID: data['creatorID'] ?? data['creatorId'] ?? '',
      vendorID: data['vendorID'] ?? data['vendorId'] ?? '',
      distributorID:
          data['distributorID'] ??
          data['distributorId'] ??
          data['contributorID'] ??
          data['contributorId'] ??
          '',
      hobbies: data['hobbies'] ?? [],
      verified: data['verified'] ?? false,
      isCreator: data['isCreator'] ?? false,
      isVendor: data['isVendor'] ?? false,
      isDistributor: data['isDistributor'] ?? false,
      
      creatorName: data['creatorName'] ?? '',
      vendorName: data['vendorName'] ?? '',
      distributorName: data['distributorName'] ?? '',
      creatorImageUrl: data['creatorImageUrl'] ?? '',
      vendorImageUrl: data['vendorImageUrl'] ?? '',
      distributorImageUrl: data['distributorImageUrl'] ?? '',
      creatorLogoUrl: data['creatorLogoUrl'] ?? '',
      vendorLogoUrl: data['vendorLogoUrl'] ?? '',
      distributorLogoUrl: data['distributorLogoUrl'] ?? '',
    );
  }

  factory MangoUser.fromJson(Map<String, dynamic> json) =>
      MangoUser.fromMap(json);
  Map<String, dynamic> toJson() => toMap();

  factory MangoUser.fromDocument(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>? ?? {};
    return MangoUser.fromMap({...data, 'id': snapshot.id});
  }

  
  factory MangoUser.fromQueryDocumentSnapshot(QueryDocumentSnapshot doc) {
    return MangoUser.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  factory MangoUser.empty() {
    return MangoUser(
      id: '',
      email: '',
      gender: '',
      password: '',
      bannerImageUrl: '',
      profileImage: '',
      bio: '',
      displayName: '',
      dob: '',
      country: '',
      city: '',
      state: '',
      profession: '',
      phone: '',
      username: '',
      fcmToken: '',
      creatorID: '',
      vendorID: '',
      distributorID: '',
      hobbies: [],
      verified: false,
      isCreator: false,
      isVendor: false,
      isDistributor: false,
      
      creatorName: '',
      vendorName: '',
      distributorName: '',
      creatorImageUrl: '',
      vendorImageUrl: '',
      distributorImageUrl: '',
      creatorLogoUrl: '',
      vendorLogoUrl: '',
      distributorLogoUrl: '',
    );
  }

  factory MangoUser.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};
    return MangoUser.fromMap({...data, 'id': snapshot.id});
  }

  MangoUser copyWith({
    String? id,
    String? email,
    String? gender,
    String? password,
    String? bannerImageUrl,
    String? profileImage,
    String? bio,
    String? displayName,
    String? dob,
    String? country,
    String? city,
    String? state,
    String? profession,
    String? phone,
    String? username,
    String? fcmToken,
    String? creatorID,
    String? vendorID,
    String? distributorID,
    List<dynamic>? hobbies,
    bool? verified,
    bool? isCreator,
    bool? isVendor,
    bool? isDistributor,
    
    String? creatorName,
    String? vendorName,
    String? distributorName,
    String? creatorImageUrl,
    String? vendorImageUrl,
    String? distributorImageUrl,
    String? creatorLogoUrl,
    String? vendorLogoUrl,
    String? distributorLogoUrl,
  }) {
    return MangoUser(
      id: id ?? this.id,
      email: email ?? this.email,
      gender: gender ?? this.gender,
      password: password ?? this.password,
      bannerImageUrl: bannerImageUrl ?? this.bannerImageUrl,
      profileImage: profileImage ?? this.profileImage,
      bio: bio ?? this.bio,
      displayName: displayName ?? this.displayName,
      dob: dob ?? this.dob,
      country: country ?? this.country,
      city: city ?? this.city,
      state: state ?? this.state,
      profession: profession ?? this.profession,
      phone: phone ?? this.phone,
      username: username ?? this.username,
      fcmToken: fcmToken ?? this.fcmToken,
      creatorID: creatorID ?? this.creatorID,
      vendorID: vendorID ?? this.vendorID,
      distributorID: distributorID ?? this.distributorID,
      hobbies: hobbies ?? this.hobbies,
      verified: verified ?? this.verified,
      isCreator: isCreator ?? this.isCreator,
      isVendor: isVendor ?? this.isVendor,
      isDistributor: isDistributor ?? this.isDistributor,
      
      creatorName: creatorName ?? this.creatorName,
      vendorName: vendorName ?? this.vendorName,
      distributorName: distributorName ?? this.distributorName,
      creatorImageUrl: creatorImageUrl ?? this.creatorImageUrl,
      vendorImageUrl: vendorImageUrl ?? this.vendorImageUrl,
      distributorImageUrl: distributorImageUrl ?? this.distributorImageUrl,
      creatorLogoUrl: creatorLogoUrl ?? this.creatorLogoUrl,
      vendorLogoUrl: vendorLogoUrl ?? this.vendorLogoUrl,
      distributorLogoUrl: distributorLogoUrl ?? this.distributorLogoUrl,
    );
  }
}
