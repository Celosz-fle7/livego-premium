import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/tv_zone.dart';

/// TV Home focus/index memory only.
///
/// Owns:
/// - active zone
/// - platform index
/// - category index
/// - grid index
///
/// Must not own FocusNode lifecycle, API/data fetching, or widget layout.
class TvHomeUiState {
  final int platformIndex;
  final int categoryIndex;
  final int gridIndex;
  final TvZone zone;

  const TvHomeUiState({
    this.platformIndex = 0,
    this.categoryIndex = 0,
    this.gridIndex = 0,
    this.zone = TvZone.banner,
  });

  TvHomeUiState copyWith({
    int? platformIndex,
    int? categoryIndex,
    int? gridIndex,
    TvZone? zone,
  }) {
    return TvHomeUiState(
      platformIndex: platformIndex ?? this.platformIndex,
      categoryIndex: categoryIndex ?? this.categoryIndex,
      gridIndex: gridIndex ?? this.gridIndex,
      zone: zone ?? this.zone,
    );
  }
}

class TvHomeFocusStateController extends StateNotifier<TvHomeUiState> {
  TvHomeFocusStateController() : super(const TvHomeUiState());

  void rememberPlatform(int index) {
    state = state.copyWith(platformIndex: index, zone: TvZone.platform);
  }

  void rememberCategory(int index) {
    state = state.copyWith(categoryIndex: index, zone: TvZone.category);
  }

  void rememberGrid(int index) {
    state = state.copyWith(gridIndex: index, zone: TvZone.grid);
  }

  void rememberZone(TvZone zone, int index) {
    switch (zone) {
      case TvZone.platform:
        rememberPlatform(index);
        return;
      case TvZone.category:
        rememberCategory(index);
        return;
      case TvZone.grid:
        rememberGrid(index);
        return;
      case TvZone.banner:
      case TvZone.nav:
      case TvZone.list:
      case TvZone.settings:
      case TvZone.placeholder:
      case TvZone.player:
        state = state.copyWith(zone: zone);
        return;
    }
  }

  void restore({
    required TvZone zone,
    required int platformIndex,
    required int categoryIndex,
    required int gridIndex,
  }) {
    state = state.copyWith(
      zone: zone,
      platformIndex: platformIndex,
      categoryIndex: categoryIndex,
      gridIndex: gridIndex,
    );
  }
}

final tvHomeProvider = StateNotifierProvider<TvHomeFocusStateController, TvHomeUiState>(
  (ref) => TvHomeFocusStateController(),
);
