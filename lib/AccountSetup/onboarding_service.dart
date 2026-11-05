// Where a signed-in person goes next, and the quick-start account calls.
//
// Every sign-in method (email, Google, Apple, phone) ends in
// [OnboardingService.continueAfterSignIn]: people who finished the quick
// start go home; everyone else gets the one-minute quick start. Older
// accounts that already have a name and username count as onboarded.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:mango/App/router/app_routes.dart';
import 'package:mango/Wallet/ledger/mango_ledger_client.dart';

import 'quick_start.dart';

class OnboardingService {
  OnboardingService._();
  static final OnboardingService instance = OnboardingService._();

  final _fn = MangoLedgerClient.instance;

  Future<bool> isOnboarded() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      final r = await _fn.call('accountStatus');
      return r['onboarded'] == true;
    } catch (_) {
      // Offline or functions not deployed yet: decide from the profile.
      try {
        final d = (await FirebaseFirestore.instance.collection('users').doc(user.uid).get()).data();
        return d != null && ((d['onboarding'] as Map?)?['completedAt'] != null || ('${d['username'] ?? ''}'.isNotEmpty && '${d['displayName'] ?? ''}'.isNotEmpty));
      } catch (_) {
        return false;
      }
    }
  }

  /// Sends the person to Home or to the quick start.
  Future<void> continueAfterSignIn() async {
    if (FirebaseAuth.instance.currentUser == null) {
      Get.offAllNamed(AppRoutes.welcome);
      return;
    }
    if (await isOnboarded()) {
      Get.offAllNamed(AppRoutes.home);
    } else {
      Get.offAll(() => const QuickStartScreen());
    }
  }

  Future<Map<String, dynamic>> checkUsername(String username) => _fn.call('accountCheckUsername', {'username': username});

  Future<String> suggestUsername(String name) async {
    try {
      return '${(await _fn.call('accountSuggestUsername', {'name': name}))['username'] ?? ''}';
    } catch (_) {
      final base = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      return base.length >= 3 ? base : 'mango${DateTime.now().millisecond}';
    }
  }

  Future<Map<String, dynamic>> onboard({required String displayName, required String username, List<String> interests = const [], String? photoUrl}) =>
      _fn.call('accountOnboard', {
        'displayName': displayName,
        'username': username,
        'interests': interests,
        if (photoUrl != null) 'photoUrl': photoUrl,
      });
}
