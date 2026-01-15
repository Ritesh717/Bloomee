import 'package:Bloomee/blocs/library/cubit/library_items_cubit.dart';
import 'package:Bloomee/routes_and_consts/global_str_consts.dart';
import 'package:Bloomee/screens/widgets/animated_list_item.dart';
import 'package:Bloomee/screens/widgets/sign_board_widget.dart';
import 'package:Bloomee/utils/imgurl_formator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:Bloomee/model/songModel.dart';
import 'package:Bloomee/screens/widgets/createPlaylist_bottomsheet.dart';
import 'package:Bloomee/services/db/GlobalDB.dart';
import 'package:Bloomee/theme_data/default.dart';
// import 'package:Bloomee/routes_and_consts/global_conts.dart';
import 'package:Bloomee/utils/load_Image.dart';
import 'package:icons_plus/icons_plus.dart';

class AddToPlaylistFromListScreen extends StatefulWidget {
  final List<MediaItemModel> mediaItems;
  const AddToPlaylistFromListScreen({super.key, required this.mediaItems});

  @override
  State<AddToPlaylistFromListScreen> createState() =>
      _AddToPlaylistFromListScreenState();
}

class _AddToPlaylistFromListScreenState
    extends State<AddToPlaylistFromListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ValueNotifier<String> _searchQuery = ValueNotifier('');

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchQuery.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchQuery.value = _searchController.text.trim();
  }

  List<PlaylistItemProperties> _filterPlaylists(
    List<PlaylistItemProperties> playlists,
    String query,
  ) {
    // Filter out system playlists first
    final userPlaylists = playlists.where((p) {
      return p.playlistName != "recently_played" &&
          p.playlistName != GlobalStrConsts.downloadPlaylist;
    }).toList();

    if (query.isEmpty) return userPlaylists;

    return userPlaylists.where((element) {
      return element.playlistName.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  void _addSongsToPlaylist(
    BuildContext context,
    PlaylistItemProperties playlist,
  ) {
    final playlistDB = MediaPlaylistDB(playlistName: playlist.playlistName);

    // Add songs to playlist
    context.read<LibraryItemsCubit>().addMultipleToPlaylist(
          widget.mediaItems,
          playlistDB,
          showSnackbar: true,
        );

    // Close the screen after adding
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Default_Theme.themeColor,
      appBar: AppBar(
        backgroundColor: Default_Theme.themeColor,
        surfaceTintColor: Default_Theme.themeColor,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Default_Theme.primaryColor1,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Add to Playlist',
          style: Default_Theme.secondoryTextStyleMedium.merge(
            const TextStyle(
              color: Default_Theme.primaryColor1,
              fontSize: 18,
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              MingCute.add_circle_line,
              color: Default_Theme.accentColor2,
              size: 26,
            ),
            tooltip: 'Create New Playlist',
            onPressed: () => createPlaylistBottomSheet(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Batch Info Card
            _BatchInfoCard(mediaItems: widget.mediaItems),

            // Search Bar
            _SearchBar(
              controller: _searchController,
              focusNode: _searchFocusNode,
              searchQuery: _searchQuery,
            ),

            // Playlists List
            Expanded(
              child: BlocBuilder<LibraryItemsCubit, LibraryItemsState>(
                builder: (context, libraryState) {
                  if (libraryState is LibraryItemsLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Default_Theme.accentColor2,
                      ),
                    );
                  }

                  return ValueListenableBuilder<String>(
                    valueListenable: _searchQuery,
                    builder: (context, query, _) {
                      final filteredPlaylists = _filterPlaylists(
                        libraryState.playlists,
                        query,
                      );

                      if (filteredPlaylists.isEmpty) {
                        return Center(
                          child: SignBoardWidget(
                            message: query.isEmpty
                                ? "No playlists yet.\nCreate one to get started!"
                                : "No playlists match your search",
                            icon: query.isEmpty
                                ? MingCute.playlist_line
                                : MingCute.search_line,
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: 100,
                        ),
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredPlaylists.length,
                        itemBuilder: (context, index) {
                          final playlist = filteredPlaylists[index];
                          return AnimatedListItem(
                            key: ValueKey(playlist.playlistName),
                            index: index,
                            child: _PlaylistTile(
                              playlist: playlist,
                              onTap: () => _addSongsToPlaylist(
                                context,
                                playlist,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_to_playlist_fab_list',
        backgroundColor: Default_Theme.accentColor2,
        elevation: 2,
        onPressed: () => createPlaylistBottomSheet(context),
        child: const Icon(
          Icons.add_rounded,
          size: 28,
          color: Default_Theme.primaryColor1,
        ),
      ),
    );
  }
}

/// Compact card showing summary of items being added
class _BatchInfoCard extends StatelessWidget {
  final List<MediaItemModel> mediaItems;

  const _BatchInfoCard({required this.mediaItems});

  @override
  Widget build(BuildContext context) {
    // Determine the art to show (first item's art)
    final firstArt = mediaItems.isNotEmpty ? mediaItems.first.artUri : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Default_Theme.primaryColor1.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Album Art of first item
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 48,
              height: 48,
              child: LoadImageCached(
                imageUrl: formatImgURL(
                  firstArt?.toString() ?? '',
                  ImageQuality.low,
                ),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Adding ${mediaItems.length} songs",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Default_Theme.secondoryTextStyleMedium.merge(
                    const TextStyle(
                      color: Default_Theme.primaryColor1,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Select a playlist to save these songs",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Default_Theme.secondoryTextStyle.merge(
                    TextStyle(
                      color: Default_Theme.primaryColor1.withValues(alpha: 0.5),
                      fontSize: 12,
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

/// Search bar widget with clear button
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueNotifier<String> searchQuery;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: Default_Theme.primaryColor1.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.search,
          style: Default_Theme.secondoryTextStyle.merge(
            const TextStyle(
              color: Default_Theme.primaryColor1,
              fontSize: 15,
            ),
          ),
          decoration: InputDecoration(
            hintText: 'Search playlists...',
            hintStyle: Default_Theme.secondoryTextStyle.merge(
              TextStyle(
                color: Default_Theme.primaryColor1.withValues(alpha: 0.35),
                fontSize: 15,
              ),
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: Default_Theme.primaryColor1.withValues(alpha: 0.4),
              size: 22,
            ),
            suffixIcon: ValueListenableBuilder<String>(
              valueListenable: searchQuery,
              builder: (context, query, _) {
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: query.isEmpty
                      ? const SizedBox.shrink(key: ValueKey('empty'))
                      : IconButton(
                          key: const ValueKey('clear'),
                          icon: Icon(
                            Icons.close_rounded,
                            color: Default_Theme.primaryColor1
                                .withValues(alpha: 0.4),
                            size: 20,
                          ),
                          onPressed: () => controller.clear(),
                        ),
                );
              },
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ),
    );
  }
}

/// Individual playlist tile - clean, minimal design
class _PlaylistTile extends StatelessWidget {
  final PlaylistItemProperties playlist;
  final VoidCallback onTap;

  const _PlaylistTile({
    required this.playlist,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        splashColor: Default_Theme.primaryColor1.withValues(alpha: 0.08),
        highlightColor: Default_Theme.primaryColor1.withValues(alpha: 0.04),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              // Playlist Cover
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: LoadImageCached(
                    imageUrl: formatImgURL(
                      playlist.coverImgUrl ?? '',
                      ImageQuality.low,
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Playlist Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      playlist.playlistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Default_Theme.secondoryTextStyleMedium.merge(
                        const TextStyle(
                          color: Default_Theme.primaryColor1,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      playlist.subTitle ?? 'Playlist',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Default_Theme.secondoryTextStyle.merge(
                        TextStyle(
                          color: Default_Theme.primaryColor1
                              .withValues(alpha: 0.5),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Add icon
              SizedBox(
                width: 32,
                height: 32,
                child: Icon(
                  Icons.add_rounded,
                  color: Default_Theme.primaryColor1.withValues(alpha: 0.4),
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
