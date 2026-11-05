import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Music/controllers/music_detail_controller.dart';
import 'package:mango/Music/controllers/mango_music_controller.dart';

import '../widgets/music_rating.dart';
import '../widgets/two_side_rounded_button.dart';
import 'package:mango/Core/theme/mango_palette.dart';
import 'package:mango/Core/design_system/mango_ui.dart';

class MusicDetailsScreen extends StatelessWidget {
  MusicDetailsScreen({super.key});
  final MusicDetailController controller = Get.put(MusicDetailController());
  final MangoMusicController musicController = Get.put(MangoMusicController());

  @override
  Widget build(BuildContext context) {
    var id = Get.parameters['id']!;
    controller.fetchMusic(id);
    var size = MediaQuery.of(context).size;
    return Obx(() {
      return Scaffold(
            body: Stack(
              children: [
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Stack(
                        alignment: Alignment.topCenter,
                        children: <Widget>[
                          Container(
                              alignment: Alignment.topCenter,
                              height: size.height * .48,
                              decoration: BoxDecoration(
                                image: DecorationImage(
                                  image: NetworkImage(controller.music['image'] ?? ''),
                                  fit: BoxFit.fitWidth,
                                ),
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(50),
                                  bottomRight: Radius.circular(50),
                                ),
                              ),
                              child: Container(
                                padding: EdgeInsets.only(
                                    top: size.height * .12,
                                    left: size.width * .1,
                                    right: size.width * .02),
                                height: size.height * .48,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      MangoPalette.black.withOpacity(1.0),
                                      MangoPalette.black.withOpacity(0.6)
                                    ],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  ),
                                  borderRadius: BorderRadius.circular(MangoRadius.md),
                                ),
                                child: MusicInfo(
                                  size: size,
                                  music: controller.music,
                                ),
                              )),
                          Padding(
                            padding: EdgeInsets.only(top: size.height * .48 - 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                ChapterCard(
                                  name: controller.music['title'] ?? '',
                                  chapterNumber: 1,
                                  tag: controller.music['artiste'] ?? '',
                                  press: () {
                                    musicController.playMusic(controller.music);
                                  },
                                  link: controller.music['record'] ?? '',
                                ),
                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            RichText(
                              text: TextSpan(
                                style: Theme.of(context).textTheme.bodyMedium,
                                children: const [
                                  TextSpan(
                                    text: "You might also ",
                                  ),
                                  TextSpan(
                                    text: "like….",
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            bestOfTheDayCard(size, context),
                          ],
                        ),
                      ),
                      const SizedBox(
                        height: 40,
                      ),
                    ],
                  ),
                ),

                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Obx(() {
                    return musicController.isPanelVisible.value ? MangoPressable(
                      onTap: musicController.togglePanel,
                      onLongPress: musicController.removePanel,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: musicController.isPanelOpen.value
                            ? MediaQuery.of(context).size.height
                            : MediaQuery.of(context).size.height / 6,
                        decoration: const BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        child: musicController.isPanelOpen.value
                            ? _buildExpandedPanel(context)
                            : _buildCollapsedPanel(context),
                      ),
                    ) : const SizedBox.shrink();
                  }),
                ),
              ],
            ),
          );
    });
  }

  Widget _buildCollapsedPanel(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          
          Image.network(
            musicController.nowPlaying["image"] ?? '',
            width: 60,
            height: 60,
            fit: BoxFit.cover,
          ),
          const SizedBox(width: 10),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  musicController.nowPlaying["title"] ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  musicController.nowPlaying["artist"] ?? '',
                  style: TextStyle(color: MangoPalette.grey400, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          IconButton(
        tooltip: 'Previous track',
            icon: const Icon(Icons.skip_previous, color: Colors.white, size: 30),
            onPressed: () {
              
            },
          ),
          IconButton(
        tooltip: 'Pause',
            icon: const Icon(Icons.pause, color: Colors.white, size: 40),
            onPressed: () {
              
            },
          ),
          IconButton(
        tooltip: 'Next track',
            icon: const Icon(Icons.skip_next, color: Colors.white, size: 30),
            onPressed: () {
              
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedPanel(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        
        Image.network(
          musicController.nowPlaying["image"] ?? '',
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.width * 0.8,
          fit: BoxFit.cover,
        ),
        const SizedBox(height: 20),
        
        Text(
          musicController.nowPlaying["title"] ?? '',
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        
        Text(
          musicController.nowPlaying["artist"] ?? '',
          style: TextStyle(color: MangoPalette.grey400, fontSize: 18),
        ),
        const SizedBox(height: 20),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
        tooltip: 'Previous track',
              icon: const Icon(Icons.skip_previous, color: Colors.white, size: 30),
              onPressed: () {
                
              },
            ),
            IconButton(
        tooltip: 'Pause',
              icon: const Icon(Icons.pause, color: Colors.white, size: 40),
              onPressed: () {
                
              },
            ),
            IconButton(
        tooltip: 'Next track',
              icon: const Icon(Icons.skip_next, color: Colors.white, size: 30),
              onPressed: () {
                
              },
            ),
          ],
        ),
      ],
    );
  }


  Container bestOfTheDayCard(Size size, BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      width: double.infinity,
      height: 245,
      child: Stack(
        children: <Widget>[
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 24,
                top: 24,
                right: size.width * .35,
              ),
              height: 230,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColorLight.withOpacity(.45),
                borderRadius: BorderRadius.circular(29),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    margin: const EdgeInsets.only(top: 10.0, bottom: 10.0),
                    child: Text(
                      "Mango Best Seller For 16th March 2024",
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).primaryColorLight,
                      ),
                    ),
                  ),
                  Text(
                    "How To Win \nFriends &  Influence",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    "Gary Venchuk",
                    style:
                        TextStyle(color: Theme.of(context).primaryColorLight),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 10.0),
                    child: Row(
                      children: <Widget>[
                        const Padding(
                          padding: EdgeInsets.only(right: 10.0),
                          child: MusicRating(score: 4),
                        ),
                        Expanded(
                          child: Text(
                            "When the earth was flat and everyone wanted to win the game of the best and people….",
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).primaryColorLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Image.asset(
              "asset/images/mango-13.jpg",
              width: size.width * .37,
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: SizedBox(
              height: 40,
              width: size.width * .3,
              child: TwoSideRoundedButton(
                text: "Read",
                radious: 24,
                press: () {},
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MusicPlayerMainSheet extends StatelessWidget {
  final MangoMusicController controller = Get.put(MangoMusicController());

  MusicPlayerMainSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.all(20),
      height: MediaQuery.of(context).size.height,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        ],
      ),
    );
  }
}

class ChapterCard extends StatelessWidget {
  final String name;
  final String tag;
  final int chapterNumber;
  final Function press;
  final String link;
  ChapterCard({
    super.key,
    required this.name,
    required this.tag,
    required this.link,
    required this.chapterNumber,
    required this.press,
  });


  final MangoMusicController controller = Get.put(MangoMusicController());

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    return MangoPressable(
      onTap: () => controller.playMusic(link),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 30),
        margin: const EdgeInsets.only(bottom: 16),
        width: size.width - 48,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(38.5),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 10),
              blurRadius: 33,
              color: Theme.of(context).primaryColorDark.withOpacity(.94),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: "$name \n",
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).primaryColorLight,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: tag,
                    style: TextStyle(color: Theme.of(context).splashColor),
                  ),
                ],
              ),
            ),
            const Spacer(),
            IconButton(
        tooltip: 'More options',
              icon: const Icon(
                Icons.more_vert,
                size: 18,
              ),
              onPressed: () => press,
            )
          ],
        ),
      ),
    );
  }
}

class MusicInfo extends StatelessWidget {
  MusicInfo({
    super.key,
    required this.size,
    required this.music,
  });

  final Size size;
  var music;

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Flex(
        crossAxisAlignment: CrossAxisAlignment.start,
        direction: Axis.horizontal,
        children: <Widget>[
          Expanded(
              flex: 1,
              child: Column(
                children: <Widget>[
                  Container(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      music['title'] ?? '',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium!
                          .copyWith(fontSize: 28),
                    ),
                  ),
                  Container(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      music['genre'] ?? '',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium!
                          .copyWith(fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            width: size.width * .3,
                            padding: EdgeInsets.only(top: size.height * .02),
                            child: Text(
                              music['text'] ?? '',
                              maxLines: 5,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).primaryColorLight,
                              ),
                            ),
                          ),
                          Container(
                            margin: EdgeInsets.only(top: size.height * .015),
                            padding: const EdgeInsets.only(left: 10, right: 10),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).primaryColorLight,
                                width: 1.5,
                              ),
                              
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: TextButton(
                              onPressed: () {},
                              child: Text(
                                "View details",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColorLight),
                              ),
                            ),
                          )
                        ],
                      ),
                      Column(
                        children: <Widget>[
                          IconButton(
                            icon: const Icon(
                              Icons.favorite_border,
                              size: 20,
                              color: MangoPalette.grey500,
                            ),
                            onPressed: () {},
                          ),
                          MusicRating(score: music['plays'] ?? 0),
                        ],
                      )
                    ],
                  )
                ],
              )),
          Expanded(
              flex: 1,
              child: Container(
                height: 200,
                width: 200,
                
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(MangoRadius.md),
                  boxShadow: [
                    BoxShadow(
                      offset: const Offset(3, 7),
                      blurRadius: 20,
                      color: Theme.of(context).cardColor.withOpacity(.5),
                    ),
                  ],
                  image: DecorationImage(
                    image: NetworkImage(music['image'] ?? ''),
                    fit: BoxFit.fitWidth,
                    alignment: Alignment.topRight,
                  ),
                ),
              )),
        ],
      ),
    );
  }
}