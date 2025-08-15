import 'package:flutter/material.dart';
import '../utils/responsive_breakpoints.dart';
import 'constrained_responsive_container.dart';

/// Responsive two-column layout that adapts based on screen size
class ResponsiveTwoColumnLayout extends StatelessWidget {
  final Widget leftChild;
  final Widget rightChild;
  final double leftFlex;
  final double rightFlex;
  final double spacing;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;

  const ResponsiveTwoColumnLayout({
    super.key,
    required this.leftChild,
    required this.rightChild,
    this.leftFlex = 1.0,
    this.rightFlex = 1.0,
    this.spacing = 16.0,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisAlignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    // On mobile, stack vertically
    if (ResponsiveBreakpoints.isMobile(context)) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: crossAxisAlignment,
          mainAxisAlignment: mainAxisAlignment,
          children: [
            leftChild,
            SizedBox(height: spacing),
            rightChild,
          ],
        ),
      );
    }

    // On tablet and desktop, use row layout
    return Row(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisAlignment: mainAxisAlignment,
      children: [
        Expanded(flex: leftFlex.round(), child: leftChild),
        SizedBox(width: spacing),
        Expanded(flex: rightFlex.round(), child: rightChild),
      ],
    );
  }
}

/// Responsive three-column layout for desktop with adaptive behavior
class ResponsiveThreeColumnLayout extends StatelessWidget {
  final Widget leftChild;
  final Widget centerChild;
  final Widget rightChild;
  final double leftFlex;
  final double centerFlex;
  final double rightFlex;
  final double spacing;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;

  const ResponsiveThreeColumnLayout({
    super.key,
    required this.leftChild,
    required this.centerChild,
    required this.rightChild,
    this.leftFlex = 1.0,
    this.centerFlex = 2.0,
    this.rightFlex = 1.0,
    this.spacing = 0.0,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisAlignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    // On mobile, show only center content with drawer/modal for side panels
    if (ResponsiveBreakpoints.isMobile(context)) {
      return centerChild;
    }

    // On tablet, show two columns (center + right)
    if (ResponsiveBreakpoints.isTablet(context)) {
      return ResponsiveTwoColumnLayout(
        leftChild: centerChild,
        rightChild: rightChild,
        leftFlex: centerFlex,
        rightFlex: rightFlex,
        spacing: spacing,
        crossAxisAlignment: crossAxisAlignment,
        mainAxisAlignment: mainAxisAlignment,
      );
    }

    // On desktop, show all three columns
    return Row(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisAlignment: mainAxisAlignment,
      children: [
        Expanded(flex: leftFlex.round(), child: leftChild),
        if (spacing > 0) SizedBox(width: spacing),
        Expanded(flex: centerFlex.round(), child: centerChild),
        if (spacing > 0) SizedBox(width: spacing),
        Expanded(flex: rightFlex.round(), child: rightChild),
      ],
    );
  }
}

/// Responsive grid layout that adapts column count based on screen size
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int mobileColumns;
  final int tabletColumns;
  final int desktopColumns;
  final double spacing;
  final double runSpacing;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 3,
    this.spacing = 16.0,
    this.runSpacing = 16.0,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisAlignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    int columns;
    if (ResponsiveBreakpoints.isMobile(context)) {
      columns = mobileColumns;
    } else if (ResponsiveBreakpoints.isTablet(context)) {
      columns = tabletColumns;
    } else {
      columns = desktopColumns;
    }

    if (columns == 1) {
      return Column(
        crossAxisAlignment: crossAxisAlignment,
        mainAxisAlignment: mainAxisAlignment,
        children: children
            .map(
              (child) => Padding(
                padding: EdgeInsets.only(bottom: runSpacing),
                child: child,
              ),
            )
            .toList(),
      );
    }

    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: children.map((child) {
        return SizedBox(
          width:
              (MediaQuery.of(context).size.width -
                  (spacing * (columns - 1)) -
                  ResponsiveBreakpoints.getResponsivePadding(
                    context,
                  ).horizontal) /
              columns,
          child: child,
        );
      }).toList(),
    );
  }
}

/// Responsive card layout with adaptive sizing
class ResponsiveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double? elevation;
  final Color? color;
  final BorderRadius? borderRadius;

  const ResponsiveCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.elevation,
    this.color,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedResponsiveContainer.card(
      margin: margin ?? ResponsiveBreakpoints.getResponsiveMargin(context),
      child: Card(
        elevation: elevation,
        color: color,
        shape: borderRadius != null
            ? RoundedRectangleBorder(borderRadius: borderRadius!)
            : null,
        child: Padding(
          padding:
              padding ?? ResponsiveBreakpoints.getResponsivePadding(context),
          child: child,
        ),
      ),
    );
  }
}

/// Responsive navigation layout that switches between sidebar and bottom navigation
class ResponsiveNavigation extends StatelessWidget {
  final Widget child;
  final List<NavigationItem> navigationItems;
  final int currentIndex;
  final ValueChanged<int>? onTap;
  final Widget? drawer;

  const ResponsiveNavigation({
    super.key,
    required this.child,
    required this.navigationItems,
    required this.currentIndex,
    this.onTap,
    this.drawer,
  });

  @override
  Widget build(BuildContext context) {
    if (ResponsiveBreakpoints.isMobile(context)) {
      return Scaffold(
        body: child,
        drawer: drawer,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: onTap,
          type: BottomNavigationBarType.fixed,
          items: navigationItems
              .map(
                (item) => BottomNavigationBarItem(
                  icon: Icon(item.icon),
                  label: item.label,
                ),
              )
              .toList(),
        ),
      );
    }

    // Desktop/tablet: sidebar navigation
    return Row(
      children: [
        ConstrainedResponsiveContainer(
          minWidth: 250,
          maxWidth: 300,
          child: Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Column(
              children: [
                ...navigationItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final isSelected = index == currentIndex;

                  return ListTile(
                    leading: Icon(
                      item.icon,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : null,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    selected: isSelected,
                    onTap: () => onTap?.call(index),
                  );
                }),
              ],
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// Navigation item model
class NavigationItem {
  final IconData icon;
  final String label;
  final String? route;

  const NavigationItem({required this.icon, required this.label, this.route});
}
