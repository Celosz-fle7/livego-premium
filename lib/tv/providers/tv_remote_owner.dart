/// Logical owner of TV remote input.
///
/// This is the target state model for the TV foundation. Only one owner should
/// process a remote event at a time. Current screens are being migrated toward
/// this contract gradually so popup/player/home do not compete for the same key.
enum TvRemoteOwner {
  home,
  navbar,
  account,
  sourceManager,
  search,
  library,
  downloads,
  player,
  popup,
}
