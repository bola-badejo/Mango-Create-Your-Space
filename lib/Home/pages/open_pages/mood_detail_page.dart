
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Home/dashboard.dart';
import 'package:mango/Models/customModel/mango_genres.dart';
import 'package:mango/Models/customModel/playlist.dart';
import 'package:mango/Utils/optimized_lists.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class MoodDetailPage extends StatelessWidget {
  final MangoGenre mood;

  const MoodDetailPage({Key? key, required this.mood}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final MangoDashboard controller = Get.find();

    return Scaffold(
      backgroundColor: MangoPalette.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Text(mood.emoji, style: TextStyle(fontSize: 24)),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mood.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                Text(
                  'Mood',
                  style: TextStyle(
                    color: MangoPalette.grey400,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        leading: IconButton(
        tooltip: 'Back',
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mood.description,
                  style: TextStyle(
                    color: MangoPalette.grey300,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: mood.genres.map((genre) {
                    return Chip(
                      label: Text(
                        genre,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor: mood.color.withOpacity(0.3),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          
          
          Expanded(
            child: StreamBuilder<List<MangoPlaylist>>(
              stream: controller.getSongsForMood(mood.genres),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(semanticsLabel: 'Loading'));
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading songs: ${snapshot.error}'),
                  );
                }
                
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.music_off, size: 50, color: MangoPalette.grey500),
                        SizedBox(height: 16),
                        Text(
                          'No songs found for this mood',
                          style: TextStyle(color: MangoPalette.grey500),
                        ),
                      ],
                    ),
                  );
                }
                
                final songs = snapshot.data!;
                return OptimizedListView(
                  padding: EdgeInsets.all(16),
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    return _buildSongCard(song, mood.color);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongCard(MangoPlaylist song, Color moodColor) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: MangoPalette.grey900,
        borderRadius: BorderRadius.circular(MangoRadius.md),
      ),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(MangoRadius.sm),
          child: Image.network(
            song.image,
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 50,
                height: 50,
                color: moodColor,
                child: Icon(Icons.music_note, color: Colors.white),
              );
            },
          ),
        ),
        title: Text(
          song.title, 
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${song.artiste} • ${song.plays} plays • ${song.genre}',
          style: TextStyle(color: MangoPalette.grey400),
        ),
        trailing: Icon(Icons.play_arrow, color: moodColor),
        onTap: () {
          
          
          Get.toNamed('/song/${song.id}');
        },
      ),
    );
  }
}