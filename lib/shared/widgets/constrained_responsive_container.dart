import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Widget constraints model for defining size limits
class WidgetConstraints {
  final double? minWidth;
  final double? maxWidth;
  final double? minHeight;
  final double? maxHeight;
  final double? aspectRatio;

  const WidgetConstraints({
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
    this.aspectRatio,
  });

  /// Convert to Flutter BoxConstraints
  BoxConstraints toBoxConstraints() {
    return BoxConstraints(
      minWidth: minWidth ?? 0.0,
      maxWidth: maxWidth ?? double.infinity,
      minHeight: minHeight ?? 0.0,
      maxHeight: maxHeight ?? double.infinity,
    );
  }
}

/// Predefined constraint sets for common UI elements
class ResponsiveConstraints {
  // Card constraints: minWidth: 280px, maxWidth: 600px
  static const WidgetConstraints card = WidgetConstraints(
    minWidth: 280.0,
    maxWidth: 600.0,
  );

  // Button constraints: minHeight: 44px, maxWidth: 400px
  static const WidgetConstraints button = WidgetConstraints(
    minHeight: 44.0,
    maxWidth: 400.0,
  );

  // Input field constraints: minWidth: 200px, maxWidth: 500px
  static const WidgetConstraints inputField = WidgetConstraints(
    minWidth: 200.0,
    maxWidth: 500.0,
  );

  // Vitals card constraints: minWidth: 150px, maxWidth: 250px
  static const WidgetConstraints vitalsCard = WidgetConstraints(
    minWidth: 150.0,
    maxWidth: 250.0,
  );

  // Hospital map constraints: minHeight: 200px, maxHeight: 400px
  static const WidgetConstraints hospitalMap = WidgetConstraints(
    minHeight: 200.0,
    maxHeight: 400.0,
  );

  // Image constraints: maintain aspect ratio, max width 100% of container
  static const WidgetConstraints image = WidgetConstraints(
    maxWidth: double.infinity,
  );
}

/// Container that automatically enforces size constraints for responsive design
class ConstrainedResponsiveContainer extends StatelessWidget {
  final Widget child;
  final WidgetConstraints? constraints;
  final double? minWidth;
  final double? maxWidth;
  final double? minHeight;
  final double? maxHeight;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final AlignmentGeometry? alignment;
  final bool enableOverflowDetection;

  const ConstrainedResponsiveContainer({
    super.key,
    required this.child,
    this.constraints,
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
    this.padding,
    this.margin,
    this.alignment,
    this.enableOverflowDetection = false,
  });

  /// Factory constructor for card constraints
  factory ConstrainedResponsiveContainer.card({
    Key? key,
    required Widget child,
    EdgeInsets? padding,
    EdgeInsets? margin,
    AlignmentGeometry? alignment,
  }) {
    return ConstrainedResponsiveContainer(
      key: key,
      constraints: ResponsiveConstraints.card,
      padding: padding,
      margin: margin,
      alignment: alignment,
      child: child,
    );
  }

  /// Factory constructor for button constraints
  factory ConstrainedResponsiveContainer.button({
    Key? key,
    required Widget child,
    EdgeInsets? padding,
    EdgeInsets? margin,
    AlignmentGeometry? alignment,
  }) {
    return ConstrainedResponsiveContainer(
      key: key,
      constraints: ResponsiveConstraints.button,
      padding: padding,
      margin: margin,
      alignment: alignment,
      child: child,
    );
  }

  /// Factory constructor for input field constraints
  factory ConstrainedResponsiveContainer.inputField({
    Key? key,
    required Widget child,
    EdgeInsets? padding,
    EdgeInsets? margin,
    AlignmentGeometry? alignment,
  }) {
    return ConstrainedResponsiveContainer(
      key: key,
      constraints: ResponsiveConstraints.inputField,
      padding: padding,
      margin: margin,
      alignment: alignment,
      child: child,
    );
  }

  /// Factory constructor for vitals card constraints
  factory ConstrainedResponsiveContainer.vitalsCard({
    Key? key,
    required Widget child,
    EdgeInsets? padding,
    EdgeInsets? margin,
    AlignmentGeometry? alignment,
  }) {
    return ConstrainedResponsiveContainer(
      key: key,
      constraints: ResponsiveConstraints.vitalsCard,
      padding: padding,
      margin: margin,
      alignment: alignment,
      child: child,
    );
  }

  /// Factory constructor for hospital map constraints
  factory ConstrainedResponsiveContainer.hospitalMap({
    Key? key,
    required Widget child,
    EdgeInsets? padding,
    EdgeInsets? margin,
    AlignmentGeometry? alignment,
  }) {
    return ConstrainedResponsiveContainer(
      key: key,
      constraints: ResponsiveConstraints.hospitalMap,
      padding: padding,
      margin: margin,
      alignment: alignment,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine final constraints
    final finalConstraints = WidgetConstraints(
      minWidth: minWidth ?? constraints?.minWidth,
      maxWidth: maxWidth ?? constraints?.maxWidth,
      minHeight: minHeight ?? constraints?.minHeight,
      maxHeight: maxHeight ?? constraints?.maxHeight,
      aspectRatio: constraints?.aspectRatio,
    );

    Widget constrainedChild = child;

    // Apply box constraints if any are specified
    if (finalConstraints.minWidth != null ||
        finalConstraints.maxWidth != null ||
        finalConstraints.minHeight != null ||
        finalConstraints.maxHeight != null) {
      constrainedChild = ConstrainedBox(
        constraints: finalConstraints.toBoxConstraints(),
        child: constrainedChild,
      );
    }

    // Apply aspect ratio if specified
    if (finalConstraints.aspectRatio != null) {
      constrainedChild = AspectRatio(
        aspectRatio: finalConstraints.aspectRatio!,
        child: constrainedChild,
      );
    }

    // Apply padding if specified
    if (padding != null) {
      constrainedChild = Padding(padding: padding!, child: constrainedChild);
    }

    // Apply margin if specified
    if (margin != null) {
      constrainedChild = Container(margin: margin, child: constrainedChild);
    }

    // Apply alignment if specified
    if (alignment != null) {
      constrainedChild = Align(alignment: alignment!, child: constrainedChild);
    }

    // Add overflow detection in debug mode
    if (enableOverflowDetection && kDebugMode) {
      constrainedChild = _OverflowDetectionWrapper(child: constrainedChild);
    }

    return constrainedChild;
  }
}

/// Wrapper widget for detecting overflow in debug mode
class _OverflowDetectionWrapper extends StatelessWidget {
  final Widget child;

  const _OverflowDetectionWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return child;
      },
    );
  }
}

/// Extension to add responsive constraints to any widget
extension ResponsiveConstraintsExtension on Widget {
  /// Apply card constraints to this widget
  Widget withCardConstraints({
    EdgeInsets? padding,
    EdgeInsets? margin,
    AlignmentGeometry? alignment,
  }) {
    return ConstrainedResponsiveContainer.card(
      padding: padding,
      margin: margin,
      alignment: alignment,
      child: this,
    );
  }

  /// Apply button constraints to this widget
  Widget withButtonConstraints({
    EdgeInsets? padding,
    EdgeInsets? margin,
    AlignmentGeometry? alignment,
  }) {
    return ConstrainedResponsiveContainer.button(
      padding: padding,
      margin: margin,
      alignment: alignment,
      child: this,
    );
  }

  /// Apply input field constraints to this widget
  Widget withInputFieldConstraints({
    EdgeInsets? padding,
    EdgeInsets? margin,
    AlignmentGeometry? alignment,
  }) {
    return ConstrainedResponsiveContainer.inputField(
      padding: padding,
      margin: margin,
      alignment: alignment,
      child: this,
    );
  }

  /// Apply custom constraints to this widget
  Widget withConstraints({
    double? minWidth,
    double? maxWidth,
    double? minHeight,
    double? maxHeight,
    EdgeInsets? padding,
    EdgeInsets? margin,
    AlignmentGeometry? alignment,
  }) {
    return ConstrainedResponsiveContainer(
      minWidth: minWidth,
      maxWidth: maxWidth,
      minHeight: minHeight,
      maxHeight: maxHeight,
      padding: padding,
      margin: margin,
      alignment: alignment,
      child: this,
    );
  }
}
