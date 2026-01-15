import 'package:Bloomee/blocs/album_view/album_cubit.dart';
import 'package:Bloomee/blocs/mediaPlayer/bloomee_player_cubit.dart';
import 'package:Bloomee/model/album_onl_model.dart';
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
// import 'package:Bloomee/services/db/bloomee_db_service.dart'; // Ensure DB service is available if needed for Share export (Wait, usually in cubit or UI helper)
// import 'package:Bloomee/services/import_export_service.dart';
import 'package:Bloomee/screens/screen/common_views/add_to_playlist_from_list_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AlbumView extends StatefulWidget {
  final AlbumModel album;
  const AlbumView({super.key, required this.album});

  @override
  State<AlbumView> createState() => _AlbumViewState();
}

class _AlbumViewState extends State<AlbumView> {
  late AlbumCubit albumCubit;
  @override
  void initState() {
    albumCubit = AlbumCubit(
      album: widget.album,
      sourceEngine: widget.album.source == 'saavn'
          ? SourceEngine.eng_JIS
          : SourceEngine.eng_YTM,
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: BlocBuilder<AlbumCubit, AlbumState>(
          bloc: albumCubit,
          builder: (context, state) {
            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight:
                      ResponsiveBreakpoints.of(context).isMobile ? 220 : 250,
                  flexibleSpace: LayoutBuilder(builder: (context, constraints) {
                    String subtitle = widget.album.description ?? "";
                    if (widget.album.genre != null &&
                        widget.album.genre != "Unknown") {
                      subtitle += ' - ${widget.album.genre!}';
                    }
                    if (widget.album.language != null) {
                      subtitle += ' - ${widget.album.language!}';
                    }

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
                                      tag: widget.album.sourceId,
                                      child: LoadImageCached(
                                        imageUrl: formatImgURL(
                                            widget.album.imageURL,
                                            ImageQuality.medium),
                                      )),
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
                                        "Album by",
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
                                        widget.album.artists,
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
                                      Text(
                                        subtitle,
                                        style: Default_Theme.secondoryTextStyle
                                            .merge(
                                          TextStyle(
                                            overflow: TextOverflow.ellipsis,
                                            fontSize: 13,
                                            color: Default_Theme.primaryColor1
                                                .withValues(alpha: 0.5),
                                          ),
                                        ),
                                      ),
                                      FittedBox(
                                        fit: BoxFit
                                            .scaleDown, // Keeping just textual info here or remove?
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(top: 8),
                                          child: ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                  maxWidth: 300),
                                              child: Text(
                                                // Just placeholder or empty?
                                                "", // Removing actions from here.
                                                style: TextStyle(fontSize: 0),
                                              )),
                                        ),
                                      )
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
                          widget.album.name,
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
                  final songs = state.album.songs;
                  bool isAlbumDownloaded = false;
                  if (songs.isNotEmpty) {
                    isAlbumDownloaded = songs.every((song) =>
                        downloaderState.downloaded.any((d) => d.id == song.id));
                  }

                  return SliverPersistentHeader(
                    pinned: true,
                    delegate: StickyActionBarDelegate(
                      isLiked: state.isSavedToCollections,
                      isDownloaded: isAlbumDownloaded,
                      onPlay: () {
                        if (context
                                .read<BloomeePlayerCubit>()
                                .bloomeePlayer
                                .queueTitle
                                .value !=
                            widget.album.name) {
                          context
                              .read<BloomeePlayerCubit>()
                              .bloomeePlayer
                              .loadPlaylist(state.album.playlist,
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
                        albumCubit.addToSavedCollections();
                      },
                      onDownload: () {
                        if (isAlbumDownloaded) {
                          SnackbarService.showMessage(
                              "Album already downloaded");
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
                        if (state.album.sourceURL.isNotEmpty) {
                          Share.share(
                              "Check out this album: ${state.album.name} on Bloomee! ${state.album.sourceURL}");
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
                        launchUrl(Uri.parse(state.album.sourceURL),
                            mode: LaunchMode.externalApplication);
                      },
                    ),
                  );
                }),
                (state is AlbumLoaded ||
                        (state.album.songs.isNotEmpty &&
                            state is! AlbumLoading))
                    ? SliverList.builder(
                        itemBuilder: (context, index) {
                          return SongCardWidget(
                            song: state.album.songs[index],
                            onOptionsTap: () {
                              showMoreBottomSheet(
                                context,
                                state.album.songs[index],
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
                                      widget.album.name ||
                                  context
                                          .read<BloomeePlayerCubit>()
                                          .bloomeePlayer
                                          .currentMedia !=
                                      state.album.songs[index]) {
                                context
                                    .read<BloomeePlayerCubit>()
                                    .bloomeePlayer
                                    .loadPlaylist(state.album.playlist,
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
                        itemCount: state.album.songs.length)
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
