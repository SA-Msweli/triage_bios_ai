import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// Extension to add overflow detection to widgets for debugging
extension OverflowDetection on Widget {
  /// Wraps widget with overflow detection for debugging purposes
  Widget withOverflowDetection({String? debugName}) {
    if (kDebugMode) {
      return _OverflowDetectionWrapper(
        debugName: debugName,
        child: this,
      );
    }
    return this;
  }
}

class _OverflowDetectionWrapper extends StatelessWidget {
  final Widget child;
  final String? debugName;

  const _OverflowDetectionWrapper({
    required this.child,
    this.debugName,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: 0,
          minHeight: 0,
          maxWidth: constraints.maxWidth,
          maxHeight: constraints.maxHeight,
          child: Stack(
            children: [
              child,
              if (kDebugMode)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha((0.7 * 255).round()),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      debugName ?? 'Widget',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Custom render object for detecting overflow
class OverflowDetector extends SingleChildRenderObjectWidget {
  final String? debugName;

  const OverflowDetector({
    super.key,
    required Widget child,
    this.debugName,
  }) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderOverflowDetector(debugName: debugName);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderOverflowDetector renderObject,
  ) {
    renderObject.debugName = debugName;
  }
}

class RenderOverflowDetector extends RenderProxyBox {
  String? debugName;

  RenderOverflowDetector({this.debugName});

  @override
  void performLayout() {
    super.performLayout();
    
    if (kDebugMode && child != null) {
      final childSize = child!.size;
      final constraintSize = constraints.biggest;
      
      if (childSize.width > constraintSize.width ||
          childSize.height > constraintSize.height) {
        debugPrint(
          'OVERFLOW DETECTED in ${debugName ?? 'Widget'}: '
          'Child size: $childSize, Constraint size: $constraintSize',
        );
      }
    }
  }
}