// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:Bloomee/screens/screen/common_views/song_info_screen.dart';
import 'package:Bloomee/screens/widgets/snackbar.dart';
import 'package:Bloomee/utils/imgurl_formator.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:icons_plus/icons_plus.dart';

import 'package:Bloomee/blocs/mediaPlayer/bloomee_player_cubit.dart';
import 'package:Bloomee/model/songModel.dart';
import 'package:Bloomee/theme_data/default.dart';
import 'package:Bloomee/utils/load_Image.dart';
import 'package:Bloomee/blocs/downloader/cubit/downloader_cubit.dart';
import 'package:Bloomee/utils/dload.dart';

// Cached styles to avoid repeated merges
class _SongCardStyles {
  static final titleStyle = Default_Theme.tertiaryTextStyle.merge(
    const TextStyle(
      fontWeight: FontWeight.w600,
      color: Default_Theme.primaryColor1,
      fontSize: 14,
    ),
  );

  static final subtitleStyle = Default_Theme.tertiaryTextStyle.merge(
    TextStyle(
      color: Default_Theme.primaryColor1.withValues(alpha: 0.8),
      fontSize: 13,
    ),
  );

  static const borderRadius = BorderRadius.all(Radius.circular(12));
  static const imageBorderRadius = BorderRadius.all(Radius.circular(10));
  static const tilePadding =
      EdgeInsets.only(left: 10, right: 2, top: 4, bottom: 4);
  static const buttonPadding = EdgeInsets.symmetric(horizontal: 2);

  // Cached action icons to avoid recreation
  static const playIcon = Icon(
    FontAwesome.play_solid,
    size: 30,
    color: Default_Theme.primaryColor1,
  );
  static const copyIcon = Icon(
    Icons.copy_outlined,
    size: 25,
    color: Default_Theme.primaryColor1,
  );
  static const infoIcon = Icon(
    MingCute.information_line,
    size: 30,
    color: Default_Theme.primaryColor1,
  );
  static const deleteIcon = Icon(
    MingCute.delete_2_line,
    size: 28,
    color: Default_Theme.primaryColor1,
  );
  static const optionsIcon = Icon(
    MingCute.more_2_fill,
    color: Default_Theme.primaryColor1,
  );
}

class SongCardWidget extends StatelessWidget {
  final MediaItemModel song;
  final bool showOptions;
  final bool showInfoBtn;
  final bool showPlayBtn;
  final bool showCopyBtn;
  final bool delDownBtn;
  final bool isWide;
  final String? subtitleOverride;
  final VoidCallback? onOptionsTap;
  final VoidCallback? onInfoTap;
  final VoidCallback? onPlayTap;
  final VoidCallback? onDelDownTap;
  final VoidCallback? onTap;
  final Widget? trailing;

  const SongCardWidget({
    super.key,
    required this.song,
    this.showOptions = true,
    this.showInfoBtn = false,
    this.showPlayBtn = false,
    this.delDownBtn = false,
    this.onOptionsTap,
    this.onInfoTap,
    this.onPlayTap,
    this.onTap,
    this.onDelDownTap,
    this.showCopyBtn = false,
    this.isWide = false,
    this.subtitleOverride,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final playerCubit = context.read<BloomeePlayerCubit>();

    return SizedBox(
      height: 70,
      child: InkWell(
        borderRadius: _SongCardStyles.borderRadius,
        splashColor: Default_Theme.accentColor1.withValues(alpha: 0.2),
        hoverColor: Default_Theme.primaryColor2.withValues(alpha: 0.1),
        highlightColor: Default_Theme.primaryColor2.withValues(alpha: 0.1),
        onTap: onTap,
        onSecondaryTap: onOptionsTap,
        child: Padding(
          padding: _SongCardStyles.tilePadding,
          child: Row(
            children: [
              _PlayingIndicator(
                songId: song.id,
                mediaItemStream: playerCubit.bloomeePlayer.mediaItem,
              ),
              _SongImage(
                imageUrl:
                    formatImgURL(song.artUri.toString(), ImageQuality.low),
                isWide: isWide,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SongInfo(
                  title: song.title,
                  subtitle: subtitleOverride ?? song.artist ?? 'Unknown',
                ),
              ),
              if (showPlayBtn)
                _ActionButton(
                  icon: _SongCardStyles.playIcon,
                  onPressed: onPlayTap,
                ),
              if (showCopyBtn)
                _CopyButton(
                  songTitle: song.title,
                  songArtist: song.artist,
                ),
              if (showInfoBtn)
                _InfoButton(
                  song: song,
                  onInfoTap: onInfoTap,
                ),
              _DownloadStatusButton(song: song), // Always show download button
              if (delDownBtn)
                _DeleteButton(
                  song: song,
                  playerCubit: playerCubit,
                ),
              if (showOptions)
                IconButton(
                  icon: _SongCardStyles.optionsIcon,
                  onPressed: onOptionsTap,
                ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class _DownloadStatusButton extends StatelessWidget {
  final MediaItemModel song;

  const _DownloadStatusButton({required this.song});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DownloaderCubit, DownloaderState>(
      builder: (context, state) {
        Widget content;

        // 1. Check if already downloaded
        final isDownloaded = state.downloaded.any((item) => item.id == song.id);
        if (isDownloaded) {
          content = IconButton(
            icon: const Icon(MingCute.check_circle_fill,
                color: Default_Theme.accentColor1, size: 26),
            onPressed: () {
              SnackbarService.showMessage("Already downloaded");
            },
          );
        } else {
          // 2. Check if currently downloading/queued
          final activeDownload = state.downloads.firstWhere(
              (progress) => progress.task.song.id == song.id,
              orElse: () => DownloadProgress(
                  task: DownloadTask.empty(),
                  status: const DownloadStatus(state: DownloadState.failed)));

          if (activeDownload.task.originalUrl.isNotEmpty) {
            final status = activeDownload.status;

            if (status.state == DownloadState.downloading) {
              // Show Pie Progress
              content = Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    value: status.progress,
                    strokeWidth: 2.0,
                    color: Default_Theme.accentColor1,
                    backgroundColor:
                        Default_Theme.primaryColor2.withValues(alpha: 0.2),
                  ),
                ),
              );
            } else if (status.state == DownloadState.queued ||
                status.state == DownloadState.resolving ||
                status.state == DownloadState.fetchingMetadata) {
              // Show Queue Clock
              content = const Center(
                  child: Icon(MingCute.time_line,
                      color: Default_Theme.primaryColor1, size: 22));
            } else {
              // Fallback for other non-empty states
              content = const SizedBox.shrink();
            }
          } else {
            // 3. Default: Not Downloaded
            content = IconButton(
              icon: const Icon(MingCute.download_2_line,
                  color: Default_Theme.primaryColor1,
                  size: 25), // Standard size
              onPressed: () {
                context
                    .read<DownloaderCubit>()
                    .downloadSong(song, showSnackbar: false);
              },
            );
          }
        }

        // Return fixed-size container for alignment
        return SizedBox(
          width:
              48, // Standard touch target width (matches standard IconButton with padding)
          height: 48,
          child: Center(child: content),
        );
      },
    );
  }
}

// Extracted widget for playing indicator with snappy slide animation
class _PlayingIndicator extends StatefulWidget {
  final String songId;
  final Stream<MediaItem?> mediaItemStream;

  const _PlayingIndicator({
    required this.songId,
    required this.mediaItemStream,
  });

  @override
  State<_PlayingIndicator> createState() => _PlayingIndicatorState();
}

class _PlayingIndicatorState extends State<_PlayingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _slideAnimation;

  bool _isPlaying = false;

  static const double _indicatorWidth = 25.0;
  static const Duration _animationDuration = Duration(milliseconds: 150);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _animationDuration,
    );

    // Single fast animation - width and opacity together
    _slideAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePlayingChange(bool isPlaying) {
    if (_isPlaying == isPlaying) return;
    _isPlaying = isPlaying;

    if (isPlaying) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: widget.mediaItemStream,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data?.id == widget.songId;

        // Direct call - no postFrameCallback delay
        _handlePlayingChange(isPlaying);

        return SizeTransition(
          axis: Axis.horizontal,
          sizeFactor: _slideAnimation,
          child: FadeTransition(
            opacity: _slideAnimation,
            child: Center(
              child: SizedBox(
                width: _indicatorWidth,
                child: const Icon(
                  FontAwesome.caret_right_solid,
                  color: Default_Theme.accentColor1,
                  size: 25,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Extracted widget for song image with RepaintBoundary
class _SongImage extends StatelessWidget {
  final String imageUrl;
  final bool isWide;

  const _SongImage({
    required this.imageUrl,
    required this.isWide,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: _SongCardStyles.imageBorderRadius,
          child: SizedBox(
            width: isWide ? 80 : 55,
            height: 55,
            child: LoadImageCached(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}

// Extracted widget for song info text
class _SongInfo extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SongInfo({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 1),
          child: Text(
            title,
            textAlign: TextAlign.start,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: _SongCardStyles.titleStyle,
          ),
        ),
        Text(
          subtitle,
          textAlign: TextAlign.start,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: _SongCardStyles.subtitleStyle,
        ),
      ],
    );
  }
}

// Reusable action button
class _ActionButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _SongCardStyles.buttonPadding,
      child: IconButton(
        icon: icon,
        onPressed: onPressed,
      ),
    );
  }
}

// Copy button with tooltip
class _CopyButton extends StatelessWidget {
  final String songTitle;
  final String? songArtist;

  const _CopyButton({
    required this.songTitle,
    this.songArtist,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _SongCardStyles.buttonPadding,
      child: Tooltip(
        message: "Copy to clipboard",
        child: IconButton(
          icon: _SongCardStyles.copyIcon,
          onPressed: _copyToClipboard,
        ),
      ),
    );
  }

  void _copyToClipboard() {
    try {
      Clipboard.setData(ClipboardData(text: "$songTitle by $songArtist"));
      SnackbarService.showMessage(
        "Copied to clipboard",
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      SnackbarService.showMessage("Failed to copy $songTitle");
    }
  }
}

// Info button
class _InfoButton extends StatelessWidget {
  final MediaItemModel song;
  final VoidCallback? onInfoTap;

  const _InfoButton({
    required this.song,
    this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _SongCardStyles.buttonPadding,
      child: Tooltip(
        message: "About this song",
        child: IconButton(
          icon: _SongCardStyles.infoIcon,
          onPressed: () {
            if (onInfoTap != null) {
              onInfoTap!();
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SongInfoScreen(song: song),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}

// Delete button
class _DeleteButton extends StatelessWidget {
  final MediaItemModel song;
  final BloomeePlayerCubit playerCubit;

  const _DeleteButton({
    required this.song,
    required this.playerCubit,
  });

  @override
  Widget build(BuildContext context) {
    final downloaderCubit = context.read<DownloaderCubit>();

    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: IconButton(
        icon: _SongCardStyles.deleteIcon,
        onPressed: () => _handleDelete(downloaderCubit),
      ),
    );
  }

  void _handleDelete(DownloaderCubit downloaderCubit) async {
    try {
      if (playerCubit.bloomeePlayer.currentMedia.id != song.id) {
        await downloaderCubit.deleteDownload(song);
        SnackbarService.showMessage("Removed ${song.title}");
      } else {
        SnackbarService.showMessage("Cannot delete currently playing song");
      }
    } catch (e) {
      await downloaderCubit.deleteDownload(song);
      SnackbarService.showMessage("Removed ${song.title}");
    }
  }
}

class SongCardDummyWidget extends StatelessWidget {
  const SongCardDummyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 70,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Container(
                      width: 300,
                      height: 17,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  Container(
                    width: 200,
                    height: 15,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
