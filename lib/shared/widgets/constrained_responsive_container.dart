import 'package:flutter/material.dart';
import '../utils/responsive_breakpoints.dart';

/// Constrained responsive container that adapts to different screen sizes
class ConstrainedResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? minWidth;
  final double? minHeight;
  final double? maxWidth;
  final double? maxHeight;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  const ConstrainedResponsiveContainer({
    super.key,
    required this.child,
    this.minWidth,
    this.minHeight,
    this.maxWidth,
    this.maxHeight,
    this.padding,
    this.margin,
  });

  /// Factory constructor for hospital map containers
  factory ConstrainedResponsiveContainer.hospitalMap({
    required Widget child,
    double? minWidth, // Added
    double? minHeight, // Added
  }) {
    return ConstrainedResponsiveContainer(
      minWidth: minWidth, // Added
      minHeight: minHeight, // Added
      maxWidth: 1200,
      maxHeight: 800,
      child: child,
    );
  }

  /// Factory constructor for card containers
  factory ConstrainedResponsiveContainer.card({
    required Widget child, 
    EdgeInsets? margin, // Changed from 'required EdgeInsets margin'
    double? minWidth, 
    double? minHeight, 
  }) {
    return ConstrainedResponsiveContainer(
      minWidth: minWidth, 
      minHeight: minHeight, 
      maxWidth: 600,
      margin: margin, // If margin is null here, the main constructor's default will apply
      child: child,
    );
  }

  /// Factory constructor for button containers
  factory ConstrainedResponsiveContainer.button({
    required Widget child,
    double? minWidth, 
    double? minHeight, 
  }) {
    return ConstrainedResponsiveContainer(
      minWidth: minWidth, 
      minHeight: minHeight, 
      maxWidth: 300,
      child: child,
    );
  }

  /// Factory constructor for vitals card containers
  factory ConstrainedResponsiveContainer.vitalsCard({
    required Widget child,
    EdgeInsets? margin,
    EdgeInsets? padding,
  }) {
    return ConstrainedResponsiveContainer(
      minWidth: 150.0,
      maxWidth: 250.0,
      margin: margin, // Allows custom margin, otherwise defaults
      padding: padding, // Allows custom padding, otherwise defaults
      child: child,
    );
  }

  /// Factory constructor for input field containers
  factory ConstrainedResponsiveContainer.inputField({
    required Widget child,
    double? minWidth,
    double? minHeight,
    double? maxHeight, 
  }) {
    return ConstrainedResponsiveContainer(
      minWidth: minWidth ?? 200, 
      maxWidth: 500,           
      minHeight: minHeight,
      maxHeight: maxHeight,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        minWidth: minWidth ?? 0.0,
        minHeight: minHeight ?? 0.0,
        maxWidth: maxWidth ?? double.infinity,
        maxHeight: maxHeight ?? double.infinity,
      ),
      padding: padding ?? ResponsiveBreakpoints.getResponsivePadding(context),
      margin: margin ?? ResponsiveBreakpoints.getResponsiveMargin(context),
      child: child,
    );
  }
}
