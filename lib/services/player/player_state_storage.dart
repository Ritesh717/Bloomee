import 'dart:convert';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:Bloomee/model/songModel.dart';

class PlayerStateStorage {
  static const String _fileName = 'player_state.json';

  Future<File> get _file async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<void> saveState({
    required List<MediaItem> queue,
    required int index,
    required Duration position,
  }) async {
    try {
      final file = await _file;
      final List<Map<String, dynamic>> queueMap =
          queue.map((item) => _mediaItemToMap(item)).toList();

      final Map<String, dynamic> data = {
        'queue': queueMap,
        'index': index,
        'position': position.inMilliseconds,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await file.writeAsString(jsonEncode(data));
      // print("Player State Saved: Index $index, Pos ${position.inSeconds}s");
    } catch (e) {
      print("Error saving player state: $e");
    }
  }

  Future<Map<String, dynamic>?> restoreState() async {
    try {
      final file = await _file;
      if (!await file.exists()) return null;

      final content = await file.readAsString();
      if (content.isEmpty) return null;

      final Map<String, dynamic> data = jsonDecode(content);

      List<dynamic> queueList = data['queue'] ?? [];
      List<MediaItem> queue = queueList
          .map((item) => _mapToMediaItem(item as Map<String, dynamic>))
          .toList();

      return {
        'queue': queue,
        'index': data['index'],
        'position': Duration(
            milliseconds: data['index'] == -1 ? 0 : (data['position'] ?? 0)),
      };
    } catch (e) {
      print("Error restoring player state: $e");
      return null;
    }
  }

  Map<String, dynamic> _mediaItemToMap(MediaItem item) {
    return {
      'id': item.id,
      'title': item.title,
      'album': item.album,
      'artist': item.artist,
      'genre': item.genre,
      'duration': item.duration?.inMilliseconds,
      'artUri': item.artUri?.toString(),
      'extras': item.extras,
    };
  }

  MediaItem _mapToMediaItem(Map<String, dynamic> map) {
    // Assuming MediaItemModel is compatible or we use base MediaItem
    // Using MediaItem directly is safer for generic storage
    return MediaItem(
      id: map['id'],
      title: map['title'],
      album: map['album'],
      artist: map['artist'],
      genre: map['genre'],
      duration: map['duration'] != null
          ? Duration(milliseconds: map['duration'])
          : null,
      artUri: map['artUri'] != null ? Uri.parse(map['artUri']) : null,
      extras: map['extras'],
    );
  }
}
