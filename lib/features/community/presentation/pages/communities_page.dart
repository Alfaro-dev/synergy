import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/community.dart';
import '../bloc/community_bloc.dart';
import '../bloc/community_event.dart';
import '../bloc/community_state.dart';

class CommunitiesPage extends StatelessWidget {
  const CommunitiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comunidades'),
      ),
      body: BlocBuilder<CommunityBloc, CommunityState>(
        builder: (context, state) {
          if (state is CommunityLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is CommunityError) {
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
                      context.read<CommunityBloc>().add(const CommunityRefreshRequested());
                    },
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          if (state is CommunityLoaded) {
            if (state.communities.isEmpty) {
              return const Center(
                child: Text('No hay comunidades disponibles'),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<CommunityBloc>().add(const CommunityRefreshRequested());
              },
              child: ListView.builder(
                itemCount: state.communities.length,
                itemBuilder: (context, index) {
                  final community = state.communities[index];
                  return _CommunityTile(community: community);
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

class _CommunityTile extends StatelessWidget {
  const _CommunityTile({required this.community});

  final Community community;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: community.avatarCid != null
              ? const Icon(Icons.image)
              : Text(
                  community.name[0].toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
        ),
        title: Text(community.name),
        subtitle: community.bio != null
            ? Text(
                community.bio!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: community.isPublic
            ? const Icon(Icons.public, color: Colors.green)
            : const Icon(Icons.lock, color: Colors.grey),
        onTap: () {
          // TODO: Navigate to community detail
        },
      ),
    );
  }
}