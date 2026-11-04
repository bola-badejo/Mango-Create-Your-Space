import 'package:flutter/material.dart';

class SpaceItems extends StatelessWidget {
  const SpaceItems({
    Key? key,
    required this.name,
    required this.value,
    this.textColor = Colors.white,
  }) : super(key: key);

  final String name;
  final String value;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: textColor.withOpacity(0.7),
          ),
        ),
        Text(
          name,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        )
      ],
    );
  }
}