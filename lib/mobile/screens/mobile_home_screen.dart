import 'package:flutter/material.dart';
import '../../models/content_item.dart';
import '../home/mobile_home_controller.dart';
import '../home/mobile_home_state.dart';
import '../home/widgets/mobile_hero_carousel.dart';
import '../home/widgets/mobile_home_selectors.dart';
import '../home/widgets/mobile_home_grid.dart';
import '../mobile_player_entry.dart';

class MobileHomeScreen extends StatefulWidget {
  final ValueChanged<int> onTab;
  const MobileHomeScreen({super.key, required this.onTab});

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> {
  final MobileHomeController _controller = MobileHomeController();

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _open(ContentItem item) async {
    await MobilePlayerEntry.open(context, item: item);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MobileHomeState>(
      valueListenable: _controller.state,
      builder: (context, state, _) {
        return RefreshIndicator(
          onRefresh: () => _controller.load(silent: true),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 110),
            children: [
              MobileHeroCarousel(
                items: state.banners,
                loading: state.loading,
                onTap: _open,
              ),
              const SizedBox(height: 12),
              MobileHomeSelectors(
                platforms: state.platformLabels,
                selectedPlatform: state.selectedPlatformIndex,
                onPlatformSelected: _controller.selectPlatform,
                categories: state.categories,
                selectedCategory: state.selectedCategoryIndex,
                onCategorySelected: _controller.selectCategory,
              ),
              const SizedBox(height: 16),
              MobileHomeGrid(
                items: state.items,
                loading: state.loading,
                errorMessage: state.errorMessage,
                onTap: _open,
              ),
            ],
          ),
        );
      },
    );
  }
}
