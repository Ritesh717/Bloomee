// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:isolate';
import 'package:Bloomee/routes_and_consts/global_str_consts.dart';
import 'package:Bloomee/repository/Youtube/yt_music_home.dart';
import 'package:Bloomee/repository/Youtube/yt_music_api.dart';
import 'package:Bloomee/services/db/GlobalDB.dart';
import 'package:Bloomee/utils/country_info.dart';
import 'package:Bloomee/model/MediaPlaylistModel.dart';
import 'package:Bloomee/model/chart_model.dart';
import 'package:Bloomee/plugins/ext_charts/chart_defines.dart';
import 'package:Bloomee/repository/Youtube/yt_charts_home.dart';
import 'package:Bloomee/screens/screen/chart/show_charts.dart';
import 'package:Bloomee/services/db/bloomee_db_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
part 'explore_states.dart';

class TrendingCubit extends Cubit<TrendingCubitState> {
  bool isLatest = false;
  TrendingCubit() : super(TrendingCubitInitial()) {
    getTrendingVideosFromDB();
    getTrendingVideos();
  }

  void getTrendingVideos() async {
    List<ChartModel> ytCharts = await fetchTrendingVideos();
    ChartModel chart = ytCharts[0]
      ..chartItems = getFirstElements(ytCharts[0].chartItems!, 16);
    emit(state.copyWith(ytCharts: [chart]));
    isLatest = true;
  }

  List<ChartItemModel> getFirstElements(List<ChartItemModel> list, int count) {
    return list.length > count ? list.sublist(0, count) : list;
  }

  void getTrendingVideosFromDB() async {
    ChartModel? ytChart = await BloomeeDBService.getChart("Trending Videos");
    if ((!isLatest) &&
        ytChart != null &&
        (ytChart.chartItems?.isNotEmpty ?? false)) {
      ChartModel chart = ytChart
        ..chartItems = getFirstElements(ytChart.chartItems!, 16);
      emit(state.copyWith(ytCharts: [chart]));
    }
  }
}

class RecentlyCubit extends Cubit<RecentlyCubitState> {
  StreamSubscription<void>? watcher;
  RecentlyCubit() : super(RecentlyCubitInitial()) {
    getRecentlyPlayed();
    watchRecentlyPlayed();
  }

  Future<void> watchRecentlyPlayed() async {
    watcher = (await BloomeeDBService.watchRecentlyPlayed()).listen((event) {
      getRecentlyPlayed();
      log("Recently Played Updated");
    });
  }

  @override
  Future<void> close() {
    watcher?.cancel();
    return super.close();
  }

  void getRecentlyPlayed() async {
    final mediaPlaylist = await BloomeeDBService.getRecentlyPlayed(limit: 15);
    emit(state.copyWith(mediaPlaylist: mediaPlaylist));
  }
}

class ChartCubit extends Cubit<ChartState> {
  ChartInfo chartInfo;
  StreamSubscription? strm;
  FetchChartCubit fetchChartCubit;
  ChartCubit(
    this.chartInfo,
    this.fetchChartCubit,
  ) : super(ChartInitial()) {
    getChartFromDB();
    initListener();
  }
  void initListener() {
    strm = fetchChartCubit.stream.listen((state) {
      if (state.isFetched) {
        log("Chart Fetched from Isolate - ${chartInfo.title}",
            name: "Isolate Fetched");
        getChartFromDB();
      }
    });
  }

  Future<void> getChartFromDB() async {
    final chart = await BloomeeDBService.getChart(chartInfo.title);
    if (chart != null) {
      emit(state.copyWith(
          chart: chart, coverImg: chart.chartItems?.first.imageUrl));
    }
  }

  @override
  Future<void> close() {
    fetchChartCubit.close();
    strm?.cancel();
    return super.close();
  }
}

Map<String, List<dynamic>> parseYTMusicData(String source) {
  final dynamicMap = jsonDecode(source);

  Map<String, List<dynamic>> listDynamicMap;
  if (dynamicMap is Map) {
    listDynamicMap = dynamicMap.map((key, value) {
      List<dynamic> list = [];
      if (value is List) {
        list = value;
      }
      return MapEntry(key, list);
    });
  } else {
    listDynamicMap = {};
  }
  return listDynamicMap;
}

class FetchChartCubit extends Cubit<FetchChartState> {
  FetchChartCubit() : super(FetchChartInitial()) {
    fetchCharts();
  }

  Future<void> fetchCharts() async {
    try {
      String _path = (await getApplicationSupportDirectory()).path;
      BackgroundIsolateBinaryMessenger.ensureInitialized(
        ServicesBinding.rootIsolateToken!,
      );
      await BloomeeDBService.db;
      String langsJson = await BloomeeDBService.getSettingStr(
              GlobalStrConsts.contentLanguages) ??
          '["Hindi"]';

      final chartList = await Isolate.run<List<ChartModel>>(() async {
        log(_path, name: "Isolate Path");
        List<ChartModel> _chartList = List.empty(growable: true);
        ChartModel chart;
        final db = await Isar.open(
          [
            ChartsCacheDBSchema,
          ],
          directory: _path,
        );

        List<String> langs = [];
        try {
          langs = List<String>.from(jsonDecode(langsJson));
        } catch (e) {
          langs = ["Hindi"];
        }
        String primaryLang = langs.isNotEmpty ? langs[0] : "Hindi";

        List<ChartInfo> sortedCharts = List.from(chartInfoList);

        if ([
          "Hindi",
          "Punjabi",
          "Tamil",
          "Telugu",
          "Marathi",
          "Gujarati",
          "Bengali",
          "Kannada",
          "Malayalam",
          "Bhojpuri",
          "Haryanvi",
          "Rajasthani",
          "Odia",
          "Assamese"
        ].contains(primaryLang)) {
          final indiaIndex = sortedCharts
              .indexWhere((element) => element.title.contains("India"));
          if (indiaIndex != -1) {
            final indiaChart = sortedCharts.removeAt(indiaIndex);
            sortedCharts.insert(0, indiaChart);
          }
        } else if (primaryLang == "Japanese") {
          final japanIndex = sortedCharts
              .indexWhere((element) => element.title.contains("Japan"));
          if (japanIndex != -1) {
            final japanChart = sortedCharts.removeAt(japanIndex);
            sortedCharts.insert(0, japanChart);
          }
        } else if (primaryLang == "Korean") {
          // Keep/Move Melon or Billboard Korea
        }

        for (var i in sortedCharts) {
          try {
            final chartCacheDB = db.chartsCacheDBs
                .where()
                .filter()
                .chartNameEqualTo(i.title)
                .findFirstSync();
            bool _shouldFetch = (chartCacheDB?.lastUpdated
                        .difference(DateTime.now())
                        .inHours
                        .abs() ??
                    80) >
                16;
            log("Last Updated - ${(chartCacheDB?.lastUpdated.difference(DateTime.now()).inHours)?.abs()} Hours before ",
                name: "Isolate");

            if (_shouldFetch) {
              chart = await i.chartFunction(i.url);
              if ((chart.chartItems?.isNotEmpty) ?? false) {
                db.writeTxnSync(() =>
                    db.chartsCacheDBs.putSync(chartModelToChartCacheDB(chart)));
              }
              log("Chart Fetched - ${chart.chartName}", name: "Isolate");
              _chartList.add(chart);
            }
          } catch (e) {
            log('Error fetching chart ${i.title}: $e', name: "Isolate");
          }
        }
        db.close();
        return _chartList;
      });

      if (chartList.isNotEmpty) {
        emit(state.copyWith(isFetched: true));
      }
    } catch (e) {
      log('Error in fetchCharts: $e', name: "FetchChartCubit");
    }
  }
}

class YTMusicCubit extends Cubit<YTMusicCubitState> {
  YTMusicCubit() : super(YTMusicCubitInitial()) {
    fetchYTMusicDB();
    fetchYTMusic();
  }

  void fetchYTMusicDB() async {
    final data = await BloomeeDBService.getAPICache("YTMusic");
    if (data != null) {
      final ytmData = await compute(parseYTMusicData, data);
      if (ytmData.isNotEmpty) {
        // Check if data has language tags - if not, clear cache and fetch fresh
        final bodyData = ytmData['body'] as List?;
        if (bodyData != null && bodyData.isNotEmpty) {
          final firstSection = bodyData[0] as Map<String, dynamic>?;
          final items = firstSection?['items'] as List?;
          if (items != null && items.isNotEmpty) {
            final firstItem = items[0] as Map<String, dynamic>?;
            // If first item doesn't have _language tag, clear cache
            if (firstItem != null && !firstItem.containsKey('_language')) {
              print("LOG: Cache data missing language tags, clearing cache");
              await BloomeeDBService.putAPICache("YTMusic", "");
              return; // Don't emit old data, let fetchYTMusic get fresh data
            }
          }
        }
        emit(state.copyWith(ytmData: ytmData, isLoading: false));
      }
    }
  }

  Future<void> fetchYTMusic() async {
    String countryCode = await getCountry();
    String langsJson = await BloomeeDBService.getSettingStr(
            GlobalStrConsts.contentLanguages) ??
        '["Hindi"]';
    List<String> langs = [];
    try {
      langs = List<String>.from(jsonDecode(langsJson));
    } catch (e) {
      langs = ["Hindi"];
    }

    String langName =
        await BloomeeDBService.getSettingStr(GlobalStrConsts.displayLanguage) ??
            "English";

    String langCode = 'en';
    switch (langName) {
      case 'Hindi':
        langCode = 'hi';
        break;
      case 'English':
        langCode = 'en';
        break;
      case 'Punjabi':
        langCode = 'pa';
        break;
      case 'Tamil':
        langCode = 'ta';
        break;
      case 'Telugu':
        langCode = 'te';
        break;
      case 'Marathi':
        langCode = 'mr';
        break;
      case 'Gujarati':
        langCode = 'gu';
        break;
      case 'Bengali':
        langCode = 'bn';
        break;
      case 'Kannada':
        langCode = 'kn';
        break;
      case 'Malayalam':
        langCode = 'ml';
        break;
      case 'Bhojpuri':
        langCode = 'bho';
        break;
      case 'Urdu':
        langCode = 'ur';
        break;
      case 'Haryanvi':
        langCode = 'hi';
        break; // Approximate
      case 'Rajasthani':
        langCode = 'hi';
        break; // Approximate
      case 'Odia':
        langCode = 'or';
        break;
      case 'Assamese':
        langCode = 'as';
        break;
      default:
        langCode = 'en';
    }

    // Override country code based on content language for better suggestions
    // while keeping HL as per display language.
    String contentLang = "Hindi";
    try {
      if (langs.isNotEmpty) contentLang = langs[0];
    } catch (e) {
      // ignore
    }

    String? targetCountry;
    switch (contentLang) {
      case 'Hindi':
      case 'Punjabi':
      case 'Tamil':
      case 'Telugu':
      case 'Marathi':
      case 'Gujarati':
      case 'Bengali':
      case 'Kannada':
      case 'Malayalam':
      case 'Bhojpuri':
      case 'Haryanvi':
      case 'Rajasthani':
      case 'Odia':
      case 'Assamese':
        targetCountry = 'IN';
        break;
      case 'Urdu':
        targetCountry = 'PK'; // Or IN
        break;
    }

    print(
        "LOG: FetchYTMusic: langName=$langName, langCode=$langCode, contentLang=$contentLang, targetCountry=$targetCountry");

    final ytCharts = await Isolate.run(() => getMusicHome(
        countryCode: targetCountry ?? countryCode, lang: langCode));

    if (ytCharts.isNotEmpty) {
      List<Map<String, dynamic>> finalYtCharts =
          List<Map<String, dynamic>>.from(ytCharts['body'] as List);

      // Inject Language Specific Content by searching
      if (targetCountry == 'IN' &&
          langs.isNotEmpty &&
          !langs.every((lang) => lang == 'English' || lang == 'Hindi')) {
        print(
            "LOG: FetchYTMusic: Attempting injection for FIRST language only: ${langs[0]}");

        try {
          List<Map<String, dynamic>> allSongResults = [];
          List<Map<String, dynamic>> allAlbumResults = [];
          List<Map<String, dynamic>> allLatestResults = [];

          // Only fetch FIRST language (lazy loading)
          final lang = langs[0];
          print("LOG: FetchYTMusic: Fetching content for $lang");

          final songResults =
              await YtMusicService().search("$lang Top Songs", filter: "songs");
          final albumResults = await YtMusicService()
              .search("$lang Top Albums", filter: "albums");
          final latestResults = await YtMusicService()
              .search("Latest $lang Songs", filter: "songs");

          // Collect all items from each language and TAG them
          if (songResults.isNotEmpty &&
              songResults[0] != null &&
              songResults[0]['items'] != null) {
            final items = songResults[0]['items'] as List;
            for (var item in items) {
              final typedItem = Map<String, dynamic>.from(item as Map);
              typedItem['_language'] = lang; // Add language tag
              allSongResults.add(typedItem);
            }
          }
          if (albumResults.isNotEmpty &&
              albumResults[0] != null &&
              albumResults[0]['items'] != null) {
            final items = albumResults[0]['items'] as List;
            for (var item in items) {
              final typedItem = Map<String, dynamic>.from(item as Map);
              typedItem['_language'] = lang; // Add language tag
              allAlbumResults.add(typedItem);
            }
          }
          if (latestResults.isNotEmpty &&
              latestResults[0] != null &&
              latestResults[0]['items'] != null) {
            final items = latestResults[0]['items'] as List;
            for (var item in items) {
              final typedItem = Map<String, dynamic>.from(item as Map);
              typedItem['_language'] = lang; // Add language tag
              allLatestResults.add(typedItem);
            }
          }

          print(
              "LOG: FetchYTMusic: Total - Songs: ${allSongResults.length}, Albums: ${allAlbumResults.length}, Latest: ${allLatestResults.length}");

          // Insert sections in reverse order (so they appear in correct order at top)
          if (allLatestResults.isNotEmpty) {
            finalYtCharts.insert(0, {
              'title': 'Latest Songs',
              'items': allLatestResults,
            });
          }

          if (allAlbumResults.isNotEmpty) {
            finalYtCharts.insert(0, {
              'title': 'Top Albums',
              'items': allAlbumResults,
            });
          }

          if (allSongResults.isNotEmpty) {
            finalYtCharts.insert(0, {
              'title': 'Top Songs',
              'items': allSongResults,
            });
          }

          print("LOG: FetchYTMusic: Injection successful");
        } catch (e) {
          print("LOG: Error fetching specific language content: $e");
        }
      } else {
        print(
            "LOG: FetchYTMusic: Injection condition failed. Country: $targetCountry, Languages: $langs");
      }

      final ytChartsData = {
        'body': finalYtCharts,
        'head': ytCharts['head'] as List
      };

      // Store original unfiltered data for filtering
      _originalYtmData = Map<String, dynamic>.from(ytChartsData);

      // Mark first language as fetched
      if (langs.isNotEmpty) {
        _fetchedLanguages.add(langs[0]);
        print("LOG: Marked ${langs[0]} as fetched");
      }

      emit(state.copyWith(ytmData: ytChartsData, isLoading: false));

      // Cache the result
      final ytChartsJson = await compute(jsonEncode, ytChartsData);
      BloomeeDBService.putAPICache("YTMusic", ytChartsJson);
      log("YTMusic Fetched", name: "YTMusic");
    } else {
      log("YTMusic Empty", name: "YTMusic");
    }
  }

  Map<String, dynamic> _originalYtmData = {};
  Set<String> _fetchedLanguages = {}; // Track which languages have been fetched

  // Fetch specific language content on-demand
  Future<void> fetchLanguageContent(String language) async {
    if (_fetchedLanguages.contains(language)) {
      print("LOG: $language already fetched, skipping");
      return;
    }

    print("LOG: Fetching on-demand content for $language");

    try {
      final songResults =
          await YtMusicService().search("$language Top Songs", filter: "songs");
      final albumResults = await YtMusicService()
          .search("$language Top Albums", filter: "albums");
      final latestResults = await YtMusicService()
          .search("Latest $language Songs", filter: "songs");

      // Get current data
      final currentData = Map<String, dynamic>.from(_originalYtmData);
      final bodyData =
          List<Map<String, dynamic>>.from(currentData['body'] as List);

      // Find the 3 sections
      final topSongsIndex = bodyData.indexWhere((s) =>
          s['title']?.toString().contains('Top') == true &&
          s['title']?.toString().contains('Songs') == true);
      final topAlbumsIndex = bodyData.indexWhere((s) =>
          s['title']?.toString().contains('Top') == true &&
          s['title']?.toString().contains('Albums') == true);
      final latestSongsIndex = bodyData
          .indexWhere((s) => s['title']?.toString().contains('Latest') == true);

      // Add new language items to existing sections
      if (topSongsIndex != -1 &&
          songResults.isNotEmpty &&
          songResults[0]['items'] != null) {
        final items = songResults[0]['items'] as List;
        final existingItems =
            List<Map<String, dynamic>>.from(bodyData[topSongsIndex]['items']);
        for (var item in items) {
          final typedItem = Map<String, dynamic>.from(item as Map);
          typedItem['_language'] = language;
          existingItems.add(typedItem);
        }
        bodyData[topSongsIndex]['items'] = existingItems;
        print("LOG: Added ${items.length} songs for $language");
      }

      if (topAlbumsIndex != -1 &&
          albumResults.isNotEmpty &&
          albumResults[0]['items'] != null) {
        final items = albumResults[0]['items'] as List;
        final existingItems =
            List<Map<String, dynamic>>.from(bodyData[topAlbumsIndex]['items']);
        for (var item in items) {
          final typedItem = Map<String, dynamic>.from(item as Map);
          typedItem['_language'] = language;
          existingItems.add(typedItem);
        }
        bodyData[topAlbumsIndex]['items'] = existingItems;
        print("LOG: Added ${items.length} albums for $language");
      }

      if (latestSongsIndex != -1 &&
          latestResults.isNotEmpty &&
          latestResults[0]['items'] != null) {
        final items = latestResults[0]['items'] as List;
        final existingItems = List<Map<String, dynamic>>.from(
            bodyData[latestSongsIndex]['items']);
        for (var item in items) {
          final typedItem = Map<String, dynamic>.from(item as Map);
          typedItem['_language'] = language;
          existingItems.add(typedItem);
        }
        bodyData[latestSongsIndex]['items'] = existingItems;
        print("LOG: Added ${items.length} latest songs for $language");
      }

      // Update original data
      _originalYtmData = {'body': bodyData, 'head': currentData['head']};
      _fetchedLanguages.add(language);

      print("LOG: Successfully fetched and added $language content");
    } catch (e) {
      print("LOG: Error fetching $language: $e");
    }
  }

  void filterByLanguage(String language) async {
    print("LOG: Filtering content for language: $language");

    // Set loading state with empty data to show skeleton
    emit(state.copyWith(
      ytmData: {'body': [], 'head': []},
      isLoading: true,
    ));

    // Fetch language content if not already fetched
    if (!_fetchedLanguages.contains(language)) {
      print("LOG: Language $language not fetched, fetching now...");
      await fetchLanguageContent(language);
    }

    // Small delay to ensure skeleton shows
    await Future.delayed(const Duration(milliseconds: 100));

    // Use original data if available, otherwise use current state
    final sourceData =
        _originalYtmData.isNotEmpty ? _originalYtmData : state.ytmData;

    if (sourceData.isEmpty) {
      emit(state.copyWith(isLoading: false));
      return;
    }

    // Create a DEEP COPY to avoid modifying original data
    final fullData = Map<String, List<dynamic>>.from(sourceData);
    final sourceBody = fullData['body'] as List;
    final List<Map<String, dynamic>> bodyData = [];

    // Deep copy each section
    for (var section in sourceBody) {
      final sectionMap = Map<String, dynamic>.from(section as Map);
      if (sectionMap['items'] != null) {
        final items = sectionMap['items'] as List;
        sectionMap['items'] = List<Map<String, dynamic>>.from(
            items.map((item) => Map<String, dynamic>.from(item as Map)));
      }
      bodyData.add(sectionMap);
    }

    // Find the 3 injected sections
    final topSongsIndex = bodyData.indexWhere((section) =>
        section['title'] == 'Top Songs' ||
        (section['title']?.toString().contains('Top') == true &&
            section['title']?.toString().contains('Songs') == true));
    final topAlbumsIndex = bodyData.indexWhere((section) =>
        section['title'] == 'Top Albums' ||
        (section['title']?.toString().contains('Top') == true &&
            section['title']?.toString().contains('Albums') == true));
    final latestSongsIndex = bodyData.indexWhere((section) =>
        section['title'] == 'Latest Songs' ||
        section['title']?.toString().contains('Latest') == true);

    // Filter items in each section by language tag and update titles
    if (topSongsIndex != -1) {
      final allItems =
          bodyData[topSongsIndex]['items'] as List<Map<String, dynamic>>;
      bodyData[topSongsIndex]['items'] = allItems.where((item) {
        return item['_language'] == language;
      }).toList();
      bodyData[topSongsIndex]['title'] = 'Top $language Songs';
      print(
          "LOG: Top Songs filtered: ${bodyData[topSongsIndex]['items'].length} items");
    }

    if (topAlbumsIndex != -1) {
      final allItems =
          bodyData[topAlbumsIndex]['items'] as List<Map<String, dynamic>>;
      bodyData[topAlbumsIndex]['items'] = allItems.where((item) {
        return item['_language'] == language;
      }).toList();
      bodyData[topAlbumsIndex]['title'] = 'Top $language Albums';
      print(
          "LOG: Top Albums filtered: ${bodyData[topAlbumsIndex]['items'].length} items");
    }

    if (latestSongsIndex != -1) {
      final allItems =
          bodyData[latestSongsIndex]['items'] as List<Map<String, dynamic>>;
      bodyData[latestSongsIndex]['items'] = allItems.where((item) {
        return item['_language'] == language;
      }).toList();
      bodyData[latestSongsIndex]['title'] = 'Latest $language Songs';
      print(
          "LOG: Latest Songs filtered: ${bodyData[latestSongsIndex]['items'].length} items");
    }

    emit(state.copyWith(
      ytmData: {'body': bodyData, 'head': List.from(fullData['head'] ?? [])},
      isLoading: false,
    ));
    print("LOG: Filter applied successfully for $language");
  }

  void showAllLanguages() {
    print("LOG: Showing all languages");

    if (_originalYtmData.isEmpty) {
      // If no original data, fetch fresh
      fetchYTMusic();
      return;
    }

    // Restore original data with generic titles
    final fullData = Map<String, List<dynamic>>.from(_originalYtmData);
    final List<Map<String, dynamic>> bodyData =
        List<Map<String, dynamic>>.from(fullData['body'] as List);

    // Reset titles to generic
    for (var section in bodyData) {
      final title = section['title']?.toString() ?? '';
      if (title.contains('Top') && title.contains('Songs')) {
        section['title'] = 'Top Songs';
      } else if (title.contains('Top') && title.contains('Albums')) {
        section['title'] = 'Top Albums';
      } else if (title.contains('Latest')) {
        section['title'] = 'Latest Songs';
      }
    }

    emit(state.copyWith(ytmData: {
      'body': bodyData,
      'head': List.from(fullData['head'] ?? [])
    }));
  }
}
