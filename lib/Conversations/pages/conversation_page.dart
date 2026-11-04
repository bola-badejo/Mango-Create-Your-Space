import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:mango/Conversations/controllers/conversation_controller.dart';
import 'package:mango/Conversations/pages/chat_page.dart';
import 'package:mango/Models/customModel/chat.dart';
import 'package:mango/Models/customModel/user.dart';
import 'package:mango/Spaces/controllers/friends.dart';
import 'package:mango/Utils/theme.dart';
import 'package:mango/Utils/optimized_lists.dart';

class ConversationPage extends StatefulWidget {
  @override
  _ConversationPageState createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final ConversationController _controller = Get.put(ConversationController());
  final FriendsController _friendsController = Get.put(FriendsController());
  final ThemeController _themeController = Get.find<ThemeController>();
  final TextEditingController _searchController = TextEditingController();

  
  final TextEditingController _allUsersSearchController = TextEditingController();
  List<MangoUser> _allUsers = [];
  List<MangoUser> _filteredAllUsers = [];
  bool _isLoadingAllUsers = false;
  
  
  List<MangoUser> _searchResults = [];
  final ScrollController _mainScrollController = ScrollController();
  
  
  DocumentSnapshot? _lastUsernameDoc;
  DocumentSnapshot? _lastDisplayNameDoc;
  bool _hasMoreUsers = true;
  String _lastSearchQuery = '';
  Timer? _debounceTimer;
  bool _isLoadingMore = false;
  final Set<String> _seenUserIds = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _allUsersSearchController.addListener(_onAllUsersSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _searchResults.clear();
      });
    } else {
      setState(() {
        _searchResults = _friendsController.friends.where((friend) {
          return friend.username.toLowerCase().contains(query) ||
              friend.displayName.toLowerCase().contains(query);
        }).toList();
      });
    }
  }

  void _onAllUsersSearchChanged() {
    final query = _allUsersSearchController.text.trim();
    
    
    if (query.isEmpty) {
      setState(() {
        _filteredAllUsers = List.from(_allUsers);
        _isLoadingAllUsers = false;
      });
      return;
    }
    
    
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (_allUsersSearchController.text.isNotEmpty) {
        _searchAllUsers(query);
      }
    });
  }

  void _selectFriend(MangoUser friend) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => ConversationChatPage(
              controller: _controller,
              selectedFriend: friend,
            ),
          ),
        )
        .then((_) {
          _searchController.clear();
          _searchResults.clear();
        });
  }

  Future<void> _showAllUsersDialog(BuildContext context) async {
    final isDarkMode = _themeController.isDarkMode.value;
    final primaryColor = _themeController.primaryColorValue;

    
    _allUsersSearchController.clear();
    _allUsers.clear();
    _filteredAllUsers.clear();
    _lastUsernameDoc = null;
    _lastDisplayNameDoc = null;
    _hasMoreUsers = true;
    _lastSearchQuery = '';
    _seenUserIds.clear();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              insetPadding: const EdgeInsets.all(20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                  maxWidth: 500,
                ),
                child: Column(
                  children: [
                    
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          const SizedBox(width: 40), 
                          Expanded(
                            child: Text(
                              'Find People',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),

                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _allUsersSearchController,
                          autofocus: true,
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search by username or name...',
                            hintStyle: TextStyle(
                              color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 15,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    
                    Expanded(
                      child: _isLoadingAllUsers && _filteredAllUsers.isEmpty
                          ? Center(
                              child: CircularProgressIndicator(
                                color: primaryColor,
                              ),
                            )
                          : _filteredAllUsers.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.group_off,
                                        size: 60,
                                        color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _allUsersSearchController.text.isEmpty
                                            ? 'Start typing to search users'
                                            : 'No results found',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                        ),
                                      ),
                                      if (_allUsersSearchController.text.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text(
                                            'Try a different search term',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDarkMode ? Colors.grey[500] : Colors.grey[700],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                )
                              : Column(
                                  children: [
                                    Expanded(
                                      child: OptimizedListView(
                                        padding: const EdgeInsets.only(bottom: 20),
                                        itemCount: _filteredAllUsers.length + (_hasMoreUsers && !_isLoadingMore ? 1 : 0),
                                        itemBuilder: (context, index) {
                                          if (index < _filteredAllUsers.length) {
                                            final user = _filteredAllUsers[index];
                                            final isFriend = _friendsController.friends.any(
                                              (friend) => friend.id == user.id,
                                            );

                                            return _buildAllUserListItem(
                                              user,
                                              isFriend,
                                              isDarkMode,
                                              primaryColor,
                                              setState,
                                            );
                                          } else {
                                            
                                            return _buildLoadMoreButton(isDarkMode, primaryColor, setState);
                                          }
                                        },
                                      ),
                                    ),
                                    if (_isLoadingMore)
                                      Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: CircularProgressIndicator(color: primaryColor),
                                      ),
                                  ],
                                ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    
    _allUsersSearchController.clear();
    _allUsers.clear();
    _filteredAllUsers.clear();
  }

  Future<void> _searchAllUsers(String query) async {
    final queryLower = query.trim().toLowerCase();
    
    
    if (queryLower != _lastSearchQuery) {
      _lastUsernameDoc = null;
      _lastDisplayNameDoc = null;
      _hasMoreUsers = true;
      _seenUserIds.clear();
      _allUsers.clear();
    }
    
    _lastSearchQuery = queryLower;
    
    
    if (queryLower.isEmpty) {
      setState(() {
        _allUsers = [];
        _filteredAllUsers = [];
        _isLoadingAllUsers = false;
      });
      return;
    }
    
    setState(() {
      _isLoadingAllUsers = true;
      _isLoadingMore = false;
    });
    
    try {
      final searchResults = await _performFirestoreSearch(queryLower);
      
      
      searchResults.sort((a, b) => _calculateRelevanceScore(a, b, queryLower));
      
      setState(() {
        _allUsers = searchResults;
        _filteredAllUsers = searchResults;
        _isLoadingAllUsers = false;
        _isLoadingMore = false;
      });
      
    } catch (e) {
      print('Error searching users: $e');
      setState(() {
        _isLoadingAllUsers = false;
        _isLoadingMore = false;
      });
      
      
      await _fallbackSearch(queryLower);
    }
  }

  Future<List<MangoUser>> _performFirestoreSearch(String queryLower) async {
    final usersRef = FirebaseFirestore.instance.collection('users');
    final currentUserId = _controller.authentication.currentUser?.uid;
    final List<MangoUser> searchResults = [];
    
    
    final exactUsernameSnapshot = await usersRef
        .where('username', isEqualTo: queryLower)
        .limit(5)
        .get();
    
    for (final doc in exactUsernameSnapshot.docs) {
      final user = _documentToUser(doc);
      if (user != null && user.id != currentUserId && !_seenUserIds.contains(user.id)) {
        searchResults.add(user);
        _seenUserIds.add(user.id);
      }
    }
    
    
    
    Query usernameQuery = usersRef
        .where('username', isGreaterThanOrEqualTo: queryLower)
        .where('username', isLessThan: queryLower + '\uf8ff')
        .orderBy('username')
        .limit(15);
    
    if (_lastUsernameDoc != null && queryLower == _lastSearchQuery) {
      usernameQuery = usernameQuery.startAfterDocument(_lastUsernameDoc!);
    }
    
    final usernameSnapshot = await usernameQuery.get();
    
    
    if (usernameSnapshot.docs.isNotEmpty) {
      _lastUsernameDoc = usernameSnapshot.docs.last;
    }
    
    for (final doc in usernameSnapshot.docs) {
      final user = _documentToUser(doc);
      if (user != null && user.id != currentUserId && !_seenUserIds.contains(user.id)) {
        searchResults.add(user);
        _seenUserIds.add(user.id);
      }
    }
    
    
    Query displayNameQuery = usersRef
        .where('displayName', isGreaterThanOrEqualTo: queryLower)
        .where('displayName', isLessThan: queryLower + '\uf8ff')
        .orderBy('displayName')
        .limit(15);
    
    if (_lastDisplayNameDoc != null && queryLower == _lastSearchQuery) {
      displayNameQuery = displayNameQuery.startAfterDocument(_lastDisplayNameDoc!);
    }
    
    final displayNameSnapshot = await displayNameQuery.get();
    
    if (displayNameSnapshot.docs.isNotEmpty) {
      _lastDisplayNameDoc = displayNameSnapshot.docs.last;
    }
    
    for (final doc in displayNameSnapshot.docs) {
      final user = _documentToUser(doc);
      if (user != null && user.id != currentUserId && !_seenUserIds.contains(user.id)) {
        searchResults.add(user);
        _seenUserIds.add(user.id);
      }
    }
    
    
    if (queryLower.length >= 3 && searchResults.length < 30) {
      await _performBroadSearch(queryLower, searchResults, currentUserId);
    }
    
    
    _hasMoreUsers = (usernameSnapshot.docs.length == 15 || displayNameSnapshot.docs.length == 15);
    
    return searchResults;
  }

  Future<void> _performBroadSearch(
    String queryLower,
    List<MangoUser> searchResults,
    String? currentUserId,
  ) async {
    final usersRef = FirebaseFirestore.instance.collection('users');
    
    
    final List<String> searchPrefixes = [];
    for (int i = 1; i <= queryLower.length; i++) {
      searchPrefixes.add(queryLower.substring(0, i));
    }
    
    
    for (final prefix in searchPrefixes) {
      if (searchResults.length >= 40) break; 
      
      final usernameSnapshot = await usersRef
          .where('username', isGreaterThanOrEqualTo: prefix)
          .where('username', isLessThan: prefix + '\uf8ff')
          .orderBy('username')
          .limit(10)
          .get();
      
      for (final doc in usernameSnapshot.docs) {
        final user = _documentToUser(doc);
        if (user != null && 
            user.id != currentUserId && 
            !_seenUserIds.contains(user.id)) {
          
          
          if (user.username.toLowerCase().contains(queryLower) ||
              user.displayName.toLowerCase().contains(queryLower)) {
            searchResults.add(user);
            _seenUserIds.add(user.id);
          }
        }
      }
    }
    
    
    for (final prefix in searchPrefixes) {
      if (searchResults.length >= 50) break;
      
      final displayNameSnapshot = await usersRef
          .where('displayName', isGreaterThanOrEqualTo: prefix)
          .where('displayName', isLessThan: prefix + '\uf8ff')
          .orderBy('displayName')
          .limit(10)
          .get();
      
      for (final doc in displayNameSnapshot.docs) {
        final user = _documentToUser(doc);
        if (user != null && 
            user.id != currentUserId && 
            !_seenUserIds.contains(user.id)) {
          
          if (user.username.toLowerCase().contains(queryLower) ||
              user.displayName.toLowerCase().contains(queryLower)) {
            searchResults.add(user);
            _seenUserIds.add(user.id);
          }
        }
      }
    }
  }

  Future<void> _loadMoreUsers() async {
    if (!_hasMoreUsers || _isLoadingMore || _lastSearchQuery.isEmpty) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    try {
      final additionalResults = await _performFirestoreSearch(_lastSearchQuery);
      
      
      additionalResults.sort((a, b) => _calculateRelevanceScore(a, b, _lastSearchQuery));
      
      setState(() {
        _allUsers.addAll(additionalResults);
        _filteredAllUsers = List.from(_allUsers);
        _isLoadingMore = false;
      });
      
    } catch (e) {
      print('Error loading more users: $e');
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  MangoUser? _documentToUser(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return null;
      
      return MangoUser.fromDocument(doc);
    } catch (e) {
      print('Error converting document to user: $e');
      return null;
    }
  }

  int _calculateRelevanceScore(MangoUser a, MangoUser b, String queryLower) {
    final aUsername = a.username.toLowerCase();
    final bUsername = b.username.toLowerCase();
    final aDisplayName = a.displayName.toLowerCase();
    final bDisplayName = b.displayName.toLowerCase();
    
    
    final aIsExactUsername = aUsername == queryLower;
    final bIsExactUsername = bUsername == queryLower;
    final aIsExactDisplayName = aDisplayName == queryLower;
    final bIsExactDisplayName = bDisplayName == queryLower;
    
    if (aIsExactUsername || aIsExactDisplayName) {
      if (!(bIsExactUsername || bIsExactDisplayName)) return -1;
    }
    if (bIsExactUsername || bIsExactDisplayName) {
      if (!(aIsExactUsername || aIsExactDisplayName)) return 1;
    }
    
    
    final aUsernameContains = aUsername.contains(queryLower);
    final bUsernameContains = bUsername.contains(queryLower);
    final aDisplayNameContains = aDisplayName.contains(queryLower);
    final bDisplayNameContains = bDisplayName.contains(queryLower);
    
    if (aUsernameContains && !bUsernameContains) return -1;
    if (!aUsernameContains && bUsernameContains) return 1;
    
    
    final aUsernameStartsWith = aUsername.startsWith(queryLower);
    final bUsernameStartsWith = bUsername.startsWith(queryLower);
    final aDisplayNameStartsWith = aDisplayName.startsWith(queryLower);
    final bDisplayNameStartsWith = bDisplayName.startsWith(queryLower);
    
    if (aUsernameStartsWith && !bUsernameStartsWith) return -1;
    if (!aUsernameStartsWith && bUsernameStartsWith) return 1;
    if (aDisplayNameStartsWith && !bDisplayNameStartsWith) return -1;
    if (!aDisplayNameStartsWith && bDisplayNameStartsWith) return 1;
    
    
    final aUsernameIndex = aUsername.indexOf(queryLower);
    final bUsernameIndex = bUsername.indexOf(queryLower);
    final aDisplayNameIndex = aDisplayName.indexOf(queryLower);
    final bDisplayNameIndex = bDisplayName.indexOf(queryLower);
    
    final aBestIndex = aUsernameIndex != -1 
        ? (aDisplayNameIndex != -1 ? (aUsernameIndex < aDisplayNameIndex ? aUsernameIndex : aDisplayNameIndex) : aUsernameIndex)
        : aDisplayNameIndex;
    
    final bBestIndex = bUsernameIndex != -1
        ? (bDisplayNameIndex != -1 ? (bUsernameIndex < bDisplayNameIndex ? bUsernameIndex : bDisplayNameIndex) : bUsernameIndex)
        : bDisplayNameIndex;
    
    if (aBestIndex != bBestIndex) {
      if (aBestIndex == -1) return 1;
      if (bBestIndex == -1) return -1;
      return aBestIndex.compareTo(bBestIndex);
    }
    
    
    return aUsername.compareTo(bUsername);
  }

  Future<void> _fallbackSearch(String queryLower) async {
    try {
      
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('username')
          .limit(100)
          .get();
      
      final currentUserId = _controller.authentication.currentUser?.uid;
      
      final results = usersSnapshot.docs
          .map((doc) => _documentToUser(doc))
          .where((user) => user != null && user.id != currentUserId)
          .cast<MangoUser>()
          .where((user) {
            return user.username.toLowerCase().contains(queryLower) ||
                   user.displayName.toLowerCase().contains(queryLower);
          })
          .toList();
      
      results.sort((a, b) => _calculateRelevanceScore(a, b, queryLower));
      
      setState(() {
        _allUsers = results;
        _filteredAllUsers = results;
        _isLoadingAllUsers = false;
      });
      
    } catch (e) {
      print('Error in fallback search: $e');
      setState(() {
        _isLoadingAllUsers = false;
      });
    }
  }

  Widget _buildAllUserListItem(
    MangoUser user,
    bool isFriend,
    bool isDarkMode,
    Color primaryColor,
    StateSetter setState,
  ) {
    final query = _allUsersSearchController.text.toLowerCase();
    final username = user.username.toLowerCase();
    final displayName = user.displayName.toLowerCase();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (!isFriend) {
              _startChatWithUser(user);
            } else {
              _selectFriend(user);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[800] : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: (username.startsWith(query) || displayName.startsWith(query))
                  ? Border.all(color: primaryColor.withOpacity(0.3), width: 1)
                  : null,
            ),
            child: Row(
              children: [
                
                CircleAvatar(
                  backgroundImage: user.profileImage.isNotEmpty
                      ? NetworkImage(user.profileImage)
                      : null,
                  radius: 22,
                  backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                  child: user.profileImage.isEmpty
                      ? Icon(
                          Icons.person,
                          color: isDarkMode ? Colors.white : Colors.black,
                        )
                      : null,
                ),

                const SizedBox(width: 12),

                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      
                      _buildHighlightedText(
                        text: user.displayName,
                        highlight: query,
                        isDarkMode: isDarkMode,
                        isBold: true,
                        primaryColor: primaryColor,
                      ),
                      const SizedBox(height: 2),
                      
                      _buildHighlightedText(
                        text: '@${user.username}',
                        highlight: query,
                        isDarkMode: isDarkMode,
                        isUsername: true,
                        primaryColor: primaryColor,
                      ),
                    ],
                  ),
                ),

                
                if (isFriend)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check, color: primaryColor, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Friends',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_add, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Add',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
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

  Widget _buildHighlightedText({
    required String text,
    required String highlight,
    required bool isDarkMode,
    required Color primaryColor,
    bool isBold = false,
    bool isUsername = false,
  }) {
    if (highlight.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          fontSize: isUsername ? 12 : 14,
          fontWeight: isBold ? FontWeight.bold : (isUsername ? FontWeight.normal : FontWeight.w500),
          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
        ),
      );
    }
    
    final textLower = text.toLowerCase();
    final startIndex = textLower.indexOf(highlight);
    
    if (startIndex == -1) {
      return Text(
        text,
        style: TextStyle(
          fontSize: isUsername ? 12 : 14,
          fontWeight: isBold ? FontWeight.bold : (isUsername ? FontWeight.normal : FontWeight.w500),
          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
        ),
      );
    }
    
    final endIndex = startIndex + highlight.length;
    
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: text.substring(0, startIndex),
            style: TextStyle(
              fontSize: isUsername ? 12 : 14,
              fontWeight: isBold ? FontWeight.bold : (isUsername ? FontWeight.normal : FontWeight.w500),
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          TextSpan(
            text: text.substring(startIndex, endIndex),
            style: TextStyle(
              fontSize: isUsername ? 12 : 14,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
              backgroundColor: primaryColor.withOpacity(0.2),
            ),
          ),
          TextSpan(
            text: text.substring(endIndex),
            style: TextStyle(
              fontSize: isUsername ? 12 : 14,
              fontWeight: isBold ? FontWeight.bold : (isUsername ? FontWeight.normal : FontWeight.w500),
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreButton(bool isDarkMode, Color primaryColor, StateSetter setState) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton(
        onPressed: _hasMoreUsers && !_isLoadingMore ? _loadMoreUsers : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor.withOpacity(0.1),
          foregroundColor: primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.expand_more, size: 20),
            const SizedBox(width: 8),
            Text('Load More Users'),
          ],
        ),
      ),
    );
  }

  void _startChatWithUser(MangoUser user) {
    
    Navigator.pop(context);

    
    showDialog(
      context: context,
      builder: (context) {
        final isDarkMode = _themeController.isDarkMode.value;
        final primaryColor = _themeController.primaryColorValue;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
          title: Text(
            'Start Chat',
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Start a conversation with ${user.displayName}?',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You can send a message to @${user.username}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
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
            TextButton(
              onPressed: () {
                Navigator.pop(context); 
                _selectFriend(user); 
              },
              style: TextButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Start Chat',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _allUsersSearchController.removeListener(_onAllUsersSearchChanged);
    _allUsersSearchController.dispose();
    _debounceTimer?.cancel();
    _mainScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isDarkMode = _themeController.isDarkMode.value;
      final primaryColor = _themeController.primaryColorValue;

      return Scaffold(
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        body: _buildMainInterface(isDarkMode, primaryColor),
      );
    });
  }

  Widget _buildMainInterface(bool isDarkMode, Color primaryColor) {
    return Column(
      children: [
        
        Container(
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.black : Colors.white,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              SizedBox(height: MediaQuery.of(context).padding.top),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Text(
                      'Chat',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    const Spacer(),
                    
                    GestureDetector(
                      onTap: () => _showAllUsersDialog(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: primaryColor.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.group, color: primaryColor, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Make Friends',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Your friends',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'See All',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildHorizontalChatGrid(isDarkMode, primaryColor),
              const SizedBox(height: 12),
              
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 5,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[900] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search friends...',
                      hintStyle: TextStyle(
                        color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),

        
        Expanded(
          child: Container(
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[900] : Colors.grey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: _buildScrollableContent(isDarkMode, primaryColor),
          ),
        ),
      ],
    );
  }

  Widget _buildScrollableContent(bool isDarkMode, Color primaryColor) {
    return CustomScrollView(
      controller: _mainScrollController,
      slivers: [
        _searchController.text.isNotEmpty
            ? _buildSearchResultsSliver(isDarkMode, primaryColor)
            : _buildRecentChatsSliver(isDarkMode, primaryColor),
      ],
    );
  }

  Widget _buildSearchResultsSliver(bool isDarkMode, Color primaryColor) {
    return _searchResults.isEmpty
        ? SliverToBoxAdapter(
            child: Container(
              height: 300,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 60,
                      color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No friends found',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        : SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final user = _searchResults[index];
              return _buildFriendListItem(user, isDarkMode, primaryColor);
            }, childCount: _searchResults.length),
          );
  }

  Widget _buildRecentChatsSliver(bool isDarkMode, Color primaryColor) {
    return StreamBuilder<List<Message>>(
      stream: _controller.getUserConversations(
        _controller.authentication.currentUser!.uid,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverToBoxAdapter(
            child: Container(
              height: 200,
              child: Center(
                child: CircularProgressIndicator(color: primaryColor),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Container(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 60,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading chats',
                      style: TextStyle(color: Colors.redAccent, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please try again later',
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SliverToBoxAdapter(child: _buildEmptyInboxState(isDarkMode));
        }

        final messages = snapshot.data!;
        final uniqueConversations = _getUniqueConversations(messages);

        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final message = uniqueConversations[index];
            return _buildMessageListItem(message, isDarkMode, primaryColor);
          }, childCount: uniqueConversations.length),
        );
      },
    );
  }

  List<Message> _getUniqueConversations(List<Message> messages) {
    final Map<String, Message> conversationMap = {};
    final currentUserId = _controller.authentication.currentUser!.uid;

    for (final message in messages) {
      final otherUserId = message.sender == currentUserId
          ? message.receiver
          : message.sender;

      if (!conversationMap.containsKey(otherUserId) ||
          message.timeStamp.compareTo(conversationMap[otherUserId]!.timeStamp) >
              0) {
        conversationMap[otherUserId] = message;
      }
    }

    final result = conversationMap.values.toList();
    result.sort((a, b) => b.timeStamp.compareTo(a.timeStamp));
    return result;
  }

  Widget _buildFriendListItem(
    MangoUser user,
    bool isDarkMode,
    Color primaryColor,
  ) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: (user.profileImage.isNotEmpty)
            ? NetworkImage(user.profileImage)
            : null,
        radius: 25,
        child: (user.profileImage.isEmpty)
            ? Icon(
                Icons.person,
                color: isDarkMode ? Colors.white : Colors.black,
              )
            : null,
        backgroundColor: (user.profileImage.isEmpty)
            ? isDarkMode
                ? Colors.grey[700]
                : Colors.grey[300]
            : null,
      ),
      title: Text(
        user.displayName,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          height: 1,
          letterSpacing: -0.1,
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ),
      subtitle: Text(
        '@${user.username}',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 11,
          height: 1,
          letterSpacing: -0.1,
          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
      trailing: Icon(Icons.chat_bubble_outline, color: primaryColor, size: 14),
      onTap: () => _selectFriend(user),
    );
  }

  Widget _buildMessageListItem(
    Message message,
    bool isDarkMode,
    Color primaryColor,
  ) {
    final otherUserId =
        message.sender == _controller.authentication.currentUser!.uid
            ? message.receiver
            : message.sender;

    return StreamBuilder<MangoUser?>(
      stream: _controller.getUserInfo(otherUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[800] : Colors.grey.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                  child: CircularProgressIndicator(color: primaryColor),
                ),
                const SizedBox(width: 12),
                Text(
                  'Loading...',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[800] : Colors.grey.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                  child: Icon(
                    Icons.person,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Unknown User',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          );
        }

        final user = snapshot.data!;
        return GestureDetector(
          onTap: () => _selectFriend(user),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[900] : Colors.white.withOpacity(0.95),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundImage: (user.profileImage.isNotEmpty)
                      ? NetworkImage(user.profileImage)
                      : null,
                  backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                  child: (user.profileImage.isEmpty)
                      ? Icon(
                          Icons.person,
                          color: isDarkMode ? Colors.white : Colors.black,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: -0.1,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 0),
                      Text(
                        message.text,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formatMessageTime(message.timeStamp),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatMessageTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      final monthNames = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final monthName = monthNames[date.month - 1];

      final oneYearAgo = DateTime(now.year - 1, now.month, now.day);
      if (messageDate.isBefore(oneYearAgo)) {
        return '$monthName ${date.day}, ${date.year}';
      } else {
        return '$monthName ${date.day}';
      }
    }
  }

  Widget _buildHorizontalChatGrid(bool isDarkMode, Color primaryColor) {
    return Obx(() {
      if (_friendsController.friends.isEmpty) {
        return Container(
          height: 100,
          child: Center(
            child: Text(
              'No friends yet',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
              ),
            ),
          ),
        );
      }

      return Container(
        height: 100,
        child: OptimizedListView(
          scrollDirection: Axis.horizontal,
          itemCount: _friendsController.friends.length,
          itemBuilder: (context, index) {
            final user = _friendsController.friends[index];
            return _buildFollowedUserCard(user, isDarkMode, primaryColor);
          },
        ),
      );
    });
  }

  Widget _buildFollowedUserCard(
    MangoUser user,
    bool isDarkMode,
    Color primaryColor,
  ) {
    String formatUsername(String username) {
      return username.length > 7 ? '${username.substring(0, 10)}..' : username;
    }

    return GestureDetector(
      onTap: () => _selectFriend(user),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: [
                CircleAvatar(
                  backgroundImage: (user.profileImage.isNotEmpty)
                      ? NetworkImage(user.profileImage)
                      : null,
                  radius: 30,
                  child: (user.profileImage.isEmpty)
                      ? Icon(
                          Icons.person,
                          color: isDarkMode ? Colors.white : Colors.black,
                          size: 30,
                        )
                      : null,
                  backgroundColor: (user.profileImage.isEmpty)
                      ? isDarkMode
                          ? Colors.grey[700]
                          : Colors.grey[300]
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDarkMode ? Colors.black : Colors.white,
                        width: 1,
                      ),
                    ),
                    child: Icon(Icons.chat, size: 10, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '@${formatUsername(user.username)}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyInboxState(bool isDarkMode) {
    return Container(
      height: 400,
      color: isDarkMode ? Colors.grey[900] : Colors.grey[50],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'asset/images/box.json',
              width: 200,
              height: 200,
              fit: BoxFit.cover,
              repeat: true,
            ),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: TextStyle(
                fontSize: 18,
                color: isDarkMode ? Colors.grey[400] : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a conversation with your friends!',
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}