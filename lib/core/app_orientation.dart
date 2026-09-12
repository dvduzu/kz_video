import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../data/models.dart';

abstract final class AppOrientation {
  static const double tabletShortestSide = 600;

  static UiMode resolve(UiMode mode, double shortestSide) {
    if (mode == UiMode.auto) {
      return shortestSide >= tabletShortestSide ? UiMode.tablet : UiMode.phone;
    }
    return mode;
  }

  static UiMode resolveFromView(UiMode mode) {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final size = view.physicalSize / view.devicePixelRatio;
    return resolve(mode, size.shortestSide);
  }

  static List<DeviceOrientation> orientationsFor(UiMode mode) {
    switch (mode) {
      case UiMode.phone:
        return const [DeviceOrientation.portraitUp];
      case UiMode.tablet:
        return const [DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight];
      case UiMode.auto:
        return const [DeviceOrientation.portraitUp];
    }
  }

  static Future<void> apply(UiMode mode) {
    return SystemChrome.setPreferredOrientations(orientationsFor(resolveFromView(mode)));
  }
}
