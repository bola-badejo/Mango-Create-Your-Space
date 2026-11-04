import 'package:flutter/material.dart';
import 'package:mango/Books/widgets/two_side_rounded_button.dart';
import 'package:mango/Models/customModel/library.dart';

import 'book_rating.dart';

class ReadingListCard extends StatelessWidget {
  final MangoBooks book;
  final Function pressDetails;
  final Function? pressRead;

  const ReadingListCard({
    super.key,
    required this.book,
    required this.pressDetails,
    this.pressRead,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 24, bottom: 40),
      height: 180,
      width: 150,
      child: Stack(
        children: <Widget>[
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 100,
              width: 150,
              decoration: BoxDecoration(
                color: Theme.of(context).splashColor,
                borderRadius: BorderRadius.circular(29),
                boxShadow: [
                  
                  
                  
                  
                  
                ],
              ),
            ),
          ),
          Positioned(
            top: -20,
            left: 10,
            child: Container(
              clipBehavior: Clip.hardEdge,
              width: 60,
              height: 100,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    offset: const Offset(3, 7),
                    blurRadius: 20,
                    color: Theme.of(context).cardColor.withOpacity(.5),
                  ),
                ],
                image: DecorationImage(
                  image: NetworkImage(book.coverUrl),
                  fit: BoxFit.fill,
                ),
              ),
            ),
          ),
          Positioned(
            top: 30,
            right: 10,
            child: Row(
              children: <Widget>[
                Icon(
                    Icons.favorite_border,
                    size: 12,
                  ),
                SizedBox(width:5),
                BookRating(score: book.reads),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 5,
            child: Container(
              height: 75,
              width: 120,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(left: 5, right: 5),
                    child: RichText(
                      maxLines: 2,
                      text: TextSpan(
                        style: TextStyle(
                            color: Theme.of(context).primaryColorLight),
                        children: [
                          TextSpan(
                            text: "${book.title}\n",
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: "${book.author}\n",
                            style: TextStyle(
                              fontSize: 9,
                              color: Theme.of(context).primaryColorLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 6,
            right: 8,
            child: Container(
              child: RichText(
                maxLines: 2,
                text: TextSpan(
                  style: TextStyle(color: Theme.of(context).primaryColorLight),
                  children: [
                    const TextSpan(
                      text: "price\n",
                      style: TextStyle(fontSize: 8),
                    ),
                    TextSpan(
                      text: "N0.00",
                      style: TextStyle(
                          color: Theme.of(context).primaryColorLight,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
