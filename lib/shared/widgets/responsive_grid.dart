import 'package:flutter/material.dart';
import '../utils/responsive_breakpoints.dart';

/// Responsive grid widget that adapts column count based on screen size
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int mobileColumns;
  final int tabletColumns;
  final int desktopColumns;
  final double spacing;
  final double runSpacing;
  final EdgeInsets? padding;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 3,
    this.spacing = 16.0,
    this.runSpacing = 16.0,
    this.padding,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    final columns = _getColumnCount(context);

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    // Create rows of widgets based on column count
    final rows = <Widget>[];
    for (int i = 0; i < children.length; i += columns) {
      final rowChildren = <Widget>[];

      for (int j = 0; j < columns && (i + j) < children.length; j++) {
        rowChildren.add(Expanded(child: children[i + j]));
      }

      // Fill remaining slots with empty expanded widgets
      while (rowChildren.length < columns) {
        rowChildren.add(const Expanded(child: SizedBox.shrink()));
      }

      rows.add(
        Row(
          mainAxisAlignment: mainAxisAlignment,
          crossAxisAlignment: crossAxisAlignment,
          children: rowChildren,
        ),
      );
    }

    Widget grid = Column(
      mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
      children: rows.map((row) {
        return Padding(
          padding: EdgeInsets.only(bottom: runSpacing),
          child: row,
        );
      }).toList(),
    );

    if (padding != null) {
      grid = Padding(padding: padding!, child: grid);
    }

    return grid;
  }

  int _getColumnCount(BuildContext context) {
    if (ResponsiveBreakpoints.isMobile(context)) {
      return mobileColumns;
    } else if (ResponsiveBreakpoints.isTablet(context)) {
      return tabletColumns;
    } else {
      return desktopColumns;
    }
  }
}

/// Responsive wrap widget that adapts spacing based on screen size
class ResponsiveWrap extends StatelessWidget {
  final List<Widget> children;
  final Axis direction;
  final WrapAlignment alignment;
  final double? spacing;
  final WrapAlignment runAlignment;
  final double? runSpacing;
  final WrapCrossAlignment crossAxisAlignment;
  final TextDirection? textDirection;
  final VerticalDirection verticalDirection;
  final Clip clipBehavior;

  const ResponsiveWrap({
    super.key,
    required this.children,
    this.direction = Axis.horizontal,
    this.alignment = WrapAlignment.start,
    this.spacing,
    this.runAlignment = WrapAlignment.start,
    this.runSpacing,
    this.crossAxisAlignment = WrapCrossAlignment.start,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    this.clipBehavior = Clip.none,
  });

  @override
  Widget build(BuildContext context) {
    final responsiveSpacing = spacing ?? _getResponsiveSpacing(context);
    final responsiveRunSpacing = runSpacing ?? _getResponsiveSpacing(context);

    return Wrap(
      direction: direction,
      alignment: alignment,
      spacing: responsiveSpacing,
      runAlignment: runAlignment,
      runSpacing: responsiveRunSpacing,
      crossAxisAlignment: crossAxisAlignment,
      textDirection: textDirection,
      verticalDirection: verticalDirection,
      clipBehavior: clipBehavior,
      children: children,
    );
  }

  double _getResponsiveSpacing(BuildContext context) {
    if (ResponsiveBreakpoints.isMobile(context)) {
      return 8.0;
    } else if (ResponsiveBreakpoints.isTablet(context)) {
      return 12.0;
    } else {
      return 16.0;
    }
  }
}

/// Responsive two-column layout that switches to single column on mobile
class ResponsiveTwoColumnLayout extends StatelessWidget {
  final Widget leftChild;
  final Widget rightChild;
  final double spacing;
  final double leftFlex;
  final double rightFlex;
  final EdgeInsets? padding;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;

  const ResponsiveTwoColumnLayout({
    super.key,
    required this.leftChild,
    required this.rightChild,
    this.spacing = 16.0,
    this.leftFlex = 1.0,
    this.rightFlex = 1.0,
    this.padding,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    Widget layout;

    if (ResponsiveBreakpoints.isMobile(context)) {
      // Single column layout for mobile
      layout = Column(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        children: [
          leftChild,
          SizedBox(height: spacing),
          rightChild,
        ],
      );
    } else {
      // Two column layout for tablet and desktop
      layout = Row(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        children: [
          Expanded(flex: leftFlex.round(), child: leftChild),
          SizedBox(width: spacing),
          Expanded(flex: rightFlex.round(), child: rightChild),
        ],
      );
    }

    if (padding != null) {
      layout = Padding(padding: padding!, child: layout);
    }

    return layout;
  }
}

/// Responsive three-column layout that adapts based on screen size
class ResponsiveThreeColumnLayout extends StatelessWidget {
  final Widget leftChild;
  final Widget centerChild;
  final Widget rightChild;
  final double spacing;
  final double leftFlex;
  final double centerFlex;
  final double rightFlex;
  final EdgeInsets? padding;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;

  const ResponsiveThreeColumnLayout({
    super.key,
    required this.leftChild,
    required this.centerChild,
    required this.rightChild,
    this.spacing = 16.0,
    this.leftFlex = 1.0,
    this.centerFlex = 2.0,
    this.rightFlex = 1.0,
    this.padding,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    Widget layout;

    if (ResponsiveBreakpoints.isMobile(context)) {
      // Single column layout for mobile
      layout = Column(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        children: [
          leftChild,
          SizedBox(height: spacing),
          centerChild,
          SizedBox(height: spacing),
          rightChild,
        ],
      );
    } else if (ResponsiveBreakpoints.isTablet(context)) {
      // Two column layout for tablet (center and right combined)
      layout = Row(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        children: [
          Expanded(flex: leftFlex.round(), child: leftChild),
          SizedBox(width: spacing),
          Expanded(
            flex: (centerFlex + rightFlex).round(),
            child: Column(
              children: [
                centerChild,
                SizedBox(height: spacing),
                rightChild,
              ],
            ),
          ),
        ],
      );
    } else {
      // Three column layout for desktop
      layout = Row(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        children: [
          Expanded(flex: leftFlex.round(), child: leftChild),
          SizedBox(width: spacing),
          Expanded(flex: centerFlex.round(), child: centerChild),
          SizedBox(width: spacing),
          Expanded(flex: rightFlex.round(), child: rightChild),
        ],
      );
    }

    if (padding != null) {
      layout = Padding(padding: padding!, child: layout);
    }

    return layout;
  }
}
