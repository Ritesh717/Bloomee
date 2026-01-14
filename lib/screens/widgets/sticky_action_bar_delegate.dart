import 'package:Bloomee/theme_data/default.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';

class StickyActionBarDelegate extends SliverPersistentHeaderDelegate {
  final VoidCallback onPlay;
  final VoidCallback onLike;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final VoidCallback onAddToPlaylist;
  final VoidCallback onExternalLink; // Was onMore
  final bool isLiked;
  final bool isDownloaded;
  final double height;
  final bool showDownload;

  StickyActionBarDelegate({
    required this.onPlay,
    required this.onLike,
    required this.onDownload,
    required this.onShare,
    required this.onAddToPlaylist,
    required this.onExternalLink,
    required this.isLiked,
    required this.isDownloaded,
    this.height = 60.0,
    this.showDownload = true,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Default_Theme.themeColor,
        border: Border(
          bottom: BorderSide(
            color: Default_Theme.primaryColor2.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Play Button
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor:
                      Default_Theme.primaryColor2.withValues(alpha: 0.1),
                  side: const BorderSide(
                    width: 1,
                    color: Default_Theme.accentColor2,
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: onPlay,
                label: const Text(
                  "Play",
                  style: TextStyle(
                      color: Default_Theme.primaryColor1,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                icon: const Icon(
                  MingCute.play_fill,
                  size: 22,
                  color: Default_Theme.primaryColor1,
                ),
              ),
            ),
          ),

          // Action Buttons Row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Like
              IconButton(
                onPressed: onLike,
                icon: Icon(
                  isLiked ? FontAwesome.heart_solid : FontAwesome.heart,
                  color: Default_Theme.accentColor2,
                  size: 22,
                ),
                tooltip: "Save to Library",
              ),

              // Save to Playlist (New)
              IconButton(
                onPressed: onAddToPlaylist,
                icon: const Icon(
                  MingCute.playlist_line,
                  color: Default_Theme.primaryColor1,
                ),
                tooltip: "Save to Playlist",
              ),

              // Download
              if (showDownload)
                Tooltip(
                  message: isDownloaded ? "Downloaded" : "Download All",
                  child: IconButton(
                    onPressed: onDownload,
                    icon: Icon(
                      isDownloaded
                          ? MingCute.check_circle_fill
                          : MingCute.download_2_line,
                      color: isDownloaded
                          ? Default_Theme.accentColor2
                          : Default_Theme.primaryColor1,
                      size: 24,
                    ),
                  ),
                ),

              // Share
              IconButton(
                onPressed: onShare,
                icon: const Icon(
                  Icons.share_rounded,
                  color: Default_Theme.primaryColor1,
                  size: 22,
                ),
                tooltip: "Share",
              ),

              // External Link (Was More)
              IconButton(
                onPressed: onExternalLink,
                icon: const Icon(
                  MingCute.external_link_line,
                  color: Default_Theme.primaryColor1,
                  size: 24,
                ),
                tooltip: "Open Original Link",
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(StickyActionBarDelegate oldDelegate) {
    return oldDelegate.isLiked != isLiked ||
        oldDelegate.isDownloaded != isDownloaded ||
        oldDelegate.onPlay != onPlay;
  }
}
