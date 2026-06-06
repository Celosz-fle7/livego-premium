import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/content_item.dart';
import '../focus/tv_focus_utils.dart';
import 'tv_player_screen.dart';

class TvPlayerStageScreen extends StatefulWidget {
  final ContentItem item;

  const TvPlayerStageScreen({
    super.key,
    required this.item,
  });

  @override
  State<TvPlayerStageScreen> createState() => _TvPlayerStageScreenState();
}

class _TvPlayerStageScreenState extends State<TvPlayerStageScreen> {
  final FocusNode _rootFocus = FocusNode(skipTraversal: true, debugLabel: 'tv-player-stage-root');
  Timer? _mountTimer;
  bool _showPlayer = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_rootFocus.canRequestFocus) _rootFocus.requestFocus();

      // Give Android TV/Flutter one clean black frame before mounting the real
      // player subtree. This avoids route/window handoff flashes from old
      // landscape/mobile-style player startup.
      _mountTimer = Timer(const Duration(milliseconds: 180), () {
        if (!mounted || _closing) return;
        setState(() => _showPlayer = true);
      });
    });
  }

  @override
  void dispose() {
    _mountTimer?.cancel();
    _rootFocus.dispose();
    super.dispose();
  }

  void _close() {
    if (_closing || !mounted) return;
    _closing = true;
    _mountTimer?.cancel();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    if (tvIsBackKey(event.logicalKey)) {
      _close();
      return KeyEventResult.handled;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _close();
      },
      child: Focus(
        focusNode: _rootFocus,
        autofocus: true,
        skipTraversal: true,
        onKeyEvent: _showPlayer ? null : _onKey,
        child: const ColoredBox(color: Colors.black).buildWithChild(
          child: _showPlayer
              ? TvPlayerScreen(item: widget.item)
              : const _BlackStageBody(),
        ),
      ),
    );
  }
}

class _BlackStageBody extends StatelessWidget {
  const _BlackStageBody();

  @override
  Widget build(BuildContext context) {
    return const Material(
      color: Colors.black,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: ColoredBox(color: Colors.black),
      ),
    );
  }
}

extension _BlackStageColoredBoxChild on ColoredBox {
  Widget buildWithChild({required Widget child}) {
    return Material(
      color: Colors.black,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            this,
            child,
          ],
        ),
      ),
    );
  }
}
