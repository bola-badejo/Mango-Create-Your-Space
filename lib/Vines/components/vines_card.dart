import 'package:flutter/material.dart';
import '../../Models/customModel/vine.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class VinesCard extends StatelessWidget {
  final MangoVine vine;
  final Function pressDetails;
  final Function? pressPlay;

  const VinesCard({
    super.key,
    required this.vine,
    required this.pressDetails,
    this.pressPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 80,
            height: 120,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(vine.thumbnailUrl),
                fit: BoxFit.cover,
              ),
              borderRadius: BorderRadius.circular(MangoRadius.md),
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
              width: 80,
              child: Text(vine.postCreator,
                  style: const TextStyle(color: Colors.white, fontSize: 14))),
          const SizedBox(height: 3),
          
          
          
          
          
          
          
          
          
          
          
          
          
          
          
          
          
          
        ],
      ),
    );
  }
}