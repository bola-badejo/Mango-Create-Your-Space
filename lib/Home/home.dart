// Updated MangoHome with mini player
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Conversations/pages/conversation_page.dart';
import 'package:mango/Home/dashboard.dart';
import 'package:mango/Home/feeds.dart';
import 'package:mango/MusicPlayer/controllers/global_music_controller.dart';
import 'package:mango/MusicPlayer/mini_player.dart';
import 'package:mango/Profile/profile.dart';
import 'package:mango/Spaces/screens/space_home.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class KeepAliveConversationPage extends StatefulWidget {
  const KeepAliveConversationPage({super.key});

  @override
  State<KeepAliveConversationPage> createState() => _KeepAliveConversationPageState();
}

class _KeepAliveConversationPageState extends State<KeepAliveConversationPage> 
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ConversationPage();
  }
}

class KeepAliveSpaceHome extends StatefulWidget {
  const KeepAliveSpaceHome({super.key});

  @override
  State<KeepAliveSpaceHome> createState() => _KeepAliveSpaceHomeState();
}

class _KeepAliveSpaceHomeState extends State<KeepAliveSpaceHome> 
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SpaceHomeScreen();
  }
}

class KeepAliveDashboard extends StatefulWidget {
  const KeepAliveDashboard({super.key});

  @override
  State<KeepAliveDashboard> createState() => _KeepAliveDashboardState();
}

class _KeepAliveDashboardState extends State<KeepAliveDashboard> 
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return MangoDashboard();
  }
}

class KeepAliveFeedPage extends StatefulWidget {
  const KeepAliveFeedPage({super.key});

  @override
  State<KeepAliveFeedPage> createState() => _KeepAliveFeedPageState();
}

class _KeepAliveFeedPageState extends State<KeepAliveFeedPage> 
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const FeedPage();
  }
}

class KeepAliveProfilePage extends StatefulWidget {
  const KeepAliveProfilePage({super.key});

  @override
  State<KeepAliveProfilePage> createState() => _KeepAliveProfilePageState();
}

class _KeepAliveProfilePageState extends State<KeepAliveProfilePage> 
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ProfilePage(id: FirebaseAuth.instance.currentUser!.uid);
  }
}

class MangoHome extends StatefulWidget {
  const MangoHome({super.key});

  @override
  State<MangoHome> createState() => _MangoHomeState();
}

class _MangoHomeState extends State<MangoHome> with SingleTickerProviderStateMixin {
  final PageController pageController = PageController(initialPage: 2);
  
  // CHANGE: Use Get.find() instead of Get.put() since it's already registered
  late final GlobalMusicController musicController;
  
  int _currentPage = 2;
  bool _showFullNavBar = true;
  Timer? _hideNavBarTimer;
  late AnimationController _animationController;

  final List<IconData> _navIcons = [
    FontAwesomeIcons.comments,
    FontAwesomeIcons.rocket,
    FontAwesomeIcons.house,
    FontAwesomeIcons.rss,
    FontAwesomeIcons.user,
  ];

  final List<Widget> _pages = const [
    KeepAliveConversationPage(),
    KeepAliveSpaceHome(),
    KeepAliveDashboard(),
    KeepAliveFeedPage(),
    KeepAliveProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    
    // CHANGE: Find the already registered controller
    musicController = Get.find<GlobalMusicController>();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _startHideTimer();
  }

  void _startHideTimer() {
    _hideNavBarTimer?.cancel();
    _hideNavBarTimer = Timer(const Duration(seconds: 5), () {
      if (_showFullNavBar && mounted) {
        _animationController.reverse();
        setState(() {
          _showFullNavBar = false;
        });
      }
    });
  }

  void _resetHideTimer() {
    if (!_showFullNavBar && mounted) {
      _animationController.forward();
      setState(() {
        _showFullNavBar = true;
      });
    }
    _startHideTimer();
  }

  void _onNavItemTapped(int index) {
    _resetHideTimer();
    pageController.jumpToPage(index);
    setState(() {
      _currentPage = index;
    });
  }

  void _onDotTapped() {
    if (mounted) {
      _animationController.forward();
      setState(() {
        _showFullNavBar = true;
      });
      _resetHideTimer();
    }
  }

  @override
  void dispose() {
    _hideNavBarTimer?.cancel();
    _animationController.dispose();
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // Main content
          PageView.builder(
            controller: pageController,
            padEnds: false,
            physics: const ClampingScrollPhysics(),
            itemCount: _pages.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
              _resetHideTimer();
            },
            itemBuilder: (context, index) {
              return _pages[index];
            },
          ),
          
          // Mini player positioned above bottom nav
          Positioned(
            bottom: _showFullNavBar ? 76 : 28,
            left: 0,
            right: 0,
            child: Obx(() => musicController.showMiniPlayer.value 
                ? MiniPlayer() 
                : const SizedBox.shrink()),
          ),
        ],
      ),
      bottomNavigationBar: _buildFloatingNavBar(),
    );
  }

  Widget _buildFloatingNavBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: _showFullNavBar ? null : _onDotTapped,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: _showFullNavBar ? 60 : 12,
            width: _showFullNavBar ? null : 80,
            constraints: _showFullNavBar 
                ? const BoxConstraints(minWidth: 300, maxWidth: 400)
                : null,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.9),
              borderRadius: BorderRadius.circular(_showFullNavBar ? 30 : 6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _showFullNavBar ? _buildFullNavBar() : _buildDotIndicators(),
          ),
        ),
      ),
    );
  }

  Widget _buildFullNavBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(_navIcons.length, (index) {
        return GestureDetector(
          onTap: () => _onNavItemTapped(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _currentPage == index 
                  ? Colors.orange.withOpacity(0.2)
                  : Colors.transparent,
            ),
            child: FaIcon(
              _navIcons[index],
              color: _currentPage == index ? Colors.orange : Colors.white,
              size: 20,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDotIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(_navIcons.length, (index) {
        return GestureDetector(
          onTap: () => _onNavItemTapped(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _currentPage == index ? Colors.orange : Colors.white.withOpacity(0.7),
            ),
          ),
        );
      }),
    );
  }
}