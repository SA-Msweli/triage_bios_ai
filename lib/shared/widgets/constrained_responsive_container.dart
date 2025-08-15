import 'package:flutter/material.dart';
import '../utils/responsive_breakpoints.dart';

/// Constrained responsive container that adapts to different screen sizes
class ConstrainedResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final double? maxHeight;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  const ConstrainedResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.maxHeight,
    this.padding,
    this.margin,
  });

  /// Factory constructor for hospital map containers
  factory ConstrainedResponsiveContainer.hospitalMap({
    required Widget child,
  }) {
    return ConstrainedResponsiveContainer(
      maxWidth: 1200,
      maxHeight: 800,
      child: child,
    );
  }

  /// Factory constructor for card containers
  factory ConstrainedResponsiveContainer.card({
    required Widget child,
  }) {
    return ConstrainedResponsiveContainer(
      maxWidth: 600,
      child: child,
    );
  }

  /// Factory constructor for button containers
  factory ConstrainedResponsiveContainer.button({
    required Widget child,
  }) {
    return ConstrainedResponsiveContainer(
      maxWidth: 300,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? double.infinity,
        maxHeight: maxHeight ?? double.infinity,
      ),
      padding: padding ?? ResponsiveBreakpoints.getResponsivePadding(context),
      margin: margin ?? ResponsiveBreakpoints.getResponsiveMargin(context),
      child: child,
    );
  }
}