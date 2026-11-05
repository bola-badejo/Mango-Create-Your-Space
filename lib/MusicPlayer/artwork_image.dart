import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class ArtWorkImage extends StatelessWidget {
  final String? image;

  const ArtWorkImage({super.key, required this.image});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.maxFinite,
      height: MediaQuery.of(context).size.width * 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(MangoRadius.xs),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MangoRadius.xs),
        child: image != null && image!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: image!,
                placeholder: (context, url) => Container(
                  color: MangoPalette.grey300,
                  child: Center(
                    child: Icon(
                      Icons.music_note,
                      size: 60,
                      color: MangoPalette.grey500,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: MangoPalette.grey300,
                  child: Center(
                    child: Icon(
                      Icons.music_note,
                      size: 60,
                      color: MangoPalette.grey500,
                    ),
                  ),
                ),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              )
            : Container(
                color: MangoPalette.grey300,
                child: Center(
                  child: Icon(
                    Icons.music_note,
                    size: 60,
                    color: MangoPalette.grey500,
                  ),
                ),
              ),
      ),
    );
  }
}