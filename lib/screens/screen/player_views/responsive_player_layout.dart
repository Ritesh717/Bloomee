import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';

/// Responsive layout manager for the player screen
/// Handles different layouts for mobile, tablet, and desktop

enum PlayerLayoutType {
  mobile,
  tablet,
  desktop,
}

class ResponsivePlayerLayout extends StatelessWidget {
  final Widget mobileLayout;
  final Widget? tabletLayout;
  final Widget? desktopLayout;

  const ResponsivePlayerLayout({
    super.key,
    required this.mobileLayout,
    this.tabletLayout,
    this.desktopLayout,
  });

  PlayerLayoutType _getLayoutType(BuildContext context) {
    final breakpoint = ResponsiveBreakpoints.of(context);
    
    if (breakpoint.largerThan(TABLET)) {
      return PlayerLayoutType.desktop;
    } else if (breakpoint.largerThan(MOBILE)) {
      return PlayerLayoutType.tablet;
    }
    return PlayerLayoutType.mobile;
  }

  @override
  Widget build(BuildContext context) {
    final layoutType = _getLayoutType(context);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: _buildLayout(layoutType),
    );
  }

  Widget _buildLayout(PlayerLayoutType type) {
    switch (type) {
      case PlayerLayoutType.desktop:
        return desktopLayout ?? tabletLayout ?? mobileLayout;
      case PlayerLayoutType.tablet:
        return tabletLayout ?? mobileLayout;
      case PlayerLayoutType.mobile:
        return mobileLayout;
    }
  }
}

/// Layout configuration for different screen sizes
class PlayerLayoutConfig {
  final double albumArtSize;
  final double controlsSpacing;
  final double horizontalPadding;
  final double verticalPadding;
  final bool showLargeControls;
  final bool enableGestures;

  const PlayerLayoutConfig({
    required this.albumArtSize,
    required this.controlsSpacing,
    required this.horizontalPadding,
    required this.verticalPadding,
    this.showLargeControls = false,
    this.enableGestures = true,
  });

  static PlayerLayoutConfig forMobile(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return PlayerLayoutConfig(
      albumArtSize: size.width * 0.85,
      controlsSpacing: 20,
      horizontalPadding: 16,
      verticalPadding: 20,
      showLargeControls: true,
      enableGestures: true,
    );
  }

  static PlayerLayoutConfig forTablet(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return PlayerLayoutConfig(
      albumArtSize: size.width * 0.60,
      controlsSpacing: 24,
      horizontalPadding: 32,
      verticalPadding: 24,
      showLargeControls: true,
      enableGestures: true,
    );
  }

  static PlayerLayoutConfig forDesktop(BuildContext context) {
    return const PlayerLayoutConfig(
      albumArtSize: 400,
      controlsSpacing: 28,
      horizontalPadding: 48,
      verticalPadding: 32,
      showLargeControls: false,
      enableGestures: false,
    );
  }

  static PlayerLayoutConfig fromContext(BuildContext context) {
    final breakpoint = ResponsiveBreakpoints.of(context);
    
    if (breakpoint.largerThan(TABLET)) {
      return forDesktop(context);
    } else if (breakpoint.largerThan(MOBILE)) {
      return forTablet(context);
    }
    return forMobile(context);
  }
}
