import 'package:flutter/material.dart';

/// HOME_PREVIEW zone.
///
/// Banner, Platform, Kategori, and only the first grid row are shown here.
/// The full content grid is not rendered in this zone. Pressing DOWN from the
/// preview row switches the parent screen into FULL_GRID mode.
class TvHomePreviewZone extends StatelessWidget {
  final EdgeInsets padding;
  final Widget banner;
  final List<Widget> below;
  final Widget sourceHeader;

  const TvHomePreviewZone({
    super.key,
    required this.padding,
    required this.banner,
    required this.sourceHeader,
    this.below = const <Widget>[],
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(padding.left, padding.top, padding.right, 0),
      sliver: SliverList(
        delegate: SliverChildListDelegate.fixed([
          banner,
          ...below,
          const SizedBox(height: 8),
          sourceHeader,
          const SizedBox(height: 6),
        ]),
      ),
    );
  }
}
