/// Central router for Android TV BACK behavior.
///
/// Screen files may still close their own local UI (popup/panel), but the
/// decision order lives here so the main TV flow stays consistent.
enum TvBackAction {
  none,
  closeDialog,
  focusNavbar,
  goHomeBanner,
  showExitDialog,
  closePanel,
  exitLocalScreen,
}

class TvBackRouter {
  const TvBackRouter();

  static const int homeIndex = 0;
  static const int duplicateGuardMs = 240;

  bool isDuplicatePress(int nowMs, int lastHandledMs) {
    return nowMs - lastHandledMs < duplicateGuardMs;
  }

  TvBackAction resolveRootBack({
    required bool exitDialogOpen,
    required bool navHasFocus,
    required int currentIndex,
  }) {
    if (exitDialogOpen) return TvBackAction.closeDialog;
    if (!navHasFocus) return TvBackAction.focusNavbar;
    if (currentIndex != homeIndex) return TvBackAction.goHomeBanner;
    return TvBackAction.showExitDialog;
  }

  TvBackAction resolveChildContentBack() {
    return TvBackAction.goHomeBanner;
  }

  TvBackAction resolveSourceManagerBack({
    required bool confirmOpen,
    required bool panelOpen,
  }) {
    if (confirmOpen) return TvBackAction.closeDialog;
    if (panelOpen) return TvBackAction.closePanel;
    return TvBackAction.exitLocalScreen;
  }
}
