import 'package:flutter/material.dart';

/// Builds TV tab pages lazily.
///
/// Unlike a plain IndexedStack with a fixed children list, this widget only
/// builds a page after it has been opened at least once. Visited pages are kept
/// alive so focus/state can survive tab changes, while cold-start stays light.
class TvLazyIndexedStack extends StatefulWidget {
  final int index;
  final List<WidgetBuilder> builders;
  final Widget placeholder;

  const TvLazyIndexedStack({
    super.key,
    required this.index,
    required this.builders,
    this.placeholder = const SizedBox.shrink(),
  });

  @override
  State<TvLazyIndexedStack> createState() => _TvLazyIndexedStackState();
}

class _TvLazyIndexedStackState extends State<TvLazyIndexedStack> {
  final Set<int> _visited = <int>{};

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
    _visited
      ..removeWhere((index) => index >= widget.builders.length)
      ..add(_safeIndex);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.builders.isEmpty) return widget.placeholder;
    final index = _safeIndex;
    _visited.add(index);

    return IndexedStack(
      index: index,
      sizing: StackFit.expand,
      children: [
        for (var i = 0; i < widget.builders.length; i++)
          RepaintBoundary(
            child: _visited.contains(i)
                ? KeyedSubtree(
                    key: ValueKey<int>(i),
                    child: widget.builders[i](context),
                  )
                : widget.placeholder,
          ),
      ],
    );
  }
}
