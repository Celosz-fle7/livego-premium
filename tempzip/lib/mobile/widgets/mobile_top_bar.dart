import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

class MobileTopBar extends StatelessWidget {
  final VoidCallback onHistory;
  final VoidCallback onFavorite;
  final VoidCallback onSearch;

  const MobileTopBar({super.key, required this.onHistory, required this.onFavorite, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF24344A)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'LiveGO',
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
            ),
          ),
          _IconBubble(icon: Icons.history, onTap: onHistory),
          const SizedBox(width: 10),
          _IconBubble(icon: Icons.favorite_border, onTap: onFavorite),
          const SizedBox(width: 10),
          _IconBubble(icon: Icons.search, onTap: onSearch),
        ],
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBubble({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: const Color(0xFF0D1422),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF26364B)),
        ),
        child: Icon(icon, color: Colors.white, size: 25),
      ),
    );
  }
}
