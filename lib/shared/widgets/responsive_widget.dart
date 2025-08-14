import 'package:flutter/material.dart';
import '../utils/responsive_breakpoints.dart';

/// Abstract base class for creating responsive widgets
/// Provides a consistent pattern for implementing responsive layouts
abstract class ResponsiveWidget extends StatelessWidget {
  const ResponsiveWidget({super.key});

  /// Build the mobile layout (<600px)
  Widget buildMobile(BuildContext context);

  /// Build the tablet layout (600px - 1200px)
  Widget buildTablet(BuildContext context);

  /// Build the desktop layout (>=1200px)
  Widget buildDesktop(BuildContext context);

  @override
  Widget build(BuildContext context) {
    if (ResponsiveBreakpoints.isMobile(context)) {
      return buildMobile(context);
    } else if (ResponsiveBreakpoints.isTablet(context)) {
      return buildTablet(context);
    } else {
      return buildDesktop(context);
    }
  }
}

/// Responsive builder widget for inline responsive layouts
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context) mobile;
  final Widget Function(BuildContext context) tablet;
  final Widget Function(BuildContext context) desktop;

  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    required this.tablet,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    if (ResponsiveBreakpoints.isMobile(context)) {
      return mobile(context);
    } else if (ResponsiveBreakpoints.isTablet(context)) {
      return tablet(context);
    } else {
      return desktop(context);
    }
  }
}

/// Responsive layout helper that provides common responsive patterns
class ResponsiveLayout extends StatelessWidget {
  final Widget child;
  final double? mobileMaxWidth;
  final double? tabletMaxWidth;
  final double? desktopMaxWidth;
  final EdgeInsets? padding;
  final bool centerContent;

  const ResponsiveLayout({
    super.key,
    required this.child,
    this.mobileMaxWidth,
    this.tabletMaxWidth,
    this.desktopMaxWidth,
    this.padding,
    this.centerContent = true,
  });

  @override
  Widget build(BuildContext context) {
    double? maxWidth;

    if (ResponsiveBreakpoints.isMobile(context)) {
      maxWidth = mobileMaxWidth;
    } else if (ResponsiveBreakpoints.isTablet(context)) {
      maxWidth = tabletMaxWidth;
    } else {
      maxWidth = desktopMaxWidth;
    }

    Widget content = child;

    if (maxWidth != null) {
      content = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: content,
      );
    }

    if (centerContent) {
      content = Center(child: content);
    }

    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    } else {
      content = Padding(
        padding: ResponsiveBreakpoints.getResponsivePadding(context),
        child: content,
      );
    }

    return content;
  }
}
