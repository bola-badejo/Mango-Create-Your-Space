import 'package:flutter/material.dart';
import 'package:mango/MusicPlayer/music.dart';
import 'package:mango/Core/theme/mango_palette.dart';
import 'package:mango/Core/design_system/mango_ui.dart';

class RecentPlayedCard extends StatelessWidget {
  final Music music;
  final Function pressDetails;
  final Function? pressPlay;

  const RecentPlayedCard({
    super.key,
    required this.music,
    required this.pressDetails,
    this.pressPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: MangoPressable(
        onTap: () => pressDetails(),
        child: Container(
          width: 100,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: NetworkImage(music.artworkUrl),
              fit: BoxFit.cover,
            ),
            borderRadius: BorderRadius.circular(MangoRadius.md),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  MangoPalette.black.withOpacity(0.5),
                  MangoPalette.black.withOpacity(0.1)
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
              borderRadius: BorderRadius.circular(MangoRadius.md),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      music.title,
                      style: TextStyle(
                        fontSize: 12, 
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      music.artistName,
                      style: TextStyle(
                        fontSize: 12, 
                        color: Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MusicCard extends StatelessWidget {
  final Music music;
  final Function pressDetails;
  final Function? pressPlay;

  const MusicCard({
    super.key,
    required this.music,
    required this.pressDetails,
    this.pressPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5.0),
      child: MangoPressable(
        onTap: () => pressDetails(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(music.artworkUrl),
                  fit: BoxFit.cover,
                ),
                borderRadius: BorderRadius.circular(MangoRadius.md),
              ),
            ),
            const SizedBox(height: 5),
            SizedBox(
              width: 100,
              child: Text(
                music.title,
                style: TextStyle(
                  color: Theme.of(context).primaryColorLight, 
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              width: 100,
              child: Text(
                music.artistName,
                style: const TextStyle(
                  color: MangoPalette.grey500,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}