
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mango/Utils/optimized_lists.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mango/Conversations/controllers/conversation_controller.dart';
import 'package:mango/Conversations/utils/audio_visualizer.dart';
import 'package:mango/Conversations/utils/media_viewing_dialog.dart';
import 'package:mango/Conversations/utils/voice_note_player_widget.dart';
import 'package:mango/Conversations/utils/voice_recorder_service.dart';
import 'package:mango/Models/customModel/chat.dart';
import 'package:mango/SpaceConversations/upload_progress_dialog.dart';
import 'package:mango/Models/customModel/user.dart';
import 'package:mango/SpaceConversations/space_conversations_controller.dart';
import 'package:mango/SpaceConversations/space_conversations_model.dart';
import 'package:mango/constants.dart';
import 'package:path/path.dart' as path;
import 'package:mango/Core/theme/mango_palette.dart';
import 'package:mango/Core/design_system/mango_ui.dart';

class SpaceConversationChatPage extends StatefulWidget {
  final String spaceId;
  final SpaceConversation conversation;

  const SpaceConversationChatPage({
    Key? key,
    required this.spaceId,
    required this.conversation,
  }) : super(key: key);

  @override
  _SpaceConversationChatPageState createState() =>
      _SpaceConversationChatPageState();
}

class _SpaceConversationChatPageState extends State<SpaceConversationChatPage> {
  final ConversationController _conversationController =
      Get.find<ConversationController>();
  final SpaceConversationController _spaceConvController =
      Get.find<SpaceConversationController>();
  final TextEditingController _messageController = TextEditingController();
  final VoiceRecorderService _voiceRecorder = VoiceRecorderService();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  
  bool _isRecording = false;
  int _recordingDuration = 0;
  Timer? _recordingTimer;
  double _currentAmplitude = 0.0;
  bool _useCircleVisualizer = true;

  @override
  void initState() {
    super.initState();
    _voiceRecorder.amplitudeStream.listen((amplitude) {
      if (mounted) {
        setState(() {
          _currentAmplitude = amplitude;
        });
      }
    });
  }

  @override
  void dispose() {
    _voiceRecorder.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MangoPalette.grey50,
      body: Column(
        children: [
          _buildConversationHeader(),
          Expanded(child: _buildMessagesList()),
          _buildMessageInput(),
        ],
      ),
    );
  }

  
  Future<void> _startRecording() async {
    final path = await _voiceRecorder.startRecording();
    if (path != null) {
      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
        _currentAmplitude = 0.0;
      });

      _recordingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          _recordingDuration++;
        });
      });
    }
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    final path = await _voiceRecorder.stopRecording();

    if (path != null && mounted) {
      _showCaptionDialog(
        filePath: path,
        fileType: 'audio',
        onSend: (caption) {
          _sendVoiceNote(path, caption);
        },
      );
    }

    setState(() {
      _isRecording = false;
      _recordingDuration = 0;
      _currentAmplitude = 0.0;
    });
  }

  void _cancelRecording() {
    _recordingTimer?.cancel();
    _voiceRecorder.cancelRecording();
    setState(() {
      _isRecording = false;
      _recordingDuration = 0;
      _currentAmplitude = 0.0;
    });
  }

  
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      _showCaptionDialog(
        filePath: image.path,
        fileType: 'image',
        onSend: (caption) {
          _sendMediaMessage(image.path, 'image', caption);
        },
      );
    }
  }

  Future<void> _pickVideo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

    if (video != null) {
      _showCaptionDialog(
        filePath: video.path,
        fileType: 'video',
        onSend: (caption) {
          _sendMediaMessage(video.path, 'video', caption);
        },
      );
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null && result.files.single.path != null) {
      _sendMediaMessage(result.files.single.path!, 'file', '');
    }
  }

  
  Future<void> _sendVoiceNote(String filePath, String? caption) async {
    try {
      
      final file = File(filePath);
      final stat = await file.stat();
      if (stat.size > 10 * 1024 * 1024) {
        throw Exception('Voice note too large. Maximum size is 10MB.');
      }

      final audioUrl = await _uploadFile(filePath, 'audio');
      final duration = _recordingDuration.toDouble();

      
      await _spaceConvController.sendSpaceConversationMessage(
        spaceId: widget.spaceId,
        conversationId: widget.conversation.id,
        text: caption ?? '',
        senderId: _conversationController.authentication.currentUser!.uid,
        audioUrl: audioUrl, 
        audioDuration: duration, 
        messageType: MessageType.audio, 
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Voice note sent!'),
          backgroundColor: MangoPalette.green500,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send voice note: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendMediaMessage(
    String filePath,
    String type,
    String? caption,
  ) async {
    try {
      
      final file = File(filePath);
      final stat = await file.stat();
      final maxSize = type == 'image'
          ? 20 * 1024 * 1024
          : type == 'video'
          ? 100 * 1024 * 1024
          : 50 * 1024 * 1024;

      if (stat.size > maxSize) {
        throw Exception(
          'File too large. Maximum size is ${maxSize ~/ (1024 * 1024)}MB.',
        );
      }

      final fileUrl = await _uploadFile(filePath, type);

      await _spaceConvController.sendSpaceConversationMessage(
        spaceId: widget.spaceId,
        conversationId: widget.conversation.id,
        text: caption ?? '',
        senderId: _conversationController.authentication.currentUser!.uid,
        imageUrl: type == 'image' ? fileUrl : null,
        videoUrl: type == 'video' ? fileUrl : null,
        messageType: type == 'image'
            ? MessageType.image
            : type == 'video'
            ? MessageType.video
            : MessageType.file,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_capitalizeFirst(type)} sent!'),
          backgroundColor: MangoPalette.green500,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send ${type}: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  
  Future<String> _uploadFile(String filePath, String type) async {
    final file = File(filePath);
    final userId = _conversationController.authentication.currentUser!.uid;

    
    final downloadUrl = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => UploadProgressDialog(
        fileType: type,
        fileName: file.path.split('/').last,
        uploadFunction: (onProgress) async {
          
          return await _performUpload(
            file: file,
            userId: userId,
            type: type,
            onProgress: onProgress,
          );
        },
      ),
    );

    if (downloadUrl != null) {
      return downloadUrl;
    } else {
      throw Exception('Upload cancelled or failed');
    }
  }

  
  Future<String> _performUpload({
    required File file,
    required String userId,
    required String type,
    required Function(double) onProgress,
  }) async {
    try {
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(file.path);
      final fileName = '${type}_$timestamp$extension';

      
      final Reference storageRef = _storage
          .ref()
          .child('spaces')
          .child(widget.spaceId)
          .child('conversations')
          .child(widget.conversation.id)
          .child(type)
          .child(fileName);

      
      final SettableMetadata metadata = SettableMetadata(
        contentType: _getContentType(type, extension),
        customMetadata: {
          'uploadedBy': userId,
          'uploadedAt': timestamp.toString(),
          'originalName': path.basename(file.path),
        },
      );

      
      final UploadTask uploadTask = storageRef.putFile(file, metadata);

      
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress(progress);
      });

      
      final TaskSnapshot snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      throw Exception('Upload failed: $e');
    }
  }

  String _getContentType(String fileType, String extension) {
    switch (fileType) {
      case 'audio':
        return 'audio/m4a';
      case 'image':
        return 'image/jpeg';
      case 'video':
        return 'video/mp4';
      default:
        return 'application/octet-stream';
    }
  }

  
  void _showCaptionDialog({
    required String filePath,
    required String fileType,
    required Function(String?) onSend,
  }) {
    TextEditingController captionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Caption (Optional)'),
        content: TextField(
          controller: captionController,
          decoration: InputDecoration(
            hintText: 'Add a caption...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onSend(captionController.text.trim());
            },
            child: Text('Send'),
          ),
        ],
      ),
    );
  }

  
  void _viewMedia(String url, String type, String? caption) {
    showDialog(
      context: context,
      builder: (context) =>
          MediaViewerDialog(url: url, type: type, caption: caption),
    );
  }

  
  Widget _buildMessageBubble(Message message) {
    final isSender =
        message.sender ==
        _conversationController.authentication.currentUser!.uid;

    return StreamBuilder<MangoUser?>(
      stream:
          _conversationController.getUserInfo(message.sender)
              as Stream<MangoUser?>,
      builder: (context, userSnapshot) {
        final user = userSnapshot.data;

        return Container(
          margin: EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isSender && user != null)
                CircleAvatar(
                  backgroundImage: NetworkImage(user.profileImage),
                  radius: 16,
                ),
              if (!isSender && user == null)
                CircleAvatar(radius: 16, backgroundColor: MangoPalette.grey500),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: isSender
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (!isSender && user != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          user.displayName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: MangoPalette.grey700,
                          ),
                        ),
                      ),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSender ? MangoPalette.grey300 : MangoPalette.green300,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                          bottomLeft: isSender
                              ? Radius.circular(16)
                              : Radius.circular(4),
                          bottomRight: isSender
                              ? Radius.circular(4)
                              : Radius.circular(16),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          
                          if (message.audio != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                VoiceNotePlayer(
                                  audioUrl: message.audio!,
                                  duration: message.audioDuration ?? 0,
                                ),
                                SizedBox(height: 8),
                              ],
                            ),

                          
                          if (message.image != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MangoPressable(
                                  onTap: () => _viewMedia(
                                    message.image!,
                                    'image',
                                    message.caption,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(MangoRadius.sm),
                                    child: Image.network(
                                      message.image!,
                                      width: 200,
                                      height: 150,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null)
                                          return child;
                                        return Container(
                                          width: 200,
                                          height: 150,
                                          color: MangoPalette.grey300,
                                          child: Center(
                                            child: CircularProgressIndicator(semanticsLabel: 'Loading', 
                                              value:
                                                  loadingProgress
                                                          .expectedTotalBytes !=
                                                      null
                                                  ? loadingProgress
                                                            .cumulativeBytesLoaded /
                                                        loadingProgress
                                                            .expectedTotalBytes!
                                                  : null,
                                            ),
                                          ),
                                        );
                                      },
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Container(
                                              width: 200,
                                              height: 150,
                                              color: MangoPalette.grey300,
                                              child: Icon(
                                                Icons.error,
                                                color: Colors.red,
                                              ),
                                            );
                                          },
                                    ),
                                  ),
                                ),
                                SizedBox(height: 8),
                              ],
                            ),

                          
                          if (message.video != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MangoPressable(
                                  onTap: () => _viewMedia(
                                    message.video!,
                                    'video',
                                    message.caption,
                                  ),
                                  child: Container(
                                    width: 200,
                                    height: 150,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(MangoRadius.sm),
                                      color: Colors.black12,
                                    ),
                                    child: Stack(
                                      children: [
                                        
                                        Center(
                                          child: Icon(
                                            Icons.play_circle_filled,
                                            size: 50,
                                            color: Colors.white,
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 8,
                                          right: 8,
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius:
                                                  BorderRadius.circular(MangoRadius.xs),
                                            ),
                                            child: Text(
                                              'VIDEO',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: 8),
                              ],
                            ),

                          
                          if (message.text.isNotEmpty &&
                              message.audio == null &&
                              message.image == null &&
                              message.video == null)
                            Text(
                              message.text,
                              style: TextStyle(
                                color: isSender ? MangoPalette.black : Colors.black87,
                              ),
                            ),

                          
                          if (message.caption != null &&
                              message.caption!.isNotEmpty &&
                              (message.image != null ||
                                  message.video != null ||
                                  message.audio != null))
                            Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                message.caption!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color:MangoPalette.black,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),

                          
                          SizedBox(height: 4),
                          Text(
                            '${message.timeStamp.toDate().hour}:${message.timeStamp.toDate().minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 12,
                              color:MangoPalette.grey800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageInput() {
    if (_isRecording) {
      return _buildRecordingUI();
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(MangoRadius.sm), color: Colors.transparent,),
      child: Row(
        children: [
          
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: MangoPalette.grey100,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  IconButton(
        tooltip: 'Emoji',
                    icon: Icon(Icons.emoji_emotions_outlined),
                    onPressed: () {},
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                        suffix: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PopupMenuButton<String>(
                              icon: Icon(Icons.attach_file_outlined, color: priMangoOrange),
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'image',
                                  child: Row(
                                    children: [
                                      Icon(Icons.image),
                                      SizedBox(width: 8),
                                      Text('Image'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'video',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.videocam,
                                      ),
                                      SizedBox(width: 8),
                                      Text('Video'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'file',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.attach_file,
                                        color: Colors.blueGrey,
                                      ),
                                      SizedBox(width: 8),
                                      Text('File'),
                                    ],
                                  ),
                                ),
                              ],
                              onSelected: (value) {
                                if (value == 'image') _pickImage();
                                if (value == 'video') _pickVideo();
                                if (value == 'file') _pickFile();
                              },
                            ),

                            
                            IconButton(
                              icon: Icon(Icons.mic, color: MangoPalette.green500),
                              onPressed: _startRecording,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          
          SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: _messageController.text.trim().isEmpty
                ? MangoPalette.grey500
                : Colors.blue[600],
            child: IconButton(
        tooltip: 'Send',
              icon: Icon(Icons.send, color: Colors.white),
              onPressed: _messageController.text.trim().isEmpty
                  ? null
                  : () {
                      _spaceConvController.sendSpaceConversationMessage(
                        spaceId: widget.spaceId,
                        conversationId: widget.conversation.id,
                        text: _messageController.text.trim(),
                        senderId: _conversationController
                            .authentication
                            .currentUser!
                            .uid,
                      );
                      _messageController.clear();
                    },
            ),
          ),
        ],
      ),
    );
  }

  
  Widget _buildRecordingUI() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.red.shade50, Colors.red.shade100],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: MangoPalette.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(MangoRadius.lg),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'RECORDING',
                  style: TextStyle(
                    color: Colors.red.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Visualizer: ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade800,
                ),
              ),
              Switch(
                value: _useCircleVisualizer,
                onChanged: (value) {
                  setState(() {
                    _useCircleVisualizer = value;
                  });
                },
                activeColor: Colors.red,
              ),
              Text(
                _useCircleVisualizer ? 'Circle' : 'Bars',
                style: TextStyle(color: Colors.red.shade800),
              ),
            ],
          ),

          const SizedBox(height: 20),

          
          _useCircleVisualizer
              ? CircleAudioVisualizer(
                  isRecording: _isRecording,
                  amplitude: _currentAmplitude,
                )
              : AudioVisualizer(
                  isRecording: _isRecording,
                  amplitude: _currentAmplitude,
                ),

          const SizedBox(height: 20),

          
          Column(
            children: [
              Text(
                'Recording Voice Note',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_recordingDuration ~/ 60}:${(_recordingDuration % 60).toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade600,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Amplitude: ${(_currentAmplitude * 100).toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 12, color: Colors.red.shade700),
              ),
            ],
          ),

          const SizedBox(height: 30),

          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.cancel, size: 20),
                  label: const Text('Cancel'),
                  onPressed: _cancelRecording,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Colors.red.shade400),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MangoRadius.md),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 16),

              
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.send, size: 20),
                  label: const Text('Send'),
                  onPressed: _stopRecording,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MangoRadius.md),
                    ),
                    elevation: 4,
                    shadowColor: Colors.red.withOpacity(0.3),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          
          Text(
            'Recording will automatically stop after 5 minutes',
            style: TextStyle(
              fontSize: 12,
              color: Colors.red.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
        tooltip: 'Back',
                    icon: Icon(Icons.arrow_back),
                    onPressed: () => Get.back(),
                  ),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.blue[100],
                    backgroundImage:
                        widget.conversation.image != null &&
                            widget.conversation.image!.isNotEmpty
                        ? NetworkImage(widget.conversation.image!)
                        : null,
                    child:
                        widget.conversation.image == null ||
                            widget.conversation.image!.isEmpty
                        ? Text(
                            widget.conversation.title[0].toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          )
                        : null,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.conversation.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${widget.conversation.participantCount} participants',
                          style: TextStyle(color: MangoPalette.grey500, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
        tooltip: 'People',
                    icon: Icon(Icons.people),
                    onPressed: _showParticipants,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 56, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.conversation.description,
                      style: TextStyle(color: MangoPalette.grey600, fontSize: 12),
                    ),
                    SizedBox(height: 4),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(MangoRadius.sm),
                      ),
                      child: Text(
                        widget.conversation.category,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    return StreamBuilder<List<Message>>(
      stream: _conversationController.getSpaceConversationMessages(
        widget.spaceId,
        widget.conversation.id,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(semanticsLabel: 'Loading'));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyConversationState();
        }

        final messages = snapshot.data!;

        return OptimizedListView(
          padding: EdgeInsets.all(16),
          reverse: false,
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[messages.length - 1 - index];
            return _buildMessageBubble(message);
          },
        );
      },
    );
  }

  Widget _buildEmptyConversationState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: MangoPalette.grey400),
          SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(fontSize: 18, color: MangoPalette.grey500),
          ),
          SizedBox(height: 8),
          Text(
            'Start the conversation in ${widget.conversation.title}!',
            style: TextStyle(fontSize: 14, color: MangoPalette.grey600),
          ),
        ],
      ),
    );
  }

  void _showParticipants() {
    Get.bottomSheet(
      Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Conversation Participants (${widget.conversation.participantCount})',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<MangoUser>>(
                stream: _spaceConvController.getSpaceConversationMembers(
                  widget.spaceId,
                  widget.conversation.id,
                ),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator(semanticsLabel: 'Loading'));
                  }

                  final participants = snapshot.data!;

                  return OptimizedListView(
                    padding: EdgeInsets.all(16),
                    itemCount: participants.length,
                    itemBuilder: (context, index) {
                      final user = participants[index];
                      final isAdmin = widget.conversation.admins.contains(
                        user.id,
                      );

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(user.profileImage),
                        ),
                        title: Text(user.displayName),
                        subtitle: Text('@${user.username}'),
                        trailing: isAdmin
                            ? Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue[100],
                                  borderRadius: BorderRadius.circular(MangoRadius.md),
                                ),
                                child: Text(
                                  'Admin',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
