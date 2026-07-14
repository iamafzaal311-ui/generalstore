/// Responsive Layout Helper
///
/// Provides utilities for building responsive layouts that work across
/// all device sizes (mobile, tablet, desktop).
library;

import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Helper class for responsive design
class ResponsiveHelper {
  /// Get the current device type based on screen width
  static DeviceType getDeviceType(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < ResponsiveBreakpoints.tablet) {
      return DeviceType.mobile;
    } else if (screenWidth < ResponsiveBreakpoints.desktop) {
      return DeviceType.tablet;
    } else if (screenWidth < ResponsiveBreakpoints.largeDesktop) {
      return DeviceType.desktop;
    } else {
      return DeviceType.largeDesktop;
    }
  }

  /// Check if device is mobile
  static bool isMobile(BuildContext context) {
    return getDeviceType(context) == DeviceType.mobile;
  }

  /// Check if device is tablet or larger
  static bool isTablet(BuildContext context) {
    return getDeviceType(context).index >= DeviceType.tablet.index;
  }

  /// Check if device is desktop or larger
  static bool isDesktop(BuildContext context) {
    return getDeviceType(context).index >= DeviceType.desktop.index;
  }

  /// Get adaptive padding based on device type
  static EdgeInsets getAdaptivePadding(BuildContext context) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.mobile:
        return const EdgeInsets.all(AppSpacing.md);
      case DeviceType.tablet:
        return const EdgeInsets.all(AppSpacing.lg);
      case DeviceType.desktop:
      case DeviceType.largeDesktop:
        return const EdgeInsets.all(AppSpacing.xl);
    }
  }

  /// Get adaptive columns for grid layout
  static int getGridColumns(BuildContext context) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.mobile:
        return 1;
      case DeviceType.tablet:
        return 2;
      case DeviceType.desktop:
        return 3;
      case DeviceType.largeDesktop:
        return 4;
    }
  }

  /// Get adaptive font size
  static double getAdaptiveFontSize(
    BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.tablet:
        return tablet ?? mobile + 2;
      case DeviceType.desktop:
      case DeviceType.largeDesktop:
        return desktop ?? mobile + 4;
    }
  }

  /// Get adaptive width for a widget
  static double getAdaptiveWidth(
    BuildContext context, {
    required double mobilePercent,
    double? tabletPercent,
    double? desktopPercent,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final deviceType = getDeviceType(context);

    switch (deviceType) {
      case DeviceType.mobile:
        return screenWidth * mobilePercent;
      case DeviceType.tablet:
        return screenWidth * (tabletPercent ?? 0.8);
      case DeviceType.desktop:
      case DeviceType.largeDesktop:
        return screenWidth * (desktopPercent ?? 0.6);
    }
  }

  /// Get max content width for desktop layout
  static double getMaxContentWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > ResponsiveBreakpoints.largeDesktop) {
      return ResponsiveBreakpoints.largeDesktop * 0.8;
    }
    return screenWidth * 0.9;
  }
}

/// Device types
enum DeviceType {
  mobile,
  tablet,
  desktop,
  largeDesktop,
}

/// Responsive widget builder
/// Usage: ResponsiveBuilder(
///   mobile: (context) => MobileWidget(),
///   tablet: (context) => TabletWidget(),
///   desktop: (context) => DesktopWidget(),
/// )
class ResponsiveBuilder extends StatelessWidget {
  final WidgetBuilder? mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder? desktop;
  final WidgetBuilder? largeDesktop;
  final WidgetBuilder? fallback;

  const ResponsiveBuilder({super.key, 
    this.mobile,
    this.tablet,
    this.desktop,
    this.largeDesktop,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final deviceType = ResponsiveHelper.getDeviceType(context);

    switch (deviceType) {
      case DeviceType.mobile:
        return mobile?.call(context) ?? fallback?.call(context) ?? Container();
      case DeviceType.tablet:
        return tablet?.call(context) ??
            mobile?.call(context) ??
            fallback?.call(context) ??
            Container();
      case DeviceType.desktop:
        return desktop?.call(context) ??
            tablet?.call(context) ??
            mobile?.call(context) ??
            fallback?.call(context) ??
            Container();
      case DeviceType.largeDesktop:
        return largeDesktop?.call(context) ??
            desktop?.call(context) ??
            tablet?.call(context) ??
            mobile?.call(context) ??
            fallback?.call(context) ??
            Container();
    }
  }
}

/// Adaptive container that constrains width on large screens
class AdaptiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;

  const AdaptiveContainer({super.key, 
    required this.child,
    this.maxWidth,
    this.padding,
    this.margin,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final maxContentWidth = maxWidth ?? ResponsiveHelper.getMaxContentWidth(context);

    return Container(
      color: color,
      margin: margin,
      alignment: Alignment.topCenter,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxContentWidth),
        padding: padding,
        child: child,
      ),
    );
  }
}

/// Responsive two-column layout
/// Shows two columns on desktop, one on mobile/tablet
class ResponsiveTwoColumn extends StatelessWidget {
  final Widget first;
  final Widget second;
  final double spacing;

  const ResponsiveTwoColumn({super.key, 
    required this.first,
    required this.second,
    this.spacing = AppSpacing.md,
  });

  @override
  Widget build(BuildContext context) {
    if (ResponsiveHelper.isDesktop(context)) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: first),
          SizedBox(width: spacing),
          Expanded(child: second),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        first,
        SizedBox(height: spacing),
        second,
      ],
    );
  }
}

/// Responsive grid with adaptive columns
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final int? mobileColumns;
  final int? tabletColumns;
  final int? desktopColumns;

  const ResponsiveGrid({super.key, 
    required this.children,
    this.spacing = AppSpacing.md,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 3,
  });

  @override
  Widget build(BuildContext context) {
    int columns = ResponsiveHelper.getGridColumns(context);

    return GridView.count(
      crossAxisCount: columns,
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: children,
    );
  }
}
