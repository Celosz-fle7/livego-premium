import 'package:flutter/material.dart';

/// Builds TV tab pages lazily and keeps memory under control.
///
/// TV lifecycle rule:
/// - active page is mounted
/// - explicitly kept page may stay mounted
/// - inactive non-kept pages are removed from the tree and disposed
///
/// KeepAlive must stay very small. Home is the normal warm page because it owns
/// the main TV landing experience. Other screens should be disposable unless
/// real-device testing proves otherwise.
class TvLazyIndexedStack extends StatefulWidget {
  final int index;
  final List<WidgetBuilder> builders;
  final Widget placeholder;

  /// Pages that should remain mounted after first visit.
  ///
  /// Keep this list small. Every kept page stays in memory and can still receive
  /// provider updates while mounted.
  final Set<int> keepAliveIndexes;

  const TvLazyIndexedStack({
    super.key,
    required this.index,
    required this.builders,
    this.placeholder = const SizedBox.shrink(),
    this.keepAliveIndexes = const <int>{0},
  });

  @override
  State<TvLazyIndexedStack> createState() => _TvLazyIndexedStackState();
}

class _TvLazyIndexedStackState extends State<TvLazyIndexedStack> {
  final Set<int> _visited = <int>{};
  final Map<int, Widget> _cache = <int, Widget>{};

  int get _safeIndex {
    if (widget.builders.isEmpty) return 0;
    return widget.index.clamp(0, widget.builders.length - 1).toInt();
  }

  @override
  void initState() {
    super.initState();
    _visited.add(_safeIndex);
  }

  @override
  void didUpdateWidget(covariant TvLazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _collect(active: _safeIndex);
  }

  void _collect({required int active}) {
    _visited
      ..removeWhere((index) => index >= widget.builders.length)
      ..add(active);

    // Dispose all inactive pages that are not explicitly kept warm.
    _visited.removeWhere((index) => index != active && !widget.keepAliveIndexes.contains(index));
    _cache.removeWhere((index, _) => index >= widget.builders.length || !_visited.contains(index));
  }

  Widget _buildPage(BuildContext context, int pageIndex, int activeIndex) {
    if (pageIndex == activeIndex) {
      // Active page must rebuild so focus tickets / provider updates are fresh.
      final page = KeyedSubtree(
        key: ValueKey<int>(pageIndex),
        child: widget.builders[pageIndex](context),
      );
      _cache[pageIndex] = page;
      return page;
    }

    return _cache.putIfAbsent(
      pageIndex,
      () => KeyedSubtree(
        key: ValueKey<int>(pageIndex),
        child: widget.builders[pageIndex](context),
      ),
    );
  }

  Widget _wrapPage({
    required int pageIndex,
    required int activeIndex,
    required Widget child,
  }) {
    final active = pageIndex == activeIndex;
    return Positioned.fill(
      child: Offstage(
        offstage: !active,
        child: TickerMode(
          enabled: active,
          child: IgnorePointer(
            ignoring: !active,
            child: RepaintBoundary(child: child),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.builders.isEmpty) return widget.placeholder;

    final active = _safeIndex;
    _collect(active: active);

    final keptInactive = _visited
        .where((index) => index != active && widget.keepAliveIndexes.contains(index))
        .toList(growable: false)
      ..sort();

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        for (final pageIndex in keptInactive)
          _wrapPage(
            pageIndex: pageIndex,
            activeIndex: active,
            child: _buildPage(context, pageIndex, active),
          ),
        _wrapPage(
          pageIndex: active,
          activeIndex: active,
          child: _buildPage(context, active, active),
        ),
      ],
    );
  }
}
