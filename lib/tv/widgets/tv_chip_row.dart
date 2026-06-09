import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';

class TvChipRow extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (labels.isEmpty || nodes.isEmpty) return const SizedBox.shrink();
    final count = labels.length;
    Widget chipAt(int i) => _TvChip(
          text: labels[i],
          active: i == selected,
          focusNode: nodes[i],
          focusedOverride: focusedIndex == i,
          onTap: () => onTap(i),
          onFocus: () => onFocus(i),
          onKey: (node, event) => onKey(i, event),
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
      scrollDirection: Axis.horizontal,
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
