import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Overflow detection and prevention utilities
class OverflowDetection {
  static bool _debugMode = kDebugMode;

  /// Enable or disable debug mode for overflow detection
  static void setDebugMode(bool enabled) {
    _debugMode = enabled;
  }

  /// Check if debug mode is enabled
  static bool get isDebugMode => _debugMode;

  /// Log overflow warning in debug mode
  static void logOverflowWarning(String widgetName, String details) {
    if (_debugMode) {
      debugPrint('🚨 OVERFLOW WARNING: $widgetName - $details');
    }
  }

  /// Check if a RenderBox has overflow
  static bool hasOverflow(RenderBox renderBox) {
    if (renderBox.hasSize) {
      final size = renderBox.size;
      final constraints = renderBox.constraints;

      // Check if the widget exceeds its constraints
      return size.width > constraints.maxWidth ||
          size.height > constraints.maxHeight;
    }
    return false;
  }

  /// Get overflow information for a RenderBox
  static OverflowInfo getOverflowInfo(RenderBox renderBox) {
    if (!renderBox.hasSize) {
      return const OverflowInfo(hasOverflow: false);
    }

    final size = renderBox.size;
    final constraints = renderBox.constraints;

    final widthOverflow = size.width > constraints.maxWidth
        ? size.width - constraints.maxWidth
        : 0.0;
    final heightOverflow = size.height > constraints.maxHeight
        ? size.height - constraints.maxHeight
        : 0.0;

    return OverflowInfo(
      hasOverflow: widthOverflow > 0 || heightOverflow > 0,
      widthOverflow: widthOverflow,
      heightOverflow: heightOverflow,
      actualSize: size,
      constraints: constraints,
    );
  }
}

/// Information about widget overflow
class OverflowInfo {
  final bool hasOverflow;
  final double widthOverflow;
  final double heightOverflow;
  final Size? actualSize;
  final BoxConstraints? constraints;

  const OverflowInfo({
    required this.hasOverflow,
    this.widthOverflow = 0.0,
    this.heightOverflow = 0.0,
    this.actualSize,
    this.constraints,
  });

  @override
  String toString() {
    if (!hasOverflow) return 'No overflow detected';

    return 'Overflow detected: '
        'Width: ${widthOverflow.toStringAsFixed(1)}px, '
        'Height: ${heightOverflow.toStringAsFixed(1)}px, '
        'Actual size: ${actualSize?.width.toStringAsFixed(1)}x${actualSize?.height.toStringAsFixed(1)}, '
        'Max constraints: ${constraints?.maxWidth.toStringAsFixed(1)}x${constraints?.maxHeight.toStringAsFixed(1)}';
  }
}

/// Widget that automatically detects and prevents overflow
class OverflowSafeWidget extends StatelessWidget {
  final Widget child;
  final String? debugName;
  final bool enableScrolling;
  final ScrollPhysics? scrollPhysics;
  final bool enableAutoFix;

  const OverflowSafeWidget({
    super.key,
    required this.child,
    this.debugName,
    this.enableScrolling = true,
    this.scrollPhysics,
    this.enableAutoFix = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enableAutoFix) {
      return child;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return _OverflowDetector(
          debugName: debugName,
          enableScrolling: enableScrolling,
          scrollPhysics: scrollPhysics,
          child: child,
        );
      },
    );
  }
}

/// Internal widget for detecting overflow and applying fixes
class _OverflowDetector extends StatefulWidget {
  final Widget child;
  final String? debugName;
  final bool enableScrolling;
  final ScrollPhysics? scrollPhysics;

  const _OverflowDetector({
    required this.child,
    this.debugName,
    this.enableScrolling = true,
    this.scrollPhysics,
  });

  @override
  State<_OverflowDetector> createState() => _OverflowDetectorState();
}

class _OverflowDetectorState extends State<_OverflowDetector> {
  bool _hasDetectedOverflow = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // In debug mode, check for overflow after the frame is built
        if (OverflowDetection.isDebugMode) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkForOverflow();
          });
        }

        // If overflow was detected and scrolling is enabled, wrap in scrollable
        if (_hasDetectedOverflow && widget.enableScrolling) {
          return SingleChildScrollView(
            physics: widget.scrollPhysics,
            child: widget.child,
          );
        }

        return widget.child;
      },
    );
  }

  void _checkForOverflow() {
    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      final overflowInfo = OverflowDetection.getOverflowInfo(renderObject);

      if (overflowInfo.hasOverflow && !_hasDetectedOverflow) {
        final widgetName = widget.debugName ?? 'Unknown Widget';
        OverflowDetection.logOverflowWarning(
          widgetName,
          overflowInfo.toString(),
        );

        if (widget.enableScrolling) {
          setState(() {
            _hasDetectedOverflow = true;
          });
        }
      }
    }
  }
}

/// Extension to add overflow detection to any widget
extension OverflowDetectionExtension on Widget {
  /// Wrap this widget with overflow detection and automatic scrolling
  Widget withOverflowDetection({
    String? debugName,
    bool enableScrolling = true,
    ScrollPhysics? scrollPhysics,
    bool enableAutoFix = true,
  }) {
    return OverflowSafeWidget(
      debugName: debugName,
      enableScrolling: enableScrolling,
      scrollPhysics: scrollPhysics,
      enableAutoFix: enableAutoFix,
      child: this,
    );
  }
}

/// Mixin for widgets that want to implement overflow detection
mixin OverflowDetectionMixin<T extends StatefulWidget> on State<T> {
  /// Check for overflow in the current widget
  void checkOverflow({String? debugName}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final renderObject = context.findRenderObject();
      if (renderObject is RenderBox && renderObject.hasSize) {
        final overflowInfo = OverflowDetection.getOverflowInfo(renderObject);

        if (overflowInfo.hasOverflow) {
          final widgetName = debugName ?? T.toString();
          OverflowDetection.logOverflowWarning(
            widgetName,
            overflowInfo.toString(),
          );
          onOverflowDetected(overflowInfo);
        }
      }
    });
  }

  /// Called when overflow is detected - override to handle overflow
  void onOverflowDetected(OverflowInfo overflowInfo) {
    // Default implementation - can be overridden
  }
}
