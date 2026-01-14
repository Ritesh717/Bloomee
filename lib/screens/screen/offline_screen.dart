import 'package:Bloomee/blocs/mediaPlayer/bloomee_player_cubit.dart';
import 'package:Bloomee/blocs/downloader/cubit/downloader_cubit.dart';
import 'package:Bloomee/model/MediaPlaylistModel.dart';
import 'package:Bloomee/model/album_onl_model.dart';
import 'package:Bloomee/model/artist_onl_model.dart';
import 'package:Bloomee/model/songModel.dart';
import 'package:Bloomee/screens/widgets/album_card.dart';
import 'package:Bloomee/screens/widgets/artist_card.dart';
import 'package:Bloomee/screens/widgets/downloading_item.dart';
import 'package:Bloomee/screens/widgets/more_bottom_sheet.dart';
import 'package:Bloomee/screens/widgets/sign_board_widget.dart';
import 'package:Bloomee/screens/widgets/song_tile.dart';
import 'package:flutter/material.dart';
import 'package:Bloomee/theme_data/default.dart';
import 'package:Bloomee/screens/screen/home_views/setting_views/download_setting.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:icons_plus/icons_plus.dart';

enum DownloadFilter { songs, albums, artists }

extension DownloadFilterExt on DownloadFilter {
  String get label {
    switch (this) {
      case DownloadFilter.songs:
        return 'Songs';
      case DownloadFilter.albums:
        return 'Albums';
      case DownloadFilter.artists:
        return 'Artists';
    }
  }
}

class OfflineScreen extends StatefulWidget {
  const OfflineScreen({super.key});

  @override
  State<OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends State<OfflineScreen> {
  bool _isSearch = false;
  final TextEditingController _searchController = TextEditingController();
  List<MediaItemModel> _filteredSongs = [];
  DownloadFilter _selectedFilter = DownloadFilter.songs;

  // Grouped data computed on fly

  @override
  void initState() {
    super.initState();
    final downloaderState = context.read<DownloaderCubit>().state;
    _updateData(downloaderState.downloaded);
    _searchController.addListener(_filterSongs);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterSongs);
    _searchController.dispose();
    super.dispose();
  }

  void _updateData(List<MediaItemModel> allSongs) {
    _filteredSongs = allSongs;
    // We also need to process albums and artists here or lazily?
    // Let's process them when switching filters or when data updates.
    // However, _filteredSongs is what is displayed.
    // If search is active, _filteredSongs is already filtered.
    // We should probably filter FIRST, then Group.

    // Initial load:
    if (_searchController.text.isNotEmpty) {
      _filterSongs();
    } else {
      // Just update derived lists if needed, but we do that in build or specific methods
    }
  }

  void _filterSongs() {
    final downloaderState = context.read<DownloaderCubit>().state;
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredSongs = downloaderState.downloaded
          .where((song) =>
              "${song.title.toLowerCase()} ${song.artist?.toLowerCase()}"
                  .contains(query))
          .toList();
    });
  }

  // --- Grouping Logic ---

  List<AlbumModel> _groupSongsByAlbum(List<MediaItemModel> songs) {
    final Map<String, List<MediaItemModel>> grouped = {};
    for (var song in songs) {
      final key = song.album ?? "Unknown Album";
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(song);
    }

    return grouped.entries.map((entry) {
      final firstSong = entry.value.first;
      return AlbumModel(
        name: entry.key,
        imageURL: firstSong.artUri.toString(),
        source: 'local', // Mark as local
        sourceId: 'local_${entry.key.hashCode}',
        artists: firstSong.artist ?? "Unknown Artist",
        sourceURL: '', // No source URL for local
        songs: entry.value,
        description: "${entry.value.length} songs",
      );
    }).toList();
  }

  List<ArtistModel> _groupSongsByArtist(List<MediaItemModel> songs) {
    final Map<String, List<MediaItemModel>> grouped = {};
    for (var song in songs) {
      // Split artists if multiple? For now assume primary artist or full string
      final key = song.artist ?? "Unknown Artist";
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(song);
    }

    return grouped.entries.map((entry) {
      final firstSong = entry.value.first;
      return ArtistModel(
        name: entry.key,
        imageUrl: firstSong.artUri.toString(), // Use album art as fallback
        source: 'local',
        sourceId: 'local_${entry.key.hashCode}',
        sourceURL: '',
        songs: entry.value,
        description: "${entry.value.length} songs",
      );
    }).toList();
  }

  void _toggleSearch() {
    setState(() {
      _isSearch = !_isSearch;
      if (!_isSearch) {
        _searchController.clear();
        final downloaderState = context.read<DownloaderCubit>().state;
        _filteredSongs = downloaderState.downloaded;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Default_Theme.themeColor,
        body: BlocBuilder<DownloaderCubit, DownloaderState>(
          builder: (context, state) {
            // Ensure data sync if search is empty
            if (_searchController.text.isEmpty &&
                _filteredSongs.length != state.downloaded.length) {
              _filteredSongs = state.downloaded;
            }

            return CustomScrollView(
              slivers: [
                customDiscoverSliverBar(context),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _FilterHeaderDelegate(
                    selectedFilter: _selectedFilter,
                    onFilterSelected: (filter) {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                  ),
                ),
                if (state.downloads.isEmpty && state.downloaded.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: SignBoardWidget(
                        message: "No Downloads",
                        icon: FontAwesome.download_solid,
                      ),
                    ),
                  )
                else
                  Builder(builder: (context) {
                    // Active Downloads (Only show in Songs view or always?)
                    // Usually Active downloads are songs. Let's show them at top only if 'Songs' or maybe always?
                    // User request: "display downloaded items". Active downloads are "downloading" not "downloaded".
                    // But typically we want to see progress. Let's keep them at top for 'Songs' tab, or Separate?
                    // Let's keep them in 'Songs' tab for now.

                    if (_selectedFilter == DownloadFilter.songs) {
                      return SliverList(
                        delegate: SliverChildListDelegate(
                          [
                            // Active Downloads
                            ...state.downloads.map((download) =>
                                DownloadingCardWidget(
                                    downloadProgress: download)),

                            // Downloaded Songs
                            if (_filteredSongs.isEmpty &&
                                _searchController.text.isNotEmpty)
                              const Padding(
                                padding: EdgeInsets.all(20.0),
                                child: Center(
                                    child: Text("No songs found",
                                        style:
                                            TextStyle(color: Colors.white70))),
                              )
                            else
                              ..._filteredSongs.map((song) => SongCardWidget(
                                    song: song,
                                    showOptions: true,
                                    delDownBtn: true,
                                    onTap: () {
                                      context
                                          .read<BloomeePlayerCubit>()
                                          .bloomeePlayer
                                          .loadPlaylist(
                                              MediaPlaylist(
                                                  mediaItems:
                                                      _filteredSongs, // Play filtered list
                                                  playlistName: "Offline"),
                                              idx: _filteredSongs.indexOf(song),
                                              doPlay: true);
                                    },
                                    onOptionsTap: () {
                                      showMoreBottomSheet(context, song,
                                          showDelete: false);
                                    },
                                  )),
                          ],
                        ),
                      );
                    } else if (_selectedFilter == DownloadFilter.albums) {
                      final albums = _groupSongsByAlbum(_filteredSongs);
                      if (albums.isEmpty) {
                        return const SliverFillRemaining(
                          child: Center(
                              child: Text("No albums found",
                                  style: TextStyle(color: Colors.white70))),
                        );
                      }
                      return SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return AlbumCard(album: albums[index]);
                          },
                          childCount: albums.length,
                        ),
                      );
                    } else {
                      // Artists
                      final artists = _groupSongsByArtist(_filteredSongs);
                      if (artists.isEmpty) {
                        return const SliverFillRemaining(
                          child: Center(
                              child: Text("No artists found",
                                  style: TextStyle(color: Colors.white70))),
                        );
                      }
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            children: artists
                                .map((artist) => ArtistCard(artist: artist))
                                .toList(),
                          ),
                        ),
                      );
                    }
                  }),
              ],
            );
          },
        ),
      ),
    );
  }

  SliverAppBar customDiscoverSliverBar(BuildContext context) {
    return SliverAppBar(
      floating: true,
      pinned: true,
      surfaceTintColor: Default_Theme.themeColor,
      backgroundColor: Default_Theme.themeColor,
      title: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        transitionBuilder: (Widget child, Animation<double> animation) {
          final slideAnimation = Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          ));
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: slideAnimation,
              child: child,
            ),
          );
        },
        child: _isSearch ? _buildSearchField() : _buildTitle(),
      ),
      actions: [
        !_isSearch
            ? Tooltip(
                message: "Refresh Downloads",
                child: IconButton(
                  icon: const Icon(MingCute.refresh_2_line),
                  onPressed: () {
                    context.read<DownloaderCubit>().refreshDownloadedSongs();
                  },
                ),
              )
            : const SizedBox.shrink(),
        !_isSearch
            ? Tooltip(
                message: "Download Settings",
                child: IconButton(
                  icon: const Icon(MingCute.settings_3_line),
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const DownloadSettings()));
                  },
                ),
              )
            : const SizedBox.shrink(),
        Tooltip(
          message: _isSearch ? "Close Search" : "Search",
          child: IconButton(
            icon: Icon(
              _isSearch ? Icons.close : Icons.search,
              color: Default_Theme.primaryColor1,
            ),
            onPressed: _toggleSearch,
          ),
        ),
      ],
    );
  }

  Widget _buildTitle() {
    return Container(
      key: const ValueKey('title'),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Offline",
              style: Default_Theme.primaryTextStyle.merge(const TextStyle(
                  fontSize: 34, color: Default_Theme.primaryColor1))),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      key: const ValueKey('search'),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        cursorColor: Default_Theme.primaryColor1,
        decoration: InputDecoration(
          hintText: "Search your songs...",
          border: InputBorder.none,
          hintStyle: TextStyle(
              color: Default_Theme.primaryColor1.withValues(alpha: 0.7)),
        ),
        style: Default_Theme.secondoryTextStyle.merge(
          const TextStyle(
            color: Default_Theme.primaryColor1,
            fontSize: 15.0,
          ),
        ),
      ),
    );
  }
}

class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final DownloadFilter selectedFilter;
  final ValueChanged<DownloadFilter> onFilterSelected;

  _FilterHeaderDelegate(
      {required this.selectedFilter, required this.onFilterSelected});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Default_Theme.themeColor,
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: DownloadFilter.values.map((filter) {
              final isSelected = selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => onFilterSelected(filter),
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Default_Theme.primaryColor1
                          : Default_Theme.primaryColor1.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      filter.label,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.black
                            : Default_Theme.primaryColor1,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 60.0;

  @override
  double get minExtent => 60.0;

  @override
  bool shouldRebuild(covariant _FilterHeaderDelegate oldDelegate) {
    return oldDelegate.selectedFilter != selectedFilter;
  }
}
