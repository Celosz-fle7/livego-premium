import 'package:flutter/foundation.dart';

/// Central BACK Logic Manager for Android TV.
///
/// BACK ladder (tanpa sidebar rail — rail sudah dihapus total):
/// 1. Close Open Dialog / Modal
/// 2. Non-Home tab -> kembali ke Home di posisi terakhir
/// 3. Home -> Open Exit App Confirmation Dialog
enum TvBackStep {
  none,
  closeModal,
  returnToParent,
  showExitDialog,
}

class TvBackManager {
  TvBackManager._();
  static final TvBackManager instance = TvBackManager._();

  static const int backDebounceMs = 280;
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
    required int currentTabIndex,
  }) {
    if (isExitDialogOpen) {
      return TvBackStep.closeModal;
    }
    if (currentTabIndex != 0) {
      // Di tab non-Home -> kembali ke Home posisi terakhir.
      return TvBackStep.returnToParent;
    }
    // Di Home -> konfirmasi keluar.
    return TvBackStep.showExitDialog;
  }
}
