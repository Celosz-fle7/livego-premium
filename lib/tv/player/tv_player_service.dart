import '../../data/livego_catalog.dart';
import '../../models/content_item.dart';
import '../../models/livego_episode.dart';
import '../../models/stream_info.dart';

/// Player data/service boundary.
///
/// Phase 1 keeps the existing video_player controller inside the old screen.
/// Phase 2 can move controller ownership here after UI/focus split is stable.
class TvPlayerService {
  const TvPlayerService();

  Future<StreamInfo> fastStream(
    ContentItem item, {
    String? chapterId,
    Duration timeout = const Duration(seconds: 7),
  }) {
    return LiveGoCatalog.fastStreamInfo(item, chapterId: chapterId, timeout: timeout);
  }

  Future<StreamInfo> streamInfo(ContentItem item, {String? chapterId}) {
    return LiveGoCatalog.streamInfo(item, chapterId: chapterId);
  }

  Future<ContentItem> detail(ContentItem item) {
    return LiveGoCatalog.detail(item);
  }

  Future<List<LiveGoEpisode>> episodes(ContentItem item) {
    return LiveGoCatalog.episodes(item);
  }
}
