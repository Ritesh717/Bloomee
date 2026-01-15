import 'dart:io';
import 'package:Bloomee/services/bloomeePlayer.dart';
import 'package:Bloomee/services/player/audio_source_manager.dart';
import 'package:Bloomee/services/player/player_error_handler.dart';
import 'package:Bloomee/services/player/queue_manager.dart';
import 'package:Bloomee/services/player/related_songs_manager.dart';
import 'package:Bloomee/theme_data/default.dart';
import 'package:audio_service/audio_service.dart';

class PlayerInitializer {
  static final PlayerInitializer _instance = PlayerInitializer._internal();
  factory PlayerInitializer() {
    return _instance;
  }

  PlayerInitializer._internal();

  static bool _isInitialized = false;
  static BloomeeMusicPlayer? bloomeeMusicPlayer;

  Future<void> _initialize() async {
    // Instantiate dependencies
    final audioSourceManager = AudioSourceManager();
    final queueManager = QueueManager();
    final relatedSongsManager = RelatedSongsManager();
    final errorHandler = PlayerErrorHandler();

    bloomeeMusicPlayer = await AudioService.init(
      builder: () => BloomeeMusicPlayer(
        audioSourceManager: audioSourceManager,
        queueManager: queueManager,
        relatedSongsManager: relatedSongsManager,
        errorHandler: errorHandler,
      ),
      config: const AudioServiceConfig(
        androidStopForegroundOnPause: false,
        androidNotificationChannelId: 'com.BloomeePlayer.notification.status',
        androidNotificationChannelName: 'BloomeTunes',
        androidResumeOnClick: true,
        androidShowNotificationBadge: true,
        notificationColor: Default_Theme.accentColor2,
      ),
    );

    // Brief delay on Android for native side to stabilize
    if (Platform.isAndroid && bloomeeMusicPlayer != null) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Restore last session
    if (bloomeeMusicPlayer != null) {
      await bloomeeMusicPlayer!.restoreLastSession();
    }

    // Check for zombie state and revive if necessary
    if (bloomeeMusicPlayer != null && !bloomeeMusicPlayer!.isPlayerHealthy) {
      await bloomeeMusicPlayer!.revive();
    }
  }

  Future<BloomeeMusicPlayer> getBloomeeMusicPlayer() async {
    if (!_isInitialized || bloomeeMusicPlayer == null) {
      await _initialize();
      _isInitialized = true;
    }
    return bloomeeMusicPlayer!;
  }
}
