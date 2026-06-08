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
import '../player/tv_player_entry.dart';
import '../../services/analytics/livego_analytics.dart';
import '../widgets/tv_professional_loading.dart';
import 'tv_content_detail_config.dart';

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
  final FocusNode _retryNode = FocusNode(skipTraversal: true, debugLabel: 'tv-detail-retry');
  final List<FocusNode> _episodeNodes = <FocusNode>[];
  int _buttonIndex = 0;
  int _episodeCursor = 0;
  int _playerReturnTicket = 0;
  bool _openingPlayer = false;
  bool _favoriteBusy = false;

  @override
  void initState() {
    super.initState();
    LiveGoAnalytics.contentOpen(widget.item.platformSlug, widget.item.id, widget.item.title);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) tvFocus(_playNode, alignment: TvContentDetailConfig.playFocusAlignment, throttle: false);
    });
  }

  @override
  void dispose() {
    _backNode.dispose();
    _playNode.dispose();
    _favoriteNode.dispose();
    _retryNode.dispose();
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
    final fallbackEpisode = LiveGoLocalStore.continueEpisode(item);
    final itemChapter = int.tryParse(item.chapterId) ?? fallbackEpisode;
    final chapter = episode?.id.trim().isNotEmpty == true ? episode!.id.trim() : '${episode?.index ?? itemChapter}';
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

  Future<void> _openPlayer(ContentItem detail, {LiveGoEpisode? episode}) async {
    if (_openingPlayer || !mounted) return;
    _openingPlayer = true;
    final episodeNumber = episode?.index ?? (int.tryParse(detail.chapterId) ?? LiveGoLocalStore.continueEpisode(detail));
    LiveGoAnalytics.play(detail.platformSlug, detail.id, detail.title, episodeNumber);

    // Player upper route guard:
    // Give Shell one frame to paint its fullscreen black guard before the
    // Explorer 3 route is pushed. This keeps white/default frames above Player
    // from leaking during the Detail -> Player handoff.
    widget.onPlayerRouteOpen?.call();

    try {
      await Future<void>.delayed(TvContentDetailConfig.playerHandoffDelay);
      if (!mounted) return;

      final playerItem = _episodeItem(detail, episode);
      await TvPlayerEntry.open(
        context,
        item: playerItem,
        episode: episodeNumber,
      );
    } finally {
      widget.onPlayerRouteClosed?.call();
      _openingPlayer = false;
      if (mounted) _schedulePlayerReturnFocus(preferEpisode: episode != null);
    }
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

  void _retryDetail() {
    ref.invalidate(tvDetailProvider(widget.item));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) tvFocus(_playNode, alignment: TvContentDetailConfig.playFocusAlignment, throttle: false);
    });
  }

  bool _focusPlayerReturnTarget({required bool preferEpisode}) {
    if (preferEpisode && _episodeNodes.isNotEmpty) {
      final target = _episodeCursor.clamp(0, _episodeNodes.length - 1).toInt();
      if (tvFocusComfort(_episodeNodes[target], throttle: false)) return true;
    }
    if (tvFocus(_playNode, alignment: TvContentDetailConfig.playFocusAlignment, throttle: false)) return true;
    if (_episodeNodes.isNotEmpty) {
      final target = _episodeCursor.clamp(0, _episodeNodes.length - 1).toInt();
      if (tvFocusComfort(_episodeNodes[target], throttle: false)) return true;
    }
    return tvFocus(_backNode, alignment: TvContentDetailConfig.backFocusAlignment, throttle: false);
  }

  void _schedulePlayerReturnFocus({required bool preferEpisode, int attempt = 0}) {
    if (!mounted || attempt > TvContentDetailConfig.maxPlayerReturnAttempts) return;
    final token = ++_playerReturnTicket;
    final delay = attempt == 0
        ? TvContentDetailConfig.playerReturnRetryDelays[0]
        : attempt == 1
            ? TvContentDetailConfig.playerReturnRetryDelays[1]
            : attempt == 2
                ? TvContentDetailConfig.playerReturnRetryDelays[2]
                : TvContentDetailConfig.playerReturnRetryDelays[3];

    Future<void>.delayed(delay, () {
      if (!mounted || token != _playerReturnTicket) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || token != _playerReturnTicket) return;
        final ok = _focusPlayerReturnTarget(preferEpisode: preferEpisode);
        if (!ok && attempt < TvContentDetailConfig.maxPlayerReturnAttempts) {
          _schedulePlayerReturnFocus(preferEpisode: preferEpisode, attempt: attempt + 1);
        }
      });
    });
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
      tvFocus(_playNode, alignment: TvContentDetailConfig.playFocusAlignment);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _buttonKey(ContentItem detail, bool favorite, bool canRetry, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;
    if (_isBack(key)) {
      _pop();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (_buttonIndex == 0) {
        tvFocus(_backNode, alignment: TvContentDetailConfig.backFocusAlignment);
      } else if (_buttonIndex == 2) {
        _buttonIndex = 1;
        tvFocus(_favoriteNode, alignment: TvContentDetailConfig.playFocusAlignment);
      } else {
        _buttonIndex = 0;
        tvFocus(_playNode, alignment: TvContentDetailConfig.playFocusAlignment);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (_buttonIndex == 0) {
        _buttonIndex = 1;
        tvFocus(_favoriteNode, alignment: TvContentDetailConfig.playFocusAlignment);
      } else if (canRetry) {
        _buttonIndex = 2;
        tvFocus(_retryNode, alignment: TvContentDetailConfig.playFocusAlignment);
      }
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
      } else if (_buttonIndex == 2 && canRetry) {
        _retryDetail();
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
      tvFocus(_playNode, alignment: TvContentDetailConfig.playFocusAlignment, throttle: false);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (index == 0) {
        tvFocus(_backNode, alignment: TvContentDetailConfig.backFocusAlignment);
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
      tvFocus(_playNode, alignment: TvContentDetailConfig.playFocusAlignment);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      final next = index + TvContentDetailConfig.episodeGridStep;
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
          error: (error, __) {
            LiveGoAnalytics.error('detail', error);
            _syncEpisodes(0);
            return _DetailBody(
              scroll: _scroll,
              item: widget.item,
              episodes: const <LiveGoEpisode>[],
              backNode: _backNode,
              playNode: _playNode,
              favoriteNode: _favoriteNode,
              retryNode: _retryNode,
              degraded: true,
              episodeNodes: _episodeNodes,
              onBackKey: _backButtonKey,
              onButtonKey: (event) => _buttonKey(widget.item, LiveGoLocalStore.isFavorite(widget.item), true, event),
              onEpisodeKey: (i, event) => _episodeKey(widget.item, const <LiveGoEpisode>[], i, event),
              onPlay: () => _openPlayer(widget.item),
              onToggleFavorite: () => unawaited(_toggleFavorite(widget.item)),
              onRetryDetail: _retryDetail,
            );
          },
          data: (data) {
            final detail = data.detail;
            final episodes = data.episodes.take(TvContentDetailConfig.maxEpisodeChips).toList(growable: false);
            _syncEpisodes(episodes.length);
            return _DetailBody(
              scroll: _scroll,
              item: detail,
              episodes: episodes,
              backNode: _backNode,
              playNode: _playNode,
              favoriteNode: _favoriteNode,
              retryNode: _retryNode,
              degraded: false,
              episodeNodes: _episodeNodes,
              onBackKey: _backButtonKey,
              onButtonKey: (event) => _buttonKey(detail, LiveGoLocalStore.isFavorite(detail), false, event),
              onEpisodeKey: (i, event) => _episodeKey(detail, episodes, i, event),
              onPlay: () => _openPlayer(detail),
              onToggleFavorite: () => unawaited(_toggleFavorite(detail)),
              onRetryDetail: _retryDetail,
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
        const TvDetailSkeleton(),
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
  final FocusNode retryNode;
  final bool degraded;
  final List<FocusNode> episodeNodes;
  final FocusOnKeyEventCallback onBackKey;
  final KeyEventResult Function(KeyEvent event) onButtonKey;
  final KeyEventResult Function(int index, KeyEvent event) onEpisodeKey;
  final VoidCallback onPlay;
  final VoidCallback onToggleFavorite;
  final VoidCallback onRetryDetail;

  const _DetailBody({
    required this.scroll,
    required this.item,
    required this.episodes,
    required this.backNode,
    required this.playNode,
    required this.favoriteNode,
    required this.retryNode,
    required this.degraded,
    required this.episodeNodes,
    required this.onBackKey,
    required this.onButtonKey,
    required this.onEpisodeKey,
    required this.onPlay,
    required this.onToggleFavorite,
    required this.onRetryDetail,
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
            padding: const EdgeInsets.fromLTRB(TvContentDetailConfig.horizontalPadding, TvContentDetailConfig.topPadding, TvContentDetailConfig.horizontalPadding, TvContentDetailConfig.bottomPadding),
            children: [
              Row(
                children: [
                  Focus(
                    focusNode: backNode,
                    skipTraversal: true,
                    onKeyEvent: onBackKey,
                    child: _RoundIconButton(node: backNode, icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).maybePop()),
                  ),
                  const SizedBox(width: TvContentDetailConfig.actionButtonGap),
                  Text(TvContentDetailConfig.pageLabel, style: TextStyle(color: AppTheme.textSoft.withOpacity(0.85), fontSize: 12.2, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                ],
              ),
              const SizedBox(height: TvContentDetailConfig.headerToContentGap),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: TvContentDetailConfig.posterWidth,
                    height: TvContentDetailConfig.posterHeight,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.surface2.withOpacity(0.72),
                      borderRadius: BorderRadius.circular(TvContentDetailConfig.posterRadius),
                      border: Border.all(color: AppTheme.borderSoft.withOpacity(0.76)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(TvContentDetailConfig.posterRadius - 4),
                      child: LiveGoCachedImage(url: item.posterUrl, fit: BoxFit.cover, role: LiveGoImageRole.poster, tv: true),
                    ),
                  ),
                  const SizedBox(width: TvContentDetailConfig.posterToInfoGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: TvContentDetailConfig.titleFontSize, fontWeight: FontWeight.w900, decoration: TextDecoration.none, height: 1.02)),
                        const SizedBox(height: TvContentDetailConfig.titleToPillGap),
                        Wrap(
                          spacing: TvContentDetailConfig.episodeChipSpacing,
                          runSpacing: 8,
                          children: [
                            _InfoPill(Icons.apps_rounded, item.platformSlug),
                            _InfoPill(Icons.local_offer_rounded, item.category.isEmpty ? 'Drama' : item.category),
                            _InfoPill(Icons.video_library_rounded, '${item.episodes <= 0 ? 1 : item.episodes} Episode'),
                            _InfoPill(Icons.star_rounded, item.rating.toStringAsFixed(1)),
                          ],
                        ),
                        if (degraded) ...[
                          const SizedBox(height: TvContentDetailConfig.degradedNoticeGap),
                          const _DetailDegradedNotice(),
                        ],
                        const SizedBox(height: TvContentDetailConfig.descriptionGap),
                        Text(
                          item.description.trim().isEmpty ? TvContentDetailConfig.emptyDescription : item.description.trim(),
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppTheme.textSoft, fontSize: 14.4, fontWeight: FontWeight.w700, height: 1.40, decoration: TextDecoration.none),
                        ),
                        const SizedBox(height: TvContentDetailConfig.actionGap),
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
                            const SizedBox(width: TvContentDetailConfig.actionButtonGap),
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
              const SizedBox(height: TvContentDetailConfig.episodeSectionGap),
              if (episodes.isNotEmpty) ...[
                Row(
                  children: [
                    const Text('Episode', style: TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                    const SizedBox(width: TvContentDetailConfig.episodeTitleGap),
                    Text('${episodes.length} tersedia', style: TextStyle(color: AppTheme.textSoft.withOpacity(0.72), fontSize: 11.4, fontWeight: FontWeight.w800, decoration: TextDecoration.none)),
                  ],
                ),
                const SizedBox(height: TvContentDetailConfig.titleToPillGap),
                Wrap(
                  spacing: TvContentDetailConfig.episodeChipSpacing,
                  runSpacing: TvContentDetailConfig.episodeChipRunSpacing,
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

class _DetailDegradedNotice extends StatelessWidget {
  const _DetailDegradedNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(TvContentDetailConfig.backButtonRadius),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.32)),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: Colors.orangeAccent, size: 19),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              TvContentDetailConfig.degradedText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailEpisodeFallbackHint extends StatelessWidget {
  const _DetailEpisodeFallbackHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.72),
        borderRadius: BorderRadius.circular(TvContentDetailConfig.episodeChipRadius),
        border: Border.all(color: AppTheme.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppTheme.cyan, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              TvContentDetailConfig.episodeFallbackText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textSoft,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
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
          borderRadius: BorderRadius.circular(TvContentDetailConfig.backButtonRadius),
          child: AnimatedContainer(
            duration: TvFocusStyle.fast,
            width: TvContentDetailConfig.backButtonSize,
            height: TvContentDetailConfig.backButtonSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: focused ? AppTheme.surface3 : AppTheme.surface.withOpacity(0.92),
              borderRadius: BorderRadius.circular(TvContentDetailConfig.backButtonRadius),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.surface2.withOpacity(0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.cyan.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.cyan.withOpacity(0.92), size: 14),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11.4, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
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
              height: TvContentDetailConfig.actionButtonHeight,
              constraints: const BoxConstraints(minWidth: TvContentDetailConfig.actionButtonMinWidth),
              padding: const EdgeInsets.symmetric(horizontal: TvContentDetailConfig.actionButtonHorizontalPadding),
              decoration: BoxDecoration(
                gradient: primary ? AppTheme.activeGradient : null,
                color: primary ? null : AppTheme.surface2.withOpacity(0.88),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: focused ? AppTheme.whiteGlow : (primary ? Colors.white24 : AppTheme.borderSoft.withOpacity(0.76)), width: focused ? 2.2 : 1),
                boxShadow: focused ? [TvFocusStyle.glow(0.12, 9)] : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 22),
                  const SizedBox(width: 7),
                  Text(label, style: const TextStyle(color: Colors.white, fontSize: 14.2, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
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
            borderRadius: BorderRadius.circular(TvContentDetailConfig.episodeChipRadius),
            child: AnimatedContainer(
              duration: TvFocusStyle.fast,
              width: TvContentDetailConfig.episodeChipWidth,
              height: TvContentDetailConfig.episodeChipHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: focused ? AppTheme.surface3.withOpacity(0.98) : AppTheme.surface.withOpacity(0.78),
                borderRadius: BorderRadius.circular(TvContentDetailConfig.episodeChipRadius),
                border: Border.all(color: focused ? AppTheme.whiteGlow : AppTheme.borderSoft.withOpacity(0.72), width: focused ? 2.2 : 1),
              ),
              child: Text('Episode ${episode.index}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12.2, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
            ),
          ),
        );
      },
    );
  }
}
