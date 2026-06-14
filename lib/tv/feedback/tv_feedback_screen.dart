import 'package:flutter/material.dart';
import '../screens/tv_placeholder_screen.dart';

class TvFeedbackScreen extends StatelessWidget {
  const TvFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TvPlaceholderScreen(
      title: 'Kirim Feedback',
      icon: Icons.feedback_rounded,
    );
  }
}
