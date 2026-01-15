import 'dart:async';
import 'package:Bloomee/services/audio_service_initializer.dart';
import 'package:bloc/bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:Bloomee/services/bloomeePlayer.dart';
part 'bloomee_player_state.dart';

enum PlayerInitState { initializing, initialized, intial }

class BloomeePlayerCubit extends Cubit<BloomeePlayerState> {
  late BloomeeMusicPlayer bloomeePlayer;
  PlayerInitState playerInitState = PlayerInitState.intial;
  late Stream<ProgressBarStreams> progressStreams;
  StreamSubscription<ProgressBarStreams>? _progressSubscription;

  BloomeePlayerCubit() : super(BloomeePlayerInitial()) {
    setupPlayer().then((value) => emit(BloomeePlayerState(isReady: true)));
  }

  void switchShowLyrics({bool? value}) {
    emit(BloomeePlayerState(
        isReady: true, showLyrics: value ?? !state.showLyrics));
  }

  Future<void> setupPlayer() async {
    playerInitState = PlayerInitState.initializing;
    bloomeePlayer = await PlayerInitializer().getBloomeeMusicPlayer();
    playerInitState = PlayerInitState.initialized;
    _setupProgressStreams();
  }

  void _setupProgressStreams() {
    progressStreams = Rx.defer(
      () => Rx.combineLatest3(
          bloomeePlayer.positionStream.throttleTime(const Duration(
              milliseconds: 200)), // Throttle to 5 Hz for performance
          bloomeePlayer.playbackEventStream,
          bloomeePlayer.playerStateStream,
          (Duration a, PlaybackEvent b, PlayerState c) => ProgressBarStreams(
              currentPos: a, currentPlaybackState: b, currentPlayerState: c)),
      reusable: true,
    );
  }

  @override
  Future<void> close() async {
    // Cancel progress stream subscription to prevent memory leaks
    await _progressSubscription?.cancel();
    _progressSubscription = null;

    if (playerInitState == PlayerInitState.initialized) {
      await bloomeePlayer.stop();
    }
    return super.close();
  }
}
