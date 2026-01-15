import 'package:Bloomee/screens/widgets/base/widget_styles.dart';
import 'package:Bloomee/utils/imgurl_formator.dart';
import 'package:Bloomee/utils/load_Image.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';

/// Shape configuration for the card image
enum CardImageShape {
  square,
  rounded,
  circular,
}

/// Base card widget that consolidates common patterns from album_card, artist_card, and playlist_card.
/// Provides hover effects, image loading, and navigation support.
class BaseCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final CardImageShape imageShape;
  final double imageSize;
  final double? width;
  final String? heroTag;
  final bool showHoverEffect;
  final Widget? trailing;
  final EdgeInsets? padding;
  final ImageQuality imageQuality;

  const BaseCard({
    super.key,
    required this.imageUrl,
    required this.title,
    this.subtitle,
    this.onTap,
    this.imageShape = CardImageShape.rounded,
    this.imageSize = 160,
    this.width,
    this.heroTag,
    this.showHoverEffect = true,
    this.trailing,
    this.padding,
    this.imageQuality = ImageQuality.medium,
  });

  @override
  Widget build(BuildContext context) {
    final ValueNotifier<bool> hovering = ValueNotifier(false);

    Widget imageWidget = _buildImage(hovering);

    // Wrap in Hero if tag is provided
    if (heroTag != null) {
      imageWidget = Hero(
        tag: heroTag!,
        child: imageWidget,
      );
    }

    return Padding(
      padding: padding ?? const EdgeInsets.only(top: 10),
      child: SizedBox(
        width: width ?? 180,
        child: GestureDetector(
          onTap: onTap,
          child: Card(
            color: Colors.transparent,
            shadowColor: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                imageWidget,
                _buildTextInfo(),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage(ValueNotifier<bool> hovering) {
    Widget imageContent = Stack(
      children: [
        LoadImageCached(
          imageUrl: formatImgURL(imageUrl, imageQuality),
          fit: BoxFit.cover,
        ),
        if (showHoverEffect)
          ValueListenableBuilder(
            valueListenable: hovering,
            builder: (context, isHovering, child) {
              return Positioned.fill(
                child: AnimatedContainer(
                  duration: WidgetStyles.hoverAnimationDuration,
                  color: isHovering
                      ? Colors.black.withValues(alpha: 0.5)
                      : Colors.transparent,
                  child: Center(
                    child: AnimatedOpacity(
                      duration: WidgetStyles.hoverAnimationDuration,
                      opacity: isHovering ? 1 : 0,
                      child: Icon(
                        MingCute.play_circle_line,
                        color: Colors.white,
                        size: imageShape == CardImageShape.circular
                            ? WidgetStyles.iconSizeXLarge
                            : WidgetStyles.iconSizeLarge,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );

    // Apply shape-specific clipping
    Widget clippedImage;
    switch (imageShape) {
      case CardImageShape.circular:
        clippedImage = ClipOval(
          child: SizedBox.square(
            dimension: imageSize,
            child: imageContent,
          ),
        );
        break;
      case CardImageShape.rounded:
        clippedImage = ClipRRect(
          borderRadius: WidgetStyles.mediumBorderRadius,
          child: SizedBox.square(
            dimension: imageSize,
            child: imageContent,
          ),
        );
        break;
      case CardImageShape.square:
        clippedImage = ClipRRect(
          borderRadius: WidgetStyles.smallBorderRadius,
          child: SizedBox.square(
            dimension: imageSize,
            child: imageContent,
          ),
        );
        break;
    }

    return MouseRegion(
      onEnter: (_) => hovering.value = true,
      onExit: (_) => hovering.value = false,
      child: clippedImage,
    );
  }

  Widget _buildTextInfo() {
    return SizedBox(
      width: imageSize,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              maxLines: imageShape == CardImageShape.circular ? 3 : 1,
              textAlign: imageShape == CardImageShape.circular
                  ? TextAlign.center
                  : TextAlign.start,
              overflow: TextOverflow.ellipsis,
              style: WidgetStyles.titleStyleSmall,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                maxLines: 1,
                textAlign: imageShape == CardImageShape.circular
                    ? TextAlign.center
                    : TextAlign.start,
                overflow: TextOverflow.ellipsis,
                style: WidgetStyles.subtitleStyleSmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
