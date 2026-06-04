import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Home UI state that should survive screen rebuilds without forcing the whole
/// TV shell to rebuild. Data fetching still remains in the existing repository
/// layer; this provider is the foundation for moving Home focus/selection out
/// of the widget tree.
class TvHomeUiState {
  final int platformIndex;
  final int categoryIndex;
  final int gridIndex;

  const TvHomeUiState({
    this.platformIndex = 0,
    this.categoryIndex = 0,
    this.gridIndex = 0,
  });

  TvHomeUiState copyWith({int? platformIndex, int? categoryIndex, int? gridIndex}) {
    return TvHomeUiState(
      platformIndex: platformIndex ?? this.platformIndex,
      categoryIndex: categoryIndex ?? this.categoryIndex,
      gridIndex: gridIndex ?? this.gridIndex,
    );
  }
}

class TvHomeController extends StateNotifier<TvHomeUiState> {
  TvHomeController() : super(const TvHomeUiState());

  void rememberPlatform(int index) => state = state.copyWith(platformIndex: index);
  void rememberCategory(int index) => state = state.copyWith(categoryIndex: index);
  void rememberGrid(int index) => state = state.copyWith(gridIndex: index);
}

final tvHomeProvider = StateNotifierProvider<TvHomeController, TvHomeUiState>(
  (ref) => TvHomeController(),
);
