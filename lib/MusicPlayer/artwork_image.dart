import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ArtWorkImage extends StatelessWidget {
  final String? image;

  const ArtWorkImage({super.key, required this.image});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.maxFinite,
      height: MediaQuery.of(context).size.width * 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: image != null && image!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: image!,
                placeholder: (context, url) => Container(
                  color: Colors.grey[300],
                  child: Center(
                    child: Icon(
                      Icons.music_note,
                      size: 60,
                      color: Colors.grey,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: Center(
                    child: Icon(
                      Icons.music_note,
                      size: 60,
                      color: Colors.grey,
                    ),
                  ),
                ),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              )
            : Container(
                color: Colors.grey[300],
                child: Center(
                  child: Icon(
                    Icons.music_note,
                    size: 60,
                    color: Colors.grey,
                  ),
                ),
              ),
      ),
    );
  }
}