import 'package:Bloomee/screens/widgets/base/widget_styles.dart';
import 'package:Bloomee/theme_data/default.dart';
import 'package:flutter/material.dart';

/// Base bottom sheet wrapper that consolidates common styling and structure
/// from more_bottom_sheet and createPlaylist_bottomsheet.
class BaseBottomSheet extends StatelessWidget {
  final Widget child;
  final bool useGradient;
  final Color? backgroundColor;
  final EdgeInsets? padding;
  final double? height;
  final bool isScrollControlled;

  const BaseBottomSheet({
    super.key,
    required this.child,
    this.useGradient = true,
    this.backgroundColor,
    this.padding,
    this.height,
    this.isScrollControlled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: useGradient
            ? const LinearGradient(
                colors: [
                  Color.fromARGB(255, 7, 17, 50),
                  Color.fromARGB(255, 5, 0, 24),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.5],
              )
            : null,
        color:
            backgroundColor ?? (useGradient ? null : Default_Theme.themeColor),
        borderRadius: WidgetStyles.bottomSheetBorderRadius,
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: child,
      ),
    );
  }

  /// Helper method to show a bottom sheet with consistent styling
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    bool useGradient = true,
    Color? backgroundColor,
    EdgeInsets? padding,
    double? height,
    bool isScrollControlled = true,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      builder: (context) => BaseBottomSheet(
        useGradient: useGradient,
        backgroundColor: backgroundColor,
        padding: padding,
        height: height,
        isScrollControlled: isScrollControlled,
        child: child,
      ),
    );
  }
}

/// Standard bottom sheet list tile for consistent action items
class BottomSheetListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? textColor;
  final double iconSize;

  const BottomSheetListTile({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
    this.iconColor,
    this.textColor,
    this.iconSize = 28,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? Default_Theme.primaryColor1,
        size: iconSize,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? Default_Theme.primaryColor1,
          fontFamily: "Unageo",
          fontSize: 17,
          fontWeight: FontWeight.w400,
        ),
      ),
      onTap: onTap,
    );
  }
}
