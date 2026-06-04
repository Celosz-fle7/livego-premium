import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navigation/tv_nav_index.dart';
import 'tv_remote_owner.dart';

class TvNavigationState {
  final int navIndex;
  final TvRemoteOwner owner;
  final bool navFocused;

  const TvNavigationState({
    this.navIndex = TvNavIndex.home,
    this.owner = TvRemoteOwner.home,
    this.navFocused = false,
  });

  TvNavigationState copyWith({int? navIndex, TvRemoteOwner? owner, bool? navFocused}) {
    return TvNavigationState(
      navIndex: navIndex ?? this.navIndex,
      owner: owner ?? this.owner,
      navFocused: navFocused ?? this.navFocused,
    );
  }
}

class TvNavigationController extends StateNotifier<TvNavigationState> {
  TvNavigationController() : super(const TvNavigationState());

  void setOwner(TvRemoteOwner owner) {
    if (state.owner == owner) return;
    state = state.copyWith(owner: owner);
  }

  void selectNav(int index) {
    state = state.copyWith(navIndex: index, owner: TvRemoteOwner.navbar, navFocused: true);
  }

  void enterContent(int index) {
    state = state.copyWith(navIndex: index, owner: TvRemoteOwner.home, navFocused: false);
  }
}

final tvNavigationProvider = StateNotifierProvider<TvNavigationController, TvNavigationState>(
  (ref) => TvNavigationController(),
);
