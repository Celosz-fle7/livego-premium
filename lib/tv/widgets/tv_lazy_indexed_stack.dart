import 'package:flutter/material.dart';

/// Builds TV tab pages lazily and keeps memory under control.
///
/// Home is the only screen that should normally stay warm all the time because
/// it owns the main TV focus/scroll memory. Secondary screens can be disposed
/// when inactive so a large TV session does not keep every heavy screen alive.
class TvLazyIndexedStack extends StatefulWidget {
  final int index;
  final List<WidgetBuilder> builders;
  final Widget placeholder;

  /// Pages that should remain mounted after first visit.
  ///
  /// Keep this list small. Every kept page stays in memory.
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
    final active = _safeIndex;
    _visited
      ..removeWhere((index) => index >= widget.builders.length)
      ..add(active);

    // Dispose secondary screens when they are not active and not explicitly
    // kept alive. This keeps TV memory stable after the user opens many tabs.
    _visited.removeWhere((index) => index != active && !widget.keepAliveIndexes.contains(index));
    _cache.removeWhere((index, _) => index >= widget.builders.length || !_visited.contains(index));
  }

  Widget _pageFor(BuildContext context, int pageIndex, int activeIndex) {
    final shouldBuild = pageIndex == activeIndex || widget.keepAliveIndexes.contains(pageIndex);
    if (!_visited.contains(pageIndex) || !shouldBuild) return widget.placeholder;

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

  @override
  Widget build(BuildContext context) {
    if (widget.builders.isEmpty) return widget.placeholder;
    final active = _safeIndex;
    _visited.add(active);

    return IndexedStack(
      index: active,
      sizing: StackFit.expand,
      children: [
        for (var i = 0; i < widget.builders.length; i++)
          RepaintBoundary(child: _pageFor(context, i, active)),
      ],
    );
  }
}
