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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.of(context).pushNamed('/profile'),
          ),
        ],
      ),
      body: BlocBuilder<FeedBloc, FeedState>(
        builder: (context, state) {
          if (state is FeedLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is FeedError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Error: ${state.message}',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      context.read<FeedBloc>().add(const FeedRefreshRequested());
                    },
                    child: const Text('Reintentar'),
                  ),
                ],
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
              return const Center(
                child: Text('No hay posts aún'),
              );
            }

            return RefreshIndicator(
              onRefresh: _onRefresh,
              child: ListView.builder(
                controller: _scrollController,
                itemCount: posts.length + (hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == posts.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final post = posts[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(post.communityName[0].toUpperCase()),
                    ),
                    title: Text(post.communityName),
                    subtitle: Text(
                      post.author,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: post.hasAccess
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.lock, color: Colors.grey),
                    onTap: () {
                      // TODO: Navigate to post detail
                    },
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