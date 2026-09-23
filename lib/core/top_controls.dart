import 'package:flutter/material.dart';

/// Space for the fixed controls inside each page's scrolling content.
/// The surface behind this space still paints all the way to the top.
double topControlsClearance(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context).scale(16);
  return MediaQuery.paddingOf(context).top + (scale > 22 ? 140 : 90);
}
