import 'package:flutter/material.dart';
import 'package:mango/Models/customModel/library.dart';

abstract class PdfViewerBase extends StatefulWidget {
  final String fileUrl;
  final MangoBooks book;

  const PdfViewerBase({
    super.key,
    required this.fileUrl,
    required this.book,
  });
}