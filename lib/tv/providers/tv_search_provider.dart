import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/livego_catalog.dart';
import '../../models/content_item.dart';
import '../../services/content/content_health_service.dart';

class TvSearchState {
  final String query;
  final List<ContentItem> results;
  final bool loading;

  const TvSearchState({
    this.query = '',
    this.results = const <ContentItem>[],
    this.loading = false,
  });

  TvSearchState copyWith({String? query, List<ContentItem>? results, bool? loading}) {
    return TvSearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      loading: loading ?? this.loading,
    );
  }
}

class TvSearchController extends StateNotifier<TvSearchState> {
  TvSearchController() : super(const TvSearchState());

  int _ticket = 0;

  void setDraft(String value) {
    state = state.copyWith(query: value.trim());
  }

  Future<void> search(String value) async {
    final clean = value.trim();
    final ticket = ++_ticket;
    if (clean.isEmpty) {
      state = const TvSearchState();
      return;
    }

    state = state.copyWith(query: clean, loading: true, results: const <ContentItem>[]);
    List<ContentItem> rows = const <ContentItem>[];
    try {
      rows = await LiveGoCatalog.searchAll(clean)
          .timeout(const Duration(seconds: 22), onTimeout: () => const <ContentItem>[]);
    } catch (_) {
      rows = const <ContentItem>[];
    }
    if (ticket != _ticket) return;
    state = TvSearchState(
      query: clean,
      loading: false,
      results: ContentHealthService.filterPlayable(rows),
    );
  }
}

final tvSearchProvider = StateNotifierProvider<TvSearchController, TvSearchState>(
  (ref) => TvSearchController(),
);
