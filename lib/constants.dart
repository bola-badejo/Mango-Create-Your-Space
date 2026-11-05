import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'Authentication/controllers/auth_controller.dart';
import 'package:mango/Core/design_system/mango_ui.dart';

String API_KEY = "AIzaSyAm09dvA3oZ0B-Ve5nxuwStUoi2wCigKNg";

AuthController authController = AuthController.instance;
final Future<FirebaseApp> firebaseInitialization = Firebase.initializeApp();
FirebaseAuth auth = FirebaseAuth.instance;
FirebaseFirestore firebaseFirestore = FirebaseFirestore.instance;
GoogleSignIn googleSign = GoogleSignIn.instance;

Color kCoral = const Color(0xFF369365);
Color kCoralMono = const Color(0xFF28734F);
Color kCoralComp = const Color(0xFF43C0FF);
Color kKhaki = const Color(0xFFFFFC59);
Color kKhakiMono = const Color(0xFFD9D506);
Color kKhakiComp = const Color(0xFF595CFF);
Color kGoldComp = const Color(0xFF2460FF);
Color kGold = const Color(0xFFFFC324);
Color kGoldMono = const Color(0xFFF0AE00);
Color kMidSeaGreen = const Color(0xFF369365);
Color kMidSeaGreenComp = const Color(0xFF369365);
Color kMidSeaGreenMono = const Color(0xFF5FBF8A);


Color kDeepBlue = const Color(0xFF2460FF);
Color kDeepBlueMono = const Color(0xFF0041CC);
Color kDeepBlueComp = const Color(0xFF369365);

Color kPurple = const Color(0xFF8A2BE2);
Color kPurpleMono = const Color(0xFF7B1FD6);
Color kPurpleComp = const Color(0xFFE2BE2B);

Color kTeal = const Color(0xFF20B2AA);
Color kTealMono = const Color(0xFF1A9C95);
Color kTealComp = const Color(0xFFB22029);

Color kRose = const Color(0xFFFF66B2);
Color kRoseMono = const Color(0xFFFF3385);
Color kRoseComp = const Color(0xFF66FFB2);

Color kSlate = const Color(0xFF6A7F93);
Color kSlateMono = const Color(0xFF5A6F83);
Color kSlateComp = const Color(0xFF937A6A);

const apiKey = "8f87d6f2801b0c7e61ea62a63731e05d8a4e3de48720b5bc29ca0d62276a8eb596899537edd9d2b1";

const white = Color(0xffffffff);
const grey = Color(0xffc4c4c4);
const mkk = Colors.white;
const priMangoOrange = Color(0xFF369365);
const priMangoOrangeAccent = Color(0xFF5FBF8A);
const kBlueColor = Color(0xFF6E8AFA);
const kBestSellerColor = Color(0xFFFFD073);
const kGreenColor = Color(0xFF49CC96);


const headingextStyle = TextStyle(
  fontSize: 30,
  fontWeight: FontWeight.w900,
  height: 1.5,
);

const splashText2 = TextStyle(
  fontSize: 50,
  fontWeight: FontWeight.bold,
  height: 0.7857142857142857,
);
const splashText = TextStyle(
  fontSize: 70,
  fontWeight: FontWeight.bold,
  height: 0.7857142857142857,
);

const bodyText = TextStyle(
  fontSize: 12,
  
);

const bodyText2 = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w300,
  
);

const profileLabel = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w100,);

const profileText = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w700,
  
);

const kSubheadingextStyle = TextStyle(
  fontSize: 24,
  
);

const kTitleTextStyle = TextStyle(
  fontSize: 20,
  
  fontWeight: FontWeight.bold,
);

const kSubtitleTextStyle = TextStyle(
  fontSize: 18,
  
  
);

const textBoxText = TextStyle(
  fontSize: 16,
  
  fontWeight: FontWeight.w900,
);

const textBoxHint = TextStyle(
  
  fontWeight: FontWeight.w300,
);

const postTextBoxText2 = TextStyle(
  fontSize: 22,
  
  fontWeight: FontWeight.w600,
);

const postTextBoxText3 = TextStyle(
  fontSize: 18,
  
  fontWeight: FontWeight.w600,
);
const postTextBoxText4 = TextStyle(
  fontSize: 18,
  
  fontWeight: FontWeight.w800,
);


const postTextBoxText = TextStyle(
  fontSize: 16,
  
  fontWeight: FontWeight.w600,
);

const postTextBoxHint = TextStyle(
  
  fontWeight: FontWeight.w300,
);

const widgetTitleText = TextStyle(
  fontSize: 24,
  
  letterSpacing: 0.24,
  fontWeight: FontWeight.w700,
);

const widgetTitleText2 = TextStyle(
  fontSize: 20,
  
  letterSpacing: 0.24,
  fontWeight: FontWeight.w700,
);

const widgetSubtitleText = TextStyle(
  fontSize: 14,
  
  letterSpacing: 0.24,
);

const widgetSubtitleText2 = TextStyle(
  fontSize: 16,
  
  letterSpacing: 0.24,
);

const inactivewidgetTitleText = TextStyle(
  fontSize: 14,
  
  letterSpacing: 0.24,
  fontWeight: FontWeight.w400,
);

const bioCardText = TextStyle(
  fontSize: 12,
  
);

const userNameCardText = TextStyle(
  fontSize: 12,
  
);

const displayNameCardText = TextStyle(
  fontSize: 12,
  
  fontWeight: FontWeight.w700,
);

const likesCardText = TextStyle(
  fontSize: 12,
  
  letterSpacing: 0.07200000000000001,
);

const profileBio = TextStyle(
  fontSize: 12,
  
  fontWeight: FontWeight.w700,
);

const postLabel = TextStyle(
  fontSize: 12,
  
  
);

const postSTat = TextStyle(
  fontSize: 26,
  
  fontWeight: FontWeight.w800,
);

const textBody = TextStyle(
  fontSize: 14,
);

const textBody2 = TextStyle(
  fontSize: 12,
);
const playlistCardStat  = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800
);

const textBody3 = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w600,
);

const textHeading = TextStyle(
  fontSize: 30,
  
  fontWeight: FontWeight.w900,
);

const textHeader = TextStyle(
  fontSize: 50,
  fontWeight: FontWeight.w900,
  height: 1.1,
);


const textHeader2 = TextStyle(
  fontSize: 20,
  
  fontWeight: FontWeight.w900,
);

const labelBody = TextStyle(
  fontSize: 14,
  
  fontWeight: FontWeight.w500,
);

const labelBody_ = TextStyle(
  fontSize: 14,
  
  fontWeight: FontWeight.w500,
);

const labelBody2 = TextStyle(
  fontSize: 16,
  
  fontWeight: FontWeight.w500,
);

const labelBody3 = TextStyle(
  fontSize: 16,
  
  fontWeight: FontWeight.w500,
);

const labelBody4 = TextStyle(
  fontSize: 24,
  
  fontWeight: FontWeight.w900,
);

const genreText = TextStyle(
  fontSize: 16,
  letterSpacing: 1.3,
  
  shadows: <Shadow>[
    Shadow(
      offset: Offset(0.0, 0.0),
      blurRadius: 9.0,
      
    ),
  ],
  fontWeight: FontWeight.w900,
);

const widgetLabelText = TextStyle(
  fontSize: 20,
  
  letterSpacing: 0.24,
  fontWeight: FontWeight.w700,
);

const selectorText = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w900,
);

bool isVisible = false;

Widget? appbar(){
  Scaffold(
    appBar: AppBar(
      
      shadowColor: Colors.transparent,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: MangoPressable(
        semanticLabel: 'Menu',
          onTap: () => visibility(isVisible),
          child: const Icon(Icons.menu),
        ),
      ),

      title: SizedBox(
          width: 500,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Visibility(
                visible: isVisible,
                child: const Icon(Icons.home_filled, size: 30,),
              ),
              const SizedBox(width: 40),
              Visibility(
                visible: isVisible,
                child: const Icon(Icons.my_library_music, size: 30,),
              ),
              const SizedBox(width: 40),
              Visibility(
                visible: isVisible,
                child: const Icon(Icons.mail_rounded, size: 30,),
              ),
              const SizedBox(width: 40),
              Visibility(
                visible: isVisible,
                child: const Icon(Icons.notifications, size: 30,),
              ),
              const SizedBox(width: 40),
              Visibility(
                visible: isVisible,
                child: InkWell(
                    child: const Icon(
                      Icons.person,
                      size: 30,
                    ), onTap: (){

                }
                ),
              ),
            ],
          )
      ),

    ),
  );
  return null;
}

bool visibility(isVisible){
  isVisible = !isVisible;
  return isVisible;
}



class Dimensions extends StatelessWidget {
  const Dimensions({super.key});


  @override
  Widget build(BuildContext context) {
    return Container();
  }
}


