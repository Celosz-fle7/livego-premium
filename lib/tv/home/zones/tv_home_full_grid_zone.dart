import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/content_item.dart';
import '../../widgets/tv_poster_grid.dart';

/// FULL_GRID zone.
///
/// This zone intentionally renders only the poster grid. Banner, Platform, and
/// Kategori are not part of this layout, so the TV remote cannot pull them into
/// view while browsing deep rows.
class TvHomeFullGridZone extends StatelessWidget {
  final List<ContentItem> items;
  final List<FocusNode> nodes;
  final int columns;
  final EdgeInsets padding;
  final void Function(int index) onFocus;
  final void Function(int index, ContentItem item) onTap;
  final KeyEventResult Function(int index, ContentItem item, FocusNode node, KeyEvent event) onKey;

  const TvHomeFullGridZone({
    super.key,
    required this.items,
    required this.nodes,
    required this.columns,
    required this.padding,
    required this.onFocus,
    required this.onTap,
    required this.onKey,
  });

  @override
  Widget build(BuildContext context) {
    return TvPosterGrid(
      items: items,
      nodes: nodes,
      columns: columns,
      padding: padding,
      crossAxisSpacing: 12,
      mainAxisSpacing: 14,
      mainAxisExtent: 205,
      onFocus: onFocus,
      onTap: onTap,
      onKey: onKey,
    );
  }
}
