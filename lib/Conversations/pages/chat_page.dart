import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:mango/Conversations/controllers/conversation_controller.dart';
import 'package:mango/Conversations/utils/audio_visualizer.dart';
import 'package:mango/Conversations/utils/media_viewing_dialog.dart';
import 'package:mango/Conversations/utils/voice_note_player_widget.dart';
import 'package:mango/Conversations/utils/voice_recorder_service.dart';
import 'package:mango/Models/customModel/chat.dart';
import 'package:mango/Models/customModel/user.dart';
import 'package:mango/Utils/theme.dart';
import 'package:mango/Utils/optimized_lists.dart';
import 'package:mango/utils.dart';
import 'package:path/path.dart' as p;

class ConversationChatPage extends StatefulWidget {
  final ConversationController controller;
  final MangoUser selectedFriend;

  const ConversationChatPage({
    Key? key,
    required this.controller,
    required this.selectedFriend,
  }) : super(key: key);

  @override
  _ConversationChatPageState createState() => _ConversationChatPageState();
}

class _ConversationChatPageState extends State<ConversationChatPage> {
  late TextEditingController _messageController;
  late FocusNode _messageFocusNode;
  late ScrollController _chatScrollController;
  final ThemeController _themeController = Get.find<ThemeController>();

  
  final VoiceRecorderService _voiceRecorder = VoiceRecorderService();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  bool _isRecording = false;
  int _recordingDuration = 0;
  Timer? _recordingTimer;
  double _currentAmplitude = 0.0;
  bool _useCircleVisualizer = true;

  
  Timer? _typingTimer;
  bool _isTyping = false;

  
  final Set<String> _animatedMessages = {};
  final Set<String> _pendingMessages = {};
  bool _isSending = false;
  List<Message> _cachedMessages = [];
  Map<String, MangoUser> _userCache = {};

  
  Message? _replyToMessage;
  bool _showReplyPreview = false;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _messageFocusNode = FocusNode();
    _chatScrollController = ScrollController();

    _voiceRecorder.amplitudeStream.listen((amplitude) {
      if (mounted) {
        setState(() {
          _currentAmplitude = amplitude;
        });
      }
    });

    _messageFocusNode.addListener(_handleFocusChange);
    _messageController.addListener(_handleTyping);
  }

  void _handleFocusChange() {
    if (_messageFocusNode.hasFocus) {
      _scrollToBottom();
    }
  }

  void _handleTyping() {
    final conversationId = _generateConversationId();

    if (_messageController.text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      widget.controller.setTypingStatus(
        conversationId,
        widget.controller.authentication.currentUser!.uid,
        true,
      );
    }

    if (_typingTimer != null) {
      _typingTimer!.cancel();
    }

    _typingTimer = Timer(const Duration(seconds: 3), () {
      if (_isTyping) {
        _isTyping = false;
        widget.controller.setTypingStatus(
          conversationId,
          widget.controller.authentication.currentUser!.uid,
          false,
        );
      }
    });
  }

  void _scrollToBottom() {
    if (_chatScrollController.hasClients) {
      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_handleTyping);
    _messageController.dispose();
    _messageFocusNode.removeListener(_handleFocusChange);
    _messageFocusNode.dispose();
    _chatScrollController.dispose();
    _voiceRecorder.dispose();
    _recordingTimer?.cancel();
    _typingTimer?.cancel();

    
    final conversationId = _generateConversationId();
    widget.controller.setTypingStatus(
      conversationId,
      widget.controller.authentication.currentUser!.uid,
      false,
    );

    super.dispose();
  }

  String _generateConversationId() {
    final currentUserId = widget.controller.authentication.currentUser!.uid;
    final friendId = widget.selectedFriend.id;
    final ids = [currentUserId, friendId]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isDarkMode = _themeController.isDarkMode.value;
      final primaryColor = _themeController.primaryColorValue;
      final secondaryColor = _themeController.secondaryColorValue;

      return Scaffold(
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _buildChatHeader(isDarkMode, primaryColor),
              Expanded(
                child: Column(
                  children: [
                    
                    _buildTypingIndicator(isDarkMode),
                    
                    Expanded(
                      child: _buildMessagesStream(isDarkMode, primaryColor),
                    ),
                  ],
                ),
              ),
              
              if (_showReplyPreview && _replyToMessage != null)
                _buildReplyPreview(isDarkMode, primaryColor),
              
              _buildMessageInput(isDarkMode, primaryColor, secondaryColor),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildTypingIndicator(bool isDarkMode) {
    final conversationId = _generateConversationId();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('typingIndicators')
          .doc(conversationId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return SizedBox.shrink();
        }

        try {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data == null || data.isEmpty) {
            return SizedBox.shrink();
          }

          
          final currentUserId =
              widget.controller.authentication.currentUser!.uid;
          final typingEntries = data.entries.where((entry) {
            final userId = entry.key;
            final userData = entry.value;

            
            return userId != currentUserId &&
                userData is Map<String, dynamic> &&
                (userData['isTyping'] as bool? ?? false);
          }).toList();

          if (typingEntries.isEmpty) {
            return SizedBox.shrink();
          }

          final firstTypingUser = typingEntries.first;
          final userData = firstTypingUser.value as Map<String, dynamic>;
          final userName = userData['userName'] as String? ?? 'Someone';
          final isTyping = userData['isTyping'] as bool? ?? false;

          if (!isTyping) {
            return SizedBox.shrink();
          }

          return Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildTypingAnimation(isDarkMode),
                SizedBox(width: 8),
                Text(
                  '$userName is typing...',
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          );
        } catch (e) {
          print('Error building typing indicator: $e');
          return SizedBox.shrink();
        }
      },
    );
  }

  Widget _buildTypingAnimation(bool isDarkMode) {
    return Container(
      width: 40,
      height: 30,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTypingDot(isDarkMode, 0),
          _buildTypingDot(isDarkMode, 1),
          _buildTypingDot(isDarkMode, 2),
        ],
      ),
    );
  }

  Widget _buildTypingDot(bool isDarkMode, int index) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 2),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
        shape: BoxShape.circle,
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.3, end: 1.0),
        duration: Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        builder: (context, value, child) {
          return Opacity(opacity: value, child: child);
        },
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  
  Widget _buildReplyPreview(bool isDarkMode, Color primaryColor) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDarkMode ? Colors.grey[800]! : Colors.grey.shade300,
          ),
          bottom: BorderSide(
            color: isDarkMode ? Colors.grey[800]! : Colors.grey.shade300,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(width: 3, height: 40, color: primaryColor),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to ${_replyToMessage!.sender == widget.controller.authentication.currentUser!.uid ? 'yourself' : widget.selectedFriend.displayName}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  _replyToMessage!.text.length > 50
                      ? '${_replyToMessage!.text.substring(0, 50)}...'
                      : _replyToMessage!.text,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 20),
            onPressed: () {
              setState(() {
                _replyToMessage = null;
                _showReplyPreview = false;
              });
            },
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ],
      ),
    );
  }

  
  void _showMessageContextMenu(
    BuildContext context,
    Message message,
    bool isSender,
    bool isDarkMode,
    Color primaryColor,
  ) {
    final conversationId = _generateConversationId();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
                    ),
                  ),
                ),
                child: _buildMessagePreview(message, isDarkMode),
              ),

              
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      [
                            '❤️',
                            '😂',
                            '😮',
                            '😢',
                            '👍',
                            '👎',
                            '🔥',
                            '🎉',
                            '😍',
                            '🤔',
                          ]
                          .map(
                            (emoji) => GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                widget.controller.addReaction(
                                  messageId: message.id,
                                  conversationId: conversationId,
                                  emoji: emoji,
                                  userId: widget
                                      .controller
                                      .authentication
                                      .currentUser!
                                      .uid,
                                  username: 'You',
                                );
                              },
                              child: Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.grey[800]
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  emoji,
                                  style: TextStyle(fontSize: 20),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),

              
              ..._buildMessageActions(
                message,
                isSender,
                isDarkMode,
                primaryColor,
                conversationId,
                context,
              ),
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessagePreview(Message message, bool isDarkMode) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 40,
          color:
              message.sender ==
                  widget.controller.authentication.currentUser!.uid
              ? Colors.blue
              : Colors.green,
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.sender ==
                        widget.controller.authentication.currentUser!.uid
                    ? 'You'
                    : widget.selectedFriend.displayName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              SizedBox(height: 4),
              Text(
                message.text.isNotEmpty
                    ? (message.text.length > 100
                          ? '${message.text.substring(0, 100)}...'
                          : message.text)
                    : message.media
                    ? '📎 Media'
                    : 'Empty message',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildMessageActions(
    Message message,
    bool isSender,
    bool isDarkMode,
    Color primaryColor,
    String conversationId,
    BuildContext context,
  ) {
    return [
      
      _buildActionTile(
        icon: Icons.reply,
        title: 'Reply',
        color: isDarkMode ? Colors.white : Colors.black,
        onTap: () {
          Navigator.pop(context);
          _startReply(message);
        },
      ),

      
      _buildActionTile(
        icon: Icons.forward,
        title: 'Forward',
        color: isDarkMode ? Colors.white : Colors.black,
        onTap: () {
          Navigator.pop(context);
          _showForwardDialog(message);
        },
      ),

      
      if (message.text.isNotEmpty && !message.isDeleted)
        _buildActionTile(
          icon: Icons.copy,
          title: 'Copy',
          color: isDarkMode ? Colors.white : Colors.black,
          onTap: () {
            Clipboard.setData(ClipboardData(text: message.text));
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Message copied to clipboard'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),

      
      _buildActionTile(
        icon: message.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
        title: message.isPinned ? 'Unpin' : 'Pin',
        color: isDarkMode ? Colors.white : Colors.black,
        onTap: () {
          Navigator.pop(context);
          widget.controller.togglePinMessage(
            messageId: message.id,
            conversationId: conversationId,
            pin: !message.isPinned,
          );
        },
      ),

      
      if (isSender && !message.isDeleted && !message.media)
        _buildActionTile(
          icon: Icons.edit,
          title: 'Edit',
          color: primaryColor,
          onTap: () {
            Navigator.pop(context);
            _showEditDialog(message);
          },
        ),

      
      _buildActionTile(
        icon: Icons.delete_outline,
        title: 'Delete',
        color: Colors.red,
        onTap: () {
          Navigator.pop(context);
          _showDeleteDialog(message, conversationId);
        },
      ),
    ];
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }

  void _startReply(Message message) {
    setState(() {
      _replyToMessage = message;
      _showReplyPreview = true;
      _messageFocusNode.requestFocus();
    });
  }

  void _cancelReply() {
    setState(() {
      _replyToMessage = null;
      _showReplyPreview = false;
    });
  }

  
  void _showForwardDialog(Message message) {
    final isDarkMode = _themeController.isDarkMode.value;
    final primaryColor = _themeController.primaryColorValue;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        title: Text(
          'Forward Message',
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                message.text.isNotEmpty ? message.text : '📎 Media',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Select friends to forward to:',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            
            Container(
              height: 200,
              child: Center(
                child: Text(
                  'Friend selection will be implemented',
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text('Forward'),
          ),
        ],
      ),
    );
  }

  
  void _showEditDialog(Message message) {
    final isDarkMode = _themeController.isDarkMode.value;
    final primaryColor = _themeController.primaryColorValue;

    TextEditingController editController = TextEditingController(
      text: message.text,
    );
    final conversationId = _generateConversationId();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        title: Text(
          'Edit Message',
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        ),
        content: TextField(
          controller: editController,
          maxLines: 4,
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
          decoration: InputDecoration(
            hintText: 'Edit your message...',
            hintStyle: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: isDarkMode,
            fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[100],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final newText = editController.text.trim();
              if (newText.isNotEmpty && newText != message.text) {
                widget.controller.editMessage(
                  messageId: message.id,
                  conversationId: conversationId,
                  newText: newText,
                  userId: widget.controller.authentication.currentUser!.uid,
                );
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  
  void _showDeleteDialog(Message message, String conversationId) {
    final isDarkMode = _themeController.isDarkMode.value;
    final primaryColor = _themeController.primaryColorValue;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        title: Text(
          'Delete Message',
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        ),
        content: Text(
          'Are you sure you want to delete this message?',
          style: TextStyle(
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              widget.controller.deleteMessage(
                messageId: message.id,
                conversationId: conversationId,
                userId: widget.controller.authentication.currentUser!.uid,
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  
  Future<void> _startRecording(context) async {
    try {
      if (kIsWeb) {
        UtilsService().showSnackbar(
          'Info',
          'Voice recording may not be fully supported on web',
          snackPosition: SnackPosition.BOTTOM, context: context,
        );
        return;
      }

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

          if (_recordingDuration >= 300) {
            _stopRecording();
          }
        });
      }
    } catch (e) {
      
    }
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    try {
      if (kIsWeb) {
        
        final bytes = await _voiceRecorder.getWebRecordingBytes();
        if (bytes != null && mounted) {
          _showCaptionDialog(
            filePath: 'voice_note.m4a',
            fileType: 'audio',
            webBytes: bytes,
            onSend: (caption) {
              _sendWebVoiceNote(bytes, caption);
            },
          );
        }
      } else {
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
      }

      setState(() {
        _isRecording = false;
        _recordingDuration = 0;
        _currentAmplitude = 0.0;
      });
    } catch (e) {
      
      setState(() {
        _isRecording = false;
      });
    }
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

  Future<void> _sendWebVoiceNote(Uint8List bytes, String? caption) async {
    if (_isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      final audioUrl = await _uploadWebFile(bytes, 'audio', 'voice_note.m4a');
      final duration = _recordingDuration.toDouble();

      await widget.controller.sendMessage(
        receiverId: widget.selectedFriend.id,
        text: caption ?? '',
        senderId: widget.controller.authentication.currentUser!.uid,
        audio: audioUrl,
        audioDuration: duration,
        replyMessageId: _replyToMessage?.id,
        replyMessage: _replyToMessage?.text,
        replyImage: _replyToMessage?.image,
        messageType: MessageType.audio,
      );

      _cancelReply();
    } catch (e) {
      
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  
  Future<void> _pickImage() async {
    try {
      if (kIsWeb) {
        
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );

        if (result != null && result.files.isNotEmpty) {
          final file = result.files.first;
          if (file.bytes != null) {
            
            
            _showCaptionDialog(
              filePath: file.name,
              fileType: 'image',
              webBytes: file.bytes,
              onSend: (caption) {
                
                _sendWebMediaMessage(file.bytes!, 'image', caption, file.name);
              },
            );
          }
        }
      } else {
        
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 1920,
        );

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
    } catch (e) {
      
    }
  }

  Future<void> _pickVideo() async {
    try {
      if (kIsWeb) {
        
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.video,
          allowMultiple: false,
        );

        if (result != null && result.files.isNotEmpty) {
          final file = result.files.first;
          if (file.bytes != null) {
            _showCaptionDialog(
              filePath: file.name,
              fileType: 'video',
              webBytes: file.bytes,
              onSend: (caption) {
                _sendWebMediaMessage(file.bytes!, 'video', caption, file.name);
              },
            );
          }
        }
      } else {
        
        final ImagePicker picker = ImagePicker();
        final XFile? video = await picker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: Duration(minutes: 5),
        );

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
    } catch (e) {
      
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = result.files.single;

        if (kIsWeb) {
          if (file.bytes != null) {
            _sendWebMediaMessage(file.bytes!, 'file', '', file.name);
          }
        } else {
          _sendMediaMessage(file.path!, 'file', '');
        }
      }
    } catch (e) {
      
    }
  }

  Future<void> _sendWebMediaMessage(
    Uint8List bytes,
    String type,
    String? caption,
    String fileName,
  ) async {
    if (_isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      String fileUrl;

      if (kIsWeb) {
        
        fileUrl = await _uploadWebFile(bytes, type, fileName);
      } else {
        throw Exception('Web media method called on mobile');
      }

      await widget.controller.sendMessage(
        receiverId: widget.selectedFriend.id,
        text: caption ?? '',
        senderId: widget.controller.authentication.currentUser!.uid,
        image: type == 'image' ? fileUrl : null,
        video: type == 'video' ? fileUrl : null,
        replyMessageId: _replyToMessage?.id,
        replyMessage: _replyToMessage?.text,
        replyImage: _replyToMessage?.image,
        messageType: type == 'image'
            ? MessageType.image
            : type == 'video'
            ? MessageType.video
            : MessageType.file,
      );

      _cancelReply();
    } catch (e) {
      
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  
  Future<String> _uploadWebFile(
    Uint8List bytes,
    String type,
    String fileName,
  ) async {
    final userId = widget.controller.authentication.currentUser!.uid;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = p.extension(fileName);
    final finalFileName = '${type}_$timestamp$extension';

    final Reference storageRef = _storage
        .ref()
        .child('chats')
        .child(
          '${widget.controller.authentication.currentUser!.uid}_${widget.selectedFriend.id}',
        )
        .child(type)
        .child(finalFileName);

    final SettableMetadata metadata = SettableMetadata(
      contentType: _getContentType(type, extension),
      customMetadata: {
        'uploadedBy': userId,
        'uploadedAt': timestamp.toString(),
        'originalName': fileName,
      },
    );

    final UploadTask uploadTask = storageRef.putData(bytes, metadata);
    await uploadTask;
    final downloadUrl = await storageRef.getDownloadURL();

    return downloadUrl;
  }

  
  Future<void> _sendVoiceNote(String filePath, String? caption) async {
    if (_isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      
      if (!kIsWeb) {
        final file = File(filePath);
        final stat = await file.stat();
        if (stat.size > 10 * 1024 * 1024) {
          throw Exception('File too large');
        }

        
        final duration =
            _voiceRecorder.recordingDuration?.inSeconds.toDouble() ?? 0.0;

        
        final audioUrl = await _uploadMobileFile(filePath, 'audio');

        await widget.controller.sendMessage(
          receiverId: widget.selectedFriend.id,
          text: caption ?? '',
          senderId: widget.controller.authentication.currentUser!.uid,
          audio: audioUrl,
          audioDuration: duration,
          replyMessageId: _replyToMessage?.id,
          replyMessage: _replyToMessage?.text,
          replyImage: _replyToMessage?.image,
          messageType: MessageType.audio,
        );
      } else {
        
        
        throw Exception('Voice recording not supported on web');
      }

      _cancelReply();
    } catch (e) {
      print('Error sending voice note: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send voice note'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  
  Future<String> _uploadMobileFile(String filePath, String type) async {
    final userId = widget.controller.authentication.currentUser!.uid;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = p.basename(filePath);
    final extension = p.extension(filePath);
    final finalFileName = '${type}_$timestamp$extension';

    final Reference storageRef = _storage
        .ref()
        .child('chats')
        .child(
          '${widget.controller.authentication.currentUser!.uid}_${widget.selectedFriend.id}',
        )
        .child(type)
        .child(finalFileName);

    final SettableMetadata metadata = SettableMetadata(
      contentType: 'audio/m4a',
      customMetadata: {
        'uploadedBy': userId,
        'uploadedAt': timestamp.toString(),
        'originalName': fileName,
      },
    );

    final UploadTask uploadTask = storageRef.putFile(File(filePath), metadata);
    await uploadTask;
    return await storageRef.getDownloadURL();
  }

  Future<void> _sendMediaMessage(
    String filePath,
    String type,
    String? caption,
  ) async {
    if (_isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      String fileUrl;

      if (kIsWeb) {
        
        
        throw Exception(
          'Web media sending requires bytes - use _sendWebMediaMessage instead',
        );
      } else {
        final file = File(filePath);
        final stat = await file.stat();
        final maxSize = type == 'image'
            ? 20 * 1024 * 1024
            : type == 'video'
            ? 100 * 1024 * 1024
            : 50 * 1024 * 1024;

        if (stat.size > maxSize) return;

        fileUrl = await _uploadFile(filePath, null, type, null);
      }

      await widget.controller.sendMessage(
        receiverId: widget.selectedFriend.id,
        text: caption ?? '',
        senderId: widget.controller.authentication.currentUser!.uid,
        image: type == 'image' ? fileUrl : null,
        video: type == 'video' ? fileUrl : null,
        replyMessageId: _replyToMessage?.id,
        replyMessage: _replyToMessage?.text,
        replyImage: _replyToMessage?.image,
        messageType: type == 'image'
            ? MessageType.image
            : type == 'video'
            ? MessageType.video
            : MessageType.file,
      );

      _cancelReply();
    } catch (e) {
      
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _sendTextMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    final messageText = text;
    _messageController.clear();

    setState(() {
      _isSending = true;
    });

    final tempMessageId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    _pendingMessages.add(tempMessageId);

    widget.controller
        .sendMessage(
          receiverId: widget.selectedFriend.id,
          text: messageText,
          senderId: widget.controller.authentication.currentUser!.uid,
          replyMessageId: _replyToMessage?.id,
          replyMessage: _replyToMessage?.text,
          replyImage: _replyToMessage?.image,
        )
        .then((_) {
          if (mounted) {
            _pendingMessages.remove(tempMessageId);
            setState(() {
              _isSending = false;
            });
            _scrollToBottom();
            _cancelReply();

            
            final conversationId = _generateConversationId();
            widget.controller.setTypingStatus(
              conversationId,
              widget.controller.authentication.currentUser!.uid,
              false,
            );
          }
        })
        .catchError((e) {
          if (mounted) {
            _pendingMessages.remove(tempMessageId);
            setState(() {
              _isSending = false;
            });
            _messageController.text = messageText;
          }
        });
  }

  
  Future<String> _uploadFile(
    String filePath,
    Uint8List? bytes,
    String type,
    String? fileName,
  ) async {
    final userId = widget.controller.authentication.currentUser!.uid;

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    
    final String extension;
    if (fileName != null) {
      extension = p.extension(fileName);
    } else {
      extension = p.extension(filePath);
    }

    final finalFileName = '${type}_$timestamp$extension';

    final Reference storageRef = _storage
        .ref()
        .child('chats')
        .child(
          '${widget.controller.authentication.currentUser!.uid}_${widget.selectedFriend.id}',
        )
        .child(type)
        .child(finalFileName);

    final SettableMetadata metadata = SettableMetadata(
      contentType: _getContentType(type, extension),
      customMetadata: {
        'uploadedBy': userId,
        'uploadedAt': timestamp.toString(),
        'originalName': fileName ?? p.basename(filePath),
      },
    );

    if (kIsWeb && bytes != null) {
      
      final UploadTask uploadTask = storageRef.putData(bytes, metadata);
      await uploadTask;
    } else {
      
      final UploadTask uploadTask = storageRef.putFile(
        File(filePath),
        metadata,
      );
      await uploadTask;
    }

    final downloadUrl = await storageRef.getDownloadURL();
    return downloadUrl;
  }

  String _getContentType(String fileType, String extension) {
    final ext = extension.toLowerCase();
    switch (fileType) {
      case 'audio':
        if (ext.contains('.mp3')) return 'audio/mpeg';
        if (ext.contains('.wav')) return 'audio/wav';
        if (ext.contains('.m4a')) return 'audio/mp4';
        if (ext.contains('.aac')) return 'audio/aac';
        if (ext.contains('.flac')) return 'audio/flac';
        if (ext.contains('.ogg')) return 'audio/ogg';
        return 'audio/m4a';
      case 'image':
        if (ext.contains('.jpg') || ext.contains('.jpeg')) return 'image/jpeg';
        if (ext.contains('.png')) return 'image/png';
        if (ext.contains('.gif')) return 'image/gif';
        if (ext.contains('.webp')) return 'image/webp';
        return 'image/jpeg';
      case 'video':
        if (ext.contains('.mp4')) return 'video/mp4';
        if (ext.contains('.mov')) return 'video/quicktime';
        if (ext.contains('.avi')) return 'video/x-msvideo';
        if (ext.contains('.mkv')) return 'video/x-matroska';
        if (ext.contains('.webm')) return 'video/webm';
        return 'video/mp4';
      default:
        return 'application/octet-stream';
    }
  }

  
  void _showCaptionDialog({
    required String filePath,
    required String fileType,
    Uint8List? webBytes,
    required Function(String?) onSend,
  }) {
    final isDarkMode = _themeController.isDarkMode.value;
    final primaryColor = _themeController.primaryColorValue;

    TextEditingController captionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        title: Text(
          'Add Caption',
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (fileType == 'image')
              Container(
                height: 160,
                width: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: kIsWeb && webBytes != null
                      ? DecorationImage(
                          image: MemoryImage(webBytes!),
                          fit: BoxFit.cover,
                        )
                      : (filePath.isNotEmpty
                            ? DecorationImage(
                                image: FileImage(File(filePath)),
                                fit: BoxFit.cover,
                              )
                            : null),
                  color: isDarkMode ? Colors.grey[700] : Colors.grey.shade300,
                ),
              )
            else if (fileType == 'audio')
              Container(
                height: 80,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.audio_file, size: 40, color: primaryColor),
                    SizedBox(height: 8),
                    Text(
                      'Voice Note',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 16),
            TextField(
              controller: captionController,
              decoration: InputDecoration(
                hintText: 'Add a caption...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                filled: isDarkMode,
                fillColor: isDarkMode ? Colors.grey[800] : null,
                hintStyle: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onSend(captionController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
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

  
  Widget _buildChatHeader(bool isDarkMode, Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDarkMode ? Colors.grey[800]! : Colors.grey.shade200,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.arrow_back,
                size: 24,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              onPressed: () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
            ),
            SizedBox(width: 12),
            CircleAvatar(
              backgroundImage: widget.selectedFriend.profileImage.isNotEmpty
                  ? NetworkImage(widget.selectedFriend.profileImage)
                  : null,
              radius: 15,
              child: widget.selectedFriend.profileImage.isEmpty
                  ? Icon(
                      Icons.person,
                      size: 20,
                      color: isDarkMode ? Colors.black : Colors.white,
                    )
                  : null,
              backgroundColor: widget.selectedFriend.profileImage.isEmpty
                  ? (isDarkMode ? Colors.grey[700] : Colors.grey.shade300)
                  : null,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.selectedFriend.displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  Text(
                    '@${widget.selectedFriend.username}',
                    style: TextStyle(
                      color: isDarkMode
                          ? Colors.grey[400]
                          : Colors.grey.shade600,
                      fontSize: 9,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.more_vert,
                size: 24,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              onPressed: () => _showChatOptions(isDarkMode, primaryColor),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  void _showChatOptions(bool isDarkMode, Color primaryColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.search,
                  color: isDarkMode ? Colors.white : Colors.black,
                  size: 11,
                ),
                title: Text(
                  'Search in conversation',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                    fontSize: 10,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _searchInConversation(isDarkMode);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.push_pin,
                  color: isDarkMode ? Colors.white : Colors.black,
                  size: 11,
                ),
                title: Text(
                  'View pinned messages',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                    fontSize: 10,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _viewPinnedMessages(isDarkMode, primaryColor);
                },
              ),
              ListTile(
                leading: Icon(Icons.block, color: Colors.red, size: 11),
                title: Text(
                  'Block user',
                  style: TextStyle(color: Colors.red, fontSize: 10),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showBlockDialog(isDarkMode, primaryColor);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _searchInConversation(bool isDarkMode) {
    
  }

  void _viewPinnedMessages(bool isDarkMode, Color primaryColor) {
    final conversationId = _generateConversationId();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        title: Text(
          'Pinned Messages',
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        ),
        content: StreamBuilder<List<Message>>(
          stream: widget.controller.getPinnedMessages(conversationId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: primaryColor),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Text(
                  'No pinned messages',
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              );
            }

            final pinnedMessages = snapshot.data!;
            return Container(
              height: 300,
              width: double.maxFinite,
              child: OptimizedListView(
                shrinkWrap: true,
                itemCount: pinnedMessages.length,
                itemBuilder: (context, index) {
                  final message = pinnedMessages[index];
                  return ListTile(
                    title: Text(
                      message.text.isNotEmpty ? message.text : '📎 Media',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontSize: 10,
                      ),
                    ),
                    subtitle: Text(
                      _formatMessageTime(message.timeStamp),
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 10,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      
                    },
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBlockDialog(bool isDarkMode, Color primaryColor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        title: Text(
          'Block ${widget.selectedFriend.displayName}?',
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        ),
        content: Text(
          'You will no longer receive messages from this user.',
          style: TextStyle(
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            fontSize: 10,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Block'),
          ),
        ],
      ),
    );
  }

  
  Widget _buildMessagesStream(bool isDarkMode, Color primaryColor) {
    return StreamBuilder<List<Message>>(
      stream: widget.controller.getConversationMessagesSimple(
        widget.controller.authentication.currentUser!.uid,
        widget.selectedFriend.id,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _cachedMessages.isNotEmpty) {
          return _buildMessageList(_cachedMessages, isDarkMode, primaryColor);
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading messages',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                fontSize: 11,
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          _cachedMessages = [];
          return _buildEmptyChatState(isDarkMode);
        }

        final messages = List<Message>.from(snapshot.data!);

        if (_cachedMessages.length != messages.length) {
          messages.sort((a, b) => a.timeStamp.compareTo(b.timeStamp));
          _cachedMessages = messages;
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_chatScrollController.hasClients) {
            final maxScroll = _chatScrollController.position.maxScrollExtent;
            final currentScroll = _chatScrollController.position.pixels;
            if (maxScroll - currentScroll < 300) {
              _chatScrollController.jumpTo(maxScroll);
            }
          }
        });

        return _buildMessageList(_cachedMessages, isDarkMode, primaryColor);
      },
    );
  }

  Widget _buildMessageList(
    List<Message> messages,
    bool isDarkMode,
    Color primaryColor,
  ) {
    final messageGroups = _groupConsecutiveMessages(messages);

    return OptimizedListView(
      controller: _chatScrollController,
      padding: EdgeInsets.all(0),
      physics: BouncingScrollPhysics(),
      itemCount: messageGroups.length,
      itemBuilder: (context, index) => _buildSwipeableMessage(
        messageGroups[index],
        isDarkMode,
        primaryColor,
      ),
    );
  }

  Widget _buildSwipeableMessage(
    List<Message> messageGroup,
    bool isDarkMode,
    Color primaryColor,
  ) {
    final firstMessage = messageGroup.first;
    final isSender =
        firstMessage.sender ==
        widget.controller.authentication.currentUser!.uid;

    return Dismissible(
      key: Key(firstMessage.id),
      direction: isSender
          ? DismissDirection.endToStart
          : DismissDirection.startToEnd,
      background: Container(
        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
        alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Icon(
          Icons.reply,
          color: isDarkMode ? Colors.grey[600] : Colors.grey[800],
          size: 16,
        ),
      ),
      onDismissed: (direction) {
        _startReply(firstMessage);
      },
      child: GestureDetector(
        onLongPress: () => _showMessageContextMenu(
          context,
          firstMessage,
          isSender,
          isDarkMode,
          primaryColor,
        ),
        child: FutureBuilder<MangoUser?>(
          future: _getUserInfo(firstMessage.sender),
          builder: (context, snapshot) {
            final user = snapshot.data;
            final senderName = user?.displayName ?? 'Unknown User';

            return _buildMessageGroupBubble(
              messageGroup,
              isSender,
              isDarkMode,
              primaryColor,
              senderName,
              user,
            );
          },
        ),
      ),
    );
  }

  List<List<Message>> _groupConsecutiveMessages(List<Message> messages) {
    if (messages.isEmpty) return [];

    List<List<Message>> groups = [];
    List<Message> currentGroup = [messages[0]];

    for (int i = 1; i < messages.length; i++) {
      final currentMessage = messages[i];
      final previousMessage = messages[i - 1];

      final timeDiff = currentMessage.timeStamp.toDate().difference(
        previousMessage.timeStamp.toDate(),
      );

      
      if (currentMessage.sender == previousMessage.sender &&
          timeDiff.inMinutes <= 5) {
        currentGroup.add(currentMessage);
      } else {
        groups.add(List.from(currentGroup));
        currentGroup = [currentMessage];
      }
    }

    groups.add(currentGroup);
    return groups;
  }

  Widget _buildMessageGroupBubble(
    List<Message> messageGroup,
    bool isSender,
    bool isDarkMode,
    Color primaryColor,
    String senderName,
    MangoUser? user,
  ) {
    final firstMessage = messageGroup.first;
    final messageId = firstMessage.id;
    final isPending = _pendingMessages.contains(firstMessage.id);

    if (!_animatedMessages.contains(messageId) && !isPending) {
      _animatedMessages.add(messageId);
    }

    final bubbleColor = isSender
        ? (isPending ? Colors.grey.withOpacity(0.7) : Colors.grey.shade900)
        : (isDarkMode ? Colors.grey[800] : Colors.grey.shade100);

    final textColor = isSender
        ? Colors.white
        : (isDarkMode ? Colors.white : Colors.black87);
    final timeColor = isSender
        ? Colors.white70
        : (isDarkMode ? Colors.grey[400] : Colors.grey.shade600);
    final senderNameColor = isSender
        ? Colors.white.withOpacity(0.8)
        : (isDarkMode ? Colors.grey[400] : Colors.grey.shade600);

    return Container(
      margin: EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Row(
              children: [
                if (!isSender) ...[
                  CircleAvatar(
                    backgroundImage: user?.profileImage.isNotEmpty == true
                        ? NetworkImage(user!.profileImage)
                        : null,
                    radius: 8,
                    child: user?.profileImage.isEmpty == true
                        ? Icon(
                            Icons.person,
                            size: 10,
                            color: isDarkMode ? Colors.black : Colors.white,
                          )
                        : null,
                    backgroundColor: user?.profileImage.isEmpty == true
                        ? (isDarkMode ? Colors.grey[700] : Colors.grey.shade300)
                        : null,
                  ),
                  SizedBox(width: 4),
                ],
                Text(
                  isSender ? 'You' : senderName,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: senderNameColor,
                  ),
                ),
              ],
            ),
          ),

          Container(
            margin: EdgeInsets.symmetric(horizontal: 8),
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                if (!isPending)
                  BoxShadow(
                    color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.05),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (firstMessage.replyMessageId != null)
                  _buildReplyPreviewInMessage(
                    firstMessage,
                    isSender,
                    isDarkMode,
                    primaryColor,
                  ),
                for (int i = 0; i < messageGroup.length; i++)
                  _buildSingleMessageContent(
                    messageGroup[i],
                    isSender,
                    textColor,
                    timeColor!,
                    isDarkMode,
                    primaryColor,
                    showTimestamp:
                        i ==
                        messageGroup.length -
                            1, 
                    isLastInGroup: i == messageGroup.length - 1,
                  ),

                
                if (firstMessage.reactions != null &&
                    firstMessage.reactions!.isNotEmpty)
                  _buildReactions(firstMessage, isDarkMode),

                
                _buildReadReceipts(firstMessage, isSender, isDarkMode),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyPreviewInMessage(
    Message message,
    bool isSender,
    bool isDarkMode,
    Color primaryColor,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[700] : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: primaryColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.sender == widget.controller.authentication.currentUser!.uid
                ? 'You'
                : widget.selectedFriend.displayName,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          SizedBox(height: 2),
          Text(
            message.replyMessage ?? '',
            style: TextStyle(
              fontSize: 9,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildReactions(Message message, bool isDarkMode) {
    final reactions = message.reactions!;
    final uniqueReactions = reactions.values.fold<Map<String, int>>({}, (
      map,
      reaction,
    ) {
      map[reaction.emoji] = (map[reaction.emoji] ?? 0) + 1;
      return map;
    });

    return Container(
      margin: EdgeInsets.only(top: 4),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[700] : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 4,
        children: uniqueReactions.entries.map((entry) {
          return Text(
            '${entry.key} ${entry.value > 1 ? entry.value : ''}',
            style: TextStyle(fontSize: 12),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReadReceipts(Message message, bool isSender, bool isDarkMode) {
    if (!isSender || message.status != MessageStatus.read) {
      return SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.done_all, size: 14, color: Colors.blue),
          SizedBox(width: 4),
          Text(
            'Read',
            style: TextStyle(
              fontSize: 10,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleMessageContent(
    Message message,
    bool isSender,
    Color textColor,
    Color timeColor,
    bool isDarkMode,
    Color primaryColor, {
    required bool showTimestamp,
    required bool isLastInGroup,
  }) {
    return Column(
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
              GestureDetector(
                onTap: () =>
                    _viewMedia(message.image!, 'image', message.caption),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    message.image!,
                    width: 100,
                    height: 200,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: 100,
                        height: 200,
                        color: isDarkMode
                            ? Colors.grey[700]
                            : Colors.grey.shade300,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                            color: primaryColor,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 100,
                        height: 200,
                        color: isDarkMode
                            ? Colors.grey[700]
                            : Colors.grey.shade300,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error, color: Colors.red, size: 40),
                            SizedBox(height: 8),
                            Text(
                              'Failed to load image',
                              style: TextStyle(
                                color: isDarkMode
                                    ? Colors.grey[400]
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
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
              GestureDetector(
                onTap: () =>
                    _viewMedia(message.video!, 'video', message.caption),
                child: Container(
                  width: 100,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isDarkMode ? Colors.grey[700] : Colors.black12,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: isDarkMode ? Colors.grey[600] : Colors.black26,
                        ),
                      ),
                      Center(
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.play_arrow,
                            size: 30,
                            color: Colors.black,
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
          Padding(
            padding: EdgeInsets.only(bottom: isLastInGroup ? 0 : 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.editedAt != null)
                  Row(
                    children: [
                      Text(
                        'Edited',
                        style: TextStyle(
                          fontSize: 7,
                          color: timeColor,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      SizedBox(width: 4),
                    ],
                  ),
                Text(
                  message.text,
                  style: TextStyle(color: textColor, fontSize: 11, height: 1.1),
                ),
              ],
            ),
          ),

        
        if (message.caption != null &&
            message.caption!.isNotEmpty &&
            (message.image != null ||
                message.video != null ||
                message.audio != null))
          Padding(
            padding: EdgeInsets.only(top: 8, bottom: isLastInGroup ? 0 : 8),
            child: Text(
              message.caption!,
              style: TextStyle(
                fontSize: 9,
                color: isSender
                    ? Colors.black
                    : (isDarkMode ? Colors.black : Colors.grey.shade700),
                fontStyle: FontStyle.italic,
                height: 1.1,
              ),
            ),
          ),

        
        if (showTimestamp)
          Padding(
            padding: EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  _formatMessageTime(message.timeStamp),
                  style: TextStyle(fontSize: 8, color: timeColor),
                ),
                if (isSender) ...[
                  SizedBox(width: 6),
                  Icon(Icons.done_all, size: 9, color: timeColor),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Future<MangoUser?> _getUserInfo(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }

    try {
      final user = await widget.controller.getUserInfo(userId)!.first;
      if (user != null) {
        _userCache[userId] = user;
      }
      return user;
    } catch (e) {
      return null;
    }
  }

  Widget _buildEmptyChatState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'asset/images/box.json',
            width: 100,
            height: 100,
            repeat: true,
          ),
          SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Say hello to ${widget.selectedFriend.displayName}!',
            style: TextStyle(
              color: isDarkMode ? Colors.grey[500] : Colors.grey.shade500,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput(
    bool isDarkMode,
    Color primaryColor,
    Color secondaryColor,
  ) {
    if (_isRecording) {
      return _buildRecordingUI(isDarkMode, primaryColor);
    }

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        border: Border.all(
          color: isDarkMode ? Colors.grey[700]! : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _messageController,
            focusNode: _messageFocusNode,
            maxLines: null,
            textInputAction: TextInputAction.send,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontSize: 9,
            ),
            decoration: InputDecoration(
              hintText: 'Type a message...',
              hintStyle: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey.shade500,
                fontSize: 9,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 8),
            ),
            onSubmitted: (_) => _sendTextMessage(),
          ),

          SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: Container(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: BouncingScrollPhysics(),
                    children: [
                      _buildMediaButton(
                        icon: Icons.image,
                        onTap: _pickImage,
                        color: Colors.green,
                        tooltip: 'Send Image',
                        isDarkMode: isDarkMode,
                      ),
                      SizedBox(width: 6),
                      _buildMediaButton(
                        icon: Icons.videocam,
                        onTap: _pickVideo,
                        color: Colors.purple,
                        tooltip: 'Send Video',
                        isDarkMode: isDarkMode,
                      ),
                      SizedBox(width: 6),
                      _buildMediaButton(
                        icon: Icons.attach_file,
                        onTap: _pickFile,
                        color: Colors.blue,
                        tooltip: 'Send File',
                        isDarkMode: isDarkMode,
                      ),
                      SizedBox(width: 6),
                      _buildMediaButton(
                        icon: Icons.mic,
                        onTap: (){_startRecording(context);},
                        color: Colors.orange,
                        tooltip: 'Record Voice Note',
                        isDarkMode: isDarkMode,
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(width: 8),

              Container(
                width: 36,
                height: 36,
                child: FloatingActionButton(
                  onPressed: _sendTextMessage,
                  backgroundColor:
                      _messageController.text.trim().isEmpty || _isSending
                      ? (isDarkMode ? Colors.grey[700] : Colors.grey.shade300)
                      : primaryColor,
                  elevation: 1,
                  child: Transform.rotate(
                    angle: -0.4,
                    child: Icon(
                      Icons.send,
                      color: _messageController.text.trim().isEmpty
                          ? (isDarkMode ? Colors.grey[500] : Colors.grey)
                          : Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMediaButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
    required String tooltip,
    required bool isDarkMode,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(isDarkMode ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(isDarkMode ? 0.4 : 0.3),
              width: 1,
            ),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  Widget _buildRecordingUI(bool isDarkMode, Color primaryColor) {
    final recordingColor = primaryColor;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDarkMode
              ? [Colors.grey[900]!, Colors.black]
              : [
                  recordingColor.withOpacity(0.1),
                  recordingColor.withOpacity(0.05),
                ],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: recordingColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: Duration(milliseconds: 500),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _recordingDuration % 2 == 0
                        ? recordingColor
                        : recordingColor.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'RECORDING',
                  style: TextStyle(
                    color: recordingColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          _useCircleVisualizer
              ? CircleAudioVisualizer(
                  isRecording: _isRecording,
                  amplitude: _currentAmplitude,
                )
              : AudioVisualizer(
                  isRecording: _isRecording,
                  amplitude: _currentAmplitude,
                ),

          const SizedBox(height: 16),

          Column(
            children: [
              Text(
                '${_recordingDuration ~/ 60}:${(_recordingDuration % 60).toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: recordingColor,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Recording Voice Note',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white : recordingColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.cancel, size: 18),
                  label: const Text('Cancel'),
                  onPressed: _cancelRecording,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: recordingColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: recordingColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.send, size: 18),
                  label: const Text('Send'),
                  onPressed: _stopRecording,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: recordingColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatMessageTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();

    if (date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (date.day == now.day - 1 &&
        date.month == now.month &&
        date.year == now.year) {
      return 'Yesterday';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}
