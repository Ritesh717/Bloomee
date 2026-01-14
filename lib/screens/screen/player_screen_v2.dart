import 'dart:ui';
import 'package:Bloomee/blocs/player_overlay/player_overlay_cubit.dart';
import 'package:Bloomee/model/songModel.dart';
import 'package:Bloomee/screens/screen/home_views/timer_view.dart';
import 'package:Bloomee/screens/widgets/gradient_progress_bar.dart';
import 'package:Bloomee/screens/widgets/more_bottom_sheet.dart';
import 'package:Bloomee/screens/widgets/volume_slider.dart';
import 'package:Bloomee/services/bloomeePlayer.dart';
import 'package:Bloomee/services/db/bloomee_db_service.dart';
import 'package:Bloomee/services/db/GlobalDB.dart';

import 'package:Bloomee/utils/imgurl_formator.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:just_audio/just_audio.dart';
import 'package:Bloomee/screens/widgets/like_widget.dart';
import 'package:Bloomee/screens/widgets/playPause_widget.dart';
import 'package:Bloomee/services/db/cubit/bloomee_db_cubit.dart';
import 'package:Bloomee/theme_data/default.dart';
import 'package:Bloomee/utils/load_Image.dart';
import 'package:Bloomee/utils/pallete_generator.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/add_to_playlist/cubit/add_to_playlist_cubit.dart';
import '../../blocs/downloader/cubit/downloader_cubit.dart';
import '../../routes_and_consts/global_str_consts.dart';
import '../../blocs/mediaPlayer/bloomee_player_cubit.dart';
import '../../blocs/mini_player/mini_player_bloc.dart';
import 'player_views/fullscreen_lyrics_view.dart';
import 'player_views/lyrics_widget.dart';
import 'player_views/player_gestures.dart';

// New Player V2
class AudioPlayerViewV2 extends StatefulWidget {
  const AudioPlayerViewV2({super.key});

  @override
  State<AudioPlayerViewV2> createState() => _AudioPlayerViewV2State();
}

class _AudioPlayerViewV2State extends State<AudioPlayerViewV2> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DraggableScrollableController _sheetController = DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Register collapse callback using the DraggableScrollableController
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PlayerOverlayCubit>().registerUpNextPanelCollapse(() {
          // If sheet is expanded significantly, collapse it
          if (_sheetController.isAttached && _sheetController.size > 0.15) {
            _sheetController.animateTo(
              0.08,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
            );
            return true; // We handled the collapse
          }
          return false; // Not expanded, proceed to hide player
        });
      }
    });
  }

  @override
  void dispose() {
    context.read<PlayerOverlayCubit>().unregisterUpNextPanelCollapse();
    _tabController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('🎵 LOADING V2 PLAYER (YouTube Music Style)');
    final bloomeePlayerCubit = context.read<BloomeePlayerCubit>();
    final musicPlayer = bloomeePlayerCubit.bloomeePlayer;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F), // Darker, YouTube-like background
      resizeToAvoidBottomInset: false,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(context, musicPlayer),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Simplified responsive check for now
          // Assuming Mobile for the key feature test
          return _buildMobileLayout(context, musicPlayer, constraints);
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, BloomeeMusicPlayer musicPlayer) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32, color: Colors.white),
        onPressed: () {
          // Collapse sheet if expanded, else hide player
          if (_sheetController.isAttached && _sheetController.size > 0.15) {
            _sheetController.animateTo(0.08, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
          } else {
            context.read<PlayerOverlayCubit>().hidePlayer();
          }
        },
      ),
      title: StreamBuilder<String>(
        stream: context.read<BloomeePlayerCubit>().bloomeePlayer.queueTitle,
        builder: (context, snapshot) {
          return Column(
            children: [
              Text(
                "Now Playing",
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7)),
              ),
               Text(
                snapshot.data ?? "From Queue",
                style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          );
        },
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
          onPressed: () => showMoreBottomSheet(context, musicPlayer.currentMedia),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context, BloomeeMusicPlayer musicPlayer, BoxConstraints constraints) {
    // Adjusted sizes to prevent overflow and improve UX
    const double minSheetSize = 0.12; // ~96px on typical screen, covers 72px header safely
    const double maxSheetSize = 0.85; // Cover most of screen for list view

    return Stack(
      children: [
        // 1. Main Player Content (Behind Sheet)
        Positioned.fill(
          bottom: constraints.maxHeight * minSheetSize, // Leave space for peek
          child: GestureDetector(
            behavior: HitTestBehavior.translucent, // Ensure touches are caught
            onTap: () {
              // Close sheet if open and clicked outside
              if (_sheetController.isAttached && _sheetController.size > 0.15) {
                _sheetController.animateTo(minSheetSize, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
              }
            },
            onVerticalDragEnd: (details) {
               // Initial swipe down check - if velocity is high enough downwards
               if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
                 context.read<PlayerOverlayCubit>().hidePlayer();
               }
            },
            child: Padding(
            // Reduced top padding to shift components up
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10),
            child: Column(
              children: [
                // Album Art
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48.0),
                    child: _buildAlbumArt(context),
                  ),
                ),
                
                // Info & Controls
                Expanded(
                  flex: 4,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSongInfo(context),
                      const SizedBox(height: 10),
                      _ActionChips(), 
                      const SizedBox(height: 10),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.0),
                        child: _PlayerProgressBar(),
                      ),
                      _PlayerControlsRow(musicPlayer: musicPlayer),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ],
            ),
            ),
          ),
        ), // End of Positioned.fill (line 152)

        // Better approach: Use AnimatedBuilder on the controller
        AnimatedBuilder(
          animation: _sheetController,
          builder: (context, child) {
             final size = _sheetController.isAttached ? _sheetController.size : minSheetSize;
             if (size > minSheetSize + 0.01) {
                return Positioned.fill(
                  bottom: constraints.maxHeight * size, // Cover area ABOVE the sheet
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                       _sheetController.animateTo(minSheetSize, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                    },
                    child: Container(color: Colors.transparent), // Input blocker
                  ),
                );
             }
             return const SizedBox.shrink();
          },
        ),

        // 2. Sliding Sheet
        DraggableScrollableSheet(
          controller: _sheetController,
          initialChildSize: minSheetSize,
          minChildSize: minSheetSize,
          maxChildSize: maxSheetSize,
          snap: true,
          snapSizes: const [minSheetSize, maxSheetSize],
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF212121),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, -5))],
              ),
              child: Column(
                children: [
                  // Pull Handle / Tab Bar Header
                  GestureDetector(
                    onVerticalDragUpdate: (details) {
                      // Allow drag to drive sheet?
                    },
                     onTap: () {
                         // Removed auto-expand behavior matching user request
                     },
                    child: SingleChildScrollView(
                      controller: scrollController,
                      physics: const ClampingScrollPhysics(),
                      child: Container(
                        padding: const EdgeInsets.only(top: 8),
                        decoration: const BoxDecoration(
                           color: Colors.transparent,
                           borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        child: Column(
                          children: [
                              // Handle
                              Container(
                                width: 40, height: 4,
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)),
                              ),
                              // Tabs
                              TabBar(
                                controller: _tabController,
                                indicatorColor: Colors.white,
                                labelColor: Colors.white,
                                unselectedLabelColor: Colors.grey,
                                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                labelPadding: const EdgeInsets.symmetric(vertical: 8), // Add vertical padding for centering visual
                                dividerColor: Colors.transparent,
                                onTap: (_) {
                                   if (_sheetController.isAttached) {
                                      _sheetController.animateTo(maxSheetSize, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                                   }
                                },
                                tabs: const [
                                  Tab(child: Center(child: Text("Up Next"))),
                                  Tab(child: Center(child: Text("Lyrics"))),
                                  Tab(child: Center(child: Text("Related"))),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Tab Content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _UpNextTabContent(scrollController: scrollController), 
                        LyricsWidget(),
                        _RelatedTabContent(scrollController: scrollController),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAlbumArt(BuildContext context) {
      // Simple album art for now
      final bloomeePlayerCubit = context.read<BloomeePlayerCubit>();
      return StreamBuilder<MediaItem?>(
        stream: bloomeePlayerCubit.bloomeePlayer.mediaItem,
        builder: (context, snapshot) {
            final artUri = snapshot.data?.artUri?.toString() ?? "";
            return ClipRRect(
               borderRadius: BorderRadius.circular(8),
               child: LoadImageCached(
                 imageUrl: formatImgURL(artUri, ImageQuality.high),
                 fallbackUrl: formatImgURL(artUri, ImageQuality.medium),
                 fit: BoxFit.cover,
               ),
            );
        },
      );
  }

  Widget _buildSongInfo(BuildContext context) {
       final bloomeePlayerCubit = context.read<BloomeePlayerCubit>();
       return StreamBuilder<MediaItem?>(
         stream: bloomeePlayerCubit.bloomeePlayer.mediaItem,
         builder: (context, snapshot) {
            final item = snapshot.data;
            return Column(
               children: [
                  Text(
                    item?.title ?? "Unknown Title",
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item?.artist ?? "Unknown Artist",
                    style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7)),
                    textAlign: TextAlign.center,
                  ),
               ],
            );
         },
       );
  }
}

// Sub-widgets needed (re-implementing minimal versions)

class _ActionChips extends StatelessWidget {
  const _ActionChips();

  Widget _chip(IconData icon, String label, VoidCallback onTap) {
     return InkWell(
       onTap: onTap,
       borderRadius: BorderRadius.circular(20),
       child: Container(
         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
         decoration: BoxDecoration(
           color: Colors.white.withOpacity(0.1),
           borderRadius: BorderRadius.circular(20),
         ),
         child: Row(
           children: [
             Icon(icon, size: 18, color: Colors.white),
             const SizedBox(width: 8),
             Text(label, style: const TextStyle(color: Colors.white)),
           ],
         ),
       ),
     );
  }

  @override
  Widget build(BuildContext context) {
    // Basic functionality for chips
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
           const SizedBox(width: 16),
           _chip(Icons.playlist_add, "Save", () {
              final mediaItem = context.read<BloomeePlayerCubit>().bloomeePlayer.mediaItem.value;
              if (mediaItem != null) {
                  final song = mediaItem2MediaItemModel(mediaItem);
                  context.read<AddToPlaylistCubit>().setMediaItemModel(song);
                  context.pushNamed(GlobalStrConsts.addToPlaylistScreen);
              }
           }),
           const SizedBox(width: 8),
           // Dynamic Download Chip
           // Dynamic Download Chip
           BlocBuilder<DownloaderCubit, DownloaderState>(
             builder: (context, state) {
               final mediaItem = context.read<BloomeePlayerCubit>().bloomeePlayer.mediaItem.value;
               if (mediaItem == null) return const SizedBox.shrink();

               // Check active download progress from state.downloads list
               bool isDownloading = false;
               try {
                  isDownloading = state.downloads.any((d) => d.task.originalUrl == mediaItem.extras?['perma_url']);
               } catch (e) {
                  isDownloading = false;
               }

               // Check if already downloaded from state.downloaded list (Synchronous & Reactive)
               final isDownloaded = state.downloaded.any((item) => item.id == mediaItem.id);
               
               // Fallback FutureBuilder only if not found in state (to be safe), but mostly rely on state
               return Builder(
                 builder: (context) {
                     IconData icon;
                     String label;
                     if (isDownloading) {
                       icon = Icons.downloading;
                       label = "Downloading...";
                     } else if (isDownloaded) {
                       icon = Icons.check_circle;
                       label = "Downloaded";
                     } else {
                        icon = Icons.download;
                        label = "Download";
                     }

                     return _chip(
                       icon, 
                       label, 
                       () {
                         if (isDownloading) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Download in progress...")));
                         } else if (isDownloaded) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Song is already downloaded.")));
                         } else {
                             final song = mediaItem2MediaItemModel(mediaItem);
                             context.read<DownloaderCubit>().downloadSong(song);
                             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Downloading ${song.title}...")));
                         }
                     });
                 }
               );
             }
           ),
           const SizedBox(width: 8),
           _chip(Icons.share, "Share", () async {
               final mediaItem = context.read<BloomeePlayerCubit>().bloomeePlayer.mediaItem.value;
               if (mediaItem != null) {
                  final url = mediaItem.extras?['perma_url'];
                  if (url != null) {
                     await Share.share("Listen to ${mediaItem.title} on Bloomee! $url");
                  }
               }
           }),
           const SizedBox(width: 16),
        ],
      ),
    );
  }
}

class _UpNextTabContent extends StatelessWidget {
  final ScrollController? scrollController;
  const _UpNextTabContent({super.key, this.scrollController});

  @override
  Widget build(BuildContext context) {
     final playerCubit = context.read<BloomeePlayerCubit>();
     return StreamBuilder<List<MediaItem>>(
       stream: playerCubit.bloomeePlayer.queue,
       builder: (context, snapshot) {
          final queue = snapshot.data?.toList() ?? [];
          if (queue.isEmpty) {
             return const Center(child: Text("Queue is empty", style: TextStyle(color: Colors.white)));
          }
          return ReorderableListView.builder(
            scrollController: scrollController,
            buildDefaultDragHandles: true,
            padding: EdgeInsets.zero,
            itemCount: queue.length,
            onReorder: (oldIndex, newIndex) {
               if (oldIndex < newIndex) newIndex -= 1;
               final item = queue.removeAt(oldIndex);
               queue.insert(newIndex, item);
               playerCubit.bloomeePlayer.moveQueueItem(oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
               final item = queue[index];
               final key = "${item.id}_${index}"; 
               return Dismissible(
                 key: ValueKey("${key}_dismiss"),
                 direction: DismissDirection.endToStart,
                 background: Container(
                   alignment: Alignment.centerRight,
                   padding: const EdgeInsets.only(right: 20),
                   color: Colors.red,
                   child: const Icon(Icons.delete, color: Colors.white),
                 ),
                 onDismissed: (direction) {
                    playerCubit.bloomeePlayer.removeQueueItemAt(index);
                 },
                 child: ListTile(
                   key: ValueKey(key), 
                   leading: ClipRRect(
                     borderRadius: BorderRadius.circular(4),
                     child: SizedBox(
                       width: 40, height: 40,
                       child: LoadImageCached(
                          imageUrl: formatImgURL(item.artUri?.toString() ?? "", ImageQuality.low),
                          fit: BoxFit.cover,
                       ),
                     ),
                   ),
                   title: Text(item.title, style: const TextStyle(color: Colors.white, fontSize: 14), maxLines: 1),
                   subtitle: Text(item.artist ?? "", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12), maxLines: 1),
                   trailing: const Icon(Icons.drag_handle, color: Colors.grey, size: 20),
                   onTap: () {
                     playerCubit.bloomeePlayer.skipToQueueItem(index);
                   },
                 ),
               );
            },
          );
       },
     );
  }
}

// Reuse existing widgets where possible
class _PlayerProgressBar extends StatelessWidget {
  const _PlayerProgressBar();
  @override
  Widget build(BuildContext context) {
    final bloomeePlayerCubit = context.read<BloomeePlayerCubit>();
    return StreamBuilder<ProgressBarStreams>(
      stream: bloomeePlayerCubit.progressStreams,
      builder: (context, snapshot) {
         final data = snapshot.data;
           return GradientProgressBar.fromAccentColors(
              progress: data?.currentPos ?? Duration.zero,
              total: data?.currentPlaybackState.duration ?? Duration.zero,
              buffered: data?.currentPlaybackState.bufferedPosition ?? Duration.zero,
              onSeek: (value) => bloomeePlayerCubit.bloomeePlayer.seek(value),
              isPlaying: data?.currentPlayerState.playing ?? false,
              activeAccentColor: Colors.white,
              inactiveAccentColor: Colors.grey,
              activeGradientStyle: GradientStyle.lightAndBreezy,
              inactiveGradientStyle: GradientStyle.warmAndRich,
           );
      },
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
        children: [
           // Shuffle Button
           StreamBuilder<bool>(
             stream: musicPlayer.audioPlayer.shuffleModeEnabledStream,
             builder: (context, snapshot) {
                final isShuffle = snapshot.data ?? false;
                return IconButton(
                  icon: Icon(Icons.shuffle, size: 26, color: isShuffle ? Default_Theme.accentColor1 : Colors.white),
                  onPressed: () { 
                     musicPlayer.shuffle(!isShuffle);
                  },
                );
             }
           ),
           IconButton(
             icon: const Icon(Icons.skip_previous, size: 40, color: Colors.white),
             onPressed: () => musicPlayer.skipToPrevious(),
           ),
           // Play/Pause
           BlocBuilder<MiniPlayerBloc, MiniPlayerState>(
             builder: (context, state) {
               final isPlaying = state is MiniPlayerWorking && state.isPlaying;
               return Container(
                  height: 64, width: 64,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                  child: IconButton(
                     icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.black, size: 36),
                      onPressed: () { 
                        if (isPlaying) musicPlayer.pause(); else musicPlayer.play();
                      },
                  ),
               );
             },
           ),
           IconButton(
             icon: const Icon(Icons.skip_next, size: 40, color: Colors.white),
             onPressed: () => musicPlayer.skipToNext(),
           ),
           // Repeat Button
           StreamBuilder<LoopMode>(
             stream: musicPlayer.audioPlayer.loopModeStream,
             builder: (context, snapshot) {
                final loopMode = snapshot.data ?? LoopMode.off;
                IconData icon;
                Color color;
                if (loopMode == LoopMode.one) {
                   icon = Icons.repeat_one;
                   color = Default_Theme.accentColor1;
                } else if (loopMode == LoopMode.all) {
                   icon = Icons.repeat;
                   color = Default_Theme.accentColor1;
                } else {
                   icon = Icons.repeat;
                   color = Colors.white;
                }

                return IconButton(
                  icon: Icon(icon, size: 26, color: color),
                  onPressed: () { 
                     if (loopMode == LoopMode.off) {
                        musicPlayer.setLoopMode(LoopMode.all);
                     } else if (loopMode == LoopMode.all) {
                        musicPlayer.setLoopMode(LoopMode.one);
                     } else {
                        musicPlayer.setLoopMode(LoopMode.off);
                     }
                  },
                );
             }
           ),
        ],
      );
   }
 }

 class _RelatedTabContent extends StatelessWidget {
  final ScrollController? scrollController;
  const _RelatedTabContent({super.key, this.scrollController});

  @override
  Widget build(BuildContext context) {
     final playerCubit = context.read<BloomeePlayerCubit>();
     return StreamBuilder<List<MediaItem>>(
       stream: playerCubit.bloomeePlayer.relatedSongs,
       builder: (context, snapshot) {
          final related = snapshot.data ?? [];
          if (related.isEmpty) {
             return const Center(child: Text("No related songs found", style: TextStyle(color: Colors.white)));
          }
          return ListView.builder(
            controller: scrollController,
            padding: EdgeInsets.zero,
            itemCount: related.length,
            itemBuilder: (context, index) {
               final item = related[index];
               return ListTile(
                 leading: ClipRRect(
                   borderRadius: BorderRadius.circular(4),
                   child: SizedBox(
                     width: 40, height: 40,
                     child: LoadImageCached(
                        imageUrl: formatImgURL(item.artUri?.toString() ?? "", ImageQuality.low),
                        fit: BoxFit.cover,
                     ),
                   ),
                 ),
                 title: Text(item.title, style: const TextStyle(color: Colors.white, fontSize: 14), maxLines: 1),
                 subtitle: Text(item.artist ?? "", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12), maxLines: 1),
                 onTap: () {
                    playerCubit.bloomeePlayer.addPlayNextItem(item);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Will play ${item.title} next")));
                 },
                 trailing: IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                    onPressed: () {
                       playerCubit.bloomeePlayer.addQueueItem(item);
                       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Added ${item.title} to queue")));
                    },
                 ),
               );
            },
          );
       },
     );
  }
}
