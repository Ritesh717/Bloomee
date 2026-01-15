import 'dart:developer';
import 'package:Bloomee/model/songModel.dart';
import 'package:Bloomee/model/saavnModel.dart';
import 'package:Bloomee/routes_and_consts/global_str_consts.dart';
import 'package:Bloomee/screens/widgets/snackbar.dart';
import 'package:Bloomee/services/db/bloomee_db_service.dart';
import 'package:Bloomee/utils/ytstream_source.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:Bloomee/utils/network_quality_detector.dart';

class AudioSourceManager {
  // In-memory cache for download records to prevent blocking DB calls
  final Map<String, dynamic> _downloadCache = {};
  bool _cacheWarmed = false;

  /// Warm the cache with all downloaded songs on app startup
  Future<void> warmCache() async {
    if (_cacheWarmed) return;

    try {
      final allDownloads = await BloomeeDBService.getDownloadedSongs();
      for (var song in allDownloads) {
        final record = await BloomeeDBService.getDownloadDB(song);
        _downloadCache[song.id] = record;
      }
      _cacheWarmed = true;
      log("Download cache warmed with ${_downloadCache.length} items",
          name: "AudioSourceManager");
    } catch (e) {
      log("Error warming download cache: $e", name: "AudioSourceManager");
    }
  }

  Future<AudioSource> getAudioSource(MediaItem mediaItem) async {
    try {
      // Check in-memory cache first (instant lookup)
      final cachedRecord = _downloadCache[mediaItem.id];

      if (cachedRecord != null) {
        log("Playing Offline (cached): ${mediaItem.title}",
            name: "AudioSourceManager");
        // SnackbarService.showMessage("Playing Offline",
        //     duration: const Duration(seconds: 1));

        final audioSource = AudioSource.uri(
            Uri.file('${cachedRecord.filePath}/${cachedRecord.fileName}'),
            tag: mediaItem);
        return audioSource;
      }

      // Fallback to DB check if not in cache (only on cache miss)
      final _down = await BloomeeDBService.getDownloadDB(
          mediaItem2MediaItemModel(mediaItem));
      if (_down != null) {
        // Update cache for future lookups
        _downloadCache[mediaItem.id] = _down;

        log("Playing Offline: ${mediaItem.title}", name: "AudioSourceManager");
        // SnackbarService.showMessage("Playing Offline",
        //     duration: const Duration(seconds: 1));

        final audioSource = AudioSource.uri(
            Uri.file('${_down.filePath}/${_down.fileName}'),
            tag: mediaItem);
        return audioSource;
      }

      AudioSource audioSource;

      if (mediaItem.extras?["source"] == "youtube") {
        String? quality =
            await BloomeeDBService.getSettingStr(GlobalStrConsts.ytStrmQuality);

        // Adaptive Quality Logic
        if (quality == "Auto" || quality == null) {
          final shouldLow =
              NetworkQualityDetector().shouldUseLowQualityStreaming;
          quality = shouldLow ? "low" : "high";
          log("Adaptive Streaming: Using $quality quality (Network: ${shouldLow ? 'Poor' : 'Good'})",
              name: "AudioSourceManager");
        }

        quality = quality.toLowerCase();
        final id = mediaItem.id.replaceAll("youtube", '');

        audioSource =
            YouTubeAudioSource(videoId: id, quality: quality, tag: mediaItem);
      } else {
        String? kurl = await getJsQualityURL(mediaItem.extras?["url"]);
        if (kurl == null || kurl.isEmpty) {
          throw Exception('Failed to get stream URL');
        }

        log('Playing: $kurl', name: "AudioSourceManager");
        audioSource = AudioSource.uri(Uri.parse(kurl), tag: mediaItem);
      }

      return audioSource;
    } catch (e) {
      log('Error getting audio source for ${mediaItem.title}: $e',
          name: "AudioSourceManager");
      rethrow;
    }
  }

  /// Invalidate cache entry (call when download is deleted)
  void invalidateCache(String mediaId) {
    _downloadCache.remove(mediaId);
  }

  /// Clear entire cache (call on logout or major state changes)
  void clearCache() {
    _downloadCache.clear();
    _cacheWarmed = false;
  }

  /// Pre-fetch and cache the stream URL for a MediaItem
  Future<void> preCacheStream(MediaItem mediaItem) async {
    // 1. Skip if already downloaded (offline)
    if (_downloadCache.containsKey(mediaItem.id)) return;
    final _down = await BloomeeDBService.getDownloadDB(
        mediaItem2MediaItemModel(mediaItem));
    if (_down != null) {
      _downloadCache[mediaItem.id] = _down;
      return;
    }

    // 2. If YouTube, trigger stream resolution (which caches to DB)
    if (mediaItem.extras?["source"] == "youtube") {
      log('Pre-caching stream for: ${mediaItem.title}',
          name: "AudioSourceManager");
      try {
        final id = mediaItem.id.replaceAll("youtube", '');

        String? quality =
            await BloomeeDBService.getSettingStr(GlobalStrConsts.ytStrmQuality);
        if (quality == "Auto" || quality == null) {
          final shouldLow =
              NetworkQualityDetector().shouldUseLowQualityStreaming;
          quality = shouldLow ? "low" : "high";
        }

        final source = YouTubeAudioSource(
            videoId: id, quality: quality.toLowerCase(), tag: mediaItem);
        // This triggers the fetch and writes to DB cache
        await source.getStreamInfo();
        log('Pre-cache success: ${mediaItem.title}',
            name: "AudioSourceManager");
      } catch (e) {
        log('Pre-cache failed for ${mediaItem.title}: $e',
            name: "AudioSourceManager");
      }
    }
  }
}
