import 'dart:developer';
import 'package:audio_service/audio_service.dart';
import 'package:rxdart/rxdart.dart';
import '../../model/MediaPlaylistModel.dart';

import 'package:synchronized/synchronized.dart';

List<int> generateRandomIndices(int length) {
  List<int> indices = List<int>.generate(length, (i) => i);
  indices.shuffle();
  return indices;
}

class QueueManager {
  final BehaviorSubject<List<MediaItem>> queue =
      BehaviorSubject<List<MediaItem>>.seeded([]);
  final BehaviorSubject<bool> shuffleMode = BehaviorSubject<bool>.seeded(false);
  final BehaviorSubject<String> queueTitle =
      BehaviorSubject<String>.seeded("Queue");

  // Lock for queue synchronization
  final Lock _lock = Lock();

  int currentPlayingIdx = 0;
  int shuffleIdx = 0;
  List<int> shuffleList = [];

  // Callbacks
  Function(int idx, bool doPlay)? onPrepareToPlay;

  QueueManager() {
    // Refresh shuffle list when queue changes
    queue.listen((e) {
      shuffleList = generateRandomIndices(e.length);
    });
  }

  Future<void> loadPlaylist(MediaPlaylist mediaList,
      {int idx = 0, bool doPlay = false, bool shuffling = false}) async {
    await _lock.synchronized(() async {
      queue.add([]);
      queue.add(mediaList.mediaItems);
      queueTitle.add(mediaList.playlistName);
      await shuffle(shuffling || shuffleMode.value);
    });
    await _prepare4play(idx: idx, doPlay: doPlay);
  }

  Future<void> shuffle(bool shuffle) async {
    shuffleMode.add(shuffle);
    if (shuffle) {
      shuffleIdx = 0;
      shuffleList = generateRandomIndices(queue.value.length);
    }
  }

  Future<void> skipToNext() async {
    if (queue.value.isEmpty) {
      log('Cannot skip to next: queue is empty', name: 'QueueManager');
      return;
    }

    if (!shuffleMode.value) {
      if (currentPlayingIdx < (queue.value.length - 1)) {
        currentPlayingIdx++;
        await _prepare4play(idx: currentPlayingIdx, doPlay: true);
      }
    } else {
      if (shuffleList.isEmpty) {
        log('Cannot skip in shuffle mode: shuffle list is empty',
            name: 'QueueManager');
        return;
      }

      if (shuffleIdx < (shuffleList.length - 1)) {
        shuffleIdx++;
        await _prepare4play(idx: shuffleList[shuffleIdx], doPlay: true);
      }
    }
  }

  Future<void> skipToPrevious() async {
    if (queue.value.isEmpty) {
      log('Cannot skip to previous: queue is empty', name: 'QueueManager');
      return;
    }

    if (!shuffleMode.value) {
      if (currentPlayingIdx > 0) {
        currentPlayingIdx--;
        await _prepare4play(idx: currentPlayingIdx, doPlay: true);
      }
    } else {
      if (shuffleList.isEmpty) {
        log('Cannot skip in shuffle mode: shuffle list is empty',
            name: 'QueueManager');
        return;
      }

      if (shuffleIdx > 0) {
        shuffleIdx--;
        await _prepare4play(idx: shuffleList[shuffleIdx], doPlay: true);
      }
    }
  }

  Future<void> skipToQueueItem(int index) async {
    if (index >= queue.value.length) {
      log("skipToQueueItem: Invalid index $index, queue length: ${queue.value.length}",
          name: "QueueManager");
      return;
    }

    currentPlayingIdx = index;
    await _prepare4play(idx: index, doPlay: true);
    log("skipToQueueItem: Moved to index $index", name: "QueueManager");
  }

  Future<void> addQueueItem(MediaItem mediaItem) async {
    await _lock.synchronized(() async {
      if (queue.value.any((e) => e.id == mediaItem.id)) return;
      queueTitle.add("Queue");

      final newQueue = List<MediaItem>.from(queue.value)..add(mediaItem);
      queue.add(newQueue);

      if (newQueue.length == 1) {
        // Don't await this inside the lock as it might trigger other operations
        // Just schedule it
        _prepare4play(idx: 0, doPlay: true);
      }
    });
  }

  void restoreState(List<MediaItem> newQueue, int newIndex) {
    queue.add(newQueue);
    currentPlayingIdx = newIndex;
    queueTitle.add("Queue");
  }

  Future<void> updateQueue(List<MediaItem> newQueue,
      {bool doPlay = false}) async {
    await _lock.synchronized(() async {
      queue.add(newQueue);
    });
    await _prepare4play(idx: 0, doPlay: doPlay);
  }

  Future<void> addQueueItems(List<MediaItem> mediaItems,
      {String queueName = "Queue", bool atLast = false}) async {
    await _lock.synchronized(() async {
      if (!atLast) {
        // Need to rethink this recursive call if we lock, but here we can just add directly
        // to avoid deadlock if addQueueItem also locks

        final newItems = <MediaItem>[];
        final currentIds = queue.value.map((e) => e.id).toSet();

        for (var mediaItem in mediaItems) {
          if (!currentIds.contains(mediaItem.id)) {
            newItems.add(mediaItem);
            currentIds.add(mediaItem.id);
          }
        }

        if (newItems.isNotEmpty) {
          queueTitle.add("Queue");
          final newQueue = List<MediaItem>.from(queue.value)..addAll(newItems);
          queue.add(newQueue);

          if (queue.value.length == newItems.length) {
            _prepare4play(idx: 0, doPlay: true);
          }
        }
      } else {
        final newQueue = List<MediaItem>.from(queue.value)..addAll(mediaItems);
        queue.add(newQueue);
        queueTitle.add("Queue");
      }
    });
  }

  Future<void> addPlayNextItem(MediaItem mediaItem) async {
    if (queue.value.isNotEmpty) {
      if (queue.value.any((e) => e.id == mediaItem.id)) return;
      final newQueue = List<MediaItem>.from(queue.value)
        ..insert(currentPlayingIdx + 1, mediaItem);
      queue.add(newQueue);
    } else {
      await updateQueue([mediaItem], doPlay: true);
    }
  }

  Future<void> insertQueueItem(int index, MediaItem mediaItem) async {
    final currentQueue = List<MediaItem>.from(queue.value);
    if (index < currentQueue.length) {
      currentQueue.insert(index, mediaItem);
    } else {
      currentQueue.add(mediaItem);
    }
    queue.add(currentQueue);

    // Adjust the currentPlayingIdx
    if (currentPlayingIdx >= index) {
      currentPlayingIdx++;
    }
  }

  Future<void> removeQueueItemAt(int index) async {
    if (index < queue.value.length) {
      final newQueue = List<MediaItem>.from(queue.value);
      newQueue.removeAt(index);
      queue.add(newQueue);

      if (currentPlayingIdx == index) {
        if (index < newQueue.length) {
          await _prepare4play(idx: index, doPlay: true);
        } else if (index > 0) {
          await _prepare4play(idx: index - 1, doPlay: true);
        }
      } else if (currentPlayingIdx > index) {
        currentPlayingIdx--;
      }
    }
  }

  Future<void> moveQueueItem(int oldIndex, int newIndex) async {
    log("Moving from $oldIndex to $newIndex", name: "QueueManager");
    final newQueue = List<MediaItem>.from(queue.value);
    if (oldIndex < newIndex) {
      newIndex--;
    }

    final item = newQueue.removeAt(oldIndex);
    newQueue.insert(newIndex, item);
    queue.add(newQueue);

    // update the currentPlayingIdx
    if (currentPlayingIdx == oldIndex) {
      currentPlayingIdx = newIndex;
    } else if (oldIndex < currentPlayingIdx && newIndex >= currentPlayingIdx) {
      currentPlayingIdx--;
    } else if (oldIndex > currentPlayingIdx && newIndex <= currentPlayingIdx) {
      currentPlayingIdx++;
    }
  }

  MediaItem? get currentMediaItem {
    if (queue.value.isEmpty || currentPlayingIdx >= queue.value.length) {
      return null;
    }
    return queue.value[currentPlayingIdx];
  }

  bool get hasNext {
    if (shuffleMode.value) {
      return shuffleIdx < (shuffleList.length - 1);
    }
    return currentPlayingIdx < (queue.value.length - 1);
  }

  bool get hasPrevious {
    if (shuffleMode.value) {
      return shuffleIdx > 0;
    }
    return currentPlayingIdx > 0;
  }

  MediaItem? get nextMediaItem {
    if (queue.value.isEmpty) return null;

    if (shuffleMode.value) {
      if (shuffleList.isEmpty || shuffleIdx >= shuffleList.length - 1) {
        return null;
      }
      return queue.value[shuffleList[shuffleIdx + 1]];
    } else {
      if (currentPlayingIdx >= queue.value.length - 1) return null;
      return queue.value[currentPlayingIdx + 1];
    }
  }

  Future<void> _prepare4play({int idx = 0, bool doPlay = false}) async {
    if (queue.value.isEmpty) {
      log('Cannot prepare4play: queue is empty', name: 'QueueManager');
      return;
    }

    if (idx >= queue.value.length) {
      log('Index $idx is out of bounds, queue length: ${queue.value.length}',
          name: 'QueueManager');
      idx = queue.value.length - 1;
    }

    currentPlayingIdx = idx;
    onPrepareToPlay?.call(idx, doPlay);
  }

  void dispose() {
    queue.close();
    shuffleMode.close();
    queueTitle.close();
  }
}
