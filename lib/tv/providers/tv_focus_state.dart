import 'tv_remote_owner.dart';

/// Lightweight focus snapshot shared by future TV controllers.
///
/// This file intentionally has no Flutter dependency so it can be tested and
/// reused without rebuilding widgets.
class TvFocusState {
  final TvRemoteOwner owner;
  final int zone;
  final int index;

  const TvFocusState({
    required this.owner,
    this.zone = 0,
    this.index = 0,
  });

  TvFocusState copyWith({TvRemoteOwner? owner, int? zone, int? index}) {
    return TvFocusState(
      owner: owner ?? this.owner,
      zone: zone ?? this.zone,
      index: index ?? this.index,
    );
  }
}
