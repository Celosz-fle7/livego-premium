import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tv_player_state.dart';

final tvPlayerStateProvider =
    StateNotifierProvider.autoDispose<TvPlayerStateController, TvPlayerState>((ref) {
  return TvPlayerStateController();
});

class TvPlayerStateController extends StateNotifier<TvPlayerState> {
  TvPlayerStateController() : super(const TvPlayerState());

  void setLoading(bool value) {
    state = state.copyWith(loading: value, hasError: value ? false : state.hasError);
  }

  void setPlaying(bool value) {
    state = state.copyWith(playing: value);
  }

  void setError(String message) {
    state = state.copyWith(
      loading: false,
      buffering: false,
      hasError: message.trim().isNotEmpty,
      errorMessage: message,
    );
  }

  void setEpisode(int episode, int total) {
    state = state.copyWith(
      episode: episode <= 0 ? 1 : episode,
      totalEpisodes: total <= 0 ? 1 : total,
    );
  }

  void setPreferences({
    String? quality,
    String? subtitle,
    String? audioTrack,
    double? speed,
  }) {
    state = state.copyWith(
      quality: quality,
      subtitle: subtitle,
      audioTrack: audioTrack,
      speed: speed,
    );
  }

  void showControls(bool value) {
    state = state.copyWith(controlsVisible: value);
  }
}
