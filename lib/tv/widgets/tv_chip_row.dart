import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';

class TvChipRow extends StatefulWidget {
  final List<String> labels;
  final int selected;
  final int? focusedIndex;
  final List<FocusNode> nodes;
  final ValueChanged<int> onTap;
  final ValueChanged<int> onFocus;
  final KeyEventResult Function(int, KeyEvent) onKey;

  const TvChipRow({
    super.key,
    required this.labels,
    required this.selected,
    this.focusedIndex,
    required this.nodes,
    required this.onTap,
    required this.onFocus,
    required this.onKey,
  });

  @override
  State<TvChipRow> createState() => _TvChipRowState();
}

class _TvChipRowState extends State<TvChipRow> {
  final ScrollController _scroll = ScrollController();

  static const double _chipStep = 132.0; // 126 chip width + 6 right padding.

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncFocusedChip());
  }

  @override
  void didUpdateWidget(covariant TvChipRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusedIndex != oldWidget.focusedIndex || widget.labels.length != oldWidget.labels.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncFocusedChip());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _syncFocusedChip() {
    if (!mounted || !_scroll.hasClients) return;
    final index = widget.focusedIndex;
    if (index == null || widget.labels.length <= 6) return;

    // V6b: root-focus Home no longer gives real focus to each chip, so Flutter
    // cannot auto-reveal hidden horizontal chips. Scroll this row from index math.
    final rawTarget = (index * _chipStep) - _chipStep;
    final target = rawTarget.clamp(_scroll.position.minScrollExtent, _scroll.position.maxScrollExtent).toDouble();
    if ((target - _scroll.position.pixels).abs() < 1) return;
    _scroll.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.labels.isEmpty || widget.nodes.isEmpty) return const SizedBox.shrink();
    final count = widget.labels.length;
    Widget chipAt(int i) => _TvChip(
          text: widget.labels[i],
          active: i == widget.selected,
          focusNode: widget.nodes[i],
          focusedOverride: widget.focusedIndex == i,
          onTap: () => widget.onTap(i),
          onFocus: () => widget.onFocus(i),
          onKey: (node, event) => widget.onKey(i, event),
        );

    if (count <= 6) {
      return Row(
        children: List.generate(count, (i) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == count - 1 ? 0 : 6),
              child: chipAt(i),
            ),
          );
        }),
      );
    }

    return SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        children: List.generate(count, (i) {
          return Padding(
            padding: EdgeInsets.only(right: i == count - 1 ? 0 : 6),
            child: SizedBox(width: 126, child: chipAt(i)),
          );
        }),
      ),
    );
  }
}

class _TvChip extends StatelessWidget {
  final String text;
  final bool active;
  final FocusNode focusNode;
  final bool? focusedOverride;
  final VoidCallback onTap;
  final VoidCallback onFocus;
  final FocusOnKeyEventCallback onKey;

  const _TvChip({
    required this.text,
    required this.active,
    required this.focusNode,
    this.focusedOverride,
    required this.onTap,
    required this.onFocus,
    required this.onKey,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ListenableBuilder(
        listenable: focusNode,
        builder: (context, _) {
          final focused = focusedOverride ?? focusNode.hasFocus;
          final selected = active || focused;
          return Focus(
            focusNode: focusNode,
            skipTraversal: true,
            autofocus: false,
            onKeyEvent: onKey,
            onFocusChange: (v) {
              if (v) onFocus();
            },
            child: InkWell(
              canRequestFocus: false,
              onTap: onTap,
              borderRadius: BorderRadius.circular(999),
              focusColor: Colors.transparent,
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: active
                      ? AppTheme.activeGradient
                      : (focused
                          ? LinearGradient(colors: [AppTheme.cyan.withOpacity(0.13), AppTheme.surface3.withOpacity(0.98)])
                          : null),
                  color: active || focused ? null : AppTheme.surface2.withOpacity(0.82),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: focused
                        ? AppTheme.whiteGlow
                        : (active ? Colors.white.withOpacity(0.20) : Colors.white.withOpacity(0.075)),
                    width: focused ? 2.0 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (active) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Flexible(
                      child: Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? Colors.white : AppTheme.textSoft,
                          fontSize: 11.2,
                          fontWeight: FontWeight.w900,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
