import 'package:flutter/material.dart';

/// Bottom inset so scroll content stays above the floating nav bar.
abstract final class ShellLayout {
  static const double navBarOuterHeight = 72;
  static const double homePunchClearance = 148;

  static double scrollBottomPadding(BuildContext context) {
    return navBarOuterHeight + MediaQuery.paddingOf(context).bottom + 12;
  }

  static double homeScrollBottomPadding(BuildContext context) {
    return homePunchClearance +
        navBarOuterHeight +
        MediaQuery.paddingOf(context).bottom;
  }
}

/// Wrap tab scroll content so it clears the bottom nav.
class ShellScrollPadding extends StatelessWidget {
  const ShellScrollPadding({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: ShellLayout.scrollBottomPadding(context)),
      child: child,
    );
  }
}
