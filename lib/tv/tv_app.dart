import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'navigation/tv_shell.dart';

/// Thin TV entry point.
///
/// Keep remote ownership, navigation shell, and screen logic out of this file.
/// New TV foundation work should live under:
/// - tv/navigation
/// - tv/providers
/// - tv/focus
/// - tv/widgets
class TvApp extends StatelessWidget {
  const TvApp({super.key});

  @override
  Widget build(BuildContext context) => const ProviderScope(child: TvShell());
}
