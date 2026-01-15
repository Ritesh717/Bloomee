import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:Bloomee/blocs/library/cubit/library_items_cubit.dart';
import 'package:Bloomee/model/saavnModel.dart';
import 'package:Bloomee/utils/audio_tagger.dart';
import 'package:Bloomee/utils/dload.dart';
import 'package:Bloomee/utils/imgurl_formator.dart';
// import 'package:metadata_god/metadata_god.dart'; // Unused
import 'package:path/path.dart' as path;
import 'package:Bloomee/blocs/internet_connectivity/cubit/connectivity_cubit.dart';
import 'package:Bloomee/model/songModel.dart';
import 'package:Bloomee/routes_and_consts/global_str_consts.dart';
// import 'package:Bloomee/screens/widgets/snackbar.dart'; // Unused - snackbars disabled
import 'package:Bloomee/services/db/bloomee_db_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

part 'downloader_state.dart';

class DownloaderCubit extends Cubit<DownloaderState> {
  final ConnectivityCubit connectivityCubit;
  final LibraryItemsCubit libraryItemsCubit;
  final DownloadEngine _downloadEngine = DownloadEngine();
  final List<DownloadProgress> _activeDownloads = [];
  final YoutubeExplode _yt = YoutubeExplode();
  StreamSubscription? _librarySubscription;
  List<MediaItemModel> _downloadedSongs = [];

  DownloaderCubit({
    required this.connectivityCubit,
    required this.libraryItemsCubit,
  }) : super(DownloaderInitial()) {
    _downloadEngine.onTaskAdded = _handleNewTask;
    // MetadataGod.initialize(); // Moved to main.dart
    _setupLibrarySubscription();
    _loadDownloadedSongs();
  }

  Future<Directory> _getDownloadDirectory() async {
    // Check if a custom download path is set in settings
    final customPath =
        await BloomeeDBService.getSettingStr(GlobalStrConsts.downPathSetting);

    if (customPath != null && customPath.isNotEmpty) {
      if (Platform.isAndroid) {
        // Android 11+ (API 30+) Scoped Storage Check
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt >= 30) {
          // For custom paths on Android 11+, we need MANAGE_EXTERNAL_STORAGE
          // If we don't have it, we must fallback to app-specific directory
          // This prevents the "EACCES (Permission denied)" errors
          if (!await Permission.manageExternalStorage.isGranted) {
            log("Custom path requires MANAGE_EXTERNAL_STORAGE. Falling back to default.",
                name: "DownloaderCubit");
            // Fallback to default logic below
          } else {
            // We have permission, try to use custom path
            final customDir = Directory(customPath);
            if (await customDir.exists()) return customDir;
          }
        } else {
          // Android 10 and below, usually READ/WRITE_EXTERNAL_STORAGE is enough
          final customDir = Directory(customPath);
          if (await customDir.exists()) return customDir;
        }
      } else {
        // Non-Android platforms
        final customDir = Directory(customPath);
        if (await customDir.exists()) {
          return customDir;
        } else {
          try {
            await customDir.create(recursive: true);
            return customDir;
          } catch (e) {
            log("Failed to create custom directory: $e",
                name: "DownloaderCubit");
          }
        }
      }
    }

    if (Platform.isAndroid || Platform.isIOS) {
      final directory = (await getDownloadsDirectory()) ??
          await getApplicationDocumentsDirectory();
      return directory;
    }

    // Desktop default
    return await getApplicationDocumentsDirectory();
  }

  void _setupLibrarySubscription() {
    _librarySubscription = libraryItemsCubit.stream.listen((event) {
      log("LibraryItemsCubit event: ${event.playlists.length}",
          name: "DownloaderCubit");
      _loadDownloadedSongs();
    });
  }

  Future<void> _loadDownloadedSongs() async {
    final list = await BloomeeDBService.getDownloadedSongs();
    _downloadedSongs = List<MediaItemModel>.from(list);
    _emitUpdatedState();
  }

  void _emitUpdatedState() {
    emit(DownloaderTasksUpdated(
      List.from(_activeDownloads),
      List.from(_downloadedSongs),
    ));
  }

  /// Public method to refresh downloaded songs
  Future<void> refreshDownloadedSongs() async {
    // SnackbarService.showMessage("Refreshing downloads...");

    // 1. Queue downloads for missing files (restore)
    try {
      final missing = await BloomeeDBService.getMissingDownloads();

      if (missing.isNotEmpty) {
        // SnackbarService.showMessage(
        //     "Restoring ${missing.length} missing downloads...");
        for (var song in missing) {
          downloadSong(song, showSnackbar: false);
        }
      }
    } catch (e) {
      log("Error restoring downloads: $e", name: "DownloaderCubit");
    }

    // 2. Scan for new files in the download directory
    try {
      final directory = await _getDownloadDirectory();
      await BloomeeDBService.scanAndImportExistingFiles(directory.path);
    } catch (e) {
      log("Error scanning files: $e", name: "DownloaderCubit");
    }

    // 3. Reload from DB (this will clean up stale entries)
    await _loadDownloadedSongs();
  }

  /// Delete a downloaded song and update UI
  Future<void> deleteDownload(MediaItemModel song) async {
    try {
      await BloomeeDBService.removeDownloadDB(song);
      await _loadDownloadedSongs();
      log("Deleted ${song.title}", name: "DownloaderCubit");
    } catch (e) {
      log("Error deleting ${song.title}", error: e, name: "DownloaderCubit");
      rethrow;
    }
  }

  void _handleNewTask(DownloadTask task) {
    final newItem = DownloadProgress(
      task: task,
      status: const DownloadStatus(
          state: DownloadState.queued, message: "In Queue"),
    );
    _activeDownloads.insert(0, newItem);

    _emitUpdatedState();

    task.statusStream.listen((status) {
      final index = _activeDownloads
          .indexWhere((item) => item.task.originalUrl == task.originalUrl);
      if (index != -1) {
        _activeDownloads[index] = DownloadProgress(task: task, status: status);

        if (status.state == DownloadState.completed) {
          // Pass the completed task to the handler
          _onDownloadComplete(task);
        } else if (status.state == DownloadState.failed) {
          _onDownloadFailed(task);
        }

        _emitUpdatedState();
      }
    });
  }

  /// Handles saving metadata to the database after completion
  void _onDownloadComplete(DownloadTask task) async {
    log("Downloaded ${task.fileName}", name: "DownloaderCubit");

    // Only save to DB if it was a song with a MediaItemModel
    final downloadDirectory = path.dirname(task.targetPath);
    await BloomeeDBService.putDownloadDB(
        fileName: task.fileName,
        filePath: downloadDirectory,
        lastDownloaded: DateTime.now(),
        mediaItem: task.song);
    log("Saved metadata for ${task.fileName} to the database.",
        name: "DownloaderCubit");

    // Remove the task from the active downloads list
    _activeDownloads
        .removeWhere((item) => item.task.originalUrl == task.originalUrl);

    // Reload downloaded songs to include the newly completed download
    await _loadDownloadedSongs();
  }

  void _onDownloadFailed(DownloadTask task) {
    log("Failed to download ${task.fileName}", name: "DownloaderCubit");
    print("DownloaderCubit: Failed to download ${task.fileName}");

    // Remove the task from the active downloads list
    _activeDownloads
        .removeWhere((item) => item.task.originalUrl == task.originalUrl);
    _emitUpdatedState();
  }

  /// Checks the database and filesystem for an existing download
  Future<bool> _isAlreadyDownloaded(MediaItemModel song) async {
    final dbRecord = await BloomeeDBService.getDownloadDB(song);
    if (dbRecord != null) {
      final file = File(path.join(dbRecord.filePath, dbRecord.fileName));
      if (await file.exists()) {
        log("${song.title} is already downloaded and file exists.",
            name: "DownloaderCubit");
        return true; // The download exists in DB and on disk.
      } else {
        // The record is stale (in DB but file is missing), so remove it.
        log("Stale DB record found for ${song.title}. Removing.",
            name: "DownloaderCubit");
        await BloomeeDBService.removeDownloadDB(song);
        return false;
      }
    }
    return false; // No record found in the database.
  }

  /// The main public method to initiate a new download.
  Future<void> downloadSong(MediaItemModel song,
      {bool showSnackbar = true}) async {
    if (connectivityCubit.state != ConnectivityState.connected) {
      // if (showSnackbar) SnackbarService.showMessage("No internet connection.");
      return;
    }

    // Check queue limit (Component 9)
    if (_activeDownloads.length >= 50) {
      if (showSnackbar) {
        // SnackbarService.showMessage("Download queue full (max 50). Please wait.");
      }
      return;
    }

    // Check for duplicates in queue
    if (_activeDownloads
        .any((item) => item.task.originalUrl == song.extras!['perma_url'])) {
      // if (showSnackbar)
      //   SnackbarService.showMessage("${song.title} is already in the queue.");
      return;
    }

    // Check if already downloaded
    if (await _isAlreadyDownloaded(song)) {
      // if (showSnackbar)
      //   SnackbarService.showMessage("${song.title} is already downloaded.");
      return;
    }

    // Get directory for both placeholder and actual download
    var directory = await _getDownloadDirectory();

    // Organize by Album
    if (song.album != null &&
        song.album!.isNotEmpty &&
        song.album != "Unknown Album") {
      final sanitizedAlbum =
          song.album!.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
      final albumDir = Directory(path.join(directory.path, sanitizedAlbum));
      try {
        if (!await albumDir.exists()) {
          await albumDir.create(recursive: true);
        }
        directory = albumDir;
      } catch (e) {
        print("DownloaderCubit: Failed to create album directory: $e");
      }
    }

    // Create placeholder task immediately to show resolving state
    final sanitizedTitle =
        song.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    final tempFileName = "$sanitizedTitle.temp";

    final placeholderTask = DownloadTask(
      url: "placeholder", // Will be filled later
      originalUrl: song.extras!['perma_url'],
      fileName: tempFileName,
      targetPath: path.join(directory.path, tempFileName),
      maxRetries: 3,
      audioMetadata: null, // Will be filled later
      song: song,
    );

    final placeholderProgress = DownloadProgress(
      task: placeholderTask,
      status: const DownloadStatus(
        state: DownloadState.resolving,
        message: "Resolving download URL...",
      ),
    );

    _activeDownloads.insert(0, placeholderProgress);
    _emitUpdatedState();

    // if (showSnackbar)
    //   SnackbarService.showMessage("Preparing download for ${song.title}...");

    try {
      // Update status to fetching metadata
      final index = _activeDownloads.indexWhere(
          (item) => item.task.originalUrl == song.extras!['perma_url']);
      if (index != -1) {
        _activeDownloads[index] = DownloadProgress(
          task: placeholderTask,
          status: const DownloadStatus(
            state: DownloadState.fetchingMetadata,
            // message: "Fetching metadata...",
          ),
        );
        _emitUpdatedState();
      }

      String downloadUrl;
      String fileName;
      AudioMetadata? metadata;

      if (song.extras!['source'] == 'youtube' ||
          (song.extras!['perma_url'].toString()).contains('youtube')) {
        // --- NEW: Run YouTube manifest parsing in background isolate ---
        final quality = await BloomeeDBService.getSettingStr(
                GlobalStrConsts.ytDownQuality) ??
            "High";

        final result = await compute(_getYouTubeStream, {
          'id': song.id,
          'title': song.title,
          'artist': song.artist,
          'album': song.album,
          'artUri': song.artUri.toString(),
          'duration': song.duration?.inMilliseconds,
          'quality': quality,
        });

        downloadUrl = result['downloadUrl'];
        fileName = result['fileName'];
        metadata = result['metadata'];
      } else {
        downloadUrl = song.extras!['url'];
        final quality =
            await BloomeeDBService.getSettingStr(GlobalStrConsts.downQuality);
        if (quality == "High") {
          downloadUrl =
              (await getJsQualityURL(downloadUrl, isStreaming: false))!;
        } else {
          downloadUrl =
              (await getJsQualityURL(downloadUrl, isStreaming: false))!;
        }
        final sanitizedTitle =
            song.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
        fileName = '$sanitizedTitle by ${song.artist} - ${song.id}.m4a';
        metadata = AudioMetadata(
          title: song.title,
          artist: song.artist ?? "Unknown Artist",
          album: song.album ?? "Unknown Album",
          artworkUrl: formatImgURL(song.artUri.toString(), ImageQuality.high),
        );
      }

      // Remove the placeholder from active downloads before adding the real task
      _activeDownloads.removeWhere(
          (item) => item.task.originalUrl == song.extras!['perma_url']);

      _downloadEngine.addDownload(
        url: downloadUrl,
        originalUrl: song.extras!['perma_url'],
        directory: directory.path,
        fileName: fileName,
        maxRetries: 3,
        audioMetadata: metadata,
        song: song,
        showSnackbar: showSnackbar,
      );

      // if (showSnackbar)
      //   SnackbarService.showMessage("Added ${song.title} to download queue");
    } catch (e) {
      log("Failed to prepare download for ${song.title}",
          error: e, name: "DownloaderCubit");
      print(
          "DownloaderCubit: Failed to prepare download for ${song.title}: $e"); // Added print

      // Remove the placeholder on error
      _activeDownloads.removeWhere(
          (item) => item.task.originalUrl == song.extras!['perma_url']);
      _emitUpdatedState();

      // if (showSnackbar)
      //   SnackbarService.showMessage("Error: Could not process URL.");
    }
  }

  /// Static method to fetch YouTube stream info in an isolate
  static Future<Map<String, dynamic>> _getYouTubeStream(
      Map<String, dynamic> args) async {
    final yt = YoutubeExplode();
    try {
      final String id = args['id'].replaceAll("youtube", "");
      final String quality = args['quality'];

      final video = await yt.videos.get(id);
      var manifest = await yt.videos.streams.getManifest(video.id,
          requireWatchPage: true, ytClients: [YoutubeApiClient.androidVr]);

      AudioOnlyStreamInfo? audioStreamInfo;

      if (quality == "High") {
        audioStreamInfo = manifest.audioOnly
            .where((stream) => stream.container == StreamContainer.mp4)
            .withHighestBitrate();
      } else {
        audioStreamInfo = manifest.audioOnly
            .where((stream) => stream.container == StreamContainer.mp4)
            .sortByBitrate()
            .first;
      }

      audioStreamInfo ??= manifest.audioOnly.withHighestBitrate();

      if (audioStreamInfo == null) {
        throw Exception("No suitable audio stream found for ${video.title}");
      }

      final downloadUrl = audioStreamInfo.url.toString();
      final sanitizedTitle =
          args['title'].replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
      final fileName =
          '$sanitizedTitle by ${args['artist']} - ${args['id']}.${audioStreamInfo.container.name}';

      final metadata = AudioMetadata(
        title: args['title'],
        artist: args['artist'] ?? "Unknown Artist",
        album: args['album'] ?? "Unknown Album",
        artworkUrl: formatImgURL(args['artUri'], ImageQuality.high),
        duration: args['duration'] != null
            ? Duration(milliseconds: args['duration'])
            : null,
      );

      return {
        'downloadUrl': downloadUrl,
        'fileName': fileName,
        'metadata': metadata,
      };
    } finally {
      yt.close();
    }
  }

  @override
  Future<void> close() {
    _librarySubscription?.cancel();
    _yt.close();
    return super.close();
  }
}
