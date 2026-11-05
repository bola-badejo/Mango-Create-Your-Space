// lib/Store/widgets/vendor_card.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mango/Core/theme/mango_palette.dart';
import 'package:mango/Core/design_system/mango_ui.dart';

class VendorCard extends StatelessWidget {
  final Map<String, dynamic> vendor;
  final VoidCallback onTap;
  
  const VendorCard({
    Key? key,
    required this.vendor,
    required this.onTap,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return MangoPressable(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isDarkMode ? MangoPalette.grey850 : Colors.white,
          borderRadius: BorderRadius.circular(MangoRadius.md),
          boxShadow: [
            BoxShadow(
              color: MangoPalette.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Vendor logo
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: Container(
                width: 100,
                height: 100,
                color: MangoPalette.grey200,
                child: vendor['logoImageUrl'] != null
                    ? CachedNetworkImage(
                        imageUrl: vendor['logoImageUrl'],
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Center(
                          child: CircularProgressIndicator(semanticsLabel: 'Loading'),
                        ),
                        errorWidget: (context, url, error) => Icon(
                          Icons.store,
                          size: 40,
                          color: MangoPalette.grey400,
                        ),
                      )
                    : Icon(
                        Icons.store,
                        size: 40,
                        color: MangoPalette.grey400,
                      ),
              ),
            ),
            // Vendor info
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vendor['storeName'] ?? vendor['fullName'] ?? 'Vendor',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : MangoPalette.black,
                      ),
                    ),
                    SizedBox(height: 4),
                    if (vendor['bio'] != null)
                      Text(
                        vendor['bio'],
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          size: 14,
                          color: MangoPalette.green500,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '${vendor['rating'] ?? '4.5'} ★',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                          ),
                        ),
                        SizedBox(width: 12),
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: isDarkMode ? MangoPalette.grey500 : MangoPalette.grey400,
                        ),
                        SizedBox(width: 4),
                        Text(
                          vendor['address']?.split(',')[0] ?? 'Online',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode ? MangoPalette.grey500 : MangoPalette.grey500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: Icon(
                Icons.chevron_right,
                color: isDarkMode ? MangoPalette.grey500 : MangoPalette.grey400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}