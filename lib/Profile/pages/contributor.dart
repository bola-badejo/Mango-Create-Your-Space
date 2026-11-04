import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mango/Utils/optimized_lists.dart';
import 'package:lottie/lottie.dart';

import '../../Contributors/contribute_content.dart';
import '../../Home/controllers/dashboard_controller.dart';
import '../../Models/customModel/user.dart';

class Contributors extends StatefulWidget {
  const Contributors({super.key});

  @override
  State<Contributors> createState() => _ContributorsState();
}

class _ContributorsState extends State<Contributors>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final MangoDashboardController controller = Get.put(
    MangoDashboardController(),
  );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  final List<Map<String, String>> options = [
    {
      'title': 'Distributor',
      'description':
          'Help spread Mango\'s content by sharing music, books, podcasts, and more. Earn commissions as you grow the community.',
      'image': 'asset/images/mango-5.jpg',
      'color': '0xFFFFC107',
    },
    {
      'title': 'Creator',
      'description':
          'Showcase your talent — upload your songs, books, podcasts, movies, and products. Connect with your audience and earn from your work.',
      'image': 'asset/images/mango-7.jpg',
      'color': '0xFFFB8C00',
    },
    {
      'title': 'Vendor',
      'description':
          'Sell your services or products directly on Mango. Reach a larger market and grow your brand effortlessly.',
      'image': 'asset/images/mango-3.jpg',
      'color': '0xFFFF5722',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return StreamBuilder<MangoUser>(
      stream: controller.getUserInfo(FirebaseAuth.instance.currentUser!.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: isDarkMode ? Colors.red[300] : Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading profile',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
            body: Center(
              child: Text(
                'No user data found',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ),
          );
        }

        var user = snapshot.data!;
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          extendBodyBehindAppBar: true,
          backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
          body: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hi Contributor!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Welcome to Mango\'s contributor space. Whether you\'re distributing, creating, or selling, there\'s a place for you to shine and grow.',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Contribute',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () {
                        if (user.isCreator ||
                            user.isVendor ||
                            user.isDistributor) {
                          
                          Map<String, dynamic> contributorData = {};
                          
                          
                          if (user.isCreator) {
                            contributorData = {
                              'fullName': user.displayName,
                              'stageName': user.creatorName,
                              'bio': user.bio,
                              'profileImageUrl': user.creatorImageUrl.isNotEmpty 
                                  ? user.creatorImageUrl 
                                  : user.profileImage,
                              'logoUrl': user.creatorLogoUrl,
                              'tags': user.hobbies,
                            };
                          } else if (user.isVendor) {
                            contributorData = {
                              'fullName': user.displayName,
                              'storeName': user.vendorName,
                              'bio': user.bio,
                              'profileImageUrl': user.vendorImageUrl.isNotEmpty 
                                  ? user.vendorImageUrl 
                                  : user.profileImage,
                              'logoUrl': user.vendorLogoUrl,
                              'tags': user.hobbies,
                            };
                          } else if (user.isDistributor) {
                            contributorData = {
                              'fullName': user.displayName,
                              'distributorLabel': user.distributorName,
                              'bio': user.bio,
                              'profileImageUrl': user.distributorImageUrl.isNotEmpty 
                                  ? user.distributorImageUrl 
                                  : user.profileImage,
                              'logoUrl': user.distributorLogoUrl,
                              'tags': user.hobbies,
                            };
                          }

                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      MagicBoxPage(
                                        contentData: user,
                                        contributorData: contributorData,
                                      ),
                              transitionsBuilder:
                                  (
                                    context,
                                    animation,
                                    secondaryAnimation,
                                    child,
                                  ) {
                                    const begin = Offset(1.0, 0.0);
                                    const end = Offset.zero;
                                    const curve = Curves.easeInOut;
                                    var tween = Tween(
                                      begin: begin,
                                      end: end,
                                    ).chain(CurveTween(curve: curve));
                                    var offsetAnimation = animation.drive(
                                      tween,
                                    );
                                    return SlideTransition(
                                      position: offsetAnimation,
                                      child: child,
                                    );
                                  },
                              transitionDuration: const Duration(
                                milliseconds: 300,
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Create a Contributor Account to access the Magic Box',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              backgroundColor: Colors.redAccent,
                              action: SnackBarAction(
                                label: 'Register',
                                textColor: Colors.white,
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder:
                                          (
                                            context,
                                            animation,
                                            secondaryAnimation,
                                          ) => ContributorRegistrationPage(
                                            title: 'Creator',
                                          ),
                                      transitionsBuilder:
                                          (
                                            context,
                                            animation,
                                            secondaryAnimation,
                                            child,
                                          ) {
                                            const begin = Offset(0.0, 1.0);
                                            const end = Offset.zero;
                                            const curve = Curves.easeInOut;
                                            var tween = Tween(
                                              begin: begin,
                                              end: end,
                                            ).chain(CurveTween(curve: curve));
                                            var offsetAnimation = animation
                                                .drive(tween);
                                            return SlideTransition(
                                              position: offsetAnimation,
                                              child: child,
                                            );
                                          },
                                      transitionDuration: const Duration(
                                        milliseconds: 400,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        }
                      },
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          return Container(
                            width: double.infinity,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Stack(
                              children: [
                                ShaderMask(
                                  shaderCallback: (bounds) {
                                    return LinearGradient(
                                      colors: isDarkMode
                                          ? [
                                              Colors.blueAccent.withOpacity(
                                                0.8,
                                              ),
                                              Colors.purpleAccent.withOpacity(
                                                0.8,
                                              ),
                                              Colors.orangeAccent.withOpacity(
                                                0.8,
                                              ),
                                            ]
                                          : [
                                              Colors.blueAccent,
                                              Colors.purpleAccent,
                                              Colors.orangeAccent,
                                            ],
                                      stops: [
                                        _controller.value - 0.2,
                                        _controller.value,
                                        _controller.value + 0.2,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      tileMode: TileMode.mirror,
                                    ).createShader(bounds);
                                  },
                                  blendMode: BlendMode.srcATop,
                                  child: Container(
                                    width: double.infinity,
                                    height: 90,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      color: isDarkMode
                                          ? Colors.grey[800]
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Lottie.asset(
                                        'asset/images/creator_.json',
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Magic Pod',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: isDarkMode
                                                    ? Colors.white
                                                    : Colors.black,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Flexible(
                                              child: Text(
                                                'Unlock infinite creativity and make magic happen!',
                                                textAlign: TextAlign.start,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  height: 1.1,
                                                  fontSize: 11,
                                                  color: isDarkMode
                                                      ? Colors.white70
                                                      : Colors.white,
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
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Divider(color: isDarkMode ? Colors.grey[700] : Colors.grey),
                    Text(
                      'Registration',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...options.map((item) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: double.infinity,
                              height: 200,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                image: DecorationImage(
                                  image: AssetImage(item['image']!),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.grey[800]!.withOpacity(.8)
                                    : Colors.black.withOpacity(.8),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        item['title']!,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 1.0,
                                          ),
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            onTap: () {
                                              bool isAlreadyRegistered = false;

                                              switch (item['title']!) {
                                                case "Creator":
                                                  isAlreadyRegistered =
                                                      user.isCreator;
                                                  break;
                                                case "Vendor":
                                                  isAlreadyRegistered =
                                                      user.isVendor;
                                                  break;
                                                case "Distributor":
                                                  isAlreadyRegistered =
                                                      user.isDistributor;
                                                  break;
                                              }

                                              if (isAlreadyRegistered) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'You are already registered as a ${item['title']!}',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    backgroundColor:
                                                        Colors.redAccent,
                                                  ),
                                                );
                                              } else {
                                                Navigator.push(
                                                  context,
                                                  PageRouteBuilder(
                                                    pageBuilder:
                                                        (
                                                          context,
                                                          animation,
                                                          secondaryAnimation,
                                                        ) => ContributorRegistrationPage(
                                                          title: item['title']!,
                                                        ),
                                                    transitionsBuilder:
                                                        (
                                                          context,
                                                          animation,
                                                          secondaryAnimation,
                                                          child,
                                                        ) {
                                                          const begin = Offset(
                                                            1.0,
                                                            0.0,
                                                          );
                                                          const end =
                                                              Offset.zero;
                                                          const curve =
                                                              Curves.easeInOut;
                                                          var tween =
                                                              Tween(
                                                                begin: begin,
                                                                end: end,
                                                              ).chain(
                                                                CurveTween(
                                                                  curve: curve,
                                                                ),
                                                              );
                                                          var offsetAnimation =
                                                              animation.drive(
                                                                tween,
                                                              );
                                                          return SlideTransition(
                                                            position:
                                                                offsetAnimation,
                                                            child: child,
                                                          );
                                                        },
                                                    transitionDuration:
                                                        const Duration(
                                                          milliseconds: 400,
                                                        ),
                                                  ),
                                                );
                                              }
                                            },
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 2,
                                                    horizontal: 10,
                                                  ),
                                              child: Text(
                                                "Register Now",
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 15),
                                  Text(
                                    item['description']!,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ContributorRegistrationPage extends StatefulWidget {
  final String title;
  final bool isEditMode;
  final String? contributorId;
  final Map<String, dynamic>? existingData;

  const ContributorRegistrationPage({
    Key? key,
    required this.title,
    this.isEditMode = false,
    this.contributorId,
    this.existingData,
  }) : super(key: key);

  @override
  State<ContributorRegistrationPage> createState() =>
      _ContributorRegistrationPageState();
}

class _ContributorRegistrationPageState
    extends State<ContributorRegistrationPage> {
  final MangoDashboardController controller = Get.put(
    MangoDashboardController(),
  );
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController companyNameController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController portfolioController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  final TextEditingController stageNameController = TextEditingController();
  final TextEditingController distributorLabelController =
      TextEditingController();
  final TextEditingController storeNameController = TextEditingController();
  final TextEditingController socialMediaController = TextEditingController();

  Uint8List? _webProfileImageBytes;
  Uint8List? _webLogoImageBytes;
  String? _webProfileImageName;
  String? _webLogoImageName;

  // Enhanced skills for different contributor types
  List<String> get availableSkills {
    switch (widget.title) {
      case 'Creator':
        return creatorSkills;
      case 'Vendor':
        return vendorSkills;
      case 'Distributor':
        return distributorSkills;
      default:
        return [];
    }
  }

  // Creator-specific skills
  final List<String> creatorSkills = [
    'Music Production',
    'Vocalist/Singer',
    'Songwriting',
    'Music Composition',
    'Audio Engineering',
    'Podcast Hosting',
    'Voice Acting',
    'Audiobook Narration',
    'Writing & Authorship',
    'Poetry',
    'Screenwriting',
    'Comedy Writing',
    'Film Making',
    'Video Production',
    'Animation',
    'Motion Graphics',
    '2D/3D Modeling',
    'Photography',
    'Digital Art',
    'Illustration',
    'Graphic Design',
    'UI/UX Design',
    'Game Development',
    'Content Creation',
    'Streaming',
    'Dance Choreography',
    'Theater Performance',
    'Stand-up Comedy',
    'Magic & Illusion',
    'Craftsmanship',
  ];

  // Vendor-specific product categories
  final List<String> vendorSkills = [
    'Kitchen & Dining',
    'Cookware',
    'Bakeware',
    'Kitchen Appliances',
    'Cutlery & Knives',
    'Kitchen Tools & Gadgets',
    'Tableware & Serveware',
    'Food & Beverage',
    'Gourmet Foods',
    'Bakery Items',
    'Beverages & Drinks',
    'Organic & Health Foods',
    'Specialty Ingredients',
    'Art & Crafts',
    'Painting & Drawing',
    'Sculpture & Pottery',
    'Digital Art Prints',
    'Handmade Crafts',
    'Jewelry Making',
    'Textile Art',
    'Woodworking',
    'Fashion & Apparel',
    'Clothing',
    'Footwear',
    'Accessories',
    'Bags & Luggage',
    'Traditional Wear',
    'Streetwear',
    'Luxury Goods',
    'Electronics & Gadgets',
    'Smart Devices',
    'Audio Equipment',
    'Gaming Accessories',
    'Mobile Accessories',
    'Computer Peripherals',
    'Home & Living',
    'Furniture',
    'Home Decor',
    'Lighting',
    'Bedding & Linens',
    'Storage & Organization',
    'Garden & Outdoor',
    'Beauty & Personal Care',
    'Skincare',
    'Haircare',
    'Makeup & Cosmetics',
    'Fragrances',
    'Natural & Organic Products',
    'Health & Wellness',
    'Fitness Equipment',
    'Supplements',
    'Yoga & Meditation',
    'Wellness Products',
    'Sports & Outdoors',
    'Sports Equipment',
    'Outdoor Gear',
    'Camping & Hiking',
    'Cycling',
    'Fitness Apparel',
    'Books & Media',
    'Physical Books',
    'E-books',
    'Magazines',
    'Stationery',
    'Educational Materials',
    'Toys & Games',
    'Board Games',
    'Puzzles',
    'Collectibles',
    'Action Figures',
    'Educational Toys',
    'Pet Supplies',
    'Pet Food',
    'Pet Accessories',
    'Pet Grooming',
    'Pet Toys',
    'Automotive',
    'Car Accessories',
    'Motorcycle Gear',
    'Auto Parts',
    'Cleaning Products',
    'Baby & Kids',
    'Baby Clothing',
    'Nursery Decor',
    'Baby Gear',
    'Kids Toys',
    'Children\'s Books',
  ];

  // Distributor-specific content categories
  final List<String> distributorSkills = [
    'Music Distribution',
    'Digital Music Distribution',
    'Physical Music Distribution',
    'Independent Labels',
    'Streaming Platform Distribution',
    'Radio Promotion',
    'Music Licensing',
    'Book Distribution',
    'Physical Book Distribution',
    'E-book Distribution',
    'Academic Publishing',
    'Self-Publishing Services',
    'Audiobook Distribution',
    'Magazine Distribution',
    'Podcast Distribution',
    'Podcast Network Management',
    'RSS Feed Distribution',
    'Podcast Advertising',
    'Video & Film Distribution',
    'Movie Distribution',
    'TV Series Distribution',
    'Documentary Distribution',
    'Short Film Distribution',
    'Online Video Platforms',
    'Digital Content Distribution',
    'NFT Marketplace Integration',
    'Digital Asset Management',
    'Content Syndication',
    'API Content Delivery',
    'Software Distribution',
    'App Distribution',
    'Game Distribution',
    'SaaS Distribution',
    'Retail Distribution',
    'E-commerce Integration',
    'Retail Partnerships',
    'Dropshipping Services',
    'Warehousing & Logistics',
    'International Distribution',
    'Cross-border Logistics',
    'Global Rights Management',
    'Licensing & Royalties',
    'Merchandise Distribution',
    'Concert & Event Merchandise',
    'Artist Merchandise',
    'Branded Products',
  ];

  // Enhanced tags/categories for content types
  final List<String> contentCategories = [
    'Music',
    'Albums',
    'Singles',
    'Music Videos',
    'Live Performances',
    'Remixes',
    'DJ Mixes',
    'Instrumentals',
    'Books',
    'Fiction',
    'Non-Fiction',
    'Poetry Collections',
    'Comics & Graphic Novels',
    'Children\'s Books',
    'Educational Books',
    'Biographies',
    'Podcasts',
    'Interview Podcasts',
    'Storytelling Podcasts',
    'Educational Podcasts',
    'News Podcasts',
    'Comedy Podcasts',
    'True Crime',
    'Movies',
    'Feature Films',
    'Short Films',
    'Documentaries',
    'Animated Films',
    'Independent Films',
    'Web Series',
    'Art',
    'Digital Art',
    'Traditional Art',
    'Photography',
    'Sculpture',
    'Illustrations',
    'Street Art',
    'Calligraphy',
    'Products',
    'Physical Products',
    'Digital Products',
    'Merchandise',
    'Collectibles',
    'Limited Editions',
    'Custom Orders',
    'Services',
    'Consulting',
    'Tutoring',
    'Workshops',
    'Custom Commissions',
    'Rentals',
    'Events',
    'Concerts',
    'Workshops',
    'Exhibitions',
    'Book Signings',
    'Meet & Greets',
    'Festivals',
  ];

  String? selectedSkill;
  List<String> selectedCategories = [];
  List<String> selectedSubCategories = [];

  final List<String> creatorTypes = ['Freelance', 'Signed'];
  String? selectedCreatorType;

  bool showCompanyFields = false;
  bool _isSubmitting = false;

  final ImagePicker _imagePicker = ImagePicker();
  XFile? _profileImage;
  XFile? _logoImage;
  bool _isUploadingImage = false;

  String? _existingProfileImageUrl;
  String? _existingLogoImageUrl;

  @override
  void initState() {
    super.initState();

    if (widget.isEditMode && widget.contributorId != null) {
      _loadExistingData();
    }
  }

  Future<void> _loadExistingData() async {
    try {
      if (widget.contributorId == null) return;

      final contributorDoc = await FirebaseFirestore.instance
          .collection('contributors')
          .doc(widget.contributorId!)
          .get();

      if (contributorDoc.exists) {
        final data = contributorDoc.data() ?? {};

        _existingProfileImageUrl = data['profileImageUrl'];
        _existingLogoImageUrl = data['logoImageUrl'];

        fullNameController.text = data['fullName'] ?? '';
        emailController.text = data['email'] ?? '';
        phoneController.text = data['phone'] ?? '';
        companyNameController.text = data['companyName'] ?? '';
        addressController.text = data['address'] ?? '';
        portfolioController.text = data['portfolio'] ?? '';
        bioController.text = data['bio'] ?? '';
        socialMediaController.text = data['socialMedia'] ?? '';
        selectedSkill = data['skill'];
        selectedCategories = List<String>.from(data['categories'] ?? []);
        selectedSubCategories = List<String>.from(data['subCategories'] ?? []);

        if (widget.title == 'Creator') {
          stageNameController.text = data['stageName'] ?? '';
          selectedCreatorType = data['creatorType'];
          showCompanyFields = selectedCreatorType == 'Signed';
        } else if (widget.title == 'Distributor') {
          distributorLabelController.text = data['distributorLabel'] ?? '';
        } else if (widget.title == 'Vendor') {
          storeNameController.text = data['storeName'] ?? '';
        }

        setState(() {});
      }
    } catch (e) {
      print('Error loading existing data: $e');
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      if (kIsWeb) {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          withData: true,
        );

        if (result != null && result.files.isNotEmpty) {
          PlatformFile file = result.files.first;
          setState(() {
            _webProfileImageBytes = file.bytes;
            _webProfileImageName = file.name;
            _profileImage = null;
          });
        }
      } else {
        final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 80,
        );
        if (image != null) {
          setState(() {
            _profileImage = image;
            _webProfileImageBytes = null;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error picking image: ${e.toString()}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickLogoImage() async {
    try {
      if (kIsWeb) {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          withData: true,
        );

        if (result != null && result.files.isNotEmpty) {
          PlatformFile file = result.files.first;
          setState(() {
            _webLogoImageBytes = file.bytes;
            _webLogoImageName = file.name;
            _logoImage = null;
          });
        }
      } else {
        final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 400,
          maxHeight: 400,
          imageQuality: 80,
        );
        if (image != null) {
          setState(() {
            _logoImage = image;
            _webLogoImageBytes = null;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error picking logo: ${e.toString()}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _uploadImage(dynamic image, String path) async {
    try {
      final Reference storageRef = FirebaseStorage.instance.ref().child(path);

      if (kIsWeb) {
        if (image is Uint8List) {
          final metadata = SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {'platform': 'web'},
          );
          final uploadTask = storageRef.putData(image, metadata);
          final snapshot = await uploadTask;
          return await snapshot.ref.getDownloadURL();
        }
      } else {
        if (image is XFile) {
          final metadata = SettableMetadata(contentType: 'image/jpeg');
          final uploadTask = storageRef.putFile(File(image.path), metadata);
          final snapshot = await uploadTask;
          return await snapshot.ref.getDownloadURL();
        }
      }
      return null;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  
  bool _validateRequiredFields() {
    
    bool hasProfileImage =
        _profileImage != null ||
        _webProfileImageBytes != null ||
        (_existingProfileImageUrl != null &&
            _existingProfileImageUrl!.isNotEmpty);
    if (!hasProfileImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Profile image is required',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return false;
    }

    
    if (selectedSkill == null || selectedSkill!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select your ${widget.title.toLowerCase()} specialty',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return false;
    }

    
    if (selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please select at least one content category',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return false;
    }

    
    if (widget.title == 'Creator' &&
        (selectedCreatorType == null || selectedCreatorType!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please select Freelance or Signed',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return false;
    }

    return true;
  }

  Future<void> _submitContributorForm() async {
    
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please fill all required fields correctly',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    
    if (!_validateRequiredFields()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final String contributorId =
          widget.isEditMode && widget.contributorId != null
          ? widget.contributorId!
          : '${widget.title.toLowerCase()}_${user.uid}';

      String? profileImageUrl = _existingProfileImageUrl;
      String? logoImageUrl = _existingLogoImageUrl;

      if (_webProfileImageBytes != null || _profileImage != null) {
        setState(() {
          _isUploadingImage = true;
        });

        if (kIsWeb && _webProfileImageBytes != null) {
          profileImageUrl = await _uploadImage(
            _webProfileImageBytes!,
            'contributors/${contributorId}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
        } else if (!kIsWeb && _profileImage != null) {
          profileImageUrl = await _uploadImage(
            _profileImage!,
            'contributors/${contributorId}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
        }
      }

      if (_webLogoImageBytes != null || _logoImage != null) {
        if (kIsWeb && _webLogoImageBytes != null) {
          logoImageUrl = await _uploadImage(
            _webLogoImageBytes!,
            'contributors/${contributorId}/logo_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
        } else if (!kIsWeb && _logoImage != null) {
          logoImageUrl = await _uploadImage(
            _logoImage!,
            'contributors/${contributorId}/logo_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
        }
      }

      setState(() {
        _isUploadingImage = false;
      });

      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      final contributorData = {
        'contributorId': contributorId,
        'userId': user.uid,
        'fullName': fullNameController.text.trim(),
        'email': emailController.text.trim(),
        'phone': phoneController.text.trim(),
        'address': addressController.text.trim(),
        'skill': selectedSkill,
        'categories': selectedCategories,
        'subCategories': selectedSubCategories,
        'portfolio': portfolioController.text.trim(),
        'bio': bioController.text.trim(),
        'socialMedia': socialMediaController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        'type': widget.title.toLowerCase(),
        'isActive': true,
      };

      
      if (widget.title == 'Creator') {
        contributorData['stageName'] = stageNameController.text.trim();
        contributorData['creatorType'] = selectedCreatorType;
      } else if (widget.title == 'Distributor') {
        contributorData['distributorLabel'] = distributorLabelController.text
            .trim();
      } else if (widget.title == 'Vendor') {
        contributorData['storeName'] = storeNameController.text.trim();
      }

      
      if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
        contributorData['profileImageUrl'] = profileImageUrl;
        contributorData['${widget.title.toLowerCase()}ImageUrl'] =
            profileImageUrl;
      }

      if (logoImageUrl != null && logoImageUrl.isNotEmpty) {
        contributorData['logoImageUrl'] = logoImageUrl;
        contributorData['${widget.title.toLowerCase()}LogoUrl'] = logoImageUrl;
      }

      
      final contributorRef = firestore
          .collection('contributors')
          .doc(contributorId);
      final userRef = firestore.collection('users').doc(user.uid);
      final roleField = 'is${widget.title}'; 

      batch.set(
        contributorRef,
        contributorData,
        SetOptions(merge: widget.isEditMode),
      );
      batch.update(userRef, {roleField: true});

      final roleIdField = '${widget.title.toLowerCase()}ID';
      batch.update(userRef, {roleIdField: contributorId});

      await batch.commit();

      print(
        '${widget.title.toLowerCase()} profile created/updated successfully',
      );

      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditMode
                  ? '${widget.title} profile updated!'
                  : 'Welcome to Mango Contributors!',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      Get.back();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: ${e.toString()}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red,
        ),
      );
      print(e);
    } finally {
      setState(() {
        _isSubmitting = false;
        _isUploadingImage = false;
      });
    }
  }

  Widget _buildImageUploadSection() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Profile Images',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            _buildImagePreview(
              image: _profileImage,
              webImageBytes: _webProfileImageBytes,
              existingUrl: _existingProfileImageUrl,
              onTap: _pickProfileImage,
              label: 'Profile Image *',
              isRequired: true,
            ),
            const SizedBox(width: 16),

            _buildImagePreview(
              image: _logoImage,
              webImageBytes: _webLogoImageBytes,
              existingUrl: _existingLogoImageUrl,
              onTap: _pickLogoImage,
              label: 'Logo (Optional)',
              isRequired: false,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          widget.isEditMode
              ? '* Keep existing images or upload new ones'
              : '* Profile image is required. Logo is optional for brand identification.',
          style: TextStyle(
            fontSize: 9,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview({
    required XFile? image,
    required Uint8List? webImageBytes,
    required String? existingUrl,
    required VoidCallback onTap,
    required String label,
    required bool isRequired,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onTap,
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                border: Border.all(
                  color:
                      isRequired &&
                          image == null &&
                          webImageBytes == null &&
                          existingUrl == null
                      ? Colors.red
                      : (isDarkMode ? Colors.grey[600]! : Colors.grey),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
                color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
              ),
              child: _isUploadingImage
                  ? Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    )
                  : webImageBytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.memory(
                        webImageBytes,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    )
                  : image != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(
                        File(image.path),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    )
                  : existingUrl != null && existingUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        existingUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate,
                            size: 24,
                            color: isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.isEditMode ? 'Update' : 'Tap to upload',
                            style: TextStyle(
                              fontSize: 8,
                              color: isDarkMode
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTextField(
    String label,
    TextEditingController controller, {
    bool isRequired = true,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: isDarkMode ? Colors.grey[600]! : Colors.grey),
        borderRadius: BorderRadius.circular(5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextFormField(
        controller: controller,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isDarkMode ? Colors.white : Colors.black,
        ),
        validator: isRequired
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'This field is required';
                }
                return null;
              }
            : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 12,
          ),
          border: InputBorder.none,
          errorStyle: const TextStyle(fontSize: 9),
        ),
      ),
    );
  }

  Widget buildSearchableDropdown({
    required String label,
    required List<String> items,
    required String? value,
    required Function(String?) onChanged,
    bool isRequired = true,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    String? errorText;
    if (isRequired && value == null) {
      errorText = 'This field is required';
    }

    return GestureDetector(
      onTap: () async {
        final selected = await showDialog<String>(
          context: context,
          builder: (context) => SearchableDropdownDialog(
            items: items,
            currentValue: value,
            title: label,
          ),
        );
        if (selected != null) {
          onChanged(selected);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: errorText != null
                ? Colors.red
                : (isDarkMode ? Colors.grey[600]! : Colors.grey),
          ),
          borderRadius: BorderRadius.circular(5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InputDecorator(
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
                border: InputBorder.none,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      value ?? label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: value != null
                            ? (isDarkMode ? Colors.white : Colors.black)
                            : (isDarkMode ? Colors.grey[400] : Colors.grey),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 20,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey,
                  ),
                ],
              ),
            ),
            if (errorText != null) ...[
              const SizedBox(height: 4),
              Text(
                errorText,
                style: const TextStyle(fontSize: 9, color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditMode
              ? 'Edit ${widget.title} Profile'
              : '${widget.title} Registration',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ),
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.only(
            top: 5,
            left: 24.0,
            right: 24.0,
            bottom: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isEditMode
                      ? 'Update your ${widget.title} Profile'
                      : 'Join Mango Contributors as a ${widget.title}',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.isEditMode
                      ? 'Update your details below to keep your profile fresh.'
                      : 'Fill in your details below to get started and become a contributor on Mango.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '* indicates required field',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),

                _buildImageUploadSection(),

                const SizedBox(height: 24),

                buildTextField('Full Name *', fullNameController),

                if (widget.title == 'Creator') ...[
                  const SizedBox(height: 16),
                  buildTextField('Stage Name *', stageNameController),
                ],

                if (widget.title == 'Distributor') ...[
                  const SizedBox(height: 16),
                  buildTextField(
                    'Distributor Label *',
                    distributorLabelController,
                  ),
                ],

                if (widget.title == 'Vendor') ...[
                  const SizedBox(height: 16),
                  buildTextField('Store Name *', storeNameController),
                ],

                const SizedBox(height: 16),
                buildTextField('Email *', emailController),
                const SizedBox(height: 16),
                buildTextField('Phone Number *', phoneController),
                const SizedBox(height: 16),

                if (widget.title == 'Creator')
                  buildSearchableDropdown(
                    label: 'Freelance or Signed *',
                    items: creatorTypes,
                    value: selectedCreatorType,
                    onChanged: (value) {
                      setState(() {
                        selectedCreatorType = value;
                        showCompanyFields = value == 'Signed';
                      });
                    },
                    isRequired: true,
                  ),

                if (widget.title == 'Distributor' ||
                    widget.title == 'Vendor' ||
                    showCompanyFields) ...[
                  const SizedBox(height: 16),
                  buildTextField('Company Name *', companyNameController),
                  const SizedBox(height: 16),
                  buildTextField('Company Address *', addressController),
                ] else ...[
                  const SizedBox(height: 16),
                  buildTextField('Personal Address *', addressController),
                ],

                const SizedBox(height: 16),
                buildSearchableDropdown(
                  label: 'Select Your ${widget.title} Specialty *',
                  items: availableSkills,
                  value: selectedSkill,
                  onChanged: (value) {
                    setState(() {
                      selectedSkill = value;
                    });
                  },
                  isRequired: true,
                ),

                const SizedBox(height: 24),
                Text(
                  'Select the content categories you work with: *',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: contentCategories.map((category) {
                    final isSelected = selectedCategories.contains(category);
                    return FilterChip(
                      label: Text(
                        category,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : (isDarkMode ? Colors.white : Colors.black),
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            selectedCategories.add(category);
                          } else {
                            selectedCategories.remove(category);
                            // Also remove any subcategories that might depend on this
                            selectedSubCategories.removeWhere(
                              (sub) => sub.startsWith(category),
                            );
                          }
                        });
                      },
                      selectedColor: Colors.orange,
                      backgroundColor: isDarkMode
                          ? Colors.grey[700]
                          : Colors.grey[200],
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),
                buildTextField(
                  'Portfolio Link (Optional)',
                  portfolioController,
                  isRequired: false,
                ),
                const SizedBox(height: 16),
                buildTextField('Short Bio *', bioController),
                const SizedBox(height: 16),
                buildTextField('Social Media Handles *', socialMediaController),
                const SizedBox(height: 32),

                Container(
                  padding: const EdgeInsets.only(top: 3, left: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Theme.of(context).primaryColor),
                  ),
                  child: MaterialButton(
                    minWidth: double.infinity,
                    height: 60,
                    onPressed: _isSubmitting ? null : _submitContributorForm,
                    color: Colors.orangeAccent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            widget.isEditMode
                                ? "Update Profile"
                                : "Become a Contributor",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SearchableDropdownDialog extends StatefulWidget {
  final List<String> items;
  final String? currentValue;
  final String title;

  const SearchableDropdownDialog({
    Key? key,
    required this.items,
    this.currentValue,
    required this.title,
  }) : super(key: key);

  @override
  _SearchableDropdownDialogState createState() =>
      _SearchableDropdownDialogState();
}

class _SearchableDropdownDialogState extends State<SearchableDropdownDialog> {
  late List<String> filteredItems;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    filteredItems = widget.items;
    _searchController.addListener(_filterItems);
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredItems = widget.items
          .where((item) => item.toLowerCase().contains(query))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  labelText: 'Search ${widget.title}',
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                  ),
                  suffixIcon: Icon(
                    Icons.search,
                    size: 20,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey,
                  ),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  filled: true,
                  fillColor: isDarkMode ? Colors.grey[700] : Colors.grey[100],
                ),
              ),
            ),
            Expanded(
              child: OptimizedListView(
                shrinkWrap: true,
                itemCount: filteredItems.length,
                itemBuilder: (context, index) {
                  final item = filteredItems[index];
                  return ListTile(
                    title: Text(
                      item,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}