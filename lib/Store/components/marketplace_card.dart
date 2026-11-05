import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mango/Store/screens/general_store.dart';
import 'package:mango/Core/theme/mango_palette.dart';
import 'package:mango/Core/design_system/mango_ui.dart';

class MarketplaceCard extends StatelessWidget {
  final Map<String, dynamic> vendor;
  final int index;
  
  const MarketplaceCard({
    Key? key,
    required this.vendor,
    required this.index,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Get vendor tags if available
    final List<String> tags = vendor['tags'] != null 
        ? List<String>.from(vendor['tags']) 
        : [];
    
    // Get skill if available
    final String skill = vendor['skill'] ?? '';
    
    return MangoPressable(
      onTap: () {
        Get.to(
          () => ShopScreen(
            vendorId: vendor['contributorId'],
            vendorName: vendor['storeName'] ?? vendor['fullName'],
          ),
          transition: Transition.rightToLeft,
          duration: const Duration(milliseconds: 300),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        child: SizedBox(
          width: 180,
          height: 300, // Increased height to accommodate tags
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(MangoRadius.md),
              image: DecorationImage(
                image: vendor['profileImageUrl'] != null && vendor['profileImageUrl'].isNotEmpty
                    ? NetworkImage(vendor['profileImageUrl'])
                    : const AssetImage('asset/images/mango-11.jpg') as ImageProvider,
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  MangoPalette.black.withOpacity(0.5),
                  BlendMode.darken,
                ),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Popular badge based on tags or index
                if (index < 3 || tags.contains('Popular'))
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        color: MangoPalette.black.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(MangoRadius.sm),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_fire_department,
                            color: MangoPalette.green500,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Popular",
                            style: TextStyle(fontFamily: 'Poppins', 
                              fontSize: 12,
                              color: MangoPalette.green500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Skill badge (if available)
                if (skill.isNotEmpty)
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(MangoRadius.sm),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      child: Text(
                        skill,
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                
                // Vendor info
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      // Vendor logo/avatar
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: DecorationImage(
                            image: vendor['logoImageUrl'] != null && vendor['logoImageUrl'].isNotEmpty
                                ? NetworkImage(vendor['logoImageUrl'])
                                : const AssetImage("asset/images/mango-15.jpg") as ImageProvider,
                            fit: BoxFit.cover,
                          ),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: MangoPalette.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Vendor name
                      Text(
                        vendor['storeName'] ?? vendor['fullName'] ?? 'Vendor',
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            const Shadow(
                              color: MangoPalette.black,
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Vendor description/bio
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text(
                          vendor['bio'] ?? 'Shop with us for amazing products',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: 'Poppins', 
                            fontSize: 12,
                            color: Colors.white70,
                            shadows: [
                              const Shadow(
                                color: MangoPalette.black,
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Tags row (if tags exist)
                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 4,
                          runSpacing: 2,
                          children: tags.take(2).map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: MangoPalette.green500.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(MangoRadius.md),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(fontFamily: 'Poppins', 
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        if (tags.length > 2)
                          Text(
                            '+${tags.length - 2} more',
                            style: TextStyle(fontFamily: 'Poppins', 
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                      ],
                      const SizedBox(height: 8),
                      // Shop now button
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: MangoPalette.green500,
                          borderRadius: BorderRadius.circular(MangoRadius.lg),
                        ),
                        child: Text(
                          "Shop Now",
                          style: TextStyle(fontFamily: 'Poppins', 
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
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