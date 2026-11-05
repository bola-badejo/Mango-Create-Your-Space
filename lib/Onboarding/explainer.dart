import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class Explainer extends StatefulWidget {
  const Explainer({super.key});

  @override
  _ExplainerState createState() => _ExplainerState();
}

class _ExplainerState extends State<Explainer> {
  final PageController _pageController = PageController(initialPage: 1);
  int _currentPage = 1;

  final List<String> onboardingMessages = [
    'Craft your haven, effortlessly managing music, books, and curated content in a seamless, personalized digital space.',
    'Embark on a journey through tailored music, books, vines, and more, precisely filtered to suit your refined taste.',
    'Immerse yourself in a symphony of connection. Engage with posts, updates, and vines from friends and followers, harmonizing your online experience.'
  ];

  final List<String> onboardingHeaderMessages = [
    'Your Space',
    'Discover',
    'Feeds'
  ];

  final List<String> onboardingSwipeMessages = [
    'Swipe left',
    'Swipe left or right',
    'Swipe right'
  ];

  final List<String> onboardingImages = [
    'asset/images/ob_bg_0.png',
    'asset/images/ob_bg_1.png',
    'asset/images/ob_bg_2.png'
  ];

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Mango Tour Guide.',
          style: TextStyle(color: Colors.white),
        ),
        leading: TextButton(
          onPressed: () {
            _showMenu(context);
          },
          child: const Icon(
            Icons.menu,
            color: Colors.white,
            size: 30,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0.0,
        actions: [
          TextButton(
            onPressed: () {
              Get.offNamed('/welcome');
            },
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                Icons.skip_next,
                color: Colors.white,
                size: 15,
              ),
              SizedBox(
                width: 5.0,
              ),
              Text(
                "Skip",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(
                width: 10.0,
              ),
            ]),
          )
        ],
      ),
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            children: [
              
              Container(
                padding: const EdgeInsets.all(15),
                height: size.height,
                color: Colors.red.shade600,
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: (size.height / 10) * 1.5,
                      ),
                      Image.asset(
                          onboardingImages[_currentPage],
                          height: (size.height / 10) * 3.8,
                          width: size.width,
                          fit:BoxFit.contain
                      ),
                      SizedBox(
                        height: (size.height / 10) * .1,
                      ),
                      SizedBox(
                        width: size.width/1.2,
                        
                        child: Text(
                          onboardingHeaderMessages[_currentPage],
                          textAlign: TextAlign.start,
                          style: const TextStyle(
                            fontSize: 45,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: (size.height / 10) * .6,
                      ),
                      SizedBox(
                        width: size.width/1.2,
                        
                        child: Text(
                          onboardingMessages[_currentPage],
                          textAlign: TextAlign.start,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: (size.height / 10) * .6,
                      ),
                      SizedBox(
                        width: size.width/.8,
                        
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                onboardingSwipeMessages[_currentPage],
                                textAlign: TextAlign.start,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 5),

                              const Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.white,
                                size: 15,
                              ),
                              const Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.white,
                                size: 15,
                              ),
                              const Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.white,
                                size: 15,
                              ),
                            ]
                        ),
                      ),
                      SizedBox(
                        height: (size.height / 10) * .6,
                      ),
                    ]
                ),
              ),
              Container(
                padding: const EdgeInsets.all(15),
                color: MangoPalette.green800,
                height: size.height,
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: (size.height / 10) * 1.5,
                      ),
                      Image.asset(
                          onboardingImages[_currentPage],
                          height: (size.height / 10) * 3.8,
                          width: size.width,
                          fit:BoxFit.contain
                      ),
                      SizedBox(
                        height: (size.height / 10) * .1,
                      ),
                      SizedBox(
                        width: size.width/1.2,
                        
                        child: Text(
                          onboardingHeaderMessages[_currentPage],
                            textAlign: TextAlign.start,
                            style: const TextStyle(
                              fontSize: 45,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                      ),
                      SizedBox(
                        height: (size.height / 10) * .6,
                      ),
                      SizedBox(
                        width: size.width/1.2,
                        
                        child: Text(
                          onboardingMessages[_currentPage],
                            textAlign: TextAlign.start,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: Colors.white,
                            ),
                          ),
                      ),
                      SizedBox(
                        height: (size.height / 10) * .6,
                      ),
                      SizedBox(
                        width: size.width/.8,
                        
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                                Icons.arrow_back_ios_new,
                                color: Colors.white,
                                size: 15,
                              ),
                            const Icon(
                                Icons.arrow_back_ios_new,
                                color: Colors.white,
                                size: 15,
                              ),
                            const Icon(
                                Icons.arrow_back_ios_new,
                                color: Colors.white,
                                size: 15,
                              ),

                            const SizedBox(width: 5),

                            Text(
                                onboardingSwipeMessages[_currentPage],
                                  textAlign: TextAlign.start,
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white,
                                    ),
                                ),
                                const SizedBox(width: 5),

                                const Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.white,
                                  size: 15,
                                ),
                            const Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.white,
                                  size: 15,
                                ),
                            const Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.white,
                                  size: 15,
                                ),
                            ]
                          ),
                      ),
                      SizedBox(
                        height: (size.height / 10) * .6,
                      ),
                    ]
                ),
              ),
              Container(
                padding: const EdgeInsets.all(15),
                color: MangoPalette.green700,
                height: size.height,
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: (size.height / 10) * 1.5,
                      ),
                      Image.asset(
                          onboardingImages[_currentPage],
                          height: (size.height / 10) * 3.8,
                          width: size.width,
                          fit:BoxFit.contain
                      ),
                      SizedBox(
                        height: (size.height / 10) * .1,
                      ),
                      SizedBox(
                        width: size.width/1.2,
                        
                        child: Text(
                          onboardingHeaderMessages[_currentPage],
                          textAlign: TextAlign.start,
                          style: const TextStyle(
                            fontSize: 45,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: (size.height / 10) * .6,
                      ),
                      SizedBox(
                        width: size.width/1.2,
                        
                        child: Text(
                          onboardingMessages[_currentPage],
                          textAlign: TextAlign.start,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: (size.height / 10) * .6,
                      ),
                      SizedBox(
                        width: size.width/.8,
                        
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.arrow_back_ios_new,
                                color: Colors.white,
                                size: 15,
                              ),
                              const Icon(
                                Icons.arrow_back_ios_new,
                                color: Colors.white,
                                size: 15,
                              ),
                              const Icon(
                                Icons.arrow_back_ios_new,
                                color: Colors.white,
                                size: 15,
                              ),

                              const SizedBox(width: 5),

                              Text(
                                onboardingSwipeMessages[_currentPage],
                                textAlign: TextAlign.start,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white,
                                ),
                              ),
                            ]
                        ),
                      ),
                      SizedBox(
                        height: (size.height / 10) * .6,
                      ),
                    ]
                ),
              ),
            ],
          ),
          const Positioned(
              top: 100,
              left: 20,
              child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.upgrade_sharp,
                size: 20,
              ),
              SizedBox(width: 5),
              Text(
                "Tap to view menu",
                style: TextStyle(
                  color: Colors.white,
                  fontSize:16
                )
              )
            ],
          )),
        ],
      )
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SizedBox(
          width: double.infinity,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildIconButton(context, Icons.home, 'Home', "gives you access to music, books, vines, updates, your space and more.", "asset/images/mhom.png"),
              _buildIconButton(context, Icons.mail, 'Conversations', "stay in touch. Send realtime messages to your friends", "asset/images/mconv.png"),
              _buildIconButton(context, Icons.notification_add, 'Notifications', "be up-to-date. get realtime notifications of events and happenings on around you.", "asset/images/mnot.png"),
              _buildIconButton(context, Icons.person, 'Profile', "manage and customize your account. This is your Space.", "asset/images/mprof.png"),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIconButton(BuildContext context, IconData icon, String text, String textSubtitle, String image) {
    return IconButton(
      icon: Icon(icon, size: 40,),
      onPressed: () {
        _showImageCard(context, text, textSubtitle, image);
      },
    );
  }

  void _showImageCard(BuildContext context, String text, String textSubtitle, String image) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25)
                ),
                child: Column(
                  children: [
                    Text(
                      text,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      textSubtitle,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Image.asset(
                      image,
                      height: 500,
                      fit: BoxFit.fitHeight,
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
        tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToPage(int pageIndex) {
    _pageController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _navigateToHome() {
    Get.offNamed('/explainer');
  }
}
