import 'package:flutter/material.dart';

/// Subtle theme-aware wordmark.
class Hr360Logo extends StatelessWidget {
  const Hr360Logo({super.key, this.width = 130});

  final double width;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Image.asset(
      dark
          ? 'assets/images/darkmode_logo.png'
          : 'assets/images/lightmode_logo.png',
      width: width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}
