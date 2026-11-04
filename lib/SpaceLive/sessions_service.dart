import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mango/Models/customModel/user.dart';
import 'package:mango/SpaceLive/space_live_sessions_model.dart';
import 'package:mango/SpaceLive/web_rtc_controller.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SessionService with ChangeNotifier {
  static const String _serverUrl = 'http://localhost:3000';
  
  LiveSession? _currentSession;
  MangoUser? _currentUser;
  IO.Socket? _socket;
  final WebRTCService _webRTCService = WebRTCService(_serverUrl);
  
  List<LiveSession> _publicSessions = [];

  LiveSession? get currentSession => _currentSession;
  MangoUser? get currentUser => _currentUser;
  List<LiveSession> get publicSessions => _publicSessions;
  WebRTCService get webRTCService => _webRTCService; 

  SessionService() {
    _initializeSocket();
    _loadPublicSessions();
  }

  void _initializeSocket() {
    _socket = IO.io(_serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    _socket!.on('connect', (_) {
      print('Connected to session server');
      if (_currentUser != null) {
        _socket!.emit('register_user', _currentUser!.toJson());
      }
    });

    _socket!.on('session_created', _handleSessionCreated);
    _socket!.on('session_joined', _handleSessionJoined);
    _socket!.on('user_joined', _handleUserJoined);
    _socket!.on('user_left', _handleUserLeft);
    _socket!.on('speaker_requested', _handleSpeakerRequested);
    _socket!.on('speaker_approved', _handleSpeakerApproved);
    _socket!.on('user_muted', _handleUserMuted);
    _socket!.on('speaker_removed', _handleSpeakerRemoved);
    _socket!.on('session_ended', _handleSessionEnded);
    _socket!.on('sessions_list', _handleSessionsList);
  }

  Future<void> _loadPublicSessions() async {
    try {
      final response = await http.get(Uri.parse('$_serverUrl/sessions'));
      if (response.statusCode == 200) {
        final List<dynamic> sessionsJson = json.decode(response.body);
        _publicSessions = sessionsJson.map((json) => LiveSession.fromJson(json)).toList();
        notifyListeners();
      }
    } catch (e) {
      print('Error loading public sessions: $e');
    }
  }

  Future<void> createSession({required String title, bool isPrivate = false}) async {
    if (_currentUser == null) throw Exception('MangoUser not set');

    await _webRTCService.initialize();

    _socket!.emit('create_session', {
      'host': _currentUser!.toJson(),
      'title': title,
      'isPrivate': isPrivate,
    });
  }

  Future<void> joinSession(String sessionId, {UserRole role = UserRole.listener}) async {
    if (_currentUser == null) throw Exception('MangoUser not set');

    await _webRTCService.initialize();

    _socket!.emit('join_session', {
      'sessionId': sessionId,
      'user': _currentUser!.toJson(),
      'role': role.toString().split('.').last,
    });
  }

  Future<void> leaveSession() async {
    if (_currentSession != null && _currentUser != null) {
      _socket!.emit('leave_session', {
        'sessionId': _currentSession!.id,
        'userId': _currentUser!.id,
      });
      
      await _webRTCService.disconnect();
      _currentSession = null;
      notifyListeners();
    }
  }

  void requestToSpeak() {
    if (_currentSession != null && _currentUser != null) {
      _socket!.emit('request_to_speak', {
        'sessionId': _currentSession!.id,
        'userId': _currentUser!.id,
      });
    }
  }

  void approveSpeaker(String userId) {
    if (_currentSession != null) {
      _socket!.emit('approve_speaker', {
        'sessionId': _currentSession!.id,
        'userId': userId,
      });
    }
  }

  void toggleMute(String userId, bool muted) {
    if (_currentSession != null) {
      _socket!.emit('toggle_mute', {
        'sessionId': _currentSession!.id,
        'userId': userId,
        'muted': muted,
      });
    }
  }

  void removeSpeaker(String userId) {
    if (_currentSession != null) {
      _socket!.emit('remove_speaker', {
        'sessionId': _currentSession!.id,
        'userId': userId,
      });
    }
  }

  void endSession() {
    if (_currentSession != null) {
      _socket!.emit('end_session', {
        'sessionId': _currentSession!.id,
      });
      _currentSession = null;
      notifyListeners();
    }
  }

  void refreshSessions() {
    _socket!.emit('get_sessions');
  }

  
  void _handleSessionCreated(dynamic data) {
    try {
      final session = LiveSession.fromJson(Map<String, dynamic>.from(data));
      _currentSession = session;
      notifyListeners();
    } catch (e) {
      print('Error handling session created: $e');
    }
  }

  void _handleSessionJoined(dynamic data) {
    try {
      final session = LiveSession.fromJson(Map<String, dynamic>.from(data));
      _currentSession = session;
      notifyListeners();
    } catch (e) {
      print('Error handling session joined: $e');
    }
  }

  void _handleUserJoined(dynamic data) {
    if (_currentSession != null) {
      
      notifyListeners();
    }
  }

  void _handleUserLeft(dynamic data) {
    if (_currentSession != null) {
      
      notifyListeners();
    }
  }

  void _handleSpeakerRequested(dynamic data) {
    
    notifyListeners();
  }

  void _handleSpeakerApproved(dynamic data) {
    if (_currentSession != null) {
      final speakerIds = List<String>.from(data['speakers']);
      _currentSession = _currentSession!.copyWith(speakerIds: speakerIds);
      
      
      if (speakerIds.contains(_currentUser!.id)) {
        _initializeAsSpeaker();
      }
      
      notifyListeners();
    }
  }

  void _handleUserMuted(dynamic data) {
    if (_currentSession != null) {
      
      notifyListeners();
    }
  }

  void _handleSpeakerRemoved(dynamic data) {
    if (_currentSession != null) {
      final speakerIds = List<String>.from(data['speakers']);
      _currentSession = _currentSession!.copyWith(speakerIds: speakerIds);
      notifyListeners();
    }
  }

  void _handleSessionEnded(dynamic data) {
    _currentSession = null;
    notifyListeners();
  }

  void _handleSessionsList(dynamic data) {
    final sessionsJson = List<Map<String, dynamic>>.from(data);
    _publicSessions = sessionsJson.map((json) => LiveSession.fromJson(json)).toList();
    notifyListeners();
  }

  void _initializeAsSpeaker() {
    
    
  }

  void setCurrentUser(MangoUser user) {
    _currentUser = user;
    if (_socket != null && _socket!.connected) {
      _socket!.emit('register_user', user.toJson());
    }
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _webRTCService.disconnect();
    super.dispose();
  }
}