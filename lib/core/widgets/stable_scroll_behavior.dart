import 'package:flutter/material.dart';

/// Clamped scrolling without stretch, glow, or bounce overscroll artifacts.
class StableScrollBehavior extends MaterialScrollBehavior {
  const StableScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }
}
