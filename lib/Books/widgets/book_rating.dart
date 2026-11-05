import 'package:flutter/material.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class BookRating extends StatelessWidget {
  final int score;
  const BookRating({
    Key? key,
    required this.score,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8,),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(MangoRadius.md),
        boxShadow: [
          BoxShadow(
            offset: const Offset(3, 7),
            blurRadius: 20,
            color: Theme.of(context).cardColor.withOpacity(.5),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.bookmark_border,
            color: Theme.of(context).primaryColor,
            size: 15,
          ),
          const SizedBox(height: 5),
          Text(
            "$score",
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
