import 'package:Bloomee/blocs/mediaPlayer/bloomee_player_cubit.dart';
import 'package:Bloomee/blocs/playlist_view/online_playlist_cubit.dart';
import 'package:Bloomee/model/playlist_onl_model.dart';
import 'package:Bloomee/model/source_engines.dart';
import 'package:Bloomee/screens/widgets/more_bottom_sheet.dart';
import 'package:Bloomee/screens/widgets/snackbar.dart';
import 'package:Bloomee/screens/widgets/song_tile.dart';
import 'package:Bloomee/theme_data/default.dart';
import 'package:Bloomee/utils/imgurl_formator.dart';
import 'package:Bloomee/utils/load_Image.dart';
import 'package:Bloomee/blocs/downloader/cubit/downloader_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:icons_plus/icons_plus.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:Bloomee/screens/widgets/sticky_action_bar_delegate.dart';
// import 'package:Bloomee/services/db/bloomee_db_service.dart';
// import 'package:Bloomee/services/import_export_service.dart';
import 'package:Bloomee/screens/screen/common_views/add_to_playlist_from_list_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class OnlPlaylistView extends StatefulWidget {
  final PlaylistOnlModel playlist;
  final SourceEngine sourceEngine;
  const OnlPlaylistView(
      {super.key, required this.playlist, required this.sourceEngine});

  @override
  State<OnlPlaylistView> createState() => _OnlPlaylistViewState();
}

class _OnlPlaylistViewState extends State<OnlPlaylistView> {
  late OnlPlaylistCubit onlPlaylistCubit;
  @override
  void initState() {
    onlPlaylistCubit = OnlPlaylistCubit(
      playlist: widget.playlist,
      sourceEngine: widget.sourceEngine,
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: BlocBuilder<OnlPlaylistCubit, OnlPlaylistState>(
          bloc: onlPlaylistCubit,
          builder: (context, state) {
            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight:
                      ResponsiveBreakpoints.of(context).isMobile ? 220 : 250,
                  flexibleSpace: LayoutBuilder(builder: (context, constraints) {
                    return FlexibleSpaceBar(
                      background: Padding(
                        padding: const EdgeInsets.only(
                          left: 8,
                          right: 8,
                          top: 34,
                          bottom: 8,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: constraints.maxHeight,
                            minWidth: 350,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.4,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    left: 8,
                                    right: 8,
                                    top: 8,
                                    bottom: 8,
                                  ),
                                  child: Hero(
                                    tag: widget.playlist.sourceId,
                                    child: LoadImageCached(
                                      imageUrl: formatImgURL(
                                          widget.playlist.imageURL,
                                          ImageQuality.high),
                                      fit: BoxFit.fitWidth,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "Playlist by",
                                        style: Default_Theme
                                            .secondoryTextStyleMedium
                                            .merge(
                                          TextStyle(
                                            overflow: TextOverflow.ellipsis,
                                            fontSize: 14,
                                            color: Default_Theme.primaryColor1
                                                .withValues(alpha: 0.4),
                                          ),
                                        ),
                                      ),
                                      Text(
                                        widget.playlist.artists,
                                        maxLines: 3,
                                        style: Default_Theme
                                            .secondoryTextStyleMedium
                                            .merge(
                                          TextStyle(
                                            overflow: TextOverflow.ellipsis,
                                            fontSize: 14,
                                            color: Default_Theme.primaryColor1
                                                .withValues(alpha: 0.9),
                                          ),
                                        ),
                                      ),
                                      state.playlist.description != null
                                          ? Text(
                                              state.playlist.description ?? "",
                                              style: Default_Theme
                                                  .secondoryTextStyle
                                                  .merge(
                                                TextStyle(
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  fontSize: 13,
                                                  color: Default_Theme
                                                      .primaryColor1
                                                      .withValues(alpha: 0.5),
                                                ),
                                              ),
                                            )
                                          : const SizedBox.shrink(),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(top: 8),
                                          child: ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                  maxWidth: 300),
                                              child: Text(
                                                "",
                                                style: TextStyle(fontSize: 0),
                                              )),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 8,
                      top: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          widget.playlist.name,
                          maxLines: 3,
                          textAlign: TextAlign.center,
                          style: Default_Theme.secondoryTextStyleMedium.merge(
                            TextStyle(
                              fontSize: 20,
                              color: Default_Theme.primaryColor1
                                  .withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                BlocBuilder<DownloaderCubit, DownloaderState>(
                    builder: (context, downloaderState) {
                  final songs = state.playlist.songs;
                  bool isPlaylistDownloaded = false;
                  if (songs.isNotEmpty) {
                    isPlaylistDownloaded = songs.every((song) =>
                        downloaderState.downloaded.any((d) => d.id == song.id));
                  }

                  return SliverPersistentHeader(
                    pinned: true,
                    delegate: StickyActionBarDelegate(
                      isLiked: state.isSavedCollection,
                      isDownloaded: isPlaylistDownloaded,
                      onPlay: () {
                        if (context
                                .read<BloomeePlayerCubit>()
                                .bloomeePlayer
                                .queueTitle
                                .value !=
                            widget.playlist.name) {
                          context
                              .read<BloomeePlayerCubit>()
                              .bloomeePlayer
                              .loadPlaylist(state.playlist.playlist,
                                  doPlay: true, idx: 0);
                        } else if (!context
                            .read<BloomeePlayerCubit>()
                            .bloomeePlayer
                            .playing) {
                          context
                              .read<BloomeePlayerCubit>()
                              .bloomeePlayer
                              .play();
                        }
                      },
                      onLike: () {
                        onlPlaylistCubit.addToSavedCollections();
                      },
                      onDownload: () {
                        if (isPlaylistDownloaded) {
                          SnackbarService.showMessage(
                              "Playlist already downloaded");
                          return;
                        }
                        if (songs.isNotEmpty) {
                          SnackbarService.showMessage(
                              "Starting download for ${songs.length} songs...");
                          for (var song in songs) {
                            context
                                .read<DownloaderCubit>()
                                .downloadSong(song, showSnackbar: false);
                          }
                        }
                      },
                      onShare: () async {
                        SnackbarService.showMessage("Preparing share...");
                        if (state.playlist.sourceURL.isNotEmpty) {
                          Share.share(
                              "Check out this playlist: ${state.playlist.name} on Bloomee! ${state.playlist.sourceURL}");
                        } else {
                          SnackbarService.showMessage("No URL to share");
                        }
                      },
                      onAddToPlaylist: () {
                        if (songs.isNotEmpty) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => AddToPlaylistFromListScreen(
                                  mediaItems: songs),
                            ),
                          );
                        } else {
                          SnackbarService.showMessage("No songs to add");
                        }
                      },
                      onExternalLink: () {
                        launchUrl(Uri.parse(state.playlist.sourceURL),
                            mode: LaunchMode.externalApplication);
                      },
                    ),
                  );
                }),
                (state is OnlPlaylistLoaded || state.playlist.songs.isNotEmpty)
                    ? SliverList.builder(
                        itemBuilder: (context, index) {
                          return SongCardWidget(
                            song: state.playlist.songs[index],
                            onOptionsTap: () {
                              showMoreBottomSheet(
                                context,
                                state.playlist.songs[index],
                                showDelete: false,
                                showSinglePlay: true,
                              );
                            },
                            onTap: () {
                              if (context
                                          .read<BloomeePlayerCubit>()
                                          .bloomeePlayer
                                          .queueTitle
                                          .value !=
                                      widget.playlist.name ||
                                  context
                                          .read<BloomeePlayerCubit>()
                                          .bloomeePlayer
                                          .currentMedia !=
                                      state.playlist.songs[index]) {
                                context
                                    .read<BloomeePlayerCubit>()
                                    .bloomeePlayer
                                    .loadPlaylist(state.playlist.playlist,
                                        doPlay: true, idx: index);
                              } else if (!context
                                  .read<BloomeePlayerCubit>()
                                  .bloomeePlayer
                                  .playing) {
                                context
                                    .read<BloomeePlayerCubit>()
                                    .bloomeePlayer
                                    .play();
                              }
                            },
                          );
                        },
                        itemCount: state.playlist.songs.length)
                    : const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: CircularProgressIndicator(),
                        )),
              ],
            );
          },
        ),
      ),
    );
  }
}
