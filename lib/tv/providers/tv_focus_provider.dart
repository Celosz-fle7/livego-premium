import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tv_focus_state.dart';
import 'tv_remote_owner.dart';

class TvFocusController extends StateNotifier<TvFocusState> {
  TvFocusController() : super(const TvFocusState(owner: TvRemoteOwner.home));

  void setOwner(TvRemoteOwner owner) => state = state.copyWith(owner: owner);
  void setIndex(int index) => state = state.copyWith(index: index);
  void setZone(int zone) => state = state.copyWith(zone: zone);
}

final tvFocusProvider = StateNotifierProvider<TvFocusController, TvFocusState>(
  (ref) => TvFocusController(),
);
