import 'package:flutter/material.dart';
import '../../data/livego_catalog.dart';
import '../../models/content_item.dart';
import '../../shared/widgets/poster_card.dart';
import 'mobile_player_screen.dart';

class MobileSearchScreen extends StatefulWidget {
  const MobileSearchScreen({super.key});

  @override
  State<MobileSearchScreen> createState() => _MobileSearchScreenState();
}

class _MobileSearchScreenState extends State<MobileSearchScreen> {
  String query = '';
  int platform = 0;
  bool loading = false;
  List<ContentItem> results = [];

  Future<void> _search(String value) async {
    query = value.trim();
    if (query.isEmpty) {
      setState(() => results = []);
      return;
    }
    setState(() => loading = true);
    final items = await LiveGoCatalog.search(
      query,
      platform: LiveGoCatalog.platforms[platform],
    );
    if (!mounted) return;
    setState(() {
      results = items;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
      children: [
        TextField(
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Cari drama, movie, anime...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: const Color(0xFF111827),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
          ),
          onSubmitted: _search,
          onChanged: (v) {
            if (v.trim().isEmpty) _search(v);
          },
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(LiveGoCatalog.platformLabels.length, (i) {
              final selected = platform == i;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: selected,
                  label: Text(LiveGoCatalog.platformLabels[i]),
                  onSelected: (_) {
                    setState(() => platform = i);
                    if (query.isNotEmpty) _search(query);
                  },
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 20),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else if (results.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: Text('Cari judul dari 6 platform default LiveGo', style: TextStyle(color: Colors.white54))),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: results.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 265,
              crossAxisSpacing: 14,
              mainAxisSpacing: 18,
            ),
            itemBuilder: (_, i) {
              final ContentItem item = results[i];
              return PosterCard(item: item, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MobilePlayerScreen(item: item))));
            },
          ),
      ],
    );
  }
}
