import 'package:Bloomee/theme_data/default.dart';
import 'package:flutter/material.dart';

/// Centralized styling constants for widgets to ensure consistency
/// and reduce duplication across the app.
class WidgetStyles {
  // Border Radius Constants
  static const cardBorderRadius = BorderRadius.all(Radius.circular(12));
  static const imageBorderRadius = BorderRadius.all(Radius.circular(10));
  static const bottomSheetBorderRadius = BorderRadius.only(
    topLeft: Radius.circular(20),
    topRight: Radius.circular(20),
  );
  static const smallBorderRadius = BorderRadius.all(Radius.circular(5));
  static const mediumBorderRadius = BorderRadius.all(Radius.circular(10));
  static const largeBorderRadius = BorderRadius.all(Radius.circular(15));

  // Padding Constants
  static const tilePadding = EdgeInsets.only(left: 10, right: 2, top: 4, bottom: 4);
  static const cardPadding = EdgeInsets.symmetric(horizontal: 10, vertical: 6);
  static const buttonPadding = EdgeInsets.symmetric(horizontal: 2);
  static const standardPadding = EdgeInsets.all(8.0);

  // Text Styles - Title variants
  static final titleStyleLarge = Default_Theme.secondoryTextStyleMedium.merge(
    const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: Default_Theme.primaryColor1,
    ),
  );

  static final titleStyleMedium = Default_Theme.tertiaryTextStyle.merge(
    const TextStyle(
      fontWeight: FontWeight.w600,
      color: Default_Theme.primaryColor1,
      fontSize: 14,
    ),
  );

  static final titleStyleSmall = Default_Theme.secondoryTextStyle.merge(
    const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.bold,
      color: Default_Theme.primaryColor1,
    ),
  );

  // Text Styles - Subtitle variants
  static final subtitleStyleLarge = Default_Theme.secondoryTextStyleMedium.merge(
    TextStyle(
      fontSize: 13,
      color: Default_Theme.primaryColor1.withValues(alpha: 0.7),
    ),
  );

  static final subtitleStyleMedium = Default_Theme.tertiaryTextStyle.merge(
    TextStyle(
      color: Default_Theme.primaryColor1.withValues(alpha: 0.8),
      fontSize: 13,
    ),
  );

  static final subtitleStyleSmall = Default_Theme.secondoryTextStyle.merge(
    TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.bold,
      color: Default_Theme.primaryColor2.withValues(alpha: 0.8),
    ),
  );

  // Opacity Presets
  static const opacityHigh = 0.9;
  static const opacityMedium = 0.7;
  static const opacityLow = 0.5;
  static const opacityVeryLow = 0.2;

  // Icon Sizes
  static const iconSizeSmall = 20.0;
  static const iconSizeMedium = 25.0;
  static const iconSizeLarge = 30.0;
  static const iconSizeXLarge = 50.0;

  // Standard Heights
  static const listTileHeight = 70.0;
  static const cardImageHeight = 150.0;

  // Animation Durations
  static const hoverAnimationDuration = Duration(milliseconds: 200);
  static const slideAnimationDuration = Duration(milliseconds: 300);

  // Colors with opacity helpers
  static Color primaryWithOpacity(double opacity) =>
      Default_Theme.primaryColor1.withValues(alpha: opacity);

  static Color secondaryWithOpacity(double opacity) =>
      Default_Theme.primaryColor2.withValues(alpha: opacity);

  static Color accentWithOpacity(double opacity) =>
      Default_Theme.accentColor1.withValues(alpha: opacity);
}
