import 'package:Bloomee/screens/widgets/base/widget_styles.dart';
import 'package:Bloomee/theme_data/default.dart';
import 'package:Bloomee/utils/imgurl_formator.dart';
import 'package:Bloomee/utils/load_Image.dart';
import 'package:flutter/material.dart';

/// Shape configuration for the list tile image
enum ListTileImageShape {
  square,
  rounded,
  circular,
}

/// Base list tile widget that consolidates common patterns from song_tile, libitem_tile, and chart_list_tile.
/// Provides consistent layout with image, title, subtitle, and action buttons.
class BaseListTile extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onSecondaryTap;
  final VoidCallback? onLongPress;
  final ListTileImageShape imageShape;
  final double imageSize;
  final double? imageWidth;
  final double height;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsets? padding;
  final ImageQuality imageQuality;
  final BoxFit imageFit;
  final bool showHoverEffect;

  const BaseListTile({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.onSecondaryTap,
    this.onLongPress,
    this.imageShape = ListTileImageShape.rounded,
    this.imageSize = 70,
    this.imageWidth,
    this.height = WidgetStyles.listTileHeight,
    this.leading,
    this.trailing,
    this.padding,
    this.imageQuality = ImageQuality.medium,
    this.imageFit = BoxFit.cover,
    this.showHoverEffect = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? WidgetStyles.cardPadding,
      child: SizedBox(
        height: height,
        child: InkWell(
          borderRadius: WidgetStyles.cardBorderRadius,
          splashColor: showHoverEffect
              ? Default_Theme.accentColor1.withValues(alpha: 0.2)
              : Default_Theme.primaryColor2.withValues(alpha: 0.1),
          hoverColor: Default_Theme.primaryColor2.withValues(alpha: 0.1),
          highlightColor: Default_Theme.primaryColor2.withValues(alpha: 0.1),
          onTap: onTap,
          onSecondaryTap: onSecondaryTap,
          onLongPress: onLongPress,
          child: Container(
            color: Colors.transparent,
            child: Row(
              children: [
                if (leading != null) leading!,
                _buildImage(),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildTextInfo(),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    Widget imageContent = LoadImageCached(
      imageUrl: formatImgURL(imageUrl, imageQuality),
      fit: imageFit,
    );

    // Apply shape-specific clipping
    Widget clippedImage;
    switch (imageShape) {
      case ListTileImageShape.circular:
        clippedImage = ClipOval(
          child: SizedBox.square(
            dimension: imageSize,
            child: imageContent,
          ),
        );
        break;
      case ListTileImageShape.rounded:
        clippedImage = ClipRRect(
          borderRadius: WidgetStyles.mediumBorderRadius,
          child: SizedBox(
            width: imageWidth ?? imageSize,
            height: imageSize,
            child: imageContent,
          ),
        );
        break;
      case ListTileImageShape.square:
        clippedImage = ClipRRect(
          borderRadius: WidgetStyles.smallBorderRadius,
          child: SizedBox(
            width: imageWidth ?? imageSize,
            height: imageSize,
            child: imageContent,
          ),
        );
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: clippedImage,
    );
  }

  Widget _buildTextInfo() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: WidgetStyles.titleStyleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: WidgetStyles.subtitleStyleLarge,
        ),
      ],
    );
  }
}
