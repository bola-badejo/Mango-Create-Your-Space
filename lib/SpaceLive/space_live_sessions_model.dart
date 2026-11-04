import 'package:mango/models/customModel/user.dart';

enum SessionStatus { scheduled, live, ended }
enum UserRole { host, speaker, listener }

class SessionUser {
  final MangoUser user;
  final UserRole role;
  final bool isMuted;
  final bool hasRequestedToSpeak;
  final DateTime joinedAt;

  SessionUser({
    required this.user,
    required this.role,
    this.isMuted = false,
    this.hasRequestedToSpeak = false,
    required this.joinedAt,
  });

  SessionUser copyWith({
    UserRole? role,
    bool? isMuted,
    bool? hasRequestedToSpeak,
  }) {
    return SessionUser(
      user: user,
      role: role ?? this.role,
      isMuted: isMuted ?? this.isMuted,
      hasRequestedToSpeak: hasRequestedToSpeak ?? this.hasRequestedToSpeak,
      joinedAt: joinedAt,
    );
  }

  factory SessionUser.fromJson(Map<String, dynamic> json) {
    return SessionUser(
      user: MangoUser.fromJson(Map<String, dynamic>.from(json['user'])),
      role: UserRole.values.firstWhere(
        (e) => e.toString().split('.').last == json['role'],
        orElse: () => UserRole.listener,
      ),
      isMuted: json['isMuted'] ?? false,
      hasRequestedToSpeak: json['hasRequestedToSpeak'] ?? false,
      joinedAt: json['joinedAt'] != null 
          ? DateTime.parse(json['joinedAt'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'role': role.toString().split('.').last,
      'isMuted': isMuted,
      'hasRequestedToSpeak': hasRequestedToSpeak,
      'joinedAt': joinedAt.toIso8601String(),
    };
  }
}

class LiveSession {
  final String id;
  final MangoUser host;
  final String title;
  final SessionStatus status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final List<SessionUser> participants;
  final bool isPrivate;
  final List<String> speakerIds;

  LiveSession({
    required this.id,
    required this.host,
    required this.title,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
    required this.participants,
    required this.speakerIds,
    this.isPrivate = false,
  });

  List<SessionUser> get speakers => participants
      .where((p) => speakerIds.contains(p.user.id) || p.role == UserRole.host)
      .toList();

  List<SessionUser> get listeners => participants
      .where((p) => !speakerIds.contains(p.user.id) && p.role != UserRole.host)
      .toList();

  LiveSession copyWith({
    List<SessionUser>? participants,
    List<String>? speakerIds,
    SessionStatus? status,
  }) {
    return LiveSession(
      id: id,
      host: host,
      title: title,
      status: status ?? this.status,
      createdAt: createdAt,
      startedAt: startedAt,
      endedAt: endedAt,
      participants: participants ?? this.participants,
      speakerIds: speakerIds ?? this.speakerIds,
      isPrivate: isPrivate,
    );
  }

  factory LiveSession.fromJson(Map<String, dynamic> json) {
    
    List<SessionUser> participants = [];
    if (json['participants'] != null) {
      participants = (json['participants'] as List).map((p) {
        return SessionUser.fromJson(Map<String, dynamic>.from(p));
      }).toList();
    }

    
    SessionStatus status = SessionStatus.live;
    if (json['status'] != null) {
      status = SessionStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => SessionStatus.live,
      );
    }

    return LiveSession(
      id: json['id']?.toString() ?? '',
      host: MangoUser.fromJson(Map<String, dynamic>.from(json['host'])),
      title: json['title'] ?? 'Untitled Session',
      status: status,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      startedAt: json['startedAt'] != null 
          ? DateTime.parse(json['startedAt'].toString())
          : null,
      endedAt: json['endedAt'] != null 
          ? DateTime.parse(json['endedAt'].toString())
          : null,
      participants: participants,
      speakerIds: List<String>.from(json['speakerIds'] ?? json['speakers'] ?? []),
      isPrivate: json['isPrivate'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'host': host.toJson(),
      'title': title,
      'status': status.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'participants': participants.map((p) => p.toJson()).toList(),
      'speakerIds': speakerIds,
      'isPrivate': isPrivate,
    };
  }
}