// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:Bloomee/blocs/mediaPlayer/bloomee_player_cubit.dart';
import 'package:Bloomee/model/source_engines.dart';
import 'package:Bloomee/screens/widgets/album_card.dart';
import 'package:Bloomee/screens/widgets/artist_card.dart';
import 'package:Bloomee/screens/widgets/more_bottom_sheet.dart';
import 'package:Bloomee/screens/widgets/playlist_card.dart';
import 'package:Bloomee/screens/widgets/sign_board_widget.dart';
import 'package:Bloomee/screens/widgets/song_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:Bloomee/blocs/internet_connectivity/cubit/connectivity_cubit.dart';
import 'package:Bloomee/blocs/search/fetch_search_results.dart';
import 'package:Bloomee/screens/screen/search_views/search_page.dart';
import 'package:Bloomee/theme_data/default.dart';

class SearchScreen extends StatefulWidget {
  final String searchQuery;
  const SearchScreen({
    Key? key,
    this.searchQuery = "",
  }) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late List<SourceEngine> availSourceEngines;
  late SourceEngine _sourceEngine;
  final TextEditingController _textEditingController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<ResultTypes> resultType =
      ValueNotifier(ResultTypes.songs);

  @override
  void dispose() {
    _scrollController.removeListener(loadMoreResults);
    _scrollController.dispose();
    _textEditingController.dispose();
    resultType.dispose();
    super.dispose();
  }

  void loadMoreResults() {
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        _sourceEngine == SourceEngine.eng_JIS &&
        context.read<FetchSearchResultsCubit>().state.hasReachedMax == false) {
      context
          .read<FetchSearchResultsCubit>()
          .searchJISTracks(_textEditingController.text, loadMore: true);
    }
  }

  @override
  void initState() {
    super.initState();
    availSourceEngines = SourceEngine.values;
    _sourceEngine = availSourceEngines[0];

    setState(() {
      availableSourceEngines().then((value) {
        availSourceEngines = value;
        _sourceEngine = availSourceEngines[0];
      });
    });
    _scrollController.addListener(loadMoreResults);
    if (widget.searchQuery != "") {
      _textEditingController.text = widget.searchQuery;
      context.read<FetchSearchResultsCubit>().search(
            widget.searchQuery.toString(),
            sourceEngine: _sourceEngine,
            resultType: resultType.value,
          );
    }
  }

  Widget sourceEngineRadioButton(SourceEngine sourceEngine) {
    bool isSelected = _sourceEngine == sourceEngine;
    return InkWell(
      onTap: () {
        setState(() {
          _sourceEngine = sourceEngine;
          context.read<FetchSearchResultsCubit>().checkAndRefreshSearch(
                query: _textEditingController.text.toString(),
                sE: sourceEngine,
                rT: resultType.value,
              );
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: isSelected
              ? const Border(bottom: BorderSide(color: Colors.white, width: 2))
              : null,
        ),
        child: Text(
          sourceEngine.value.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected
                ? Default_Theme.primaryColor1
                : Default_Theme.primaryColor1.withValues(alpha: 0.6),
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 0.5,
          ).merge(Default_Theme.secondoryTextStyleMedium),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        onVerticalDragEnd: (DragEndDetails details) =>
            FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          appBar: AppBar(
            shadowColor: Colors.black,
            surfaceTintColor: Default_Theme.themeColor,
            title: SizedBox(
              height: 50.0,
              child: Padding(
                padding: const EdgeInsets.only(
                  top: 10,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    showSearch(
                            context: context,
                            delegate: SearchPageDelegate(
                                _sourceEngine, resultType.value),
                            query: _textEditingController.text)
                        .then((value) {
                      if (value != null) {
                        _textEditingController.text = value.toString();
                      }
                    });
                  },
                  child: TextField(
                    controller: _textEditingController,
                    enabled: false,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Default_Theme.primaryColor1
                            .withValues(alpha: 0.55)),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                        filled: true,
                        suffixIcon: Icon(
                          MingCute.search_2_fill,
                          color: Default_Theme.primaryColor1
                              .withValues(alpha: 0.4),
                        ),
                        fillColor:
                            Default_Theme.primaryColor2.withValues(alpha: 0.07),
                        contentPadding:
                            const EdgeInsets.only(top: 20, left: 15, right: 5),
                        hintText: "Find your next song obsession...",
                        hintStyle: TextStyle(
                          color: Default_Theme.primaryColor1
                              .withValues(alpha: 0.3),
                          fontFamily: "Unageo",
                          fontWeight: FontWeight.normal,
                        ),
                        disabledBorder: OutlineInputBorder(
                            borderSide:
                                const BorderSide(style: BorderStyle.none),
                            borderRadius: BorderRadius.circular(50)),
                        focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Default_Theme.primaryColor1
                                    .withValues(alpha: 0.7)),
                            borderRadius: BorderRadius.circular(50))),
                  ),
                ),
              ),
            ),
            backgroundColor: Default_Theme.themeColor,
          ),
          backgroundColor: Default_Theme.themeColor,
          body: BlocBuilder<ConnectivityCubit, ConnectivityState>(
            builder: (context, state) {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                child: state == ConnectivityState.disconnected
                    ? const SignBoardWidget(
                        icon: MingCute.wifi_off_line,
                        message: "No internet connection!",
                      )
                    : Column(
                        children: [
                          // Fixed Header (Source Engines + Filter Chips)
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 18, right: 18, top: 5, bottom: 5),
                            child: FutureBuilder(
                                future: availableSourceEngines(),
                                builder: (context, snapshot) {
                                  return snapshot.hasData ||
                                          snapshot.data != null
                                      ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // 1. Source Engines Row
                                            Row(
                                              children: [
                                                for (var sourceEngine
                                                    in availSourceEngines)
                                                  Expanded(
                                                    child:
                                                        sourceEngineRadioButton(
                                                            sourceEngine),
                                                  )
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            // 2. Result Types Filter Chips
                                            ValueListenableBuilder(
                                                valueListenable: resultType,
                                                builder: (context, currentType,
                                                    child) {
                                                  return Row(
                                                    children: ResultTypes.values
                                                        .map((type) => Expanded(
                                                              child: Padding(
                                                                padding: const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        4),
                                                                child: InkWell(
                                                                  onTap: () {
                                                                    resultType
                                                                            .value =
                                                                        type;
                                                                    context
                                                                        .read<
                                                                            FetchSearchResultsCubit>()
                                                                        .checkAndRefreshSearch(
                                                                          query: _textEditingController
                                                                              .text
                                                                              .toString(),
                                                                          sE: _sourceEngine,
                                                                          rT: type,
                                                                        );
                                                                  },
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              20),
                                                                  child:
                                                                      AnimatedContainer(
                                                                    duration: const Duration(
                                                                        milliseconds:
                                                                            200),
                                                                    padding: const EdgeInsets
                                                                        .symmetric(
                                                                        vertical:
                                                                            8),
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      color: currentType ==
                                                                              type
                                                                          ? Default_Theme
                                                                              .primaryColor1 // Selected: White
                                                                          : Colors
                                                                              .white
                                                                              .withValues(alpha: 0.1), // Unselected: Grey
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              20),
                                                                    ),
                                                                    child: Text(
                                                                      type.val,
                                                                      textAlign:
                                                                          TextAlign
                                                                              .center,
                                                                      style:
                                                                          TextStyle(
                                                                        color: currentType ==
                                                                                type
                                                                            ? Colors.black // Selected: Black text
                                                                            : Default_Theme.primaryColor1, // Unselected: White text
                                                                        fontWeight:
                                                                            FontWeight.w600,
                                                                        fontSize:
                                                                            13,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ))
                                                        .toList(),
                                                  );
                                                }),
                                          ],
                                        )
                                      : const SizedBox();
                                }),
                          ),
                          // Expanded Search Results List
                          Expanded(
                            child: BlocConsumer<FetchSearchResultsCubit,
                                FetchSearchResultsState>(
                              listener: (context, state) {
                                resultType.value = state.resultType;
                                if (state is! FetchSearchResultsLoaded &&
                                    state is! FetchSearchResultsInitial) {
                                  _sourceEngine =
                                      state.sourceEngine ?? _sourceEngine;
                                }
                              },
                              builder: (context, state) {
                                if (state is FetchSearchResultsLoading) {
                                  return const Center(
                                    child: CircularProgressIndicator(
                                      color: Default_Theme.accentColor2,
                                    ),
                                  );
                                } else if (state.loadingState ==
                                    LoadingState.loaded) {
                                  if (state.resultType == ResultTypes.songs &&
                                      state.mediaItems.isNotEmpty) {
                                    return ListView.builder(
                                        controller: _scrollController,
                                        physics: const BouncingScrollPhysics(),
                                        itemCount: state.hasReachedMax
                                            ? state.mediaItems.length
                                            : state.mediaItems.length + 1,
                                        itemBuilder: (context, index) {
                                          if (index ==
                                              state.mediaItems.length) {
                                            return const Center(
                                              child: SizedBox(
                                                height: 30,
                                                width: 30,
                                                child:
                                                    CircularProgressIndicator(
                                                  color: Default_Theme
                                                      .accentColor2,
                                                ),
                                              ),
                                            );
                                          }
                                          return Padding(
                                            padding:
                                                const EdgeInsets.only(left: 4),
                                            child: SongCardWidget(
                                              song: state.mediaItems[index],
                                              onTap: () {
                                                context
                                                    .read<BloomeePlayerCubit>()
                                                    .bloomeePlayer
                                                    .updateQueue(
                                                  [state.mediaItems[index]],
                                                  doPlay: true,
                                                );
                                              },
                                              onOptionsTap: () =>
                                                  showMoreBottomSheet(context,
                                                      state.mediaItems[index]),
                                            ),
                                          );
                                        });
                                  } else if (state.resultType ==
                                          ResultTypes.albums &&
                                      state.albumItems.isNotEmpty) {
                                    return ListView.builder(
                                      physics: const BouncingScrollPhysics(),
                                      itemCount: state.albumItems.length,
                                      itemBuilder: (context, index) {
                                        return AlbumCard(
                                          album: state.albumItems[index],
                                        );
                                      },
                                    );
                                  } else if (state.resultType ==
                                          ResultTypes.playlists &&
                                      state.playlistItems.isNotEmpty) {
                                    return ListView.builder(
                                      physics: const BouncingScrollPhysics(),
                                      itemCount: state.playlistItems.length,
                                      itemBuilder: (context, index) {
                                        return PlaylistCard(
                                          playlist: state.playlistItems[index],
                                          sourceEngine: _sourceEngine,
                                        );
                                      },
                                    );
                                  } else if (state.resultType ==
                                          ResultTypes.artists &&
                                      state.artistItems.isNotEmpty) {
                                    return SingleChildScrollView(
                                      physics: const BouncingScrollPhysics(),
                                      child: Wrap(
                                        alignment: WrapAlignment.center,
                                        children: [
                                          for (var artist in state.artistItems)
                                            ArtistCard(artist: artist)
                                        ],
                                      ),
                                    );
                                  } else {
                                    return const SignBoardWidget(
                                      icon: MingCute.search_2_line,
                                      message: "No results found!",
                                    );
                                  }
                                } else {
                                  return const SizedBox();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
              );
            },
          ),
        ),
      ),
    );
  }
}
