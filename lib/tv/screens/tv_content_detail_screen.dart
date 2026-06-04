import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/livego_local_store.dart';
import '../../data/livego_catalog.dart';
import '../../models/content_item.dart';
import '../../models/livego_episode.dart';
import '../../services/image/image_quality_config.dart';
import '../../shared/widgets/livego_cached_image.dart';
import '../focus/tv_focus_utils.dart';
import '../focus/tv_reachability.dart';
import '../providers/tv_detail_provider.dart';
import '../theme/tv_focus_style.dart';
import 'tv_player_screen.dart';

class TvContentDetailScreen extends ConsumerStatefulWidget {
  final ContentItem item;
  final VoidCallback? onPlayerRouteOpen;
  final VoidCallback? onPlayerRouteClosed;

  const TvContentDetailScreen({
    super.key,
    required this.item,
    this.onPlayerRouteOpen,
    this.onPlayerRouteClosed,
  });

  @override
  ConsumerState<TvContentDetailScreen> createState() => _TvContentDetailScreenState();
}

class _TvContentDetailScreenState extends ConsumerState<TvContentDetailScreen> {
  final ScrollController _scroll = ScrollController();
  final FocusNode _backNode = FocusNode(skipTraversal: true, debugLabel: 'tv-detail-back');
  final FocusNode _playNode = FocusNode(skipTraversal: true, debugLabel: 'tv-detail-play');
  final FocusNode _favoriteNode = FocusNode(skipTraversal: true, debugLabel: 'tv-detail-favorite');
  final List<FocusNode> _episodeNodes = <FocusNode>[];
  int _buttonIndex = 0;
  int _episodeCursor = 0;
  bool _openingPlayer = false;
  bool _favoriteBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) tvFocus(_playNode, alignment: 0.18, throttle: false);
    });
  }

  @override
  void dispose() {
    _backNode.dispose();
    _playNode.dispose();
    _favoriteNode.dispose();
    for (final node in _episodeNodes) {
      node.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  void _syncEpisodes(int count) {
    while (_episodeNodes.length < count) {
      _episodeNodes.add(FocusNode(skipTraversal: true, debugLabel: 'tv-detail-episode-${_episodeNodes.length}'));
    }
    while (_episodeNodes.length > count) {
      _episodeNodes.removeLast().dispose();
    }
  }

  bool _isBack(LogicalKeyboardKey key) => tvIsBackKey(key);
  bool _isSelect(LogicalKeyboardKey key) => tvIsSelectKey(key);

  ContentItem _episodeItem(ContentItem item, LiveGoEpisode? episode) {
    final chapter = episode?.id.trim().isNotEmpty == true ? episode!.id.trim() : '${episode?.index ?? 1}';
    return ContentItem(
      id: item.id,
      title: item.title,
      source: item.source,
      category: item.category,
      description: item.description,
      posterUrl: item.posterUrl,
      backdropUrl: item.backdropUrl,
      rating: item.rating,
      episodes: item.episodes <= 0 ? 1 : item.episodes,
      updated: item.updated,
      platformSlug: item.platformSlug,
      chapterId: chapter,
      lang: item.lang,
    );
  }

  void _openPlayer(ContentItem detail, {LiveGoEpisode? episode}) {
    if (_openingPlayer || !mounted) return;
    _openingPlayer = true;
    widget.onPlayerRouteOpen?.call();
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => TvPlayerScreen(item: _episodeItem(detail, episode))))
        .whenComplete(() {
      _openingPlayer = false;
      widget.onPlayerRouteClosed?.call();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (episode != null && _episodeNodes.isNotEmpty) {
          tvFocusComfort(_episodeNodes[_episodeCursor.clamp(0, _episodeNodes.length - 1).toInt()], throttle: false);
        } else {
          tvFocus(_playNode, alignment: 0.18, throttle: false);
        }
      });
    });
  }

  Future<void> _toggleFavorite(ContentItem item) async {
    if (_favoriteBusy) return;
    _favoriteBusy = true;
    await LiveGoLocalStore.toggleFavorite(item);
    _favoriteBusy = false;
    if (mounted) setState(() {});
  }

  void _pop() {
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  KeyEventResult _backButtonKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;
    if (_isBack(key) || _isSelect(key) || key == LogicalKeyboardKey.arrowLeft) {
      _pop();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.arrowDown) {
      tvFocus(_playNode, alignment: 0.18);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _buttonKey(ContentItem detail, bool favorite, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;
    if (_isBack(key)) {
      _pop();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (_buttonIndex == 0) {
        tvFocus(_backNode, alignment: 0.06);
      } else {
        _buttonIndex = 0;
        tvFocus(_playNode, alignment: 0.18);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _buttonIndex = 1;
      tvFocus(_favoriteNode, alignment: 0.18);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_episodeNodes.isNotEmpty) {
        tvFocusComfort(_episodeNodes[_episodeCursor.clamp(0, _episodeNodes.length - 1).toInt()]);
      }
      return KeyEventResult.handled;
    }
    if (_isSelect(key)) {
      if (_buttonIndex == 0) {
        _openPlayer(detail);
      } else {
        unawaited(_toggleFavorite(detail));
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _episodeKey(ContentItem detail, List<LiveGoEpisode> episodes, int index, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;
    if (_isBack(key)) {
      tvFocus(_playNode, alignment: 0.18, throttle: false);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (index == 0) {
        tvFocus(_backNode, alignment: 0.06);
      } else {
        _episodeCursor = index - 1;
        tvFocusComfort(_episodeNodes[_episodeCursor]);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (index < _episodeNodes.length - 1) {
        _episodeCursor = index + 1;
        tvFocusComfort(_episodeNodes[_episodeCursor]);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      tvFocus(_playNode, alignment: 0.18);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      final next = index + 6;
      if (next < _episodeNodes.length) {
        _episodeCursor = next;
        tvFocusComfort(_episodeNodes[next]);
      }
      return KeyEventResult.handled;
    }
    if (_isSelect(key)) {
      _episodeCursor = index;
      _openPlayer(detail, episode: episodes[index]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(tvDetailProvider(widget.item));
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _pop();
      },
      child: Scaffold(
        backgroundColor: AppTheme.bgDeep,
        body: asyncData.when(
          loading: () => _DetailLoading(item: widget.item),
          error: (_, __) => _DetailBody(
            scroll: _scroll,
            item: widget.item,
            episodes: const <LiveGoEpisode>[],
            backNode: _backNode,
            playNode: _playNode,
            favoriteNode: _favoriteNode,
            episodeNodes: _episodeNodes,
            onBackKey: _backButtonKey,
            onButtonKey: (event) => _buttonKey(widget.item, LiveGoLocalStore.isFavorite(widget.item), event),
            onEpisodeKey: (i, event) => _episodeKey(widget.item, const <LiveGoEpisode>[], i, event),
            onPlay: () => _openPlayer(widget.item),
            onToggleFavorite: () => unawaited(_toggleFavorite(widget.item)),
          ),
          data: (data) {
            final detail = data.detail;
            final episodes = data.episodes.take(80).toList(growable: false);
            _syncEpisodes(episodes.length);
            return _DetailBody(
              scroll: _scroll,
              item: detail,
              episodes: episodes,
              backNode: _backNode,
              playNode: _playNode,
              favoriteNode: _favoriteNode,
              episodeNodes: _episodeNodes,
              onBackKey: _backButtonKey,
              onButtonKey: (event) => _buttonKey(detail, LiveGoLocalStore.isFavorite(detail), event),
              onEpisodeKey: (i, event) => _episodeKey(detail, episodes, i, event),
              onPlay: () => _openPlayer(detail),
              onToggleFavorite: () => unawaited(_toggleFavorite(detail)),
            );
          },
        ),
      ),
    );
  }
}

class _DetailLoading extends StatelessWidget {
  final ContentItem item;
  const _DetailLoading({required this.item});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (item.backdropUrl.isNotEmpty || item.posterUrl.isNotEmpty)
          LiveGoCachedImage(url: item.backdropUrl.isNotEmpty ? item.backdropUrl : item.posterUrl, fit: BoxFit.cover, role: LiveGoImageRole.banner, tv: true),
        Container(color: Colors.black.withOpacity(0.70)),
        const SafeArea(child: Center(child: CircularProgressIndicator(color: AppTheme.cyan))),
      ],
    );
  }
}

class _DetailBody extends StatelessWidget {
  final ScrollController scroll;
  final ContentItem item;
  final List<LiveGoEpisode> episodes;
  final FocusNode backNode;
  final FocusNode playNode;
  final FocusNode favoriteNode;
  final List<FocusNode> episodeNodes;
  final FocusOnKeyEventCallback onBackKey;
  final KeyEventResult Function(KeyEvent event) onButtonKey;
  final KeyEventResult Function(int index, KeyEvent event) onEpisodeKey;
  final VoidCallback onPlay;
  final VoidCallback onToggleFavorite;

  const _DetailBody({
    required this.scroll,
    required this.item,
    required this.episodes,
    required this.backNode,
    required this.playNode,
    required this.favoriteNode,
    required this.episodeNodes,
    required this.onBackKey,
    required this.onButtonKey,
    required this.onEpisodeKey,
    required this.onPlay,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final favorite = LiveGoLocalStore.isFavorite(item);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (item.backdropUrl.isNotEmpty || item.posterUrl.isNotEmpty)
          LiveGoCachedImage(url: item.backdropUrl.isNotEmpty ? item.backdropUrl : item.posterUrl, fit: BoxFit.cover, role: LiveGoImageRole.banner, tv: true),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xCC020617), Color(0xF2071326), Color(0xFF020617)],
            ),
          ),
        ),
        SafeArea(
          top: true,
          bottom: true,
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(46, 24, 46, TvReachability.contentBottomPadding),
            children: [
              Row(
                children: [
                  Focus(
                    focusNode: backNode,
                    skipTraversal: true,
                    onKeyEvent: onBackKey,
                    child: _RoundIconButton(node: backNode, icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).maybePop()),
                  ),
                  const SizedBox(width: 14),
                  Text('Detail Konten', style: TextStyle(color: AppTheme.textSoft.withOpacity(0.85), fontSize: 13, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: SizedBox(
                      width: 210,
                      height: 314,
                      child: LiveGoCachedImage(url: item.posterUrl, fit: BoxFit.cover, role: LiveGoImageRole.poster, tv: true),
                    ),
                  ),
                  const SizedBox(width: 28),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, decoration: TextDecoration.none, height: 1.05)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            _InfoPill(Icons.apps_rounded, item.platformSlug),
                            _InfoPill(Icons.local_offer_rounded, item.category.isEmpty ? 'Drama' : item.category),
                            _InfoPill(Icons.video_library_rounded, '${item.episodes <= 0 ? 1 : item.episodes} Episode'),
                            _InfoPill(Icons.star_rounded, item.rating.toStringAsFixed(1)),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          item.description.trim().isEmpty ? 'Deskripsi belum tersedia dari API.' : item.description.trim(),
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppTheme.textSoft, fontSize: 15.2, fontWeight: FontWeight.w700, height: 1.45, decoration: TextDecoration.none),
                        ),
                        const SizedBox(height: 26),
                        Row(
                          children: [
                            _DetailButton(
                              node: playNode,
                              primary: true,
                              icon: Icons.play_arrow_rounded,
                              label: 'Play',
                              onTap: onPlay,
                              onKey: (node, event) => onButtonKey(event),
                            ),
                            const SizedBox(width: 14),
                            _DetailButton(
                              node: favoriteNode,
                              primary: false,
                              icon: favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              label: favorite ? 'Di My List' : 'My List',
                              onTap: onToggleFavorite,
                              onKey: (node, event) => onButtonKey(event),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              if (episodes.isNotEmpty) ...[
                Row(
                  children: [
                    const Text('Episode', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                    const SizedBox(width: 10),
                    Text('${episodes.length} tersedia', style: TextStyle(color: AppTheme.textSoft.withOpacity(0.72), fontSize: 12, fontWeight: FontWeight.w800, decoration: TextDecoration.none)),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (var i = 0; i < episodes.length; i++)
                      _EpisodeChip(
                        node: episodeNodes[i],
                        episode: episodes[i],
                        onKey: (node, event) => onEpisodeKey(i, event),
                        onTap: () {},
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final FocusNode node;
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconButton({required this.node, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: node,
      builder: (context, _) {
        final focused = node.hasFocus;
        return InkWell(
          canRequestFocus: false,
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: TvFocusStyle.fast,
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: focused ? AppTheme.surface3 : AppTheme.surface.withOpacity(0.92),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: focused ? AppTheme.cyan : AppTheme.border, width: focused ? 2 : 1),
            ),
            child: Icon(icon, color: Colors.white, size: 25),
          ),
        );
      },
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoPill(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: AppTheme.surface.withOpacity(0.84), borderRadius: BorderRadius.circular(999), border: Border.all(color: AppTheme.cyan.withOpacity(0.20))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.cyan, size: 15),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
        ],
      ),
    );
  }
}

class _DetailButton extends StatelessWidget {
  final FocusNode node;
  final bool primary;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final FocusOnKeyEventCallback onKey;

  const _DetailButton({required this.node, required this.primary, required this.icon, required this.label, required this.onTap, required this.onKey});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: node,
      builder: (context, _) {
        final focused = node.hasFocus;
        return Focus(
          focusNode: node,
          skipTraversal: true,
          onKeyEvent: onKey,
          child: InkWell(
            canRequestFocus: false,
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: AnimatedContainer(
              duration: TvFocusStyle.fast,
              height: 54,
              constraints: const BoxConstraints(minWidth: 158),
              padding: const EdgeInsets.symmetric(horizontal: 22),
              decoration: BoxDecoration(
                gradient: primary ? AppTheme.activeGradient : null,
                color: primary ? null : AppTheme.surface.withOpacity(0.90),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: focused ? AppTheme.whiteGlow : (primary ? Colors.white24 : AppTheme.border), width: focused ? 2 : 1),
                boxShadow: focused ? [TvFocusStyle.glow(0.10, 8)] : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 24),
                  const SizedBox(width: 8),
                  Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EpisodeChip extends StatelessWidget {
  final FocusNode node;
  final LiveGoEpisode episode;
  final FocusOnKeyEventCallback onKey;
  final VoidCallback onTap;

  const _EpisodeChip({required this.node, required this.episode, required this.onKey, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: node,
      builder: (context, _) {
        final focused = node.hasFocus;
        return Focus(
          focusNode: node,
          skipTraversal: true,
          onKeyEvent: onKey,
          child: InkWell(
            canRequestFocus: false,
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: TvFocusStyle.fast,
              width: 132,
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: focused ? AppTheme.surface3 : AppTheme.surface.withOpacity(0.86),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: focused ? AppTheme.cyan : AppTheme.border, width: focused ? 2 : 1),
              ),
              child: Text('Episode ${episode.index}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
            ),
          ),
        );
      },
    );
  }
}
