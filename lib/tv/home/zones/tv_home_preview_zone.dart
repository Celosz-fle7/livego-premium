import 'package:flutter/widgets.dart';

/// HOME_PREVIEW physical zone.
///
/// Banner + source header + first grid row may be visible here, but the zone is
/// static: no scroll movement is used to transform it into the full grid.
/// DOWN from the preview row performs a hard switch into HOME_FULL_GRID.
class TvHomePreviewZone extends StatelessWidget {
  final Widget child;

  const TvHomePreviewZone({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => child;
}
