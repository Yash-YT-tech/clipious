import 'package:clipious/globals.dart';
import 'package:flutter/material.dart';

bool isReducedMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

Duration motionDuration(BuildContext context, Duration normal) =>
    isReducedMotion(context) ? Duration.zero : normal;

/// Keeps the app's existing Android Zoom page transition, but skips the
/// visual motion when the platform asks for reduced motion.
class AccessibleZoomPageTransitionsBuilder extends PageTransitionsBuilder {
  static const _zoom = ZoomPageTransitionsBuilder();

  const AccessibleZoomPageTransitionsBuilder();

  @override
  Duration get transitionDuration => motionPage;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (isReducedMotion(context)) {
      return child;
    }
    return _zoom.buildTransitions(
        route, context, animation, secondaryAnimation, child);
  }
}
