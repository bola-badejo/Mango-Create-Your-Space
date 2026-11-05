// MangoHome: app shell with adaptive navigation and the mini player.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Core/design_system/navigation/mango_adaptive_shell.dart';
import 'package:mango/Chat/chat_list_screen.dart';
import 'package:mango/Home/dashboard.dart';
import 'package:mango/Home/feeds.dart';
import 'package:mango/MusicPlayer/controllers/global_music_controller.dart';
import 'package:mango/MusicPlayer/mini_player.dart';
import 'package:mango/Profile/profile.dart';
import 'package:mango/Spaces/screens/space_home.dart';

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
    // Mango Chat: one-to-one, Snapchat-style (lib/Chat).
    return const ChatListScreen();
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

class _MangoHomeState extends State<MangoHome> {
  /// Home is the default destination, as before.
  static const int _homeIndex = 2;

  late final GlobalMusicController musicController;
  int _currentPage = _homeIndex;

  // Same five pages, in the same order, as the previous PageView.
  // Labels are new: the old bar was icon-only. Material outline/filled
  // icon pairs show selection by shape as well as colour.
  static final List<MangoDestination> _destinations = [
    MangoDestination(
      label: 'Chats',
      icon: Icons.chat_bubble_outline_rounded,
      selectedIcon: Icons.chat_bubble_rounded,
      builder: (_) => const KeepAliveConversationPage(),
    ),
    MangoDestination(
      label: 'Spaces',
      icon: Icons.rocket_launch_outlined,
      selectedIcon: Icons.rocket_launch_rounded,
      builder: (_) => const KeepAliveSpaceHome(),
    ),
    MangoDestination(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      builder: (_) => const KeepAliveDashboard(),
    ),
    MangoDestination(
      label: 'Feed',
      icon: Icons.dynamic_feed_outlined,
      selectedIcon: Icons.dynamic_feed_rounded,
      builder: (_) => const KeepAliveFeedPage(),
    ),
    MangoDestination(
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      builder: (_) => const KeepAliveProfilePage(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    musicController = Get.find<GlobalMusicController>();
  }

  void _select(int index) => setState(() => _currentPage = index);

  @override
  Widget build(BuildContext context) {
    // System back on another destination returns to Home first, then
    // leaves the app, matching Android navigation conventions.
    return PopScope(
      canPop: _currentPage == _homeIndex,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(_homeIndex);
      },
      child: MangoAdaptiveShell(
        destinations: _destinations,
        selectedIndex: _currentPage,
        onDestinationSelected: _select,
        accessory: Obx(
          () => musicController.showMiniPlayer.value
              ? MiniPlayer()
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
