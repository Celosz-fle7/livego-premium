import 'package:flutter/material.dart';
import '../../data/livego_catalog.dart';
import '../../models/content_item.dart';
import '../../shared/widgets/hero_banner.dart';

class MobilePlayerScreen extends StatefulWidget {
  final ContentItem item;
  const MobilePlayerScreen({super.key, required this.item});

  @override
  State<MobilePlayerScreen> createState() => _MobilePlayerScreenState();
}

class _MobilePlayerScreenState extends State<MobilePlayerScreen> {
  late Future<_PlayerState> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PlayerState> _load() async {
    final detail = await LiveGoCatalog.detail(widget.item);
    final url = await LiveGoCatalog.videoUrl(detail);
    return _PlayerState(item: detail, streamUrl: url);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PlayerState>(
      future: _future,
      builder: (context, snap) {
        final state = snap.data;
        final item = state?.item ?? widget.item;
        final streamUrl = state?.streamUrl ?? '';
        final loading = snap.connectionState != ConnectionState.done;

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black, title: Text(item.title)),
          body: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    image: DecorationImage(image: NetworkImage(item.backdropUrl.isEmpty ? item.posterUrl : item.backdropUrl), fit: BoxFit.cover),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: Colors.black.withOpacity(0.48),
                    ),
                    child: Center(
                      child: loading
                          ? const CircularProgressIndicator()
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 96),
                                const SizedBox(height: 10),
                                Text(
                                  streamUrl.isEmpty ? 'Stream belum tersedia' : 'Stream siap diputar',
                                  style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              HeroBanner(item: item),
              const SizedBox(height: 18),
              Text(item.description, style: const TextStyle(color: Colors.white70, height: 1.45)),
              const SizedBox(height: 18),
              _InfoRow(label: 'Platform', value: item.source),
              _InfoRow(label: 'Episode', value: '${item.episodes}'),
              _InfoRow(label: 'Stream', value: streamUrl.isEmpty ? 'No URL' : streamUrl),
            ],
          ),
        );
      },
    );
  }
}

class _PlayerState {
  final ContentItem item;
  final String streamUrl;
  const _PlayerState({required this.item, required this.streamUrl});
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(color: Colors.white38))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white70))),
        ],
      ),
    );
  }
}
