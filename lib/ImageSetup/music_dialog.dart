
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mango/Utils/optimized_lists.dart';

class MusicPickerDialog extends StatefulWidget {
  const MusicPickerDialog({super.key});

  @override
  State<MusicPickerDialog> createState() => _MusicPickerDialogState();
}

class _MusicPickerDialogState extends State<MusicPickerDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _playlists = [];
  List<Map<String, dynamic>> _songs = [];
  bool _isLoading = true;
  String _selectedPlaylistId = '';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final query = _firestore
          .collection('playlists')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true);

      final snapshot = await query.get();
      
      setState(() {
        _playlists = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? 'Unnamed Playlist',
            'songCount': data['songCount'] ?? 0,
            'coverUrl': data['coverUrl'],
          };
        }).toList();
        
        if (_playlists.isNotEmpty) {
          _selectedPlaylistId = _playlists.first['id'];
          _loadSongs(_playlists.first['id']);
        } else {
          _isLoading = false;
        }
      });
    } catch (e) {
      print('Error loading playlists: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSongs(String playlistId) async {
    try {
      setState(() => _isLoading = true);

      final query = _firestore
          .collection('playlists')
          .doc(playlistId)
          .collection('songs')
          .orderBy('addedAt', descending: true);

      final snapshot = await query.get();
      
      setState(() {
        _songs = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'title': data['title'] ?? 'Unknown Title',
            'artist': data['artist'] ?? 'Unknown Artist',
            'duration': data['duration'] ?? '0:00',
            'url': data['url'] ?? '',
            'coverUrl': data['coverUrl'],
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading songs: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredSongs {
    if (_searchQuery.isEmpty) return _songs;
    
    return _songs.where((song) {
      final title = song['title']?.toLowerCase() ?? '';
      final artist = song['artist']?.toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      
      return title.contains(query) || artist.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            
            Row(
              children: [
                const Text(
                  'Select Music',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            
            
            if (_playlists.isNotEmpty) _buildPlaylistSelector(),
            
            
            _buildSearchBar(),
            
            
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredSongs.isEmpty
                      ? const Center(
                          child: Text(
                            'No songs found',
                            style: TextStyle(color: Colors.white),
                          ),
                        )
                      : _buildSongsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistSelector() {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 12),
      child: OptimizedListView(
        scrollDirection: Axis.horizontal,
        itemCount: _playlists.length,
        itemBuilder: (context, index) {
          final playlist = _playlists[index];
          final isSelected = playlist['id'] == _selectedPlaylistId;
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedPlaylistId = playlist['id'];
                _loadSongs(playlist['id']);
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue : Colors.grey[800],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  if (playlist['coverUrl'] != null)
                    Container(
                      width: 24,
                      height: 24,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        image: DecorationImage(
                          image: NetworkImage(playlist['coverUrl']),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  Text(
                    playlist['name'],
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[300],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextField(
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Search songs...',
          hintStyle: const TextStyle(color: Colors.grey),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          filled: true,
          fillColor: Colors.grey[800],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildSongsList() {
    return OptimizedListView(
      itemCount: _filteredSongs.length,
      itemBuilder: (context, index) {
        final song = _filteredSongs[index];
        
        return ListTile(
          leading: song['coverUrl'] != null
              ? Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    image: DecorationImage(
                      image: NetworkImage(song['coverUrl']),
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              : Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.music_note, color: Colors.white),
                ),
          title: Text(
            song['title'],
            style: const TextStyle(color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            song['artist'],
            style: const TextStyle(color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            song['duration'],
            style: const TextStyle(color: Colors.grey),
          ),
          onTap: () {
            Navigator.pop(context, song['url']);
          },
        );
      },
    );
  }
}