import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mango/MusicPlayer/music.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class LyricsPage extends StatefulWidget {
  final Music music;
  final AudioPlayer player;
  final String musicId;

  const LyricsPage({
    super.key,
    required this.music,
    required this.player,
    required this.musicId,
  });

  @override
  State<LyricsPage> createState() => _FirebaseLyricsPageState();
}

class _FirebaseLyricsPageState extends State<LyricsPage> {
  String? lyrics;
  final ItemScrollController itemScrollController = ItemScrollController();
  StreamSubscription? streamSubscription;

  @override
  void dispose() {
    streamSubscription?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    _loadLyrics();
    super.initState();
  }

  Future<void> _loadLyrics() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('music')
          .doc(widget.musicId)
          .get();
      
      if (doc.exists && doc.data()?['lyrics'] != null) {
        setState(() {
          lyrics = doc.data()!['lyrics'];
        });
      }
    } catch (e) {
      print('Error loading lyrics: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.music.songColor,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0).copyWith(top: 20),
          child: lyrics != null
              ? SingleChildScrollView(
                  child: Text(
                    lyrics!,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      height: 1.6,
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    'No lyrics available',
                    style: TextStyle(color: Colors.white38, fontSize: 16),
                  ),
                ),
        ),
      ),
    );
  }
}