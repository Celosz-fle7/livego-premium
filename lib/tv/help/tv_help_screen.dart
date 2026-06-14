import 'package:flutter/material.dart';
import '../screens/tv_placeholder_screen.dart';

class TvHelpScreen extends StatelessWidget {
  const TvHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TvPlaceholderScreen(
      title: 'Bantuan TV',
      icon: Icons.help_outline_rounded,
    );
  }
}
