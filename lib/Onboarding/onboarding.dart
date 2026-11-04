import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Notifications/notifications_controller.dart';
import 'package:mango/constants.dart';
import 'package:mango/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mango/Utils/optimized_lists.dart';

import 'onboarding_model.dart';

class OnBoard extends StatefulWidget {
  const OnBoard({super.key});

  @override
  _OnBoardState createState() => _OnBoardState();
}

class _OnBoardState extends State<OnBoard> {
  int currentIndex = 0;
  late PageController _pageController;
  late Timer _timer;
  final controller = Get.find<NotificationController>();
  
  List<OnboardModel> screens = <OnboardModel>[
    OnboardModel(
      img: 'assets/images/img-1.png',
      text: "Music",
      desc: "Set your moments and moods with music playlists for you",
      bg: kCoral,
      button: kCoralMono, 
      textColor: Colors.black,
    ),
    OnboardModel(
      img: 'assets/images/img-2.png',
      text: "Books",
      desc: "Fill your library with books and reading friends for you",
      bg: kKhaki,
      button: kKhakiMono, 
      textColor: Colors.black,
    ),
    OnboardModel(
      img: 'assets/images/img-3.png',
      text: "Movies",
      desc: "Discover and stream your favorite movies and TV shows",
      bg: kGold,
      button: kGoldMono, 
      textColor: Colors.black87,
    ),
    OnboardModel(
      img: 'assets/images/img-4.png',
      text: "Podcasts",
      desc: "Listen to engaging podcasts on topics you love",
      bg: kMidSeaGreen,
      button: kMidSeaGreenMono, 
      textColor: Colors.white,
    ),
    OnboardModel(
      img: 'assets/images/img-5.png',
      text: "Shop",
      desc: "Browse and purchase from our curated marketplace",
      bg: kDeepBlue,
      button: kDeepBlueMono, 
      textColor: Colors.white,
    ),
    OnboardModel(
      img: 'assets/images/img-6.png',
      text: "Blockchain",
      desc: "Explore decentralized apps and crypto services securely",
      bg: kPurple,
      button: kPurpleMono, 
      textColor: Colors.white,
    ),
    OnboardModel(
      img: 'assets/images/img-7.png',
      text: "Community",
      desc: "Join others in creating blissful moments and share them in your tribe",
      bg: kTeal,
      button: kTealMono, 
      textColor: Colors.white,
    ),
  ];

  @override
  void initState() {
    _pageController = PageController(initialPage: 0);
    controller.requestPermissionIfNeeded();
    controller.debugCheckTokenStorage();
    _startAutoSwipe();
    super.initState();
  }

  void _startAutoSwipe() {
    _timer = Timer.periodic(const Duration(seconds: 2), (Timer timer) {
      if (currentIndex < screens.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      } else {
        
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _timer.cancel();
    super.dispose();
  }

  _storeOnboardInfo() async {
    if (kDebugMode) {
      print("Shared pref called");
    }
    int isViewed = 0;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('onBoard', isViewed);
    if (kDebugMode) {
      print(prefs.getInt('onBoard'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: screens[currentIndex].bg,
      appBar: AppBar(
        backgroundColor: screens[currentIndex].bg,
        elevation: 0.0,
        actions: [
          TextButton(
            onPressed: () {
              _timer.cancel(); 
              Get.offNamed('/welcome');
            },
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                Icons.skip_next,
                color: screens[currentIndex].textColor,
                size: 15,
              ),
              const SizedBox(width: 5.0),
              Text(
                "Skip",
                style: TextStyle(
                  color: screens[currentIndex].textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10.0),
            ]),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
        child: PageView.builder(
          itemCount: screens.length,
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (int index) {
            setState(() {
              currentIndex = index;
            });
          },
          itemBuilder: (_, index) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                
                SizedBox(
                  height: 10.0,
                  child: OptimizedListView(
                    itemCount: screens.length,
                    shrinkWrap: true,
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, indicatorIndex) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3.0),
                            width: currentIndex == indicatorIndex ? 25 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: screens[currentIndex].button,
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      
                      
                      
                      
                      SizedBox(
                        width: screens[index].text.length > 9 
                            ? double.infinity 
                            : MediaQuery.of(context).size.width / 1.5,
                        child: FittedBox(
                          fit: BoxFit.fitWidth,
                          child: Text(
                            screens[index].text,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Montserrat',
                              color: screens[index].textColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20.0),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Text(
                          screens[index].desc,
                          textAlign: TextAlign.center,
                          textWidthBasis: TextWidthBasis.longestLine,
                          overflow: TextOverflow.fade,
                          maxLines: 4,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            fontStyle: FontStyle.italic,
                            fontFamily: 'Montserrat',
                            color: screens[index].textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                
                InkWell(
                  onTap: () {
                    if (index == screens.length - 1) {
                      _timer.cancel(); 
                      Get.offNamed('/welcome');
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 15),
                    decoration: BoxDecoration(
                      color: screens[index].button,
                      borderRadius: BorderRadius.circular(15.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          index == screens.length - 1 ? "Get Started" : "Next",
                          style: TextStyle(
                            fontSize: 16.0,
                            color: screens[index].textColor,
                          ),
                        ),
                        const SizedBox(width: 15.0),
                        Icon(
                          index == screens.length - 1 ? Icons.check : Icons.arrow_forward_sharp,
                          color: screens[index].textColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}