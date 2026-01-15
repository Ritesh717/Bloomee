import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:isolate';
import 'package:Bloomee/services/db/bloomee_db_service.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

Future<List<AudioOnlyStreamInfo>> getStreamInfoBG(
    String videoId, RootIsolateToken? token) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(token!);
  final ytExplode = YoutubeExplode();
  try {
    final manifest = await ytExplode.videos.streams.getManifest(videoId,
        requireWatchPage: true, ytClients: [YoutubeApiClient.androidVr]);

    // Prefer MP4 (AAC) streams for better Android compatibility
    final audioStreams = manifest.audioOnly;
    final mp4Streams =
        audioStreams.where((s) => s.container == StreamContainer.mp4).toList();
    final streamsToUse = mp4Streams.isNotEmpty ? mp4Streams : audioStreams;

    final supportedStreams = streamsToUse.sortByBitrate();
    final low = supportedStreams.firstOrNull;
    final high = supportedStreams.lastOrNull;

    if (low == null) {
      throw Exception('No audio stream available for this video.');
    }
    return [low, high ?? low];
  } finally {
    ytExplode.close();
  }
}

class YouTubeAudioSource extends StreamAudioSource {
  final String videoId;
  final String quality; // 'high' or 'low'
  final YoutubeExplode ytExplode;

  YouTubeAudioSource({
    required this.videoId,
    required this.quality,
    super.tag,
  }) : ytExplode = YoutubeExplode();

  Future<AudioOnlyStreamInfo> getStreamInfo() async {
    final cachedStreams = await getStreamFromCache(videoId);
    if (cachedStreams != null) {
      return quality == 'high' ? cachedStreams[1] : cachedStreams[0];
    }
    final vidId = videoId;
    final token = RootIsolateToken.instance;
    final streams = await Isolate.run(() => getStreamInfoBG(vidId, token));

    // Cache the streams for future use
    cacheYtStreams(id: vidId, hURL: streams[1], lURL: streams[0]);

    return quality == 'high' ? streams[1] : streams[0];
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    try {
      // final t1 = DateTime.now().millisecondsSinceEpoch;
      final audioStream = await getStreamInfo();
      // final t2 = DateTime.now().millisecondsSinceEpoch;

      start ??= 0;
      if (end != null && end > audioStream.size.totalBytes) {
        end = audioStream.size.totalBytes;
      }

      final stream = ytExplode.videos.streams.get(
        audioStream,
        start: start,
        end: end,
      );
      // dev.log('Time taken to get stream: ${t2 - t1}ms', name: 'YTStream');
      return StreamAudioResponse(
        sourceLength: audioStream.size.totalBytes,
        contentLength:
            end != null ? end - start : audioStream.size.totalBytes - start,
        offset: start,
        stream: stream,
        contentType: audioStream.codec.mimeType,
      );
    } catch (e) {
      throw Exception('Failed to load audio: $e');
    }
  }
}

Future<void> cacheYtStreams({
  required String id,
  required AudioOnlyStreamInfo hURL,
  required AudioOnlyStreamInfo lURL,
}) async {
  final expireAt = RegExp('expire=(.*?)&')
          .firstMatch(lURL.url.toString())!
          .group(1) ??
      (DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600 * 5.5).toString();

  try {
    BloomeeDBService.putYtLinkCache(
      id,
      jsonEncode(lURL.toJson()),
      jsonEncode(hURL.toJson()),
      int.parse(expireAt),
    );
    dev.log("Cached: $id, ExpireAt: $expireAt", name: "CacheYtStreams");
  } catch (e) {
    dev.log(e.toString(), name: "CacheYtStreams");
  }
}

Future<List<AudioOnlyStreamInfo>?> getStreamFromCache(String id) async {
  final cache = await BloomeeDBService.getYtLinkCache(id);
  if (cache != null) {
    final expireAt = cache.expireAt;
    if (expireAt > DateTime.now().millisecondsSinceEpoch ~/ 1000) {
      // dev.log("Cache found: $id", name: "CacheYtStreams");
      return [
        AudioOnlyStreamInfo.fromJson(jsonDecode(cache.lowQURL!)),
        AudioOnlyStreamInfo.fromJson(jsonDecode(cache.highQURL)),
      ];
    }
  }
  return null;
}
