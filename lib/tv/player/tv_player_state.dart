class TvPlayerState {
  final bool loading;
  final bool buffering;
  final bool playing;
  final bool controlsVisible;
  final bool hasError;
  final String errorMessage;
  final int episode;
  final int totalEpisodes;
  final String quality;
  final String subtitle;
  final String audioTrack;
  final double speed;

  const TvPlayerState({
    this.loading = true,
    this.buffering = false,
    this.playing = false,
    this.controlsVisible = true,
    this.hasError = false,
    this.errorMessage = '',
    this.episode = 1,
    this.totalEpisodes = 1,
    this.quality = 'Auto',
    this.subtitle = 'OFF',
    this.audioTrack = 'Source',
    this.speed = 1.0,
  });

  TvPlayerState copyWith({
    bool? loading,
    bool? buffering,
    bool? playing,
    bool? controlsVisible,
    bool? hasError,
    String? errorMessage,
    int? episode,
    int? totalEpisodes,
    String? quality,
    String? subtitle,
    String? audioTrack,
    double? speed,
  }) {
    return TvPlayerState(
      loading: loading ?? this.loading,
      buffering: buffering ?? this.buffering,
      playing: playing ?? this.playing,
      controlsVisible: controlsVisible ?? this.controlsVisible,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
      episode: episode ?? this.episode,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      quality: quality ?? this.quality,
      subtitle: subtitle ?? this.subtitle,
      audioTrack: audioTrack ?? this.audioTrack,
      speed: speed ?? this.speed,
    );
  }
}
