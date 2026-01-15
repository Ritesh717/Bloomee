import 'dart:ui';
import 'package:Bloomee/blocs/add_to_playlist/cubit/add_to_playlist_cubit.dart';
import 'package:Bloomee/blocs/mediaPlayer/bloomee_player_cubit.dart';
import 'package:Bloomee/blocs/downloader/cubit/downloader_cubit.dart';
import 'package:Bloomee/blocs/mini_player/mini_player_bloc.dart';
import 'package:Bloomee/blocs/player_overlay/player_overlay_cubit.dart';
import 'package:Bloomee/model/songModel.dart';
import 'package:Bloomee/screens/screen/common_views/add_to_playlist_screen.dart';
import 'package:Bloomee/screens/screen/home_views/timer_view.dart';
import 'package:Bloomee/screens/widgets/up_next_panel.dart';
import 'package:Bloomee/screens/widgets/gradient_progress_bar.dart';
import 'package:Bloomee/screens/widgets/more_bottom_sheet.dart';
import 'package:Bloomee/screens/widgets/snackbar.dart';
import 'package:Bloomee/services/bloomeePlayer.dart';
import 'package:Bloomee/services/db/cubit/bloomee_db_cubit.dart';
import 'package:Bloomee/services/import_export_service.dart';
import 'package:Bloomee/theme_data/default.dart';
import 'package:Bloomee/utils/dload.dart';
import 'package:Bloomee/utils/imgurl_formator.dart';
import 'package:Bloomee/utils/load_Image.dart';
import 'package:Bloomee/utils/pallete_generator.dart';
import 'package:audio_service/audio_service.dart';
// import 'package:audio_video_progress_bar/audio_video_progress_bar.dart'; // Removed invalid import
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:just_audio/just_audio.dart'; // For LoopMode
import 'package:responsive_framework/responsive_framework.dart';
import 'package:share_plus/share_plus.dart';
import 'player_views/lyrics_widget.dart';

class AudioPlayerView extends StatefulWidget {
  const AudioPlayerView({super.key});

  @override
  State<AudioPlayerView> createState() => _AudioPlayerViewState();
}

class _AudioPlayerViewState extends State<AudioPlayerView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final UpNextPanelController _upNextPanelController = UpNextPanelController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Register the collapse callback with PlayerOverlayCubit
    // This allows GlobalFooter to collapse the panel on back gesture
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PlayerOverlayCubit>().registerUpNextPanelCollapse(
              () => _upNextPanelController.collapse(),
            );
      }
    });
  }

  @override
  void dispose() {
    // Unregister the collapse callback
    context.read<PlayerOverlayCubit>().unregisterUpNextPanelCollapse();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bloomeePlayerCubit = context.read<BloomeePlayerCubit>();
    final musicPlayer = bloomeePlayerCubit.bloomeePlayer;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 12, 4, 9),
      resizeToAvoidBottomInset: false,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Default_Theme.primaryColor1,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
          onPressed: () {
            // If upnext panel is expanded, collapse it first
            // Otherwise hide the player
            if (!_upNextPanelController.collapse()) {
              context.read<PlayerOverlayCubit>().hidePlayer();
            }
          },
        ),
        actions: [
          IconButton(
              onPressed: () =>
                  showMoreBottomSheet(context, musicPlayer.currentMedia),
              icon: const Icon(MingCute.more_2_fill,
                  size: 25, color: Default_Theme.primaryColor1))
        ],
        title: Column(
          children: [
            Text(
              'Enjoying From',
              textAlign: TextAlign.center,
              style: const TextStyle(
                      color: Default_Theme.primaryColor1,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)
                  .merge(Default_Theme.secondoryTextStyle),
            ),
            StreamBuilder<String>(
                stream: bloomeePlayerCubit.bloomeePlayer.queueTitle,
                builder: (context, snapshot) {
                  return Text(
                    snapshot.data ?? "Unknown",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Default_Theme.primaryColor2,
                      fontSize: 12,
                    ).merge(Default_Theme.secondoryTextStyle),
                  );
                }),
          ],
        ),
      ),
      body: AnimatedSwitcher(
          duration: const Duration(seconds: 1),
          child: ResponsiveBreakpoints.of(context).smallerOrEqualTo(TABLET)
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        _PlayerUI(
                          musicPlayer: musicPlayer,
                          tabController: _tabController,
                          constraints: constraints,
                        ),
                        UpNextPanel(
                          peekHeight: 72.0,
                          parentHeight: constraints.maxHeight,
                          controller: _upNextPanelController,
                        ),
                      ],
                    );
                  },
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ConstrainedBox(
                        constraints: BoxConstraints(
                            minWidth: 400,
                            maxWidth: MediaQuery.of(context).size.width * 0.60),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: LayoutBuilder(builder: (context, constraints) {
                            return _PlayerUI(
                              musicPlayer: musicPlayer,
                              tabController: _tabController,
                              constraints: constraints,
                            );
                          }),
                        )),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(15.0),
                        child: SizedBox(
                            height: MediaQuery.of(context).size.height * 0.8,
                            child: UpNextPanel(
                                peekHeight: 60,
                                parentHeight:
                                    MediaQuery.of(context).size.height * 0.8,
                                isDesktopMode: true,
                                controller: _upNextPanelController)),
                      ),
                    )
                  ],
                )),
    );
  }
}

class _PlayerUI extends StatelessWidget {
  final BloomeeMusicPlayer musicPlayer;
  final TabController tabController;
  final BoxConstraints constraints;

  const _PlayerUI({
    required this.musicPlayer,
    required this.tabController,
    required this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: constraints.maxHeight * 0.92,
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: tabController.animation!,
                    builder: (context, child) {
                      final opacity = (1 - tabController.animation!.value);
                      return Opacity(
                        opacity: opacity,
                        child: child,
                      );
                    },
                    child: const AmbientImgShadowWidget(),
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight * 0.90,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: SizedBox(
                      width: constraints.maxWidth * 0.90,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(child: SizedBox(height: 5)),
                          Flexible(
                            flex: 7,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: TabBarView(
                                controller: tabController,
                                physics: const BouncingScrollPhysics(),
                                children: [
                                  Tab(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 10),
                                      child: CoverImageVolSlider(
                                          constraints: constraints),
                                    ),
                                  ),
                                  Tab(
                                    child: ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(minHeight: 200),
                                      child: LyricsWidget(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          PlayerCtrlWidgets(musicPlayer: musicPlayer)
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CoverImageVolSlider extends StatelessWidget {
  final BoxConstraints constraints;
  const CoverImageVolSlider({super.key, required this.constraints});

  @override
  Widget build(BuildContext context) {
    final bloomeePlayerCubit = context.read<BloomeePlayerCubit>();
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: StreamBuilder<MediaItem?>(
            stream: bloomeePlayerCubit.bloomeePlayer.mediaItem,
            builder: (context, snapshot) {
              final artUri = snapshot.data?.artUri?.toString() ?? "";
              return LayoutBuilder(builder: (context, constraints) {
                return ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * 0.98,
                      maxHeight: constraints.maxHeight * 0.98),
                  child: LoadImageCached(
                      imageUrl: formatImgURL(artUri, ImageQuality.high),
                      fallbackUrl: formatImgURL(artUri, ImageQuality.medium),
                      fit: BoxFit.fitWidth),
                );
              });
            }),
      ),
    );
  }
}

class PlayerCtrlWidgets extends StatelessWidget {
  const PlayerCtrlWidgets({super.key, required this.musicPlayer});
  final BloomeeMusicPlayer musicPlayer;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.92,
      child: Column(
        children: [
          const _SongInfoRow(),
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: _PlayerProgressBar(),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.only(top: 25),
              child: _PlayerControlsRow(musicPlayer: musicPlayer),
            ),
          ),
        ],
      ),
    );
  }
}

class _SongInfoRow extends StatelessWidget {
  const _SongInfoRow();

  @override
  Widget build(BuildContext context) {
    final bloomeePlayerCubit = context.read<BloomeePlayerCubit>();
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 10,
              child: StreamBuilder<MediaItem?>(
                  stream: bloomeePlayerCubit.bloomeePlayer.mediaItem,
                  builder: (context, snapshot) {
                    final mediaItem = snapshot.data;
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.antiAlias,
                          child: SelectableText(
                            mediaItem?.title ?? "Unknown",
                            textAlign: TextAlign.start,
                            style: Default_Theme.secondoryTextStyle.merge(
                                const TextStyle(
                                    fontSize: 22,
                                    fontFamily: "NotoSans",
                                    fontWeight: FontWeight.w700,
                                    overflow: TextOverflow.ellipsis,
                                    color: Default_Theme.primaryColor1)),
                          ),
                        ),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SelectableText(
                            mediaItem?.artist ?? "Unknown",
                            textAlign: TextAlign.start,
                            style: Default_Theme.secondoryTextStyle.merge(
                                TextStyle(
                                    fontSize: 15,
                                    fontFamily: "NotoSans",
                                    fontWeight: FontWeight.w500,
                                    overflow: TextOverflow.ellipsis,
                                    color: Default_Theme.primaryColor1
                                        .withValues(alpha: 0.7))),
                          ),
                        )
                      ],
                    );
                  }),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _ActionChipsRow(),
      ],
    );
  }
}

class _ActionChipsRow extends StatelessWidget {
  const _ActionChipsRow();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            _LikeChip(),
            SizedBox(width: 8),
            _DownloadChip(),
            SizedBox(width: 8),
            _ShareChip(),
            SizedBox(width: 8),
            _AddToPlaylistChip(),
            SizedBox(width: 8),
            _SleepTimerChip(),
          ],
        ),
      ),
    );
  }
}

class _LikeChip extends StatefulWidget {
  const _LikeChip();

  @override
  State<_LikeChip> createState() => _LikeChipState();
}

class _LikeChipState extends State<_LikeChip> {
  final ValueNotifier<bool> isLikedNotifier = ValueNotifier(false);
  String? currentMediaId;

  @override
  void initState() {
    super.initState();
    // Initial check will be handled by the stream builder's snapshot or we can do it here if needed
  }

  Future<void> _checkIfLiked(MediaItem mediaItem) async {
    if (currentMediaId == mediaItem.id) return; // Avoid redundant checks
    currentMediaId = mediaItem.id;

    final liked = await context
        .read<BloomeeDBCubit>()
        .isLiked(mediaItem2MediaItemModel(mediaItem));
    if (mounted && currentMediaId == mediaItem.id) {
      isLikedNotifier.value =
          liked; // No setState needed - ValueNotifier handles updates
    }
  }

  @override
  void dispose() {
    isLikedNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bloomeePlayerCubit = context.read<BloomeePlayerCubit>();

    return StreamBuilder<MediaItem?>(
        stream: bloomeePlayerCubit.bloomeePlayer.mediaItem,
        builder: (context, snapshot) {
          final mediaItem = snapshot.data;

          if (mediaItem != null) {
            // Check DB status when song changes
            _checkIfLiked(mediaItem);

            return ValueListenableBuilder<bool>(
              valueListenable: isLikedNotifier,
              builder: (context, isLiked, child) {
                return ActionChip(
                  avatar: Icon(
                    isLiked ? MingCute.heart_fill : MingCute.heart_line,
                    size: 20,
                    color: Default_Theme.primaryColor1,
                  ),
                  label: const Text('Like'),
                  labelStyle: const TextStyle(
                    color: Default_Theme.primaryColor1,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor:
                      Default_Theme.primaryColor2.withValues(alpha: 0.1),
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  labelPadding: const EdgeInsets.only(left: 4, right: 4),
                  onPressed: () {
                    final newState = !isLiked;
                    isLikedNotifier.value =
                        newState; // Update ValueNotifier instead of setState
                    context.read<BloomeeDBCubit>().setLike(
                        mediaItem2MediaItemModel(mediaItem),
                        isLiked: newState);
                  },
                );
              },
            );
          }
          return const SizedBox.shrink();
        });
  }
}

class _DownloadChip extends StatelessWidget {
  const _DownloadChip();

  @override
  Widget build(BuildContext context) {
    final bloomeePlayerCubit = context.read<BloomeePlayerCubit>();
    return StreamBuilder<MediaItem?>(
        stream: bloomeePlayerCubit.bloomeePlayer.mediaItem,
        builder: (context, mediaSnapshot) {
          final currentMedia = mediaSnapshot.data;
          if (currentMedia == null) return const SizedBox.shrink();

          return BlocBuilder<DownloaderCubit, DownloaderState>(
            builder: (context, state) {
              // Check if currently downloading
              final activeDownload = state.downloads.firstWhere(
                  (element) => element.task.song.id == currentMedia.id,
                  orElse: () => DownloadProgress(
                      task: DownloadTask.empty(),
                      status: const DownloadStatus(
                          state: DownloadState.failed, message: '')));

              bool isDownloading = activeDownload.task.url != "";

              // Check if already downloaded
              final isDownloaded = state.downloaded
                  .any((element) => element.id == currentMedia.id);

              Widget icon;
              String label;

              if (isDownloading &&
                  activeDownload.status.state != DownloadState.failed &&
                  activeDownload.status.state != DownloadState.completed) {
                // Downloading state
                icon = const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Default_Theme.primaryColor1,
                  ),
                );
                label = 'Downloading';
              } else if (isDownloaded) {
                // Downloaded state
                icon = const Icon(
                    MingCute.check_circle_fill, // Checkmark for downloaded
                    size: 20,
                    color: Default_Theme.primaryColor1);
                label = 'Downloaded';
              } else {
                // Not downloaded state
                icon = const Icon(MingCute.download_2_line,
                    size: 20, color: Default_Theme.primaryColor1);
                label = 'Download';
              }

              return ActionChip(
                avatar: icon,
                label: Text(label),
                labelStyle: const TextStyle(
                  color: Default_Theme.primaryColor1,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor:
                    Default_Theme.primaryColor2.withValues(alpha: 0.1),
                side: BorderSide.none,
                shape: const StadiumBorder(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                labelPadding: const EdgeInsets.only(left: 4, right: 4),
                onPressed: () {
                  if (!isDownloaded && !isDownloading) {
                    context
                        .read<DownloaderCubit>()
                        .downloadSong(mediaItem2MediaItemModel(currentMedia));
                  }
                },
              );
            },
          );
        });
  }
}

class _ShareChip extends StatelessWidget {
  const _ShareChip();

  @override
  Widget build(BuildContext context) {
    final bloomeePlayerCubit = context.read<BloomeePlayerCubit>();
    return ActionChip(
      avatar: const Icon(MingCute.share_forward_fill,
          size: 20, color: Default_Theme.primaryColor1),
      label: const Text('Share'),
      labelStyle: const TextStyle(
        color: Default_Theme.primaryColor1,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: Default_Theme.primaryColor2.withValues(alpha: 0.1),
      side: BorderSide.none,
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      labelPadding: const EdgeInsets.only(left: 4, right: 4),
      onPressed: () async {
        final song = bloomeePlayerCubit.bloomeePlayer.currentMedia;
        SnackbarService.showMessage("Sharing ${song.title}...");
        final tmpPath = await ImportExportService.exportMediaItem(
            MediaItem2MediaItemDB(song));
        if (tmpPath != null) {
          await Share.shareXFiles([XFile(tmpPath)]);
        } else {
          SnackbarService.showMessage("Sharing failed.");
        }
      },
    );
  }
}

class _AddToPlaylistChip extends StatelessWidget {
  const _AddToPlaylistChip();

  @override
  Widget build(BuildContext context) {
    final bloomeePlayerCubit = context.read<BloomeePlayerCubit>();
    return ActionChip(
      avatar: const Icon(Icons.playlist_add_rounded,
          size: 20, color: Default_Theme.primaryColor1),
      label: const Text('Save'),
      labelStyle: const TextStyle(
        color: Default_Theme.primaryColor1,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: Default_Theme.primaryColor2.withValues(alpha: 0.1),
      side: BorderSide.none,
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      labelPadding: const EdgeInsets.only(left: 4, right: 4),
      onPressed: () {
        final song = bloomeePlayerCubit.bloomeePlayer.currentMedia;
        context
            .read<AddToPlaylistCubit>()
            .setMediaItemModel(mediaItem2MediaItemModel(song));
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddToPlaylistScreen()));
      },
    );
  }
}

class _SleepTimerChip extends StatelessWidget {
  const _SleepTimerChip();

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(MingCute.moon_line,
          size: 20, color: Default_Theme.primaryColor1),
      label: const Text('Sleep'),
      labelStyle: const TextStyle(
        color: Default_Theme.primaryColor1,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: Default_Theme.primaryColor2.withValues(alpha: 0.1),
      side: BorderSide.none,
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      labelPadding: const EdgeInsets.only(left: 4, right: 4),
      onPressed: () {
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const TimerView()));
      },
    );
  }
}

class _PlayerProgressBar extends StatelessWidget {
  const _PlayerProgressBar();

  @override
  Widget build(BuildContext context) {
    final bloomeePlayerCubit = context.read<BloomeePlayerCubit>();
    return RepaintBoundary(
      child: StreamBuilder<ProgressBarStreams>(
          stream: bloomeePlayerCubit.progressStreams,
          builder: (context, snapshot) {
            final data = snapshot.data;
            final isPlaying = data?.currentPlayerState.playing ?? false;
            return GradientProgressBar.fromAccentColors(
              progress: data?.currentPos ?? Duration.zero,
              total: data?.currentPlaybackState.duration ?? Duration.zero,
              buffered:
                  data?.currentPlaybackState.bufferedPosition ?? Duration.zero,
              onSeek: (value) {
                bloomeePlayerCubit.bloomeePlayer.seek(value);
              },
              isPlaying: isPlaying,
              // Just pass the accent colors - gradients are auto-generated!
              activeAccentColor: Default_Theme.accentColor1, // Sky Blue
              inactiveAccentColor: Default_Theme.accentColor2, // Pink
              // Use "Light & Breezy" for Sky Blue (keeps it bright/cyan)
              activeGradientStyle: GradientStyle.lightAndBreezy,
              // Use "Warm & Rich" for Pink (makes it vibrant/orange-red, not pastel)
              inactiveGradientStyle: GradientStyle.warmAndRich,
              trackHeight: 6.0,
              thumbRadius: 8.0,
              timeLabelPadding: 5,
              timeLabelStyle: Default_Theme.secondoryTextStyle.merge(TextStyle(
                  fontSize: 15,
                  color: Default_Theme.primaryColor1.withValues(alpha: 0.7))),
              timeLabelLocation: TimeLabelLocation.above,
              inactiveTrackColor:
                  Default_Theme.primaryColor2.withValues(alpha: 0.1),
              animationDuration: const Duration(milliseconds: 200),
              animationCurve: Curves.easeOutCubic,
            );
          }),
    );
  }
}

class _PlayerControlsRow extends StatelessWidget {
  final BloomeeMusicPlayer musicPlayer;
  const _PlayerControlsRow({required this.musicPlayer});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const _ShuffleControl(),
        IconButton(
          padding: const EdgeInsets.all(5),
          constraints: const BoxConstraints(),
          style: const ButtonStyle(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          onPressed: () => musicPlayer.skipToPrevious(),
          icon: const Icon(MingCute.skip_previous_fill,
              color: Default_Theme.primaryColor1, size: 35),
        ),
        const _PlayPauseButton(),
        IconButton(
          padding: const EdgeInsets.all(5),
          constraints: const BoxConstraints(),
          style: const ButtonStyle(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          onPressed: () => musicPlayer.skipToNext(),
          icon: const Icon(MingCute.skip_forward_fill,
              color: Default_Theme.primaryColor1, size: 35),
        ),
        const _LoopControl(),
      ],
    );
  }
}

class _LoopControl extends StatelessWidget {
  const _LoopControl();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: "Loop",
      child: StreamBuilder<LoopMode>(
        stream: context.watch<BloomeePlayerCubit>().bloomeePlayer.loopMode,
        builder: (context, snapshot) {
          final loopMode = snapshot.data ?? LoopMode.off;
          return IconButton(
            onPressed: () {
              final player = context.read<BloomeePlayerCubit>().bloomeePlayer;
              switch (loopMode) {
                case LoopMode.off:
                  player.setLoopMode(LoopMode.one);
                  break;
                case LoopMode.one:
                  player.setLoopMode(LoopMode.all);
                  break;
                case LoopMode.all:
                  player.setLoopMode(LoopMode.off);
                  break;
              }
            },
            icon: Icon(
              loopMode == LoopMode.off
                  ? MingCute.repeat_line
                  : loopMode == LoopMode.one
                      ? MingCute.repeat_one_line
                      : MingCute.repeat_fill,
              color: loopMode == LoopMode.off
                  ? Default_Theme.primaryColor1.withValues(alpha: 0.7)
                  : Default_Theme
                      .primaryColor1, // Active is also white in ref image
              size: 26,
            ),
          );
        },
      ),
    );
  }
}

class _ShuffleControl extends StatelessWidget {
  const _ShuffleControl();

  @override
  Widget build(BuildContext context) {
    final bloomeePlayerCubit = context.read<BloomeePlayerCubit>();
    return StreamBuilder<bool>(
        stream: bloomeePlayerCubit.bloomeePlayer.shuffleMode,
        builder: (context, snapshot) {
          final isShuffle = snapshot.data ?? false;
          return Tooltip(
            message: "Shuffle",
            child: IconButton(
              padding: const EdgeInsets.all(5),
              constraints: const BoxConstraints(),
              style: const ButtonStyle(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              icon: Icon(
                MingCute.shuffle_2_fill,
                color: isShuffle
                    ? Default_Theme.primaryColor1
                    : Default_Theme.primaryColor1.withValues(alpha: 0.7),
                size: 26,
              ),
              onPressed: () {
                bloomeePlayerCubit.bloomeePlayer.shuffle(!isShuffle);
              },
            ),
          );
        });
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton();

  @override
  Widget build(BuildContext context) {
    final musicPlayer = context.read<BloomeePlayerCubit>().bloomeePlayer;
    return BlocBuilder<MiniPlayerBloc, MiniPlayerState>(
      builder: (context, state) {
        bool isPlaying = false;
        bool isBuffering = false;

        if (state is MiniPlayerInitial || state is MiniPlayerProcessing) {
          isBuffering = true;
        } else if (state is MiniPlayerWorking) {
          isPlaying = state.isPlaying;
          isBuffering = state.isBuffering;
        }

        return Container(
          width: 70,
          height: 70,
          decoration: const BoxDecoration(
            color: Default_Theme.primaryColor1, // White circle
            shape: BoxShape.circle,
          ),
          child: isBuffering
              ? const CircularProgressIndicator(color: Default_Theme.themeColor)
              : IconButton(
                  iconSize: 35,
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    isPlaying ? MingCute.pause_fill : MingCute.play_fill,
                    color: Default_Theme.themeColor, // Black icon
                    fill: 1.0,
                  ),
                  onPressed: () {
                    if (isPlaying) {
                      musicPlayer.pause();
                    } else {
                      musicPlayer.play();
                    }
                  },
                ),
        );
      },
    );
  }
}

class AmbientImgShadowWidget extends StatefulWidget {
  const AmbientImgShadowWidget({super.key});

  @override
  State<AmbientImgShadowWidget> createState() => _AmbientImgShadowWidgetState();
}

class _AmbientImgShadowWidgetState extends State<AmbientImgShadowWidget> {
  Color? cachedColor;
  String? lastArtUri;

  @override
  Widget build(BuildContext context) {
    final bloomeePlayerCubit = context.read<BloomeePlayerCubit>();
    return StreamBuilder<MediaItem?>(
        stream: bloomeePlayerCubit.bloomeePlayer.mediaItem,
        builder: (context, snapshot) {
          final artUri = snapshot.data?.artUri?.toString();
          if (artUri != lastArtUri) {
            lastArtUri = artUri;
            _fetchPalette(artUri);
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 100.0),
            child: RepaintBoundary(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      (cachedColor ?? const Color.fromARGB(255, 163, 44, 115))
                          .withValues(alpha: 0.30),
                      Colors.transparent,
                    ],
                    center: Alignment.center,
                    radius: 0.65,
                  ),
                ),
              ),
            ),
          );
        });
  }

  void _fetchPalette(String? artUri) async {
    if (artUri == null || artUri.isEmpty) return;
    try {
      final palette = await getPalleteFromImage(artUri);
      if (mounted) {
        setState(() {
          cachedColor = palette.dominantColor?.color ??
              const Color.fromARGB(255, 68, 252, 255);
        });
      }
    } catch (e) {
      // Handle error or ignore
    }
  }
}
