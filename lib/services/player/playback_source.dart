import '../../models/stream_info.dart';
import '../api/api_platform.dart';

class PlaybackQuality {
  final String label;
  final String url;
  final bool isDefault;

  const PlaybackQuality({
    required this.label,
    required this.url,
    this.isDefault = false,
  });

  factory PlaybackQuality.fromStreamQuality(StreamQuality quality) {
    return PlaybackQuality(
      label: quality.label,
      url: quality.url,
      isDefault: quality.isDefault,
    );
  }

  StreamQuality toStreamQuality() {
    return StreamQuality(label: label, url: url, isDefault: isDefault);
  }

  int get height {
    final match = RegExp(r'(\d{3,4})').firstMatch(label);
    return match == null ? 0 : int.tryParse(match.group(1)!) ?? 0;
  }
}

class PlaybackSubtitle {
  final String language;
  final String format;
  final String url;

  const PlaybackSubtitle({
    required this.language,
    required this.format,
    required this.url,
  });

  factory PlaybackSubtitle.fromSubtitleTrack(SubtitleTrack track) {
    return PlaybackSubtitle(
      language: track.language,
      format: track.format,
      url: track.url,
    );
  }

  SubtitleTrack toSubtitleTrack() {
    return SubtitleTrack(language: language, format: format, url: url);
  }
}

class PlaybackAudioTrack {
  final String id;
  final String label;
  final String language;

  const PlaybackAudioTrack({
    required this.id,
    required this.label,
    this.language = '',
  });
}

class PlaybackSource {
  final String platform;
  final String dramaId;
  final int episodeNumber;
  final LiveGoVideoType videoType;
  final String url;
  final Map<String, String> headers;
  final List<PlaybackQuality> qualities;
  final List<PlaybackSubtitle> subtitles;
  final List<PlaybackAudioTrack> audioTracks;
  final String selectedQuality;
  final String selectedSubtitle;
  final String selectedAudioTrack;
  final int totalEpisodes;
  final String nextEpisodeId;
  final String prevEpisodeId;
  final bool encrypted;

  const PlaybackSource({
    required this.platform,
    required this.dramaId,
    required this.episodeNumber,
    required this.videoType,
    required this.url,
    required this.headers,
    required this.qualities,
    required this.subtitles,
    required this.audioTracks,
    required this.selectedQuality,
    required this.selectedSubtitle,
    required this.selectedAudioTrack,
    required this.totalEpisodes,
    required this.nextEpisodeId,
    required this.prevEpisodeId,
    this.encrypted = false,
  });

  bool get isPlayable => url.trim().isNotEmpty && !encrypted;
  bool get isHls => videoType == LiveGoVideoType.hls;
  bool get isMp4 => videoType == LiveGoVideoType.mp4;

  factory PlaybackSource.empty({
    String platform = '',
    String dramaId = '',
    int episodeNumber = 1,
    LiveGoVideoType videoType = LiveGoVideoType.mp4,
    bool encrypted = false,
  }) {
    return PlaybackSource(
      platform: platform,
      dramaId: dramaId,
      episodeNumber: episodeNumber,
      videoType: videoType,
      url: '',
      headers: const <String, String>{},
      qualities: const <PlaybackQuality>[],
      subtitles: const <PlaybackSubtitle>[],
      audioTracks: const <PlaybackAudioTrack>[],
      selectedQuality: 'Auto',
      selectedSubtitle: 'Auto',
      selectedAudioTrack: 'Source',
      totalEpisodes: 1,
      nextEpisodeId: '0',
      prevEpisodeId: '0',
      encrypted: encrypted,
    );
  }

  factory PlaybackSource.fromStreamInfo({
    required StreamInfo stream,
    required String platform,
    required String dramaId,
    required int episodeNumber,
    required LiveGoVideoType videoType,
    required String selectedQuality,
    required String selectedSubtitle,
    required String selectedAudioTrack,
  }) {
    return PlaybackSource(
      platform: platform,
      dramaId: dramaId,
      episodeNumber: stream.episodeIndex <= 0 ? episodeNumber : stream.episodeIndex,
      videoType: videoType,
      url: stream.url,
      headers: stream.headers,
      qualities: stream.qualities.map(PlaybackQuality.fromStreamQuality).toList(),
      subtitles: stream.subtitles.map(PlaybackSubtitle.fromSubtitleTrack).toList(),
      audioTracks: const <PlaybackAudioTrack>[
        PlaybackAudioTrack(id: 'source', label: 'Source / Default'),
      ],
      selectedQuality: selectedQuality,
      selectedSubtitle: selectedSubtitle,
      selectedAudioTrack: selectedAudioTrack,
      totalEpisodes: stream.totalEpisodes,
      nextEpisodeId: stream.nextEpisodeId,
      prevEpisodeId: stream.prevEpisodeId,
    );
  }

  StreamInfo toStreamInfo() {
    if (!isPlayable) return StreamInfo.empty;
    return StreamInfo(
      url: url,
      episodeIndex: episodeNumber,
      totalEpisodes: totalEpisodes <= 0 ? 1 : totalEpisodes,
      nextEpisodeId: nextEpisodeId,
      prevEpisodeId: prevEpisodeId,
      headers: headers,
      subtitles: subtitles.map((e) => e.toSubtitleTrack()).toList(),
      qualities: qualities.map((e) => e.toStreamQuality()).toList(),
    );
  }
}
