import 'package:flutter/material.dart';

/// Black, zero-transition route for Android TV.
///
/// Use this for TV Detail/Player routes so the app never flashes Flutter's
/// default white route background before the destination screen builds.
class TvBlackPageRoute {
  const TvBlackPageRoute._();

  static PageRouteBuilder<T> build<T>({
    required WidgetBuilder builder,
    bool opaque = true,
  }) {
    return PageRouteBuilder<T>(
      opaque: opaque,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) {
        return Material(
          color: Colors.black,
          child: ColoredBox(
            color: Colors.black,
            child: builder(context),
          ),
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return child;
      },
    );
  }
}
