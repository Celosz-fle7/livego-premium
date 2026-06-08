import 'package:flutter/material.dart';

/// HOME_TOP zone.
///
/// This zone is intentionally passive except for the Banner focus supplied by
/// the parent screen. Platform/Kategori/Grid are not rendered here, so the TV
/// remote cannot accidentally reach browse content below Banner.
class TvHomeTopZone extends StatelessWidget {
  final EdgeInsets padding;
  final Widget banner;
  final List<Widget> below;

  const TvHomeTopZone({
    super.key,
    required this.padding,
    required this.banner,
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
        ]),
      ),
    );
  }
}
