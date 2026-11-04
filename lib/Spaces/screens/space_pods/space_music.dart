import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mango/Utils/optimized_lists.dart';
import 'package:intl/intl.dart';
import 'package:mango/Books/widgets/book_rating.dart';
import 'package:mango/Books/widgets/two_side_rounded_button.dart';
import 'package:mango/Conversations/controllers/conversation_controller.dart';
import 'package:mango/MusicPlayer/music_player.dart';
import 'package:mango/SpaceConversations/space_conversations.dart';
import 'package:mango/SpaceConversations/space_conversations_controller.dart';
import 'package:mango/SpaceConversations/space_conversations_model.dart';
import 'package:mango/SpaceLive/space_live_sessions.dart';
import 'package:mango/Spaces/controllers/space_item.dart';
import 'package:mango/Spaces/controllers/space_item_controller.dart';
import 'package:mango/Utils/text_field.dart';
import 'package:mango/utils.dart';

import '../../../Home/components/music_components.dart';
import '../../../Home/controllers/dashboard_controller.dart';
import '../../../Home/pages/post_shimmer.dart';
import '../../../Models/customModel/playlist.dart';

class SpaceMusic extends StatelessWidget {
  SpaceMusic({super.key});

  final MangoDashboardController controller = Get.put(
    MangoDashboardController(),
  );
  final SpaceItemsService itemController = Get.put(SpaceItemsService());
  final String? spaceId = Get.arguments?['spaceId'];

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    
    if (spaceId == null) {
      return Scaffold(
        body: Center(
          child: Text(
            'Space ID not provided',
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    }
    
    final spaceDoc = FirebaseFirestore.instance.collection('spaces').doc(spaceId!);
    
    return StreamBuilder<DocumentSnapshot>(
      stream: spaceDoc.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScaffold();
        }
        
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            body: Center(
              child: Text(
                'Space not found',
                style: TextStyle(color: Colors.red),
              ),
            ),
          );
        }
        
        final spaceData = snapshot.data!.data() as Map<String, dynamic>?;
        final isCreator = spaceData?['postCreator'] == currentUserId;
        final collaborators = List<String>.from(spaceData?['collaborators'] ?? []);
        final isCollaborator = collaborators.contains(currentUserId);
        final isAdmin = isCreator || isCollaborator;
        
        return _buildMainContent(context, isAdmin);
      },
    );
  }
  
  Widget _buildLoadingScaffold() {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
  
  Widget _buildMainContent(BuildContext context, bool isAdmin) {
    Widget _buildCardSkeleton(int rank) {
      return Container(
        width: 140,
        margin: EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '#$rank',
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
            SizedBox(height: 8),
            Container(
              width: 100,
              height: 12,
              color: Colors.grey[300],
              margin: EdgeInsets.only(bottom: 4),
            ),
            Container(width: 80, height: 10, color: Colors.grey[300]),
          ],
        ),
      );
    }

    Widget _buildSectionWithSeeAll(
      String title, {
      required VoidCallback onSeeAll,
      required Widget content,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).primaryColorLight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                GestureDetector(
                  onTap: onSeeAll,
                  child: const Icon(Icons.arrow_forward_ios, size: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          content,
        ],
      );
    }

    String playValue(int plays) {
      final int playValue = plays;

      if (playValue > 999) {
        return '${(playValue / 1000).floor()}k';
      } else if (playValue > 1000000) {
        return '${(playValue / 30).floor()}m';
      } else {
        return '$playValue';
      }
    }

    Widget _buildHitListCard(SpaceItem item, int rank) {
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection("music")
            .doc(item.originalItemId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildCardSkeleton(rank);
          }

          if (snapshot.hasError ||
              !snapshot.hasData ||
              !snapshot.data!.exists) {
            final hasError = snapshot.hasError;

            return Container(
              width: 140,
              margin: EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              hasError ? Icons.error_outline : Icons.music_off,
                              color: Colors.grey[600],
                              size: 24,
                            ),
                            SizedBox(height: 4),
                            Text(
                              hasError ? 'Error' : 'Not found',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '#$rank',
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
                  SizedBox(height: 8),
                  Text(
                    hasError ? 'Failed to load' : 'Music not found',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    hasError ? 'Tap to retry' : 'Unknown',
                    style: TextStyle(fontSize: 9, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          }

          final musicDoc = snapshot.data!;
          final musicData = musicDoc.data() as Map<String, dynamic>;

          return InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MusicPlayer(musicId: item.originalItemId)),
              );
            },
            child: Container(
              width: 140,
              margin: EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          image: DecorationImage(
                            image: NetworkImage(
                              musicData['artworkUrl'].toString(),
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '#$rank',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            playValue(musicData['plays']),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    musicData['title'],
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    item.savedBy == '' ? 'Unknown Artiste' : item.savedBy,
                    style: TextStyle(fontSize: 9, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    Widget _buildEmptyMusicSection(String message) {
      return Container(
        height: 100,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.music_note, size: 32, color: Colors.grey[400]),
              SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    Widget _buildHitListSection() {
      return _buildSectionWithSeeAll(
        'Space Jamz',
        onSeeAll: () => Get.toNamed('/music-home'),
        content: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('spaces')
              .doc(spaceId!)
              .collection('space-music')
              .orderBy('savedAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return HorizontalShimmerList(
                height: 180,
                width: 160,
                color: Colors.grey[300]!,
              );
            }
            
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyMusicSection(
                isAdmin 
                    ? 'No music added yet. Tap the + button to add songs!'
                    : 'No music has been spaced yet'
              );
            }
            
            final spaceItems = snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return SpaceItem(
                id: doc.id,
                originalItemId: data['originalItemId'] ?? '',
                itemType: data['itemType'] ?? 'music',
                savedBy: data['savedBy'] ?? '',
                savedAt: (data['savedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                spaceId: data['spaceId'] ?? '',
                data: data,
              );
            }).toList();
            
            return Container(
              height: 180,
              child: OptimizedListView(
                shrinkWrap: true,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: spaceItems.length,
                itemBuilder: (context, index) {
                  final item = spaceItems[index];
                  return Container(
                    margin: const EdgeInsets.only(right: 6),
                    child: _buildHitListCard(item, index + 1),
                  );
                },
              ),
            );
          },
        ),
      );
    }

    var size = MediaQuery.of(context).size;
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(height: size.height * .1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.titleMedium,
                        children: const [
                          TextSpan(
                            text: "This is how we catch a vibe.",
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(
                            text: "\nNo Sweat.",
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SpaceMusicActions(
                    spaceId: spaceId!, 
                    podType: 'music',
                    isAdmin: isAdmin,
                  ),
                  const SizedBox(height: 10),
                  _buildHitListSection(),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 10,
                    ),
                    child: Text(
                      'Let\'s talk..',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).primaryColorLight,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: ConversationsCard(
                      spaceId: spaceId!,
                      podType: 'music',
                      isAdmin: isAdmin,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25.0),
                    child: RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.titleSmall,
                        children: const [
                          TextSpan(text: "Live "),
                          TextSpan(
                            text: "Sessions...",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: LiveSessionsCard(
                      spaceId: spaceId!,
                      podType: 'music',
                      isAdmin: isAdmin,
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 15),
                    child: Text(
                      "DJ Booth",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DjBoothList(spaceId: spaceId!, isAdmin: isAdmin),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SpaceMusicActions extends StatelessWidget {
  final String podType;
  final String spaceId;
  final bool isAdmin;
  
  const SpaceMusicActions({
    super.key,
    required this.spaceId,
    required this.podType,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildButton(
            context,
            color: Colors.deepPurple,
            icon: Icons.chat,
            text: "Conversation",
            onTap: isAdmin 
                ? () => _openConversationSheet(context, spaceId, podType)
                : () => _showPermissionDenied(context, "start conversations"),
            isDisabled: !isAdmin,
          ),
          _buildButton(
            context,
            color: Colors.teal,
            icon: Icons.live_tv,
            text: "Live Sessions",
            onTap: isAdmin 
                ? () => _openLiveSessionSheet(context, spaceId, podType)
                : () => _showPermissionDenied(context, "create live sessions"),
            isDisabled: !isAdmin,
          ),
          _buildButton(
            context,
            color: Colors.orange,
            icon: Icons.headset,
            text: "DJ Booth",
            onTap: isAdmin 
                ? () => _openDjBoothSheet(context, spaceId, podType)
                : () => _showPermissionDenied(context, "create DJ events"),
            isDisabled: !isAdmin,
          ),
        ],
      ),
    );
  }

  Widget _buildButton(
    BuildContext context, {
    required Color color,
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    bool isDisabled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        width: 90,
        decoration: BoxDecoration(
          color: isDisabled ? Colors.grey[700] : color,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 30),
            const SizedBox(height: 10),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  void _showPermissionDenied(BuildContext context, String action) {
    UtilsService().showSnackbar(
      "Permission Denied",
      "Only space creators and collaborators can $action",
      backgroundColor: Colors.red,
      colorText: Colors.white,
      context: context,
    );
  }
}

Future<String?> _pickAndUploadImage() async {
  try {
    if (kIsWeb) {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        PlatformFile file = result.files.first;
        Uint8List? fileBytes = file.bytes;
        
        if (fileBytes == null) {
          throw Exception('Could not read file bytes');
        }

        final fileName = DateTime.now().millisecondsSinceEpoch.toString();
        final ref = FirebaseStorage.instance.ref().child("uploads/$fileName.jpg");
        
        await ref.putData(fileBytes);
        return await ref.getDownloadURL();
      }
      return null;
    } else {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile == null) return null;

      final file = File(pickedFile.path);
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final ref = FirebaseStorage.instance.ref().child("uploads/$fileName.jpg");

      await ref.putFile(file);
      return await ref.getDownloadURL();
    }
  } catch (e) {
    print('Error picking/uploading image: $e');
    return null;
  }
}

Future<void> _openConversationSheet(
  BuildContext context,
  String spaceId,
  String podType,
) async {
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  String? selectedCategory;
  String? imageUrl;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => StatefulBuilder(
      builder: (context, setState) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Start a Conversation",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              CustomTextField(
                placeholder: "Conversation Title",
                controller: titleCtrl,
                leading: const Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 16),

              GestureDetector(
                onTap: () async {
                  final url = await _pickAndUploadImage();
                  if (url != null) {
                    setState(() => imageUrl = url);
                  }
                },
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.black.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: imageUrl == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate,
                              color: Colors.grey[400],
                              size: 40,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Tap to add conversation image",
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            children: [
                              Image.network(
                                imageUrl!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              CustomDropdown<String>(
                placeholder: "Select Category",
                value: selectedCategory,
                leading: const Icon(Icons.category, color: Colors.black54),
                items:
                    [
                      'General Discussion',
                      'Music Talk',
                      'Artist Spotlight',
                      'Event Planning',
                      'Collaboration',
                      'Feedback',
                      'Announcements',
                      'Questions',
                      'Ideas & Suggestions',
                    ].map((category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedCategory = value;
                  });
                },
              ),
              const SizedBox(height: 16),

              CustomMultilineTextField(
                placeholder:
                    "What would you like to discuss? Share your thoughts...",
                controller: descCtrl,
                minLines: 3,
                maxLines: 5,
                height: 120,
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  onPressed: () async {
                    if (titleCtrl.text.isEmpty) {
                      UtilsService().showSnackbar(
                        "Error",
                        "Please enter a conversation title", context: context,
                      );
                      return;
                    }

                    try {
                      await FirebaseFirestore.instance
                          .collection('spaces')
                          .doc(spaceId)
                          .collection('conversations')
                          .add({
                            "title": titleCtrl.text,
                            "image": imageUrl ?? "",
                            "description": descCtrl.text,
                            "category":
                                selectedCategory ?? "General Discussion",
                            "createdAt": FieldValue.serverTimestamp(),
                            "createdBy": FirebaseAuth.instance.currentUser?.uid,
                            "spaceId": spaceId,
                            "podType": podType,
                            "participants": [
                              FirebaseAuth.instance.currentUser?.uid,
                            ],
                            "isActive": true,
                          });

                      UtilsService().showSnackbar("Success", "Conversation started!", context: context);
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      UtilsService().showSnackbar(
                        "Error",
                        "Failed to create conversation: $e", context: context,
                      );
                    }
                  },
                  child: const Text(
                    "Start Conversation",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    ),
  );
}

Future<void> _openLiveSessionSheet(
  BuildContext context,
  String spaceId,
  String podType,
) async {
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  String? selectedCategory;
  String? imageUrl;
  DateTime? scheduledTime;
  bool isScheduled = false;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => StatefulBuilder(
      builder: (context, setState) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "New Live Session",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Schedule for later",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Switch(
                      value: isScheduled,
                      onChanged: (value) {
                        setState(() {
                          isScheduled = value;
                          if (!value) {
                            scheduledTime = null;
                          }
                        });
                      },
                      activeColor: Colors.teal,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (isScheduled) ...[
                GestureDetector(
                  onTap: () async {
                    final DateTime now = DateTime.now();
                    final DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: now.add(const Duration(days: 1)),
                      firstDate: now,
                      lastDate: DateTime(now.year + 1),
                      helpText: 'Select session date',
                      confirmText: 'SELECT',
                      cancelText: 'CANCEL',
                    );

                    if (pickedDate != null) {
                      final TimeOfDay? pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: 18, minute: 0),
                        helpText: 'Select session time',
                        confirmText: 'SELECT',
                        cancelText: 'CANCEL',
                      );

                      if (pickedTime != null) {
                        setState(() {
                          scheduledTime = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                        });
                      }
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: scheduledTime == null
                            ? Colors.grey[300]!
                            : Colors.teal,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Session Time",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              scheduledTime == null
                                  ? "Tap to select date & time"
                                  : _formatScheduledTime(scheduledTime!),
                              style: TextStyle(
                                color: scheduledTime == null
                                    ? Colors.grey[400]
                                    : Colors.black,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Icon(
                          Icons.calendar_today,
                          color: scheduledTime == null
                              ? Colors.grey[400]
                              : Colors.teal,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              CustomTextField(
                placeholder: "Session Title",
                controller: titleCtrl,
                leading: const Icon(Icons.live_tv, color: Colors.black54),
              ),
              const SizedBox(height: 16),

              GestureDetector(
                onTap: () async {
                  final url = await _pickAndUploadImage();
                  if (url != null) {
                    setState(() => imageUrl = url);
                  }
                },
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.black.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: imageUrl == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate,
                              color: Colors.grey[400],
                              size: 40,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Tap to add cover image",
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            children: [
                              Image.network(
                                imageUrl!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              CustomDropdown<String>(
                placeholder: "Select Category",
                value: selectedCategory,
                leading: const Icon(Icons.category, color: Colors.black54),
                items:
                    [
                      'Music Performance',
                      'Q&A Session',
                      'Workshop',
                      'Interview',
                      'Discussion',
                      'Concert',
                      'Podcast',
                    ].map((category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedCategory = value;
                  });
                },
              ),
              const SizedBox(height: 16),

              CustomMultilineTextField(
                placeholder: "What's this live session about?",
                controller: descCtrl,
                minLines: 3,
                maxLines: 5,
                height: 120,
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isScheduled ? Colors.orange : Colors.teal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  onPressed: () async {
                    if (titleCtrl.text.isEmpty) {
                      UtilsService().showSnackbar("Error", "Please enter a session title", context: context);
                      return;
                    }

                    if (isScheduled && scheduledTime == null) {
                      UtilsService().showSnackbar("Error", "Please select a scheduled time", context: context);
                      return;
                    }

                    try {
                      final sessionData = {
                        "title": titleCtrl.text,
                        "image": imageUrl ?? "",
                        "description": descCtrl.text,
                        "category": selectedCategory ?? "General",
                        "listeners": 0,
                        "isLive": !isScheduled,
                        "isScheduled": isScheduled,
                        "scheduledTime": scheduledTime,
                        "createdAt": FieldValue.serverTimestamp(),
                        "spaceId": spaceId,
                        "podType": podType,
                        "status": isScheduled ? "scheduled" : "live",
                        "time": isScheduled
                            ? _formatScheduledTime(scheduledTime!)
                            : "LIVE NOW",
                      };

                      await FirebaseFirestore.instance
                          .collection('spaces')
                          .doc(spaceId)
                          .collection('liveSessions')
                          .add(sessionData);

                      UtilsService().showSnackbar(
                        "Success",
                        isScheduled
                            ? "Live session scheduled!"
                            : "Live session created!", context: context,
                      );
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      UtilsService().showSnackbar(
                        "Error",
                        "Failed to create live session: $e", context: context,
                      );
                    }
                  },
                  child: Text(
                    isScheduled ? "Schedule Session" : "Go Live Now!",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    ),
  );
}

String _formatScheduledTime(DateTime scheduledTime) {
  final now = DateTime.now();
  final difference = scheduledTime.difference(now);

  if (difference.inDays > 0) {
    return 'In ${difference.inDays} day${difference.inDays > 1 ? 's' : ''} • ${DateFormat('MMM d, yyyy • h:mm a').format(scheduledTime)}';
  } else if (difference.inHours > 0) {
    return 'In ${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} • ${DateFormat('MMM d • h:mm a').format(scheduledTime)}';
  } else {
    return 'Starting soon • ${DateFormat('h:mm a').format(scheduledTime)}';
  }
}

Future<void> _openDjBoothSheet(
  BuildContext context,
  String spaceId,
  String podType,
) async {
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final organizerCtrl = TextEditingController();
  String? selectedGenre;
  String? imageUrl;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => StatefulBuilder(
      builder: (context, setState) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "DJ Booth Event",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              CustomTextField(
                placeholder: "Event Title",
                controller: titleCtrl,
                leading: const Icon(Icons.music_note, color: Colors.black54),
              ),
              const SizedBox(height: 16),

              CustomTextField(
                placeholder: "DJ Name / Organizer",
                controller: organizerCtrl,
                leading: const Icon(Icons.person, color: Colors.black54),
              ),
              const SizedBox(height: 16),

              CustomDropdown<String>(
                placeholder: "Select Music Genre",
                value: selectedGenre,
                leading: const Icon(Icons.library_music, color: Colors.black54),
                items:
                    [
                      'Hip Hop',
                      'Electronic',
                      'House',
                      'Techno',
                      'R&B',
                      'Afrobeats',
                      'Reggae',
                      'Pop',
                      'Rock',
                      'Jazz',
                      'Mixed',
                    ].map((genre) {
                      return DropdownMenuItem<String>(
                        value: genre,
                        child: Text(genre),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedGenre = value;
                  });
                },
              ),
              const SizedBox(height: 16),

              GestureDetector(
                onTap: () async {
                  final url = await _pickAndUploadImage();
                  if (url != null) {
                    setState(() => imageUrl = url);
                  }
                },
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.black.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: imageUrl == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate,
                              color: Colors.grey[400],
                              size: 40,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Tap to add event poster",
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            children: [
                              Image.network(
                                imageUrl!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              CustomMultilineTextField(
                placeholder:
                    "Describe the DJ set, special guests, or event details...",
                controller: descCtrl,
                minLines: 3,
                maxLines: 5,
                height: 120,
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  onPressed: () async {
                    if (titleCtrl.text.isEmpty) {
                      UtilsService().showSnackbar("Error", "Please enter an event title", context: context);
                      return;
                    }
                    if (organizerCtrl.text.isEmpty) {
                      UtilsService().showSnackbar("Error", "Please enter a DJ/organizer name", context: context);
                      return;
                    }

                    try {
                      await FirebaseFirestore.instance
                          .collection('spaces')
                          .doc(spaceId)
                          .collection('djBooth')
                          .add({
                            "title": titleCtrl.text,
                            "organizer": organizerCtrl.text,
                            "genre": selectedGenre ?? "Mixed",
                            "image": imageUrl ?? "",
                            "description": descCtrl.text,
                            "spaceId": spaceId,
                            "attendees": 0,
                            "podType": podType,
                            "isLive": false,
                            "createdAt": FieldValue.serverTimestamp(),
                          });

                      UtilsService().showSnackbar("Success", "DJ Booth event created!", context: context);
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      UtilsService().showSnackbar("Error", "Failed to create DJ event: $e", context: context);
                    }
                  },
                  child: const Text(
                    "Create DJ Event",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    ),
  );
}

class ConversationsCard extends StatefulWidget {
  final String spaceId;
  final String podType;
  final bool isAdmin;
  
  const ConversationsCard({
    super.key,
    required this.spaceId,
    required this.podType,
    required this.isAdmin,
  });

  @override
  _ConversationsCardState createState() => _ConversationsCardState();
}

class _ConversationsCardState extends State<ConversationsCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _shimmerController;
  late Timer _shimmerTimer;
  bool _isShimmering = false;

  final List<String> _carouselImages = [
    "https://images.unsplash.com/photo-1511379938547-c1f69419868d?w=400", 
    "https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=400", 
    "https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=400", 
    "https://images.unsplash.com/photo-1494232410401-ad00d5433cfa?w=400", 
  ];
  int _currentImageIndex = 0;
  late Timer _carouselTimer;

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _shimmerTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _triggerShimmer();
    });

    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      setState(() {
        _currentImageIndex = (_currentImageIndex + 1) % _carouselImages.length;
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _triggerShimmer());
  }

  void _triggerShimmer() {
    setState(() {
      _isShimmering = true;
    });
    _shimmerController.forward().then((_) {
      _shimmerController.reset();
      Future.delayed(const Duration(milliseconds: 200), () {
        _shimmerController.forward().then((_) {
          setState(() {
            _isShimmering = false;
          });
        });
      });
    });
  }

  bool _hasUserJoined(List<dynamic> participants) {
    return participants.contains(_currentUserId);
  }

  bool _isUserCreator(String createdBy) {
    return createdBy == _currentUserId;
  }

  Future<void> _joinConversation(
    String conversationId,
    List<dynamic> participants,
  ) async {
    try {
      if (!_hasUserJoined(participants)) {
        await FirebaseFirestore.instance
            .collection('spaces')
            .doc(widget.spaceId)
            .collection('conversations')
            .doc(conversationId)
            .update({
              'participants': FieldValue.arrayUnion([_currentUserId]),
              'participantCount': FieldValue.increment(1),
              'updatedAt': FieldValue.serverTimestamp(),
            });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Joined conversation!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join conversation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToConversation(
    String conversationId,
    String createdBy,
    List<dynamic> participants,
  ) async {
    if (!_hasUserJoined(participants) && !_isUserCreator(createdBy)) {
      await _joinConversation(conversationId, participants);
    }

    final conversationController = Get.put(
      ConversationController(),
      permanent: false,
    );
    final spaceConvController = Get.put(
      SpaceConversationController(),
      permanent: false,
    );

    final conversationDoc = await FirebaseFirestore.instance
        .collection('spaces')
        .doc(widget.spaceId)
        .collection('conversations')
        .doc(conversationId)
        .get();

    if (conversationDoc.exists) {
      final conversationData = conversationDoc.data() as Map<String, dynamic>;
      final conversation = SpaceConversation.fromMap(
        conversationData,
        conversationId,
      );

      Get.to(
        () => SpaceConversationChatPage(
          spaceId: widget.spaceId,
          conversation: conversation,
        ),
      );
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _shimmerTimer.cancel();
    _carouselTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('spaces')
          .doc(widget.spaceId)
          .collection('conversations')
          .where('podType', isEqualTo: widget.podType)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNoConversationsCarousel();
        }

        final doc = snapshot.data!.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        final conversationId = doc.id;
        final participants = List<dynamic>.from(data['participants'] ?? []);
        final createdBy = data['createdBy'] ?? '';

        final hasJoined = _hasUserJoined(participants);
        final isCreator = _isUserCreator(createdBy);
        final buttonText = hasJoined || isCreator
            ? "Say something.."
            : "Join conversation";

        return Container(
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                height: _isExpanded ? 200 : 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white.withOpacity(0.3),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 10, right: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 3,
                              vertical: 3,
                            ),
                            margin: const EdgeInsets.only(bottom: 10.0),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Text(
                              "Active",
                              style: TextStyle(
                                fontSize: 7,
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            data['title'] ?? "Untitled",
                            style: TextStyle(
                              color: Theme.of(context).primaryColorLight,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            data['category'] ?? "Uncategorized",
                            style: TextStyle(
                              color: Theme.of(context).primaryColorLight,
                              fontSize: 9,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isExpanded = !_isExpanded;
                                  });
                                },
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'tap for more',
                                      style: TextStyle(
                                        fontSize: 8,
                                        color: Colors.black.withOpacity(0.8),
                                      ),
                                    ),
                                    Icon(
                                      _isExpanded
                                          ? Icons.keyboard_arrow_up
                                          : Icons.keyboard_arrow_down,
                                      color: Colors.black.withOpacity(0.8),
                                      size: 10,
                                    ),
                                  ],
                                ),
                              ),
                              if (_isExpanded)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['description'] ??
                                            'No description provided',
                                        maxLines: 2,
                                        style: TextStyle(
                                          fontSize: 8,
                                          color: Colors.black.withOpacity(0.6),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      GestureDetector(
                                        onTap: () => _navigateToConversation(
                                          conversationId,
                                          createdBy,
                                          participants,
                                        ),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: hasJoined || isCreator
                                                ? Colors.black
                                                : Colors.blue[700],
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 2,
                                            horizontal: 5,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                buttonText,
                                                style: GoogleFonts.montserrat(
                                                  fontSize: 11,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              if (!hasJoined && !isCreator)
                                                Icon(
                                                  Icons.group_add,
                                                  size: 12,
                                                  color: Colors.white,
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (_isExpanded)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: Text(
                                            '${participants.length} participants',
                                            style: TextStyle(
                                              fontSize: 8,
                                              color: Colors.black.withOpacity(
                                                0.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: () => _navigateToConversation(
                          conversationId,
                          createdBy,
                          participants,
                        ),
                        child: Container(
                          width: _isExpanded ? 140 : 90,
                          height: _isExpanded ? 160 : 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                spreadRadius: 5,
                                offset: const Offset(10, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child:
                                data['image'] != null &&
                                    data['image'].isNotEmpty
                                ? Image.network(
                                    data['image'],
                                    fit: BoxFit.cover,
                                  )
                                : Image.asset(
                                    "asset/images/mango-13.jpg",
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
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

  Widget _buildNoConversationsCarousel() {
    return Container(
      width: double.infinity,
      height: 150,
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 3,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 800),
            child: Container(
              key: ValueKey(_currentImageIndex),
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                image: DecorationImage(
                  image: NetworkImage(_carouselImages[_currentImageIndex]),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.8),
                  Colors.black,
                ],
                stops: const [0.0, 0.3, 0.5, 0.65, 0.8, 0.9, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: MediaQuery.of(context).size.height * 0.65 * 0.35,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isAdmin ? "Start the Conversation" : "No Conversations Yet",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.8),
                        blurRadius: 10,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isAdmin
                      ? "Be the first to share your thoughts and ideas in this space. Tap the conversation button above to get started!"
                      : "No conversations have been started yet. Check back later!",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 8,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_carouselImages.length, (index) {
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentImageIndex == index
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 3,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class LiveSessionsCard extends StatefulWidget {
  final String podType;
  final String spaceId;
  final bool isAdmin;
  
  const LiveSessionsCard({
    super.key,
    required this.spaceId,
    required this.podType,
    required this.isAdmin,
  });

  @override
  _LiveSessionsCardState createState() => _LiveSessionsCardState();
}

class _LiveSessionsCardState extends State<LiveSessionsCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _shimmerController;
  late Timer _shimmerTimer;
  bool _isShimmering = false;

  final List<String> _carouselImages = [
    "https://images.unsplash.com/photo-1516280440614-37939bbacd81?w=400",
    "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=400",
    "https://images.unsplash.com/photo-1501281668745-f7f57925c3b4?w=400",
    "https://images.unsplash.com/photo-1571266028243-43cfef0da8e7?w=400",
  ];
  int _currentImageIndex = 0;
  late Timer _carouselTimer;

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _shimmerTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _triggerShimmer();
    });

    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      setState(() {
        _currentImageIndex = (_currentImageIndex + 1) % _carouselImages.length;
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _triggerShimmer());
  }

  void _triggerShimmer() {
    setState(() {
      _isShimmering = true;
    });
    _shimmerController.forward().then((_) {
      _shimmerController.reset();
      Future.delayed(const Duration(milliseconds: 200), () {
        _shimmerController.forward().then((_) {
          setState(() {
            _isShimmering = false;
          });
        });
      });
    });
  }

  void _navigateToLiveSession(Map<String, dynamic> sessionData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveSessionScreen(
          sessionId:
              sessionData['id']?.toString() ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          sessionData: sessionData,
          spaceId: widget.spaceId,
        ),
      ),
    );
  }

  void _setReminder(Map<String, dynamic> sessionData) async {
    final scheduledTime = sessionData['scheduledTime']?.toDate();
    if (scheduledTime != null) {
      final timeUntilSession = scheduledTime.difference(DateTime.now());

      if (timeUntilSession.inDays > 0) {
        _scheduleReminderNotification(
          'Live Session Reminder',
          '${sessionData['title']} starts in 1 day!',
          scheduledTime.subtract(const Duration(days: 1)),
        );
      }

      if (timeUntilSession.inHours > 1) {
        _scheduleReminderNotification(
          'Live Session Starting Soon',
          '${sessionData['title']} starts in 1 hour!',
          scheduledTime.subtract(const Duration(hours: 1)),
        );
      }

      _scheduleReminderNotification(
        'Live Session Starting',
        '${sessionData['title']} starts in 15 minutes!',
        scheduledTime.subtract(const Duration(minutes: 15)),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminders set for this session')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This session is live now!')),
      );
      _navigateToLiveSession(sessionData);
    }
  }

  void _scheduleReminderNotification(
    String title,
    String body,
    DateTime scheduleTime,
  ) {
    // Implement notification scheduling
    print('Scheduled reminder: $title at $scheduleTime');
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _shimmerTimer.cancel();
    _carouselTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('spaces')
          .doc(widget.spaceId)
          .collection('liveSessions')
          .where('podType', isEqualTo: widget.podType)
          .orderBy('scheduledTime', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNoLiveSessionsCarousel();
        }

        final sessions = snapshot.data!.docs;
        final currentSession = sessions.first.data() as Map<String, dynamic>;

        return Container(
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                height: _isExpanded ? 200 : 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white.withOpacity(0.3),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 10, right: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 3,
                              vertical: 3,
                            ),
                            margin: const EdgeInsets.only(bottom: 10.0),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              _getSessionTimeText(currentSession),
                              style: const TextStyle(
                                fontSize: 7,
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            currentSession['title'] ?? "Untitled Session",
                            style: TextStyle(
                              color: Theme.of(context).primaryColorLight,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                "${currentSession['listeners'] ?? 0} listeners.",
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(currentSession),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _getStatusText(currentSession),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isExpanded = !_isExpanded;
                                  });
                                },
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'tap for more',
                                      style: TextStyle(
                                        fontSize: 8,
                                        color: Colors.black.withOpacity(0.8),
                                      ),
                                    ),
                                    Icon(
                                      _isExpanded
                                          ? Icons.keyboard_arrow_up
                                          : Icons.keyboard_arrow_down,
                                      color: Colors.black.withOpacity(0.8),
                                      size: 10,
                                    ),
                                  ],
                                ),
                              ),
                              if (_isExpanded)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        currentSession['description'] ??
                                            'No description provided',
                                        maxLines: 2,
                                        style: TextStyle(
                                          fontSize: 8,
                                          color: Colors.black.withOpacity(0.6),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          GestureDetector(
                                            onTap: () => _navigateToLiveSession(
                                              currentSession,
                                            ),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.black,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 2,
                                                    horizontal: 5,
                                                  ),
                                              child: const Text(
                                                "join now",
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (currentSession['isScheduled'] ==
                                              true)
                                            GestureDetector(
                                              onTap: () =>
                                                  _setReminder(currentSession),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.blue,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 2,
                                                      horizontal: 5,
                                                    ),
                                                child: const Text(
                                                  "set reminder",
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Stack(
                        alignment: Alignment.centerRight,
                        children: [
                          Container(
                            width: _isExpanded ? 140 : 100,
                            height: _isExpanded ? 140 : 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                  offset: const Offset(10, 10),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: currentSession['image'] != null
                                  ? Image.network(
                                      currentSession['image'],
                                      fit: BoxFit.cover,
                                    )
                                  : Image.asset(
                                      "asset/images/mango-13.jpg",
                                      fit: BoxFit.cover,
                                    ),
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

  String _getSessionTimeText(Map<String, dynamic> session) {
    if (session['isLive'] == true) {
      return "LIVE NOW";
    } else if (session['scheduledTime'] != null) {
      final scheduledTime = session['scheduledTime'].toDate();
      final now = DateTime.now();
      final difference = scheduledTime.difference(now);

      if (difference.inDays > 0) {
        return 'In ${difference.inDays} day${difference.inDays > 1 ? 's' : ''}';
      } else if (difference.inHours > 0) {
        return 'In ${difference.inHours} hour${difference.inHours > 1 ? 's' : ''}';
      } else {
        return 'Starting soon';
      }
    }
    return "00:00";
  }

  String _getStatusText(Map<String, dynamic> session) {
    if (session['isLive'] == true) return "LIVE";
    if (session['isScheduled'] == true) return "SCHEDULED";
    return "ENDED";
  }

  Color _getStatusColor(Map<String, dynamic> session) {
    if (session['isLive'] == true) return Colors.red;
    if (session['isScheduled'] == true) return Colors.orange;
    return Colors.grey;
  }

  Widget _buildNoLiveSessionsCarousel() {
    return Container(
      width: double.infinity,
      height: 150,
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 3,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 800),
            child: Container(
              key: ValueKey(_currentImageIndex),
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                image: DecorationImage(
                  image: NetworkImage(_carouselImages[_currentImageIndex]),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.8),
                  Colors.black,
                ],
                stops: const [0.0, 0.3, 0.5, 0.65, 0.8, 0.9, 1.0],
              ),
            ),
          ),
          Positioned(
            top: 15,
            right: 15,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "LIVE",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: MediaQuery.of(context).size.height * 0.65 * 0.35,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isAdmin ? "Go Live Now" : "No Live Sessions",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.8),
                        blurRadius: 10,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isAdmin
                      ? "Start a live session and connect with your audience in real-time. Share music, stories, or just hang out!"
                      : "No live sessions are currently scheduled. Check back later!",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 8,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_carouselImages.length, (index) {
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentImageIndex == index
                        ? Colors.red
                        : Colors.white.withOpacity(0.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 3,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class DjBoothList extends StatelessWidget {
  final String spaceId;
  final bool isAdmin;
  
  const DjBoothList({
    super.key,
    required this.spaceId,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('spaces')
          .doc(spaceId)
          .collection('djBooth')
          .orderBy("createdAt", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildNoDjBoothCarousel();

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return _buildNoDjBoothCarousel();
        }

        return Column(
          children: docs.map((data) {
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 25.0,
                vertical: 10,
              ),
              child: Container(
                height: 80,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(38.5),
                  boxShadow: [
                    BoxShadow(
                      offset: const Offset(0, 10),
                      blurRadius: 33,
                      color: Theme.of(context).splashColor.withOpacity(.24),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(38.5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 30, right: 20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data["title"],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                data["organizer"],
                                style: TextStyle(
                                  color: Theme.of(context).primaryColorLight,
                                ),
                              ),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Text(
                                  "New Event",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context).primaryColorLight,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Image.network(
                        data["image"],
                        width: 55,
                        fit: BoxFit.cover,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildNoDjBoothCarousel() {
    return _DjBoothCarousel(isAdmin: isAdmin);
  }
}

class _DjBoothCarousel extends StatefulWidget {
  final bool isAdmin;
  
  const _DjBoothCarousel({required this.isAdmin});
  
  @override
  State<_DjBoothCarousel> createState() => _DjBoothCarouselState();
}

class _DjBoothCarouselState extends State<_DjBoothCarousel> {
  final List<String> _carouselImages = [
    "https://images.unsplash.com/photo-1571330735066-03aaa9429d89?w=400", 
    "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=400", 
    "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=400", 
    "https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=400", 
  ];
  int _currentImageIndex = 0;
  late Timer _carouselTimer;

  @override
  void initState() {
    super.initState();
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      setState(() {
        _currentImageIndex = (_currentImageIndex + 1) % _carouselImages.length;
      });
    });
  }

  @override
  void dispose() {
    _carouselTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 150,
      margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 3,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 800),
            child: Container(
              key: ValueKey(_currentImageIndex),
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                image: DecorationImage(
                  image: NetworkImage(_carouselImages[_currentImageIndex]),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.8),
                  Colors.black,
                ],
                stops: const [0.0, 0.3, 0.5, 0.65, 0.8, 0.9, 1.0],
              ),
            ),
          ),
          Positioned(
            top: 15,
            right: 15,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.headset, color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    "DJ",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: MediaQuery.of(context).size.height * 0.65 * 0.35,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isAdmin ? "Spin the Decks" : "No DJ Events",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.8),
                        blurRadius: 10,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isAdmin
                      ? "Create a DJ booth event and showcase your mixing skills. Curate playlists and host virtual parties!"
                      : "No DJ events have been scheduled yet. Check back later!",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 8,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_carouselImages.length, (index) {
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentImageIndex == index
                        ? Colors.orange
                        : Colors.white.withOpacity(0.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 3,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}