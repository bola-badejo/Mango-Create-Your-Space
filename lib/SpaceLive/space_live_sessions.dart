import 'package:flutter/material.dart';
import 'package:mango/SpaceLive/sessions_service.dart';
import 'package:mango/SpaceLive/space_live_sessions_model.dart';
import 'package:provider/provider.dart';
import 'package:mango/Utils/optimized_lists.dart';

class LiveSessionScreen extends StatefulWidget {
  final String sessionId;
  final Map<String, dynamic> sessionData;
  final String spaceId;

  const LiveSessionScreen({
    Key? key,
    required this.sessionId,
    required this.sessionData,
    required this.spaceId,
  }) : super(key: key);

  @override
  _LiveSessionScreenState createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends State<LiveSessionScreen> {
  late SessionService _sessionService;
  bool _isMuted = false;
  bool _isHost = false;

  @override
  void initState() {
    super.initState();
    _sessionService = Provider.of<SessionService>(context, listen: false);
    _initializeSession();
  }

  Future<void> _initializeSession() async {
    try {
      
      _sessionService.webRTCService.onAddRemoteStream = (stream) {
        
        print('Remote stream added');
      };
      
      _sessionService.webRTCService.onDataChannelMessage = (socketId, message) {
        
        print('Message from $socketId: $message');
      };

      
      final currentUser = _sessionService.currentUser;
      final sessionData = widget.sessionData;
      
      if (currentUser != null && sessionData['host'] != null) {
        final hostData = Map<String, dynamic>.from(sessionData['host']);
        _isHost = currentUser.id == hostData['id'];
      }

      
      await _sessionService.joinSession(
        widget.sessionId,
        role: _isHost ? UserRole.host : UserRole.listener,
      );
    } catch (e) {
      print('Error initializing session: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to join session: $e')),
      );
    }
  }

  void _removeParticipant(String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Participant'),
        content: const Text('Are you sure you want to remove this participant?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _sessionService.removeSpeaker(userId);
              Navigator.pop(context);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _toggleMuteParticipant(String userId, bool currentlyMuted) {
    _sessionService.toggleMute(userId, !currentlyMuted);
  }

  void _makeSpeaker(String userId) {
    _sessionService.approveSpeaker(userId);
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _sessionService.webRTCService.toggleMute(_isMuted);
  }

  void _leaveSession() async {
    await _sessionService.leaveSession();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionService>(
      builder: (context, sessionService, child) {
        final currentSession = sessionService.currentSession;
        
        if (currentSession == null) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 20),
                  Text(
                    'Joining session...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          );
        }

        final speakers = currentSession.speakers;
        final listeners = currentSession.listeners;

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: _leaveSession,
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentSession.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${speakers.length} speakers • ${listeners.length} listeners',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            actions: [
              if (_isHost) _buildHostControls(),
            ],
          ),
          body: Column(
            children: [
              
              Expanded(
                flex: 2,
                child: _buildSpeakersSection(speakers),
              ),
              
              Expanded(
                flex: 1,
                child: _buildListenersSection(listeners),
              ),
              
              _buildControlPanel(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHostControls() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      onSelected: (value) {
        switch (value) {
          case 'mute_all':
            _muteAllSpeakers();
            break;
          case 'end_session':
            _endSession();
            break;
          case 'settings':
            _showSessionSettings();
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'mute_all', child: Text('Mute All')),
        const PopupMenuItem(value: 'settings', child: Text('Settings')),
        const PopupMenuItem(
          value: 'end_session',
          child: Text('End Session', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  Widget _buildSpeakersSection(List<SessionUser> speakers) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Speakers',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: OptimizedGridView(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              itemCount: speakers.length,
              itemBuilder: (context, index) {
                final speaker = speakers[index];
                return _buildSpeakerTile(speaker);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeakerTile(SessionUser speaker) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: speaker.user.profileImage.isNotEmpty
                    ? NetworkImage(speaker.user.profileImage)
                    : null,
                child: speaker.user.profileImage.isEmpty
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              if (speaker.isMuted)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic_off, size: 12, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            speaker.user.displayName.isNotEmpty 
                ? speaker.user.displayName 
                : speaker.user.username,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '@${speaker.user.username}',
            style: const TextStyle(color: Colors.grey, fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (_isHost) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    speaker.isMuted ? Icons.mic_off : Icons.mic,
                    size: 16,
                    color: Colors.white,
                  ),
                  onPressed: () => _toggleMuteParticipant(speaker.user.id, speaker.isMuted),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle, size: 16, color: Colors.red),
                  onPressed: () => _removeParticipant(speaker.user.id),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildListenersSection(List<SessionUser> listeners) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Listeners',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${listeners.length}',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: OptimizedListView(
              scrollDirection: Axis.horizontal,
              itemCount: listeners.length,
              itemBuilder: (context, index) {
                final listener = listeners[index];
                return _buildListenerTile(listener);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListenerTile(SessionUser listener) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundImage: listener.user.profileImage.isNotEmpty
                    ? NetworkImage(listener.user.profileImage)
                    : null,
                child: listener.user.profileImage.isEmpty
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              if (listener.hasRequestedToSpeak)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.waving_hand, size: 12, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            listener.user.displayName.isNotEmpty 
                ? listener.user.displayName.split(' ').first 
                : listener.user.username,
            style: const TextStyle(color: Colors.white, fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (_isHost && listener.hasRequestedToSpeak) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => _makeSpeaker(listener.user.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Approve',
                  style: TextStyle(color: Colors.white, fontSize: 8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          
          IconButton(
            icon: Icon(
              _isMuted ? Icons.mic_off : Icons.mic,
              color: _isMuted ? Colors.red : Colors.white,
              size: 30,
            ),
            onPressed: _toggleMute,
          ),
          
          IconButton(
            icon: const Icon(Icons.call_end, color: Colors.red, size: 30),
            onPressed: _leaveSession,
          ),
          
          if (!_isHost)
            IconButton(
              icon: const Icon(Icons.waving_hand, color: Colors.white, size: 30),
              onPressed: _requestToSpeak,
            ),
          
          IconButton(
            icon: const Icon(Icons.chat, color: Colors.white, size: 30),
            onPressed: _openChat,
          ),
        ],
      ),
    );
  }

  void _muteAllSpeakers() {
    final currentSession = _sessionService.currentSession;
    if (currentSession != null) {
      for (final speaker in currentSession.speakers) {
        if (speaker.role != UserRole.host) { 
          _sessionService.toggleMute(speaker.user.id, true);
        }
      }
    }
  }

  void _requestToSpeak() {
    _sessionService.requestToSpeak();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Requested to speak')),
    );
  }

  void _openChat() {
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chat feature coming soon')),
    );
  }

  void _endSession() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Session'),
        content: const Text('Are you sure you want to end this live session for everyone?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _sessionService.endSession();
              _leaveSession();
            },
            child: const Text('End Session', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showSessionSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Session Settings', style: TextStyle(color: Colors.white)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mute all participants on entry', style: TextStyle(color: Colors.white)),
            Text('Allow participants to unmute themselves', style: TextStyle(color: Colors.white)),
            Text('Enable waiting room', style: TextStyle(color: Colors.white)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}