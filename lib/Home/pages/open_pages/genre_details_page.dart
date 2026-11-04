import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Home/controllers/dashboard_controller.dart';
import 'package:mango/MusicPlayer/music.dart';
import 'package:mango/MusicPlayer/music_player.dart';

class GenreDetailPage extends StatelessWidget {
  final String genreName;
  final String genreEmoji;
  final Color genreColor;
  final String genreDescription;

  GenreDetailPage({
    Key? key,
    required this.genreName,
    required this.genreEmoji,
    required this.genreColor,
    required this.genreDescription,
  }) : super(key: key);

  final MangoDashboardController controller = Get.find();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          
          SliverAppBar(
            backgroundColor: Colors.transparent,
            expandedHeight: 200,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      genreColor.withOpacity(0.8),
                      Colors.black,
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            genreEmoji,
                            style: TextStyle(fontSize: 40),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  genreName,
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  genreDescription,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      
                      ElevatedButton.icon(
                        onPressed: () {
                          
                          _playAllSongsInGenre();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: genreColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        icon: Icon(Icons.play_arrow, color: Colors.white),
                        label: Text(
                          'PLAY ALL',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            pinned: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Get.back(),
            ),
          ),
          
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Popular ${genreName} Songs',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          
          StreamBuilder<List<Music>>(
            stream: controller.getSongsByGenre(genreName),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              
              if (snapshot.hasError) {
                return SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'Error loading songs',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                );
              }
              
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.music_off, size: 60, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No songs found for $genreName',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              final musicList = snapshot.data!;
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final music = musicList[index];
                    return _buildEnhancedMusicCard(music, genreColor, index + 1);
                  },
                  childCount: musicList.length,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedMusicCard(Music music, Color genreColor, int rank) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                music.artworkUrl,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 50,
                    height: 50,
                    color: genreColor,
                    child: Icon(Icons.music_note, color: Colors.white),
                  );
                },
              ),
            ),
            if (rank <= 3)
              Positioned(
                top: -4,
                left: -4,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: genreColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                music.displayTitle,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (music.isExplicit)
              Container(
                margin: EdgeInsets.only(left: 4),
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  'E',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              music.artistName,
              style: TextStyle(color: Colors.grey[400]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.play_arrow, size: 12, color: Colors.grey),
                SizedBox(width: 4),
                Text(
                  '${music.plays} plays',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
                SizedBox(width: 8),
                Icon(Icons.schedule, size: 12, color: Colors.grey),
                SizedBox(width: 4),
                Text(
                  music.formattedDuration,
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.play_arrow, color: genreColor),
          onPressed: () {
            Get.to(() => MusicPlayer(musicId: music.id));
          },
        ),
        onTap: () {
          Get.to(() => MusicPlayer(musicId: music.id));
        },
      ),
    );
  }

  void _playAllSongsInGenre() {
    
    controller.getSongsByGenre(genreName).first.then((musicList) {
      if (musicList.isNotEmpty) {
        Get.to(() => MusicPlayer(
          musicId: musicList.first.id,
          playlist: musicList,
        ));
      }
    });
  }
}