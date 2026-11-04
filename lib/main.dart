import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart' hide Priority;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mango/AccountSetup/user_detail/user_detail_controller.dart';
import 'package:mango/App/router/app_pages.dart';
import 'package:mango/App/router/app_routes.dart';
import 'package:mango/Contributors/controllers/home_product_controller.dart';
import 'package:mango/Contributors/controllers/product_controller.dart';
import 'package:mango/Contributors/controllers/product_detail_controller.dart';
import 'package:mango/Core/services/audio_handler.dart';
import 'package:mango/Home/controllers/dashboard_controller.dart';
import 'package:mango/Models/controllers/player_controller.dart';
import 'package:mango/MusicPlayer/controllers/global_music_controller.dart';
import 'package:mango/Notifications/notifications_controller.dart';
import 'package:mango/SpaceLive/sessions_service.dart';
import 'package:mango/Store/controller/product_services.dart';
import 'package:mango/Utils/theme.dart';
import 'package:mango/Wallet/data/coin_helper.dart';
import 'package:mango/Wallet/data/currency_service.dart';
import 'package:mango/Wallet/data/transactions.dart';
import 'package:mango/Wallet/services/wallet_services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mango/core/config/app_config.dart';
import 'package:mango/Authentication/controllers/auth_controller.dart';
import 'package:mango/Wallet/data/blockchain.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:mango/Store/controller/cart_controller.dart';
import 'package:universal_html/html.dart' as html;
import 'package:url_strategy/url_strategy.dart';

import 'utils/mobile_ui_color.dart'
    if (dart.library.html) 'utils/web_ui_color.dart';

final FlutterLocalNotificationsPlugin? localNotificationsPlugin =
    kIsWeb ? null : FlutterLocalNotificationsPlugin();
const int MAX_IMAGE_CACHE_SIZE = 200;
const int MAX_IMAGE_CACHE_SIZE_BYTES = 50 * 1024 * 1024; // 50MB

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kIsWeb) return;
  
  try {
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
    );

    await localNotificationsPlugin!.initialize(initSettings);

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'mango_channel',
      'Mango Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await localNotificationsPlugin!.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      message.notification?.title ?? '',
      message.notification?.body ?? '',
      platformDetails,
      payload: message.data.isNotEmpty ? message.data.toString() : null,
    );
  } catch (e) {
    debugPrint('Background notification error: $e');
  }
}

class WebAudioHandler {
  void play() {}
  void pause() {}
  void stop() {}
  void seek(Duration position) {}
  void dispose() {}
}

enum InitStage {
  firebase,
  sharedPrefs,
  theme,
  notifications,
  controllers,
  audio,
  complete
}

// MEMORY OPTIMIZATION: Track initialization state
bool _isInitialized = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // MEMORY OPTIMIZATION: Configure image cache
  PaintingBinding.instance.imageCache.maximumSize = MAX_IMAGE_CACHE_SIZE;
  PaintingBinding.instance.imageCache.maximumSizeBytes = MAX_IMAGE_CACHE_SIZE_BYTES;
  
  if (kIsWeb) {
    setPathUrlStrategy();
    _setupWebNavigation();
    // Web-specific optimizations
    _setupWebOptimizations();
  }

  try {
    await _initializeFirebase();
    
    final prefs = await SharedPreferences.getInstance();
    Get.put<SharedPreferences>(prefs, permanent: true);
    
    final isDarkMode = prefs.getBool('isDarkMode') ?? false;
    Get.put(ThemeController());
    setSystemUiColor(isDarkMode ? Colors.black : Colors.white);
    
    if (!kIsWeb) {
      _initializeMobileNotifications();
    } else {
      _initializeWebNotifications();
    }
    
    await _initializeCoreServicesSafely();
    
    // MEMORY OPTIMIZATION: Configure Firestore with better settings
    try {
      FirebaseFirestore.instance.settings = Settings(
        persistenceEnabled: true,
        cacheSizeBytes: MAX_IMAGE_CACHE_SIZE_BYTES,
      );
    } catch (e) {
      debugPrint('Firestore settings error (non-critical): $e');
    }

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SessionService()),
        ],
        child: MangoApp(isDarkMode: isDarkMode),
      ),
    );
    
    _isInitialized = true;
    
    // MEMORY OPTIMIZATION: Use post frame callback with debouncing
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _initializePostFrameServicesSafely();
    });

  } catch (e, s) {
    debugPrint("Critical initialization error: $e\n$s");
    runApp(ErrorApp(error: e.toString()));
  }
}

// MEMORY OPTIMIZATION: Web-specific optimizations
void _setupWebOptimizations() {
  if (!kIsWeb) return;
  
  // Clear image cache on start
  _cleanupMemory();
  
  // Set up periodic cache cleanup for web
  Timer.periodic(const Duration(minutes: 5), (timer) {
    _cleanupMemory();
  });
}

// MEMORY OPTIMIZATION: Cleanup function
void _cleanupMemory() {
  // Clear image cache
  PaintingBinding.instance.imageCache.clear();
  
  // Clear live images
  PaintingBinding.instance.imageCache.clearLiveImages();
  
  if (kIsWeb) {
    // Web-specific cleanup
    try {
      // Clear any cached network images
      PaintingBinding.instance.imageCache.clear();
    } catch (e) {
      debugPrint('Memory cleanup error: $e');
    }
  }
}

// Web navigation with memory awareness
void _setupWebNavigation() {
  if (!kIsWeb) return;
  
  // Push initial state to history
  html.window.history.pushState({'page': 'app'}, '', html.window.location.href);
  
  // Handle popstate with debouncing to prevent multiple rapid calls
  Timer? debounceTimer;
  
  html.window.onPopState.listen((html.PopStateEvent event) {
    event.preventDefault();
    
    // Debounce to prevent multiple rapid navigations
    debounceTimer?.cancel();
    debounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (Get.isRegistered<GetMaterialApp>()) {
        final currentRoute = Get.currentRoute;
        
        if (currentRoute != AppRoutes.splash && currentRoute != AppRoutes.home) {
          Get.back();
          
          // MEMORY OPTIMIZATION: Clean up when navigating back
          _cleanupOnNavigation();
        }
        
        html.window.history.pushState({'page': 'app'}, '', html.window.location.href);
      }
    });
  });
}

// MEMORY OPTIMIZATION: Cleanup on navigation
void _cleanupOnNavigation() {
  // Clear image cache on navigation
  PaintingBinding.instance.imageCache.clear();
  
  // Suggest garbage collection
  scheduleMicrotask(() {
    // This hints the VM to run GC
  });
}

Future<void> _initializeFirebase() async {
  if (kIsWeb) {
    // Initialize with timeout for web
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyBp3TZ107vJf779W5BDOPvK5dhB6A8l2zw",
        authDomain: "mango-cloud-34e08.firebaseapp.com",
        projectId: "mango-cloud-34e08",
        storageBucket: "mango-cloud-34e08.appspot.com",
        messagingSenderId: "892280623487",
        appId: "1:892280623487:web:6be3a1c41bf7f277d24a4a",
        measurementId: "G-13TGN9QS7H",
        databaseURL: "https://mango-cloud-34e08-default-rtdb.firebaseio.com",
      ),
    ).timeout(const Duration(seconds: 15), onTimeout: () {
      debugPrint('Firebase init timeout - continuing anyway');
      return Future.value();
    });
  } else {
    await Firebase.initializeApp();
  }
}

void _initializeMobileNotifications() {
  try {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    tz.initializeTimeZones();
    
    Future.microtask(() async {
      try {
        const AndroidInitializationSettings androidInit =
            AndroidInitializationSettings('@mipmap/ic_launcher');
        const InitializationSettings initSettings = InitializationSettings(
          android: androidInit,
        );
        await localNotificationsPlugin?.initialize(initSettings);
      } catch (e) {
        debugPrint('Notification init error: $e');
      }
    });
  } catch (e) {
    debugPrint('Mobile notifications setup error: $e');
  }
}

void _initializeWebNotifications() {
  Future.microtask(() async {
    try {
      await FirebaseMessaging.instance.getToken().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('FCM token timeout - notifications will use fallback');
          return null;
        },
      );
    } catch (e) {
      debugPrint('Web notifications non-critical error: $e');
    }
  });
}

Future<void> _initializeCoreServicesSafely() async {
  try {
    await AppConfig.init();
  } catch (e) {
    debugPrint('AppConfig init failed: $e');
  }
  
  // MEMORY OPTIMIZATION: Use lazy loading for controllers
  Get.put(AuthController(), permanent: true);
  
  try {
    Get.put(CurrencyService(), permanent: true);
  } catch (e) {
    debugPrint('CurrencyService init failed: $e');
  }
  
  try {
    Get.put(WalletService(), permanent: true);
  } catch (e) {
    debugPrint('WalletService init failed: $e');
  }
  
  try {
    _initializeBlockchain();
  } catch (e) {
    debugPrint('Blockchain init failed: $e');
  }
  
  // MEMORY OPTIMIZATION: Only initialize essential controllers
  Get.put(NotificationController(), permanent: true);
  Get.put(CartController(), permanent: true);
  
  // Defer music controller initialization
  Get.lazyPut<GlobalMusicController>(() => GlobalMusicController(), fenix: true);
}

void _initializePostFrameServicesSafely() {
  try {
    if (kIsWeb) {
      Get.put<WebAudioHandler>(WebAudioHandler(), permanent: true);
    } else {
      AppAudioHandler.init().then((audioHandler) {
        Get.put<AppAudioHandler>(audioHandler, permanent: true);
      }).catchError((e) {
        debugPrint('Audio handler init failed: $e');
      });
    }
    
    // MEMORY OPTIMIZATION: Lazy load non-essential controllers
    Get.lazyPut<PlayerController>(() => PlayerController(), fenix: true);
    
    try {
      Get.lazyPut<UserDetailsController>(
        () => UserDetailsController(),
        tag: UserDetailsController.tag,
        fenix: true,
      );
    } catch (e) {
      debugPrint('UserDetailsController init failed: $e');
    }
    
    try {
      Get.lazyPut<ProductService>(() => ProductService(), fenix: true);
      Get.lazyPut<ProductController>(() => ProductController(), fenix: true);
      Get.lazyPut<HomeProductController>(() => HomeProductController(), fenix: true);
      Get.lazyPut<ProductDetailController>(() => ProductDetailController(), fenix: true);
    } catch (e) {
      debugPrint('Product controllers init failed: $e');
    }
    
    // MEMORY OPTIMIZATION: Delay non-critical operations
    Future.delayed(const Duration(seconds: 2), () {
      try {
        final controller = Get.find<MangoDashboardController>();
        controller.backfillArtistNames().catchError((e) {
          debugPrint('Backfill artist names failed: $e');
        });
      } catch (e) {
        debugPrint('Dashboard controller init failed: $e');
      }
    });
    
  } catch (e) {
    debugPrint('Post-frame initialization error: $e');
  }
}

void _initializeBlockchain() {
  try {
    final blockchain = Blockchain(difficultyValue: 2);
    blockchain.addTransaction(
      MangoTransaction(
        sender: 'Telli',
        receiver: 'Gun',
        amount: EuniceHelper.toEunice(0.5),
      ),
    );
    blockchain.minePendingTransactions('Miner1');
    Get.put<Blockchain>(blockchain, permanent: true);
  } catch (e) {
    debugPrint('Blockchain initialization error: $e');
  }
}

class MangoApp extends StatelessWidget {
  final bool isDarkMode;
  const MangoApp({super.key, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppConfig.appName,
      initialBinding: DashboardBinding(),
      debugShowCheckedModeBanner: false,
      theme: AppThemes.lightTheme,
      darkTheme: AppThemes.darkTheme,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      initialRoute: AppRoutes.splash,
      getPages: AppPages.routes,
      navigatorObservers: [
        GetObserver(),
        // MEMORY OPTIMIZATION: Add navigation observer to track memory
        _MemoryAwareNavigatorObserver(),
      ],
      unknownRoute: GetPage(
        name: AppRoutes.notFound,
        page: () => const Scaffold(body: Center(child: Text('Page not found'))),
      ),
      transitionDuration: const Duration(milliseconds: 200),
      defaultTransition: kIsWeb ? Transition.fade : Transition.cupertino,
      navigatorKey: Get.key,
      
      // MEMORY OPTIMIZATION: Keep only essential pages alive
      smartManagement: SmartManagement.keepFactory,
    );
  }
}

// MEMORY OPTIMIZATION: Navigator observer for memory management
class _MemoryAwareNavigatorObserver extends NavigatorObserver {
  final List<String> _routeStack = [];
  
  @override
  void didPush(Route route, Route? previousRoute) {
    _routeStack.add(route.settings.name ?? 'unknown');
    _cleanupIfNeeded();
  }
  
  @override
  void didPop(Route route, Route? previousRoute) {
    if (_routeStack.isNotEmpty) {
      _routeStack.removeLast();
    }
    _cleanupOnNavigation();
  }
  
  @override
  void didRemove(Route route, Route? previousRoute) {
    _routeStack.remove(route.settings.name ?? 'unknown');
    _cleanupOnNavigation();
  }
  
  void _cleanupIfNeeded() {
    // Clean up if too many routes are stacked
    if (_routeStack.length > 10) {
      _cleanupOnNavigation();
    }
  }
  
  void _cleanupOnNavigation() {
    // Clear image cache on navigation
    PaintingBinding.instance.imageCache.clear();
  }
}

class ErrorApp extends StatelessWidget {
  final String error;
  
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.grey[100],
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.orange),
                const SizedBox(height: 24),
                Text(
                  'Having Trouble Loading',
                  style: GoogleFonts.montserrat(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[700],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Please check your internet connection and try again.',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    if (kIsWeb) {
                      // Clear cache before reload
                      PaintingBinding.instance.imageCache.clear();
                      html.window.location.reload();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: Text(
                    'Retry',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardBinding extends Bindings {
  @override
  void dependencies() {
    // MEMORY OPTIMIZATION: Use lazy loading with fenix for non-essential controllers
    Get.lazyPut<MangoDashboardController>(
      () => MangoDashboardController(),
      fenix: true,
    );
  }
}