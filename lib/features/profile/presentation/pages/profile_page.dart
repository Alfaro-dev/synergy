import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/profile_bloc.dart';
import '../bloc/profile_event.dart';
import '../bloc/profile_state.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
          ),
        ],
      ),
      body: BlocBuilder<ProfileBloc, ProfileState>(
        builder: (context, state) {
          if (state is ProfileLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ProfileError) {
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
                      context.read<ProfileBloc>().add(const ProfileFetchRequested());
                    },
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          if (state is ProfileNotFound) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.person_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Aún no tenés perfil',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text('Creá tu perfil para identificarte en las comunidades'),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      // TODO: Navigate to create profile
                    },
                    child: const Text('Crear Perfil'),
                  ),
                ],
              ),
            );
          }

          if (state is ProfileLoaded || state is ProfileUpdating) {
            final profile = state is ProfileLoaded
                ? state.profile
                : (state as ProfileUpdating).profile;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 64,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: profile.avatarCid != null
                        ? const Icon(Icons.person, size: 64)
                        : Text(
                            profile.pseudonym[0].toUpperCase(),
                            style: Theme.of(context).textTheme.displayMedium,
                          ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    profile.pseudonym,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (profile.bio != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      profile.bio!,
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 32),
                  if (state is ProfileUpdating)
                    const LinearProgressIndicator()
                  else
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              // TODO: Edit profile
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text('Editar'),
                          ),
                          const SizedBox(width: 16),
                          OutlinedButton.icon(
                            onPressed: () {
                              // TODO: Upload avatar
                            },
                            icon: const Icon(Icons.photo_camera),
                            label: const Text('Cambiar Avatar'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}