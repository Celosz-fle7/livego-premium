import 'package:flutter/foundation.dart';

/// Central BACK Logic Manager for Android TV.
///
/// Implements a predictable BACK Ladder across all TV screens:
/// 1. Close Open Dialog / Modal
/// 2. Subscreen / Detail -> Return to Section Header / Parent
/// 3. In-page Content / Grid -> Return to Category / Tabs
/// 4. Category / Tabs -> Open & Focus Left Sidebar
/// 5. Left Sidebar (at Home) -> Open Exit App Confirmation Dialog
enum TvBackStep {
  none,
  closeModal,
  returnToParent,
  returnToCategory,
  openSidebar,
  showExitDialog,
}

class TvBackManager {
  TvBackManager._();
  static final TvBackManager instance = TvBackManager._();

  static const int backDebounceMs = 350;
  int _lastBackHandledMs = 0;

  /// Prevents accidental double-back events caused by remote signal bouncing.
  bool canHandleBack() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastBackHandledMs < backDebounceMs) {
      debugPrint('TvBackManager: back ignored (cooldown)');
      return false;
    }
    _lastBackHandledMs = now;
    return true;
  }

  /// Resolve what BACK button should do in the TV Shell root level.
  TvBackStep resolveShellBack({
    required bool isExitDialogOpen,
    required bool isSidebarFocused,
    required int currentTabIndex,
  }) {
    if (isExitDialogOpen) {
      return TvBackStep.closeModal;
    }
    if (!isSidebarFocused) {
      return TvBackStep.openSidebar;
    }
    if (currentTabIndex != 0) {
      // If at non-home tab on sidebar, return to home tab first
      return TvBackStep.returnToParent;
    }
    // At Home tab on sidebar -> confirm exit
    return TvBackStep.showExitDialog;
  }
}
