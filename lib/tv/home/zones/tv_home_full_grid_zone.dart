import 'package:flutter/widgets.dart';

/// HOME_FULL_GRID physical zone.
///
/// This zone owns vertical grid movement. Banner, Platform, and Kategori are not
/// rendered here, so grid scrolling never fights against the tall top layout.
class TvHomeFullGridZone extends StatelessWidget {
  final Widget child;

  const TvHomeFullGridZone({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => child;
}
