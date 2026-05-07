import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/feed_bloc.dart';
import '../bloc/feed_event.dart';
import '../bloc/feed_state.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    final threshold = maxScroll - 200;

    if (currentScroll >= threshold) {
      final state = context.read<FeedBloc>().state;
      if (state is FeedLoaded && state.hasMore && state is! FeedLoadingMore) {
        context.read<FeedBloc>().add(const FeedLoadMoreRequested());
      }
    }
  }

  Future<void> _onRefresh() async {
    final bloc = context.read<FeedBloc>();
    bloc.add(const FeedRefreshRequested());
    await bloc.stream.firstWhere((s) => s is FeedLoaded || s is FeedError);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface.withOpacity(0.03),
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Feed',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.person_outline, color: colorScheme.onSurface),
            onPressed: () => Navigator.of(context).pushNamed('/profile'),
          ),
        ],
      ),
      body: BlocBuilder<FeedBloc, FeedState>(
        builder: (context, state) {
          if (state is FeedLoading) {
            return Center(
              child: CircularProgressIndicator(color: colorScheme.primary),
            );
          }

          if (state is FeedError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: colorScheme.error,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      state.message,
                      style: TextStyle(
                        fontSize: 15,
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: () {
                        context.read<FeedBloc>().add(const FeedRefreshRequested());
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        foregroundColor: colorScheme.onSurface,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is FeedLoaded || state is FeedLoadingMore) {
            final List<dynamic> posts;
            final bool hasMore;

            if (state is FeedLoaded) {
              posts = state.posts;
              hasMore = state.hasMore;
            } else {
              final moreState = state as FeedLoadingMore;
              posts = moreState.posts;
              hasMore = moreState.hasMore;
            }

            if (posts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 64,
                      color: colorScheme.onSurface.withOpacity(0.2),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Sin contenido',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No hay posts en tu feed',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: _onRefresh,
              color: colorScheme.primary,
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
                itemCount: posts.length + (hasMore ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  if (index == posts.length) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    );
                  }

                  final post = posts[index];
                  return RedditPostCard(
                    title: post.title,
                    hasAccess: post.hasAccess,
                    communityId: post.communityId,
                    createdAt: post.createdAt,
                    cid: post.cid,
                  );
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class RedditPostCard extends StatefulWidget {
  const RedditPostCard({
    super.key,
    required this.title,
    required this.hasAccess,
    required this.communityId,
    required this.createdAt,
    required this.cid,
  });

  final String? title;
  final bool hasAccess;
  final String communityId;
  final DateTime createdAt;
  final String cid;

  @override
  State<RedditPostCard> createState() => _RedditPostCardState();
}

class _RedditPostCardState extends State<RedditPostCard> {
  int _voteState = 0;
  int _score = 0;

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '${years}y';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  String _truncateAddress(String address) {
    if (address.length <= 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: Colors.transparent,
            width: 0,
          ),
          right: BorderSide(
            color: isDark ? const Color(0xFF343536) : const Color(0xFFEDEFF1),
            width: 1,
          ),
          bottom: BorderSide(
            color: isDark ? const Color(0xFF343536) : const Color(0xFFEDEFF1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVoteColumn(colorScheme),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPostHeader(colorScheme, isDark),
                _buildTitle(colorScheme),
                if (!widget.hasAccess) _buildLockedOverlay(colorScheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoteColumn(ColorScheme colorScheme) {
    return Container(
      width: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1B)
            : const Color(0xFFF6F7F8),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          bottomLeft: Radius.circular(8),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _buildVoteButton(
            Icons.arrow_upward_rounded,
            _voteState == 1 ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.5),
            () => setState(() => _voteState = _voteState == 1 ? 0 : 1),
          ),
          const SizedBox(height: 2),
          Text(
            '${(_score + (_voteState == 1 ? 1 : 0) - (_voteState == -1 ? 1 : 0))}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _voteState == 1
                  ? colorScheme.primary
                  : _voteState == -1
                      ? const Color(0xFFFF4500)
                      : colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 2),
          _buildVoteButton(
            Icons.arrow_downward_rounded,
            _voteState == -1 ? const Color(0xFFFF4500) : colorScheme.onSurface.withOpacity(0.5),
            () => setState(() => _voteState = _voteState == -1 ? 0 : -1),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildVoteButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }

  Widget _buildPostHeader(ColorScheme colorScheme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primary.withOpacity(0.8),
                  colorScheme.secondary.withOpacity(0.8),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                'S',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Synergy',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1A1A1B),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '·',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            _truncateAddress(widget.communityId),
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '·',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            _formatTimeAgo(widget.createdAt),
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle(ColorScheme colorScheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title ?? 'Sin título',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.3,
              color: isDark ? Colors.white : const Color(0xFF1A1A1B),
            ),
          ),
          const SizedBox(height: 8),
          _buildActionBar(colorScheme),
        ],
      ),
    );
  }

  Widget _buildActionBar(ColorScheme colorScheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        _ActionButton(
          icon: Icons.chat_bubble_outline_rounded,
          label: 'Comment',
          color: colorScheme.onSurface.withOpacity(0.5),
          onTap: () {},
        ),
        const SizedBox(width: 4),
        _ActionButton(
          icon: Icons.share_outlined,
          label: 'Share',
          color: colorScheme.onSurface.withOpacity(0.5),
          onTap: () {},
        ),
        const SizedBox(width: 4),
        _ActionButton(
          icon: Icons.bookmark_border_rounded,
          label: 'Save',
          color: colorScheme.onSurface.withOpacity(0.5),
          onTap: () {},
        ),
        if (!widget.hasAccess) ...[
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 14,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Encrypted',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLockedOverlay(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.lock_rounded,
            size: 32,
            color: colorScheme.primary.withOpacity(0.6),
          ),
          const SizedBox(height: 8),
          Text(
            'Contenido encriptado',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Desbloquea para ver el contenido completo',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
