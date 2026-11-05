import 'dart:async';
import 'dart:ui';
import 'package:carousel_slider/carousel_slider.dart' as slider;


import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mango/Books/screens/details_screen.dart';
import 'package:mango/Books/widgets/book_rating.dart';
import 'package:mango/Books/widgets/reading_card_list.dart';
import 'package:mango/Books/widgets/two_side_rounded_button.dart';
import 'package:mango/MusicPlayer/music.dart';

import '../../../Home/components/music_components.dart';
import '../../../Home/controllers/dashboard_controller.dart';
import '../../../Home/pages/post_shimmer.dart';
import '../../../Models/customModel/playlist.dart';

import 'package:mango/Utils/optimized_lists.dart';
import 'package:mango/Core/theme/mango_palette.dart';
import 'package:mango/Core/design_system/mango_ui.dart';
class SpaceLounge extends StatelessWidget {
  SpaceLounge({super.key});

  final MangoDashboardController controller =
  Get.put(MangoDashboardController());

  @override
  Widget build(BuildContext context) {
    final spaceId = Get.arguments['spaceId'];
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
                            text:
                            "This is how we catch a vibe.",
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(
                              text: "\nNo Sweat.",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                              ))
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Visitors\' favourite',
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).primaryColorLight,
                          fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(height: 15),
                  StreamBuilder<List<Music>>(
                    stream: controller.getMusic(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return HorizontalShimmerList(
                            height: 150,
                            width: 150,
                            color: Theme.of(context).primaryColorLight);
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(
                            child: Text("No playlists available"));
                      }
                      var playlists = snapshot.data!;
                      return Container(
                        padding: const EdgeInsets.only(left: 14),
                        height: 150,
                        child: OptimizedListView(
                          scrollDirection: Axis.horizontal,
                          itemCount: playlists.length,
                          itemBuilder: (context, index) {
                            var playlist = playlists[index];
                            return GestureDetector(
                              onTap: () {
                                
                                
                              },
                              child: MusicCard(
                                music: playlist,
                                pressDetails: () {
                                  
                                  
                                },
                                pressPlay: () {
                                  
                                },
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
                    child: Text(
                      'Let\'s talk..',
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).primaryColorLight,
                          fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: ConversationsCard(),
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

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: LiveSessionsCard(),
                  ),
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  const SizedBox(height: 15),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25.0),
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
                            color:
                            Theme.of(context).splashColor.withOpacity(.24),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(38.5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Padding(
                                padding:
                                const EdgeInsets.only(left: 30, right: 20),
                                child: Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                        MainAxisAlignment.end,
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: <Widget>[
                                          const Text(
                                            "Wrigly's Pot",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            "Amos Adegbola",
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .primaryColorLight,
                                            ),
                                          ),
                                          Align(
                                            alignment: Alignment.bottomRight,
                                            child: Text(
                                              "100 attendees",
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context)
                                                    .primaryColorLight,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                        ],
                                      ),
                                    ),
                                    Image.asset(
                                      "asset/images/mango-13.jpg",
                                      width: 55,
                                    )
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              height: 7,
                              width: size.width * .65,
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColorLight,
                                borderRadius: BorderRadius.circular(MangoRadius.sm),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),


                  const SizedBox(height: 15),
                  StreamBuilder<List<Music>>(
                    stream: controller.getMusic(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return HorizontalShimmerList(
                            height: 150,
                            width: 150,
                            color: Theme.of(context).primaryColorLight);
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(
                            child: Text("No playlists available"));
                      }
                      var playlists = snapshot.data!;
                      return Container(
                        padding: const EdgeInsets.only(left: 14),
                        height: 150,
                        child: OptimizedListView(
                          scrollDirection: Axis.horizontal,
                          itemCount: playlists.length,
                          itemBuilder: (context, index) {
                            var playlist = playlists[index];
                            return GestureDetector(
                              onTap: () {
                                
                                
                              },
                              child: MusicCard(
                                music: playlist,
                                pressDetails: () {
                                  
                                  
                                },
                                pressPlay: () {
                                  
                                },
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        RichText(
                          text: TextSpan(
                            style: Theme.of(context).textTheme.titleLarge,
                            children: const [
                              TextSpan(
                                text: "The ",
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              TextSpan(
                                text: "Shelf",
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ),
                        bestOfTheDayCard(size, context),
                        bestOfTheDayCard(size, context),
                        bestOfTheDayCard(size, context),
                        bestOfTheDayCard(size, context),
                        bestOfTheDayCard(size, context),
                        bestOfTheDayCard(size, context),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
                    "What is good about the morning?",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    "Morning stories",
                    style:
                    TextStyle(color: Theme.of(context).primaryColorLight),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 10.0),
                    child: Row(
                      children: <Widget>[
                        const Padding(
                          padding: EdgeInsets.only(right: 10.0),
                          child: BookRating(score: 4),
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


class ConversationsCard extends StatefulWidget {
  const ConversationsCard({super.key});

  @override
  _ConversationsCardState createState() =>
      _ConversationsCardState();
}

class _ConversationsCardState
    extends State<ConversationsCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _shimmerController;
  late Timer _shimmerTimer;
  bool _isShimmering = false;

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

  @override
  void dispose() {
    _shimmerController.dispose();
    _shimmerTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            height: _isExpanded ? 200 : 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(MangoRadius.lg),
              color: Colors.white.withOpacity(0.3),
              border:
              Border.all(color: Colors.white.withOpacity(0.5), width: 1),
              boxShadow: [
                BoxShadow(
                  color: MangoPalette.black.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(MangoRadius.lg),
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
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                        margin: const EdgeInsets.only(bottom: 10.0),
                        decoration: BoxDecoration(
                          color: MangoPalette.black,
                          borderRadius: BorderRadius.circular(MangoRadius.sm)
                        ),
                        child: const Text(
                          "Active",
                          style: TextStyle(fontSize: 12, color: MangoPalette.grey500, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        "What is good about the Morning?",
                        style: TextStyle(
                            color: Theme.of(context).primaryColorLight,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                      Text(
                        "Morning stories",
                        style: TextStyle(
                            color: Theme.of(context).primaryColorLight,
                            fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MangoPressable(
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
                                    fontSize: 12,
                                    color: MangoPalette.black.withOpacity(0.8),
                                  ),
                                ),
                                Icon(
                                  _isExpanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: MangoPalette.black.withOpacity(0.8),
                                  size: 10,
                                ),
                              ],
                            ),
                          ),
                          if (_isExpanded)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'This is a short description that expands when you click the dropdown button. It provides more details about the content. You can add as much text as you want here, and the glass container will expand accordingly.',
                                    maxLines: 2,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: MangoPalette.black.withOpacity(0.6),
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: MangoPalette.black,
                                      borderRadius: BorderRadius.circular(MangoRadius.sm),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 2, horizontal: 5),
                                    child: Text(
                                      "Say something..",
                                      style: TextStyle(fontFamily: 'Poppins', 
                                          fontSize: 12, color: Colors.white),
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
                  child: Stack(
                    alignment: Alignment.centerRight,
                    children: [
                      
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Container(
                          width: _isExpanded ? 140 : 90,
                          height: _isExpanded ? 160 : 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(MangoRadius.lg),
                            boxShadow: [
                              BoxShadow(
                                color: MangoPalette.black.withOpacity(0.1),
                                blurRadius: 20,
                                spreadRadius: 5,
                                offset: const Offset(10, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(MangoRadius.sm),
                            child: Image.asset(
                              "asset/images/mango-13.jpg", 
                              fit: BoxFit.cover,
                            ),
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
  }
}
class LiveSessionsCard extends StatefulWidget {
  const LiveSessionsCard({super.key});

  @override
  _LiveSessionsCardState createState() =>
      _LiveSessionsCardState();
}

class _LiveSessionsCardState
    extends State<LiveSessionsCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _shimmerController;
  late Timer _shimmerTimer;
  bool _isShimmering = false;

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

  @override
  void dispose() {
    _shimmerController.dispose();
    _shimmerTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            height: _isExpanded ? 200 : 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(MangoRadius.lg),
              color: Colors.white.withOpacity(0.3),
              border:
              Border.all(color: Colors.white.withOpacity(0.5), width: 1),
              boxShadow: [
                BoxShadow(
                  color: MangoPalette.black.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(MangoRadius.lg),
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
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                        margin: const EdgeInsets.only(bottom: 10.0),
                        decoration: BoxDecoration(
                          color: MangoPalette.black,
                          borderRadius: BorderRadius.circular(MangoRadius.sm)
                        ),
                        child: const Text(
                          "3hrs 45s",
                          style: TextStyle(fontSize: 12, color: MangoPalette.grey500, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        "If the wheels don't pop, the boys don\'t stop.",
                        style: TextStyle(
                            color: Theme.of(context).primaryColorLight,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                      SizedBox(height: 4,),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            "201 listeners.",
                            style: TextStyle(
                                fontSize: 12,
                                color: MangoPalette.black),
                          ),
                          Text(
                            "Live",
                            style: TextStyle(
                                color: Colors.amber,
                                fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MangoPressable(
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
                                    fontSize: 12,
                                    color: MangoPalette.black.withOpacity(0.8),
                                  ),
                                ),
                                Icon(
                                  _isExpanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: MangoPalette.black.withOpacity(0.8),
                                  size: 10,
                                ),
                              ],
                            ),
                          ),
                          if (_isExpanded)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Serenade, marinate and pollinate. The meter is broken, there is no limit to what you can imagine. Join this session, what\'s stoping you?',
                                    maxLines: 2,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: MangoPalette.black.withOpacity(0.6),
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: MangoPalette.black,
                                      borderRadius: BorderRadius.circular(MangoRadius.sm),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 2, horizontal: 5),
                                    child: Text(
                                      "join now",
                                      style: TextStyle(fontFamily: 'Poppins', 
                                          fontSize: 12, color: Colors.white),
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
                              color: MangoPalette.black.withOpacity(0.1),
                              blurRadius: 20,
                              spreadRadius: 5,
                              offset: const Offset(10, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(MangoRadius.sm),
                          child: Image.asset(
                            "asset/images/mango-13.jpg", 
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _shimmerController,
                          builder: (context, child) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(MangoRadius.sm),
                              child: ShaderMask(
                                shaderCallback: (rect) {
                                  return LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.white.withOpacity(0.5),
                                      Colors.transparent,
                                    ],
                                    stops: [0.0, 0.5, 1.0],
                                    begin: Alignment(
                                        -1.0 + 2.0 * _shimmerController.value,
                                        0.0),
                                    end: Alignment(
                                        1.0 + 2.0 * _shimmerController.value,
                                        0.0),
                                    tileMode: TileMode.clamp,
                                  ).createShader(rect);
                                },
                                blendMode: BlendMode.overlay,
                                child: Container(
                                  color: _isShimmering
                                      ? Colors.white.withOpacity(0.1)
                                      : Colors.transparent,
                                ),
                              ),
                            );
                          },
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
  }
}

