import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class WebRTCService {
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, MediaStream> _remoteStreams = {};
  final Map<String, RTCDataChannel> _dataChannels = {};
  final Map<String, RTCSessionDescription?> _remoteDescriptions = {};

  Function(String socketId, String status)? onDataChannelStatusChanged;
  Function(String socketId, bool isConnected)? onDataChannelConnected;
  
  MediaStream? _localStream;
  IO.Socket? _socket; 
  final String _serverUrl;
  final List<Map<String, dynamic>> _iceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
  ];

  WebRTCService(this._serverUrl);

  
  Function(MediaStream)? onAddRemoteStream;
  Function(String)? onRemoveRemoteStream;
  Function(String, dynamic)? onDataChannelMessage;

  Future<void> initialize() async {
    await _initializeLocalMedia();
    _setupSocketConnection();
  }

  Future<void> _initializeLocalMedia() async {
    final mediaConstraints = <String, dynamic>{
      'audio': true,
      'video': false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
  }

  void _setupSocketConnection() {
    _socket = IO.io(_serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    _socket!.on('connect', (_) {
      print('Connected to signaling server');
    });

    _socket!.on('webrtc_offer', _handleOffer);
    _socket!.on('webrtc_answer', _handleAnswer);
    _socket!.on('webrtc_ice_candidate', _handleIceCandidate);
    
    
    _socket!.on('error', (error) {
      print('Socket error: $error');
    });
    
    _socket!.on('disconnect', (_) {
      print('Disconnected from signaling server');
    });
  }

  Future<void> createOffer(String targetSocketId) async {
    try {
      final peerConnection = await _createPeerConnection(targetSocketId);
      _peerConnections[targetSocketId] = peerConnection;

      
      final dataChannel = await peerConnection.createDataChannel('chat', RTCDataChannelInit());
      _setupDataChannel(dataChannel, targetSocketId);

      
      final offer = await peerConnection.createOffer();
      await peerConnection.setLocalDescription(offer);

      
      _socket!.emit('webrtc_offer', {
        'target': targetSocketId,
        'offer': offer.toMap(),
      });
    } catch (e) {
      print('Error creating offer: $e');
    }
  }

  Future<void> _handleOffer(dynamic data) async {
    try {
      final offer = data['offer'];
      final sender = data['sender'];

      final peerConnection = await _createPeerConnection(sender);
      _peerConnections[sender] = peerConnection;

      _setupDataChannelHandlers(peerConnection, sender);

      
      final remoteDescription = RTCSessionDescription(offer['sdp'], offer['type']);
      await peerConnection.setRemoteDescription(remoteDescription);
      _remoteDescriptions[sender] = remoteDescription;

      
      final answer = await peerConnection.createAnswer();
      await peerConnection.setLocalDescription(answer);

      
      _socket!.emit('webrtc_answer', {
        'target': sender,
        'answer': answer.toMap(),
      });
    } catch (e) {
      print('Error handling offer: $e');
    }
  }

  Future<void> _handleAnswer(dynamic data) async {
    try {
      final answer = data['answer'];
      final sender = data['sender'];

      final peerConnection = _peerConnections[sender];
      if (peerConnection != null) {
        final remoteDescription = RTCSessionDescription(answer['sdp'], answer['type']);
        await peerConnection.setRemoteDescription(remoteDescription);
        _remoteDescriptions[sender] = remoteDescription;
      }
    } catch (e) {
      print('Error handling answer: $e');
    }
  }

  Future<void> _handleIceCandidate(dynamic data) async {
    try {
      final candidate = data['candidate'];
      final sender = data['sender'];

      final peerConnection = _peerConnections[sender];
      if (peerConnection != null) {
        await peerConnection.addCandidate(RTCIceCandidate(
          candidate['candidate'],
          candidate['sdpMid'],
          candidate['sdpMLineIndex'],
        ));
      }
    } catch (e) {
      print('Error handling ICE candidate: $e');
    }
  }

  Future<RTCPeerConnection> _createPeerConnection(String socketId) async {
    final configuration = <String, dynamic>{
      'iceServers': _iceServers,
    };

    final peerConnection = await createPeerConnection(configuration);

    
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await peerConnection.addTrack(track, _localStream!);
      }
    }

    
    peerConnection.onIceCandidate = (candidate) {
      if (_socket != null && _socket!.connected) {
        _socket!.emit('webrtc_ice_candidate', {
          'target': socketId,
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        });
      }
    };

    
    peerConnection.onTrack = (event) {
      if (event.track.kind == 'audio' && event.streams.isNotEmpty) {
        final stream = event.streams[0];
        _remoteStreams[socketId] = stream;
        onAddRemoteStream?.call(stream);
      }
    };

    
    peerConnection.onIceConnectionState = (state) {
      print('ICE connection state for $socketId: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
          state == RTCIceConnectionState.RTCIceConnectionStateClosed) {
        _cleanupPeerConnection(socketId);
      }
    };

    
    peerConnection.onDataChannel = (channel) {
      _setupDataChannel(channel, socketId);
    };

    
    peerConnection.onConnectionState = (state) {
      print('Peer connection state for $socketId: $state');
    };

    return peerConnection;
  }

  void _setupDataChannel(RTCDataChannel channel, String socketId) {
    _dataChannels[socketId] = channel;

    
    channel.messageStream.listen((message) {
      if (message.isBinary) {
        onDataChannelMessage?.call(socketId, message.binary);
      } else {
        onDataChannelMessage?.call(socketId, message.text);
      }
    });

    
    channel.stateChangeStream.listen((state) {
      print('Data channel state for $socketId: $state');
      
      final status = getDataChannelStatus(socketId);
      onDataChannelStatusChanged?.call(socketId, status);
      
      switch (state) {
        case RTCDataChannelState.RTCDataChannelConnecting:
          
          break;
          
        case RTCDataChannelState.RTCDataChannelOpen:
          print('Data channel with $socketId is now open!');
          onDataChannelConnected?.call(socketId, true);
          break;
          
        case RTCDataChannelState.RTCDataChannelClosing:
          
          break;
          
        case RTCDataChannelState.RTCDataChannelClosed:
          print('Data channel with $socketId has closed');
          onDataChannelConnected?.call(socketId, false);
          _cleanupDataChannel(socketId);
          break;
      }
    });
  }


void _cleanupDataChannel(String socketId) {
  final channel = _dataChannels[socketId];
  if (channel != null) {
    
    _dataChannels.remove(socketId);
    print('Cleaned up data channel for $socketId');
  }
}


void sendMessage(String targetSocketId, dynamic message) {
  final channel = _dataChannels[targetSocketId];
  if (channel != null && channel.state == RTCDataChannelState.RTCDataChannelOpen) {
    if (message is String) {
      channel.send(RTCDataChannelMessage(message));
      print('Message sent to $targetSocketId: $message');
    } else {
      channel.send(RTCDataChannelMessage.fromBinary(message));
      print('Binary message sent to $targetSocketId');
    }
  } else {
    print('Cannot send message - data channel not open for $targetSocketId');
    
  }
}


void closeDataChannel(String socketId) {
  final channel = _dataChannels[socketId];
  if (channel != null) {
    channel.close();
    _cleanupDataChannel(socketId);
  }
}


bool isDataChannelReady(String socketId) {
  final channel = _dataChannels[socketId];
  return channel != null && channel.state == RTCDataChannelState.RTCDataChannelOpen;
}


String getDataChannelStatus(String socketId) {
  final channel = _dataChannels[socketId];
  if (channel == null) return 'Not Created';
  
  switch (channel.state) {
    case RTCDataChannelState.RTCDataChannelConnecting:
      return 'Connecting...';
    case RTCDataChannelState.RTCDataChannelOpen:
      return 'Connected';
    case RTCDataChannelState.RTCDataChannelClosing:
      return 'Closing...';
    case RTCDataChannelState.RTCDataChannelClosed:
      return 'Disconnected';
    default:
      return 'Unknown';
  }
}

  void _setupDataChannelHandlers(RTCPeerConnection peerConnection, String socketId) {
    peerConnection.onDataChannel = (channel) {
      _setupDataChannel(channel, socketId);
    };
  }

  String? _getSocketIdForPeerConnection(RTCPeerConnection pc) {
    try {
      return _peerConnections.entries
          .firstWhere((entry) => entry.value == pc)
          .key;
    } catch (e) {
      return null;
    }
  }

  Future<void> toggleMute(bool mute) async {
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        for (final track in audioTracks) {
          track.enabled = !mute;
        }
      }
    }
  }

  void _cleanupPeerConnection(String socketId) {
    final peerConnection = _peerConnections[socketId];
    if (peerConnection != null) {
      peerConnection.close();
      _peerConnections.remove(socketId);
    }
    
    final dataChannel = _dataChannels[socketId];
    if (dataChannel != null) {
      dataChannel.close();
      _dataChannels.remove(socketId);
    }
    
    _remoteDescriptions.remove(socketId);
    
    final remoteStream = _remoteStreams[socketId];
    if (remoteStream != null) {
      onRemoveRemoteStream?.call(socketId);
      _remoteStreams.remove(socketId);
    }
  }

  Future<void> disconnect() async {
    
    final List<Future> closeFutures = [];
    for (final entry in _peerConnections.entries) {
      closeFutures.add(entry.value.close());
    }
    await Future.wait(closeFutures);
    _peerConnections.clear();
    
    
    for (final channel in _dataChannels.values) {
      channel.close();
    }
    _dataChannels.clear();
    
    
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        track.stop();
      }
      _localStream!.dispose();
      _localStream = null;
    }
    
    
    _remoteStreams.clear();
    _remoteDescriptions.clear();
    
    
    _socket?.disconnect();
    _socket = null;
  }

  
  MediaStream? getRemoteStream(String socketId) {
    return _remoteStreams[socketId];
  }

  
  bool hasConnection(String socketId) {
    return _peerConnections.containsKey(socketId);
  }

  
  List<String> getConnectedSockets() {
    return _peerConnections.keys.toList();
  }

  
  bool get isSocketConnected => _socket?.connected == true;

  
  MediaStream? get localStream => _localStream;
}