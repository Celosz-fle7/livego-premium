import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/livego_catalog.dart';
import '../../models/content_item.dart';
import '../../models/livego_episode.dart';

class TvDetailData {
  final ContentItem original;
  final ContentItem detail;
  final List<LiveGoEpisode> episodes;

  const TvDetailData({
    required this.original,
    required this.detail,
    required this.episodes,
  });

  int get totalEpisodes {
    final fromRows = episodes.isEmpty ? 0 : episodes.last.index;
    final fromDetail = detail.episodes;
    final fromOriginal = original.episodes;
    final value = [fromRows, fromDetail, fromOriginal].reduce((a, b) => a > b ? a : b);
    return value <= 0 ? 1 : value;
  }
}

final tvDetailProvider = FutureProvider.family<TvDetailData, ContentItem>((ref, item) async {
  final detail = await LiveGoCatalog.detail(item);
  List<LiveGoEpisode> episodes = const <LiveGoEpisode>[];
  try {
    episodes = await LiveGoCatalog.episodes(detail);
  } catch (_) {
    episodes = const <LiveGoEpisode>[];
  }
  return TvDetailData(original: item, detail: detail, episodes: episodes);
});
