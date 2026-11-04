import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/AccountSetup/add_description.dart';
import 'package:mango/AccountSetup/add_friends.dart';
import 'package:mango/AccountSetup/biodata_page.dart';
import 'package:mango/AccountSetup/interests.dart';
import 'package:mango/App/router/app_routes.dart';
import 'package:mango/Authentication/screens/forgotPassword.dart';
import 'package:mango/Authentication/screens/phoneSignIn.dart';

import 'package:mango/Authentication/screens/authentication.dart';
import 'package:mango/Authentication/screens/otp_screen.dart';
import 'package:mango/Authentication/screens/signin.dart';
import 'package:mango/Authentication/screens/signup.dart';
import 'package:mango/Home/pages/open_pages/genre_details_page.dart';
import 'package:mango/Home/pages/open_pages/marketplace.dart';

import 'package:mango/Onboarding/explainer.dart';
import 'package:mango/Onboarding/onboarding.dart';

import 'package:mango/Home/home.dart';
import 'package:mango/Home/pages/open_pages/book_home.dart';
import 'package:mango/Home/pages/open_pages/music_home.dart';

import 'package:mango/Books/screens/home_screen.dart';

import 'package:mango/Spaces/screens/new_space.dart';
import 'package:mango/Spaces/screens/space_home.dart';
import 'package:mango/Spaces/screens/space_pods/space_library.dart';
import 'package:mango/Spaces/screens/space_pods/space_louge.dart';
import 'package:mango/Spaces/screens/space_pods/space_music.dart';
import 'package:mango/Spaces/screens/space_pods/space_podcasts.dart';
import 'package:mango/Spaces/screens/space_pods/space_vines.dart';
import 'package:mango/Spaces/screens/space_pods/space_shop.dart';

import 'package:mango/Splash/settings.dart';
import 'package:mango/Store/controller/store_controller.dart';
import 'package:mango/Store/screens/cart_screen.dart';

import 'package:mango/Store/screens/general_store.dart';

import 'package:mango/Splash/splash_screen.dart';
import 'package:mango/Store/screens/order_confirmation_screen.dart';
import 'package:mango/Store/screens/product_detail_screen.dart';
import 'package:mango/Store/storefront.dart';

class AppPages {
  static final List<GetPage> routes = [
    GetPage(name: AppRoutes.splash, page: () => const SplashScreen()),
    GetPage(name: AppRoutes.onboarding, page: () => const OnBoard()),
    GetPage(name: AppRoutes.welcome, page: () => const Authenticate()),
    GetPage(name: AppRoutes.settings, page: () => const SettingsScreen()),
    GetPage(name: AppRoutes.login, page: () => const LoginPage()),
    GetPage(name: AppRoutes.signup, page: () => const SignUpPage()),
    GetPage(name: AppRoutes.forgotPassword, page: () => ForgotPasswordScreen()),
    GetPage(
      name: AppRoutes.phoneForgotPassword,
      page: () => PhoneNumberForgotPasswordScreen(),
    ),
    GetPage(name: AppRoutes.otp, page: () => OTPScreen()),
    GetPage(name: AppRoutes.phoneSignUp, page: () => const PhoneSignInScreen()),
    GetPage(name: AppRoutes.verification, page: () => VerificationScreen()),
    GetPage(name: AppRoutes.makeFriends, page: () => const MakeFriends()),
    GetPage(name: AppRoutes.interests, page: () => const Interests()),
    GetPage(name: AppRoutes.explainer, page: () => const Explainer()),
    GetPage(name: AppRoutes.addDetails, page: () => const AddDetails()),
    GetPage(name: AppRoutes.bioData, page: () => const BioDataPage()),
    GetPage(name: AppRoutes.home, page: () => MangoHome()),
    GetPage(name: AppRoutes.bookStore, page: () => BookStore()),
    GetPage(
      name: AppRoutes.storeFront,
      page: () => const StoreFront(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => StoreController());
      }),
    ),
    GetPage(
      name: AppRoutes.shop,
      page: () => ShopScreen(
        vendorId: Get.parameters['vendorId'] ?? '',
        vendorName: Get.parameters['vendorName'] ?? '',
      ),
    ),
    GetPage(
      name: AppRoutes.productDetail,
      page: () {
        final productId = Get.parameters['productId'];
        if (productId != null && productId.isNotEmpty) {
          return ProductDetailScreen(productId: productId);
        }
        return const SizedBox.shrink();
      },
    ),
    GetPage(name: AppRoutes.cart, page: () => const CartScreen()),
    GetPage(
      name: AppRoutes.orderConfirmation,
      page: () =>
          OrderConfirmationScreen(orderId: Get.parameters['orderId'] ?? ''),
    ),
    GetPage(name: AppRoutes.spaceHome, page: () => SpaceHomeScreen()),
    GetPage(name: AppRoutes.spaceLibrary, page: () => SpaceLibrary()),
    GetPage(name: AppRoutes.spaceMusic, page: () => SpaceMusic()),
    GetPage(name: AppRoutes.spaceVines, page: () => SpaceVines()),
    GetPage(name: AppRoutes.spacePodcasts, page: () => SpacePodcasts()),
    GetPage(name: AppRoutes.spaceShop, page: () => SpaceShop()),
    GetPage(name: AppRoutes.spaceLounge, page: () => SpaceLounge()),
    GetPage(name: AppRoutes.newSpace, page: () => NewSpaceScreen()),
    GetPage(name: AppRoutes.musicHome, page: () => MusicHomePage()),
    GetPage(name: AppRoutes.libraryHome, page: () => BookHomePage()),
    GetPage(name: AppRoutes.marketplace, page: () => MarketPlace()),
    GetPage(
      name: '/genre-detail',
      page: () {
        final arguments = Get.arguments as Map<String, dynamic>;
        return GenreDetailPage(
          genreName: arguments['genreName'],
          genreEmoji: arguments['genreEmoji'],
          genreColor: Color(arguments['genreColor']),
          genreDescription: arguments['genreDescription'],
        );
      },
    ),
  ];
}
