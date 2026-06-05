import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/content_item.dart';
import 'tv_poster_tile.dart';

class TvPosterGrid extends StatelessWidget {
  final List<ContentItem> items;
  final List<FocusNode> nodes;
  final int columns;
  final EdgeInsets padding;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double? childAspectRatio;
  final double? mainAxisExtent;
  final void Function(int index) onFocus;
  final void Function(int index, ContentItem item) onTap;
  final KeyEventResult Function(int index, ContentItem item, FocusNode node, KeyEvent event) onKey;

  const TvPosterGrid({
    super.key,
    required this.items,
    required this.nodes,
    required this.columns,
    required this.padding,
    required this.onFocus,
    required this.onTap,
    required this.onKey,
    this.crossAxisSpacing = 14,
    this.mainAxisSpacing = 16,
    this.childAspectRatio,
    this.mainAxisExtent,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty || nodes.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final usableCount = items.length < nodes.length ? items.length : nodes.length;
    final gridDelegate = mainAxisExtent != null
        ? SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: mainAxisExtent!,
            crossAxisSpacing: crossAxisSpacing,
            mainAxisSpacing: mainAxisSpacing,
          )
        : SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: childAspectRatio ?? 0.62,
            crossAxisSpacing: crossAxisSpacing,
            mainAxisSpacing: mainAxisSpacing,
          );

    return SliverPadding(
      padding: padding,
      sliver: SliverGrid(
        gridDelegate: gridDelegate,
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final item = items[i];
            final node = nodes[i];
            return TvPosterTile(
              key: ValueKey<String>('${item.platformSlug}:${item.id}:${item.chapterId}:$i'),
              item: item,
              focusNode: node,
              onFocus: () => onFocus(i),
              onTap: () => onTap(i, item),
              onKey: (focusNode, event) => onKey(i, item, focusNode, event),
            );
          },
          childCount: usableCount,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          addSemanticIndexes: false,
        ),
      ),
    );
  }
}
