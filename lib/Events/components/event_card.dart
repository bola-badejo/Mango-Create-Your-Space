import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mango/Models/customModel/user.dart';
import '../../Spaces/controllers/space_model.dart';
import '../../Spaces/screens/space_detail.dart';

class SpacesPortrait extends StatelessWidget {
  final SpaceModel space;

  const SpacesPortrait({super.key, required this.space});

  @override
  Widget build(BuildContext context) {
    final allCollaboratorIds = [space.postCreator, ...space.collaborators];

    final collaboratorsStream = FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: allCollaboratorIds.isNotEmpty ? allCollaboratorIds : [''])
        .snapshots();

    return GestureDetector(
      onTap: () {
        Get.to(() => SpaceDetailScreen(space), arguments: {'id': space.id});
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        child: SizedBox(
          width: 250,
          height: 400,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              image: DecorationImage(
                image: _getBackgroundImage(),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.4),
                  BlendMode.darken,
                ),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Space Icon - Larger Circle Avatar
                Positioned(
                  left: 16,
                  top: 16,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: _buildIconImage(),
                    ),
                  ),
                ),

                // Paid/Free Tag
                Positioned(
                  right: 16,
                  top: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: space.isPrivate ? Colors.orange : Colors.green,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 8,
                    ),
                    child: Text(
                      space.isPrivate ? "Paid" : "Free",
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                // Participants + Title + Description
                Positioned(
                  left: 16,
                  bottom: 16,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Participants avatars
                      StreamBuilder<QuerySnapshot>(
                        stream: collaboratorsStream,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const SizedBox(
                              height: 30,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          }
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return const SizedBox();
                          }

                          final users = snapshot.data!.docs
                              .map((doc) => MangoUser.fromDocument(doc))
                              .toList();

                          users.sort((a, b) => a.id == space.postCreator ? -1 : 1);

                          // Show up to 5 collaborators
                          final displayUsers = users.take(5).toList();

                          return SizedBox(
                            height: 32,
                            child: Stack(
                              children: displayUsers.asMap().entries.map((entry) {
                                final index = entry.key;
                                final user = entry.value;

                                return Positioned(
                                  left: index * 20.0,
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: Image.network(
                                        user.profileImage,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return Container(
                                            color: Colors.grey[800],
                                            child: const Center(
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            ),
                                          );
                                        },
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            color: Colors.grey[700],
                                            child: const Icon(
                                              Icons.person,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 8),
                      
                      // Space title
                      Text(
                        space.title,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(1, 1),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // Space description
                      Text(
                        space.description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(1, 1),
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Space stats row
                      Row(
                        children: [
                          Icon(Icons.people, size: 12, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text(
                            '${space.members} members',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.category, size: 12, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text(
                            space.category,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white70,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ImageProvider _getBackgroundImage() {
    if (space.spaceBackground != null && space.spaceBackground!.isNotEmpty) {
      return NetworkImage(space.spaceBackground!);
    }
    return const AssetImage('asset/images/mango-14.jpg');
  }

  Widget _buildIconImage() {
    if (space.iconUrl.isNotEmpty) {
      return Image.network(
        space.iconUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey[800],
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[700],
            child: const Icon(
              Icons.space_dashboard,
              color: Colors.white,
              size: 28,
            ),
          );
        },
      );
    }
    return Container(
      color: Colors.grey[700],
      child: const Icon(
        Icons.space_dashboard,
        color: Colors.white,
        size: 28,
      ),
    );
  }
}