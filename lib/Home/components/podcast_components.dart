import 'package:flutter/material.dart';
import 'package:mango/Models/customModel/mango_podcasts.dart';

import '../../Models/customModel/vine.dart';

class RecentPlayedCard extends StatelessWidget {
  final MangoPodcast podcast;
  final Function pressDetails;
  final Function? pressPlay;

  const RecentPlayedCard({
    super.key,
    required this.podcast,
    required this.pressDetails,
    this.pressPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Container(
        width: 100,
        
        decoration: BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(podcast.artworkUrl),
            fit: BoxFit.cover,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(0.5),
                Colors.black.withOpacity(0.1)
              ],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Align(
              alignment: Alignment.bottomLeft,
              child:
                  Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(podcast.title, style: TextStyle(fontSize: 10, color: Theme.of(context).primaryColor,)),
                      Text(podcast.userDisplayName, style: TextStyle(fontSize: 10, color: Theme.of(context).primaryColor,)),
                    ],
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class PodcastCard extends StatelessWidget {
  final MangoPodcast podcast;
  final Function pressDetails;
  final Function? pressPlay;

  const PodcastCard({
    super.key,
    required this.podcast,
    required this.pressDetails,
    this.pressPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(podcast.artworkUrl),
                fit: BoxFit.cover,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
              width: 100,
              child: Text(podcast.title,
                  style: TextStyle(color: Theme.of(context).primaryColorLight, fontSize: 11))),
          
          SizedBox(
              width: 100,
              child: podcast.userDisplayName.isEmpty
                  ? const Text("Unknown artiste",
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 9,
                          fontWeight: FontWeight.w600))
                  : Text(
                          "${podcast.userDisplayName}",
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 10))),
        ],
      ),
    );
  }
}
