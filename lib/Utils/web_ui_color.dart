import 'dart:html' as html;
import 'package:flutter/material.dart';

void setSystemUiColor(Color color) {
  final meta = html.document.querySelector('meta[name="theme-color"]');
  if (meta != null) {
    meta.setAttribute('content', '#${color.value.toRadixString(16).substring(2)}');
  }
}
