import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/AccountSetup/user_detail/user_detail_controller.dart';
import 'package:mango/AccountSetup/user_detail/widgets/navigation_buttons.dart';
import 'package:mango/AccountSetup/user_detail/widgets/step1_profile.dart';
import 'package:mango/AccountSetup/user_detail/widgets/step2_personal.dart';
import 'package:mango/AccountSetup/user_detail/widgets/step3_contact.dart';
import 'package:mango/AccountSetup/user_detail/widgets/stepper_header.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mango/utils.dart';

class AddDetails extends StatefulWidget {
  const AddDetails({super.key});

  @override
  State<AddDetails> createState() => _AddDetailsState();
}

class _AddDetailsState extends State<AddDetails> {
  UserDetailsController _controller = Get.put(UserDetailsController());
  bool _isLoading = true;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
     Get.put(UserDetailsController(), tag: UserDetailsController.tag, permanent: true);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      print('AddDetails: Initializing...');

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('AddDetails: No user found, going to login');
        Get.offAllNamed('/login');
        return;
      }

      _controller = ControllerHelper.userDetailsController;
      print('AddDetails: Controller obtained');

      _controller?.currentStep.listen((step) {
        if (mounted) {
          setState(() {
            _currentStep = step;
          });
        }
      });

      print('AddDetails: Checking user data in Firestore');
      final user = await _controller!.userService.getUserInfoOnce(
        currentUser.uid,
      );

      if (user != null) {
        print('AddDetails: Existing user found, loading data');
        await _controller!.loadUserData(user);
      } else {
        print('AddDetails: New user, creating Firestore document');
        await _controller!.userService.initializeUserInFirestore(
          uid: currentUser.uid,
          email: currentUser.email,
          displayName: currentUser.displayName,
        );
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      print('AddDetails: Error in initialization: $e\n$stack');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      UtilsService().showSnackbar(
        'Error',
        'Failed to initialize. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        context: context,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _controller == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(semanticsLabel: 'Loading', 
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Setting up your profile...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Column(
          children: [
            StepperHeader(currentStep: _currentStep),

            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildStepContent(_currentStep),
                ),
              ),
            ),

            NavigationButtons(
              currentStep: _currentStep,
              controller: _controller!,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent(int step) {
    switch (step) {
      case 0:
        return Step1Profile();
      case 1:
        return Step2Personal();
      case 2:
        return Step3Contact(controller: _controller);
      default:
        return Container(
          alignment: Alignment.center,
          child: Text(
            'Invalid step',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        );
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
