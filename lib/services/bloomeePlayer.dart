import 'dart:developer';
import 'dart:io';
import 'dart:async';
import 'package:Bloomee/routes_and_consts/global_conts.dart';
import 'package:Bloomee/services/player/audio_source_manager.dart';
import 'package:Bloomee/services/player/player_error_handler.dart';
import 'package:Bloomee/services/player/queue_manager.dart';
import 'package:Bloomee/services/player/related_songs_manager.dart';
import 'package:Bloomee/utils/imgurl_formator.dart';
import 'package:audio_service/audio_service.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:Bloomee/model/songModel.dart';
import '../model/MediaPlaylistModel.dart';
import 'package:Bloomee/services/discord_service.dart';
import 'package:Bloomee/services/player/recently_played_tracker.dart';
import 'package:Bloomee/services/player/player_state_storage.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class BloomeeMusicPlayer extends BaseAudioHandler
    with SeekHandler, QueueHandler {
  late AudioPlayer audioPlayer;

  // Modular components
  late AudioSourceManager _audioSourceManager;
  late PlayerErrorHandler _errorHandler;
  late QueueManager _queueManager;
  late RelatedSongsManager _relatedSongsManager;

  BehaviorSubject<bool> fromPlaylist = BehaviorSubject<bool>.seeded(false);
  BehaviorSubject<bool> isOffline = BehaviorSubject<bool>.seeded(false);
  BehaviorSubject<LoopMode> loopMode =
      BehaviorSubject<LoopMode>.seeded(LoopMode.off);

  // Flag to track if player is disposed
  bool _isDisposed = false;

  // Recently played tracker: records plays only after a continuous
  // playback threshold (default 15s)
  late RecentlyPlayedTracker _recentlyPlayedTracker;
  final _playerStateStorage = PlayerStateStorage();

  // Stream subscriptions for proper cleanup
  StreamSubscription? _playbackEventSubscription;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _queueSubscription;
  StreamSubscription? _mediaItemSubscription;
  StreamSubscription? _connectivitySubscription;

  // Expose properties from modular components
  BehaviorSubject<bool> get shuffleMode => _queueManager.shuffleMode;
  BehaviorSubject<PlayerError?> get lastError => _errorHandler.lastError;
  BehaviorSubject<List<MediaItem>> get relatedSongs =>
      _relatedSongsManager.relatedSongs;
  @override
  BehaviorSubject<String> get queueTitle => _queueManager.queueTitle;

  BloomeeMusicPlayer() {
    _initializeAudioPlayer();
    _initializeModules();
    _initializePlayer();
    _recentlyPlayedTracker = RecentlyPlayedTracker(
      audioPlayer,
      () => _queueManager.currentMediaItem,
    );
  }

  void _initializeAudioPlayer() {
    _isDisposed = false;
    audioPlayer = AudioPlayer(
      handleInterruptions: true,
      androidApplyAudioAttributes: true,
      handleAudioSessionActivation: true,
    );
  }

  bool get isPlayerHealthy {
    if (_isDisposed) return false;
    try {
      final _ = audioPlayer.playerState;
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> revive() async {
    if (!_isDisposed) return;
    log('Reviving BloomeeMusicPlayer...', name: 'bloomeePlayer');

    // Close old BehaviorSubjects before recreating to prevent memory leaks
    try {
      if (!fromPlaylist.isClosed) await fromPlaylist.close();
      if (!isOffline.isClosed) await isOffline.close();
      if (!loopMode.isClosed) await loopMode.close();
    } catch (e) {
      log('Error closing subjects during revive: $e', name: 'bloomeePlayer');
    }

    // Now recreate the subjects
    fromPlaylist = BehaviorSubject<bool>.seeded(false);
    isOffline = BehaviorSubject<bool>.seeded(false);
    loopMode = BehaviorSubject<LoopMode>.seeded(LoopMode.off);

    _initializeAudioPlayer();
    _initializeModules();
    _initializePlayer();
    _recentlyPlayedTracker = RecentlyPlayedTracker(
      audioPlayer,
      () => _queueManager.currentMediaItem,
    );

    _isDisposed = false;

    // Reset playback state to idle
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
  }

  /// Configure how many continuous seconds are required before a track is
  /// added to Recently Played. Default is 15.
  void setRecentlyPlayedThresholdSeconds(int seconds) {
    _recentlyPlayedTracker.setThresholdSeconds(seconds);
  }

  /// Configure percentage (0..1) of track duration required before a track
  /// is added to Recently Played. Default is 0.4 (40%).
  void setRecentlyPlayedPercentThreshold(double percent) {
    _recentlyPlayedTracker.setPercentThreshold(percent);
  }

  void _initializeModules() {
    // Initialize all modular components
    _audioSourceManager = AudioSourceManager();
    _errorHandler = PlayerErrorHandler();
    _queueManager = QueueManager();
    _relatedSongsManager = RelatedSongsManager();

    // Warm the download cache for instant offline playback lookups
    _audioSourceManager.warmCache();

    // Setup callbacks between modules
    _errorHandler.onSkipToNext = () => skipToNext();
    _errorHandler.onRetryCurrentTrack = () => _retryCurrentTrack();

    _queueManager.onPrepareToPlay =
        (idx, doPlay) => _prepare4play(idx: idx, doPlay: doPlay);

    _relatedSongsManager.onAddQueueItems =
        (items, {bool atLast = false}) => addQueueItems(items, atLast: atLast);
  }

  void _initializePlayer() {
    audioPlayer.setVolume(1);
    _playbackEventSubscription =
        audioPlayer.playbackEventStream.listen(_broadcastPlayerEvent);
    audioPlayer.setLoopMode(LoopMode.off);

    // Enhanced error handling for player events
    _playerStateSubscription = audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.idle &&
          state.playing == false &&
          _errorHandler.lastError.value != null) {
        _handlePlaybackFailure();
      }
      // Save state on significant changes (pause/stop)
      if (!state.playing) {
        _savePlayerState();
      }
    });

    // Update the current media item when the audio player changes to the next
    _mediaItemSubscription = Rx.combineLatest2(
      audioPlayer.sequenceStream,
      audioPlayer.currentIndexStream,
      (sequence, index) {
        if (sequence.isEmpty) return null;
        MediaItem item = sequence[index ?? 0].tag as MediaItem;
        final artUri = Uri.parse(
            formatImgURL(item.artUri.toString(), ImageQuality.medium));
        item = item.copyWith(artUri: artUri);
        return item;
      },
    ).whereType<MediaItem>().listen((item) {
      // Only update if the media item has actually changed (compare id and artUri)
      final currentItem = mediaItem.value;
      if (currentItem == null ||
          currentItem.id != item.id ||
          currentItem.artUri != item.artUri) {
        mediaItem.add(item);
      }
    });

    // Trigger skipToNext when the current song ends.
    final endingOffset =
        Platform.isWindows ? 200 : (Platform.isLinux ? 700 : 200);
    _positionSubscription = audioPlayer.positionStream.listen((event) {
      //check if the current queue is empty and if it is, add related songs
      EasyThrottle.throttle('loadRelatedSongs', const Duration(seconds: 5),
          () async => check4RelatedSongs());
      if (((audioPlayer.duration != null &&
              audioPlayer.duration?.inSeconds != 0 &&
              event.inMilliseconds >
                  audioPlayer.duration!.inMilliseconds - endingOffset)) &&
          loopMode.value != LoopMode.one &&
          _queueManager.queue.value.isNotEmpty) {
        // Add safety check for queue
        EasyThrottle.throttle('skipNext', const Duration(milliseconds: 2000),
            () async => skipToNext());
      }

      // Removed periodic state saving - now only saves on pause/stop and queue changes
      // This reduces battery drain and database writes
    });

    // Refresh shuffle list when queue changes - delegate to queue manager
    _queueSubscription = _queueManager.queue.listen((e) {
      queue.add(e); // Sync with base audio handler queue
      _savePlayerState(); // Save state on queue changes
    });
  }

  Future<void> _savePlayerState() async {
    // Don't save if disposed or empty
    if (_isDisposed || _queueManager.queue.value.isEmpty) return;

    await _playerStateStorage.saveState(
      queue: _queueManager.queue.value,
      index: _queueManager.currentPlayingIdx,
      position: audioPlayer.position,
    );
  }

  Future<void> restoreLastSession() async {
    final state = await _playerStateStorage.restoreState();
    if (state != null) {
      final List<MediaItem> queue = state['queue'];
      final int index = state['index'];
      final Duration position = state['position'];

      if (queue.isNotEmpty) {
        _queueManager.restoreState(queue, index);
        // Load the item but don't play automatically, seek to position
        await _prepare4play(
            idx: index, doPlay: false, initialPosition: position);
        log("Restored last session: Index $index, Pos ${position.inSeconds}s",
            name: "bloomeePlayer");
      }
    }
  }

  void _handlePlaybackFailure() {
    if (_queueManager.queue.value.isNotEmpty &&
        _queueManager.currentPlayingIdx < _queueManager.queue.value.length) {
      final currentItem =
          _queueManager.queue.value[_queueManager.currentPlayingIdx];
      _errorHandler.handleError(PlayerErrorType.playbackError,
          'Playback failed unexpectedly', currentItem);
    }
  }

  Future<void> _retryCurrentTrack() async {
    if (_queueManager.queue.value.isNotEmpty &&
        _queueManager.currentPlayingIdx < _queueManager.queue.value.length) {
      final currentItem =
          _queueManager.queue.value[_queueManager.currentPlayingIdx];
      final currentPosition = audioPlayer.position;
      log('Retrying current track: ${currentItem.title} at position $currentPosition',
          name: 'bloomeePlayer');

      try {
        _errorHandler.clearError(); // Clear previous error
        await playMediaItem(currentItem,
            doPlay: true, initialPosition: currentPosition);
      } catch (e) {
        log('Retry failed: $e', name: 'bloomeePlayer');
        _errorHandler.handleError(
            PlayerErrorType.playbackError, 'Retry failed: $e', currentItem, e);
      }
    }
  }

  void _broadcastPlayerEvent(PlaybackEvent event) {
    bool isPlaying = audioPlayer.playing;
    playbackState.add(PlaybackState(
      // Which buttons should appear in the notification now
      controls: [
        MediaControl.skipToPrevious,
        isPlaying ? MediaControl.pause : MediaControl.play,
        // MediaControl.stop,
        MediaControl.skipToNext,
      ],
      processingState: switch (event.processingState) {
        ProcessingState.idle => AudioProcessingState.idle,
        ProcessingState.loading => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready => AudioProcessingState.ready,
        ProcessingState.completed => AudioProcessingState.completed,
      },
      // Which other actions should be enabled in the notification
      systemActions: const {
        MediaAction.skipToPrevious,
        MediaAction.playPause,
        MediaAction.skipToNext,
        MediaAction.seek,
      },
      androidCompactActionIndices: const [0, 1, 2],
      updatePosition: audioPlayer.position,
      playing: isPlaying,
      bufferedPosition: audioPlayer.bufferedPosition,
      speed: audioPlayer.speed,
    ));

    DiscordService.updatePresence(
      mediaItem: currentMedia,
      isPlaying: isPlaying,
    );
  }

  MediaItemModel get currentMedia {
    if (_queueManager.queue.value.isEmpty ||
        _queueManager.currentPlayingIdx >= _queueManager.queue.value.length) {
      return mediaItemModelNull;
    }
    return mediaItem2MediaItemModel(
        _queueManager.queue.value[_queueManager.currentPlayingIdx]);
  }

  @override
  Future<void> play() async {
    if (_isDisposed) {
      log('Cannot play: player is disposed', name: 'bloomeePlayer');
      return;
    }
    await WakelockPlus.enable();
    await audioPlayer.play();
  }

  Future<void> check4RelatedSongs() async {
    if (_queueManager.currentMediaItem == null) {
      log('No current media item available for related songs check',
          name: 'bloomeePlayer');
      return;
    }

    await _relatedSongsManager.checkForRelatedSongs(
      currentMedia: _queueManager.currentMediaItem!,
      queue: _queueManager.queue.value,
      currentPlayingIdx: _queueManager.currentPlayingIdx,
      loopMode: loopMode.value,
    );
  }

  @override
  Future<void> seek(Duration position) async {
    audioPlayer.seek(position);
  }

  Future<void> seekNSecForward(Duration n) async {
    if ((audioPlayer.duration ?? const Duration(seconds: 0)) >=
        audioPlayer.position + n) {
      await audioPlayer.seek(audioPlayer.position + n);
    } else {
      await audioPlayer
          .seek(audioPlayer.duration ?? const Duration(seconds: 0));
    }
  }

  Future<void> seekNSecBackward(Duration n) async {
    if (audioPlayer.position - n >= const Duration(seconds: 0)) {
      await audioPlayer.seek(audioPlayer.position - n);
    } else {
      await audioPlayer.seek(const Duration(seconds: 0));
    }
  }

  void setLoopMode(LoopMode loopMode) {
    if (loopMode == LoopMode.one) {
      audioPlayer.setLoopMode(LoopMode.one);
    } else {
      audioPlayer.setLoopMode(LoopMode.off);
    }
    this.loopMode.add(loopMode);
  }

  Future<void> shuffle(bool shuffle) async {
    await _queueManager.shuffle(shuffle);
  }

  Future<void> loadPlaylist(MediaPlaylist mediaList,
      {int idx = 0, bool doPlay = false, bool shuffling = false}) async {
    fromPlaylist.add(true);
    _relatedSongsManager.clearRelatedSongs();
    await _queueManager.loadPlaylist(mediaList,
        idx: idx, doPlay: doPlay, shuffling: shuffling);
    queueTitle.add(mediaList.playlistName);
  }

  @override
  Future<void> pause() async {
    if (_isDisposed) {
      log('Cannot pause: player is disposed', name: 'bloomeePlayer');
      return;
    }
    await WakelockPlus.disable();
    await audioPlayer.pause();
    // If the audio player is playing, pause it [Temporary bug]
    if (audioPlayer.playing) {
      audioPlayer.pause();
    }

    log("paused", name: "bloomeePlayer");
  }

  Future<AudioSource> getAudioSource(MediaItem mediaItem) async {
    try {
      final audioSource = await _audioSourceManager.getAudioSource(mediaItem);

      // Check if it's an offline source (file URI)
      if (audioSource.toString().contains('file://')) {
        isOffline.add(true);
      } else {
        isOffline.add(false);
      }

      return audioSource;
    } catch (e) {
      log('Error getting audio source for ${mediaItem.title}: $e',
          name: "bloomeePlayer");

      final errorType = _errorHandler.categorizeError(e);
      String errorMessage;

      switch (errorType) {
        case PlayerErrorType.networkError:
          errorMessage = 'Network error while loading song';
          break;
        case PlayerErrorType.sourceError:
          errorMessage = 'Song source unavailable';
          break;
        case PlayerErrorType.playbackError:
          errorMessage = 'Playback error occurred';
          break;
        case PlayerErrorType.bufferingError:
          errorMessage = 'Buffering error occurred';
          break;
        case PlayerErrorType.permissionError:
          errorMessage = 'Permission denied';
          break;
        default:
          errorMessage = 'Unknown error loading song';
      }

      _errorHandler.handleError(errorType, errorMessage, mediaItem, e);
      rethrow;
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    await _queueManager.skipToQueueItem(index);
    return super.skipToQueueItem(index);
  }

  Future<void> playAudioSource({
    required AudioSource audioSource,
    required String mediaId,
    Duration? initialPosition,
    bool doPlay = true,
  }) async {
    try {
      await pause();

      print('[Latency] Setting AudioSource (preload: false)...');
      await audioPlayer.setAudioSource(audioSource,
          initialPosition: initialPosition,
          preload: false); // Pass initialPosition here

      // Protect against hanging load calls (observed on Android when DNS fails).
      try {
        print('[Latency] Loading AudioSource...');
        // Wait up to 8 seconds for load, otherwise treat as network error.
        await audioPlayer.load().timeout(const Duration(seconds: 8));
        print('[Latency] AudioSource Loaded.');
      } on TimeoutException catch (e) {
        log('audioPlayer.load() timed out: $e', name: 'bloomeePlayer');
        final currentItem = _queueManager.currentMediaItem;
        _errorHandler.handleError(PlayerErrorType.networkError,
            'Network timeout while loading track', currentItem, e);
        try {
          await audioPlayer.stop();
        } catch (_) {}
        rethrow;
      }

      if (doPlay && !audioPlayer.playing) {
        await play();
      }

      // Clear any previous errors on successful playback
      _errorHandler.clearError();
      _errorHandler.clearRetryAttempts(mediaId);

      log('Successfully started playback for $mediaId', name: "bloomeePlayer");
    } catch (e) {
      log("Error in playAudioSource: $e", name: "bloomeePlayer");

      PlayerErrorType errorType;
      String errorMessage;

      if (e is PlayerException) {
        if (e.message?.contains('network') == true ||
            e.message?.contains('connection') == true) {
          errorType = PlayerErrorType.networkError;
          errorMessage = 'Network error during playback';
        } else if (e.message?.contains('source') == true ||
            e.message?.contains('format') == true) {
          errorType = PlayerErrorType.sourceError;
          errorMessage = 'Audio source error';
        } else {
          errorType = PlayerErrorType.playbackError;
          errorMessage = 'Playback failed: ${e.message}';
        }

        final currentItem = _queueManager.currentMediaItem;
        _errorHandler.handleError(errorType, errorMessage, currentItem, e);

        // For critical errors, try to recover
        if (errorType == PlayerErrorType.sourceError) {
          // _audioSourceManager.clearCachedSource(mediaId);
        }
      } else {
        final currentItem = _queueManager.currentMediaItem;
        _errorHandler.handleError(PlayerErrorType.unknownError,
            'Unexpected playback error', currentItem, e);
      }

      rethrow;
    }
  }

  @override
  Future<void> playMediaItem(MediaItem mediaItem,
      {bool doPlay = true, Duration? initialPosition}) async {
    final startTime = DateTime.now();
    print('[Latency] Playback Request started for: ${mediaItem.title}');

    // Schedule pre-cache for next song (delayed to prioritize current song loading)
    final nextItem = _queueManager.nextMediaItem;
    if (nextItem != null) {
      Future.delayed(const Duration(seconds: 2), () {
        print('[PreCache] Triggering for: ${nextItem.title}');
        _audioSourceManager.preCacheStream(nextItem).then((_) {
          print('[PreCache] Success for: ${nextItem.title}');
        }).catchError((e) {
          print('[PreCache] Failed for: ${nextItem.title}: $e');
        });
      });
    }

    try {
      log('Attempting to play: ${mediaItem.title}', name: "bloomeePlayer");

      final audioSource = await getAudioSource(mediaItem);

      final fetchTime = DateTime.now();
      print(
          '[Latency] AudioSource fetched in ${fetchTime.difference(startTime).inMilliseconds}ms');

      // Concurrency Guard: Check if the queue state has changed while we were fetching the source
      // This prevents race conditions where rapid skipping causes old requests to overwrite new ones
      final currentQueueItem = _queueManager.currentMediaItem;
      if (currentQueueItem != null && currentQueueItem.id != mediaItem.id) {
        log('Aborting playback of ${mediaItem.title}: Queue moved to ${currentQueueItem.title}',
            name: "bloomeePlayer");
        return;
      }

      await playAudioSource(
          audioSource: audioSource,
          mediaId: mediaItem.id,
          initialPosition: initialPosition,
          doPlay: doPlay);

      if (doPlay) {
        final readyTime = DateTime.now();
        print(
            '[Latency] Playback Started. Total Latency: ${readyTime.difference(startTime).inMilliseconds}ms');
      }

      if (doPlay && !audioPlayer.playing) {
        await play();
      }

      await check4RelatedSongs();
    } catch (e) {
      log('Failed to play media item ${mediaItem.title}: $e',
          name: "bloomeePlayer");

      // Don't rethrow here, let the error handling system manage it
      // The error was already handled in getAudioSource or playAudioSource
    }
  }

  Future<void> _prepare4play(
      {int idx = 0, bool doPlay = false, Duration? initialPosition}) async {
    final currentItem = _queueManager.currentMediaItem;
    if (currentItem == null) {
      log('Cannot prepare4play: no current media item', name: 'bloomeePlayer');
      return;
    }

    await playMediaItem(currentItem,
        doPlay: doPlay, initialPosition: initialPosition);
  }

  @override
  Future<void> rewind() async {
    if (audioPlayer.processingState == ProcessingState.ready) {
      await audioPlayer.seek(Duration.zero);
    } else if (audioPlayer.processingState == ProcessingState.completed) {
      await _prepare4play(idx: _queueManager.currentPlayingIdx);
    }
  }

  @override
  Future<void> skipToNext() async {
    await _queueManager.skipToNext();
    // return super.skipToNext();
  }

  @override
  Future<void> stop() async {
    await WakelockPlus.disable();
    // Stop audio player and clear presence, then propagate stop to audio service
    playbackState.add(playbackState.value
        .copyWith(processingState: AudioProcessingState.idle));
    await playbackState.firstWhere(
        (state) => state.processingState == AudioProcessingState.idle);
    await audioPlayer.stop();
    DiscordService.clearPresence();
    await super.stop();
  }

  @override
  Future<void> skipToPrevious() async {
    await _queueManager.skipToPrevious();
    // return super.skipToPrevious();
  }

  @override
  Future<void> onTaskRemoved() async {
    await stop();
    await _cleanup();
    return super.onTaskRemoved();
  }

  @override
  Future<void> onNotificationDeleted() async {
    await stop();
    await _cleanup();
    return super.onNotificationDeleted();
  }

  Future<void> _cleanup() async {
    if (_isDisposed) return;
    _isDisposed = true;

    // Cancel all stream subscriptions
    await _playbackEventSubscription?.cancel();
    await _playerStateSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _queueSubscription?.cancel();
    await _mediaItemSubscription?.cancel();
    await _connectivitySubscription?.cancel();

    // Dispose modular components
    _errorHandler.dispose();
    _queueManager.dispose();
    _relatedSongsManager.dispose();
    await _recentlyPlayedTracker.dispose();

    // Clear Discord presence
    DiscordService.clearPresence();

    // Stop and dispose audio player
    try {
      await audioPlayer.stop();
      await audioPlayer.dispose();
    } catch (e) {
      log('Error disposing audio player: $e', name: 'bloomeePlayer');
    }

    // Close behavior subjects
    try {
      await fromPlaylist.close();
      await isOffline.close();
      await loopMode.close();
    } catch (e) {
      log('Error closing behavior subjects: $e', name: 'bloomeePlayer');
    }

    await super.stop();
  }

  @override
  Future<void> insertQueueItem(int index, MediaItem mediaItem) async {
    await _queueManager.insertQueueItem(index, mediaItem);
    try {
      await super.insertQueueItem(index, mediaItem);
    } catch (e) {
      log('Error syncing insertQueueItem with audio service: $e',
          name: 'bloomeePlayer');
    }
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    await _queueManager.addQueueItem(mediaItem);
  }

  @override
  Future<void> updateQueue(List<MediaItem> queue, {bool doPlay = false}) async {
    await _queueManager.updateQueue(queue, doPlay: doPlay);
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems,
      {String queueName = "Queue", bool atLast = false}) async {
    await _queueManager.addQueueItems(mediaItems,
        queueName: queueName, atLast: atLast);
  }

  Future<void> addPlayNextItem(MediaItem mediaItem) async {
    await _queueManager.addPlayNextItem(mediaItem);
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    await _queueManager.removeQueueItemAt(index);
  }

  Future<void> moveQueueItem(int oldIndex, int newIndex) async {
    await _queueManager.moveQueueItem(oldIndex, newIndex);
  }
}
