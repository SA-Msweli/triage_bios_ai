import 'package:flutter/material.dart';

/// Responsive breakpoints for the Triage BioS AI application
/// Provides consistent breakpoint handling across all components
class ResponsiveBreakpoints {
  // Breakpoint constants matching the design specification
  static const double mobile = 600.0;
  static const double tablet = 800.0;
  static const double desktop = 1200.0;

  /// Check if the current screen size is mobile (<600px)
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobile;
  }

  /// Check if the current screen size is tablet (600px - 1200px)
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobile && width < desktop;
  }

  /// Check if the current screen size is desktop (>=1200px)
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktop;
  }

  /// Get the current device type based on screen width
  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobile) return DeviceType.mobile;
    if (width < desktop) return DeviceType.tablet;
    return DeviceType.desktop;
  }

  /// Get screen size information for responsive calculations
  static ScreenSizeInfo getScreenInfo(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return ScreenSizeInfo(
      width: mediaQuery.size.width,
      height: mediaQuery.size.height,
      devicePixelRatio: mediaQuery.devicePixelRatio,
      orientation: mediaQuery.orientation,
      deviceType: getDeviceType(context),
      isKeyboardVisible: mediaQuery.viewInsets.bottom > 0,
    );
  }

  /// Get responsive padding based on screen size
  static EdgeInsets getResponsivePadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.all(16.0);
    } else if (isTablet(context)) {
      return const EdgeInsets.all(24.0);
    } else {
      return const EdgeInsets.all(32.0);
    }
  }

  /// Get responsive margin based on screen size
  static EdgeInsets getResponsiveMargin(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.all(8.0);
    } else if (isTablet(context)) {
      return const EdgeInsets.all(12.0);
    } else {
      return const EdgeInsets.all(16.0);
    }
  }
}

/// Device type enumeration
enum DeviceType { mobile, tablet, desktop }

/// Screen size information model
class ScreenSizeInfo {
  final double width;
  final double height;
  final double devicePixelRatio;
  final Orientation orientation;
  final DeviceType deviceType;
  final bool isKeyboardVisible;

  const ScreenSizeInfo({
    required this.width,
    required this.height,
    required this.devicePixelRatio,
    required this.orientation,
    required this.deviceType,
    required this.isKeyboardVisible,
  });

  /// Check if the screen is in landscape mode
  bool get isLandscape => orientation == Orientation.landscape;

  /// Check if the screen is in portrait mode
  bool get isPortrait => orientation == Orientation.portrait;

  /// Get the aspect ratio of the screen
  double get aspectRatio => width / height;
}
