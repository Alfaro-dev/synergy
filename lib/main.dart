import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/network/api_client.dart';
import 'core/network/secure_storage_service.dart';
import 'features/auth/data/datasources/auth_local_data_source.dart';
import 'features/auth/data/datasources/auth_remote_data_source.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/usecases/check_auth_status.dart';
import 'features/auth/domain/usecases/get_nonce.dart';
import 'features/auth/domain/usecases/get_saved_session.dart';
import 'features/auth/domain/usecases/logout.dart';
import 'features/auth/domain/usecases/verify_signature.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/pages/onboarding_page.dart';
import 'features/auth/presentation/pages/welcome_page.dart';
import 'features/community/data/datasources/community_remote_data_source.dart';
import 'features/community/data/repositories/community_repository_impl.dart';
import 'features/community/domain/repositories/community_repository.dart';
import 'features/community/presentation/bloc/community_bloc.dart';
import 'features/community/presentation/bloc/community_event.dart';
import 'features/community/presentation/bloc/community_state.dart';
import 'features/community/presentation/pages/communities_page.dart';
import 'features/content/data/datasources/content_remote_data_source.dart';
import 'features/content/data/repositories/content_repository_impl.dart';
import 'features/content/domain/repositories/content_repository.dart';
import 'features/content/presentation/bloc/feed_bloc.dart';
import 'features/content/presentation/bloc/feed_event.dart';
import 'features/content/presentation/bloc/feed_state.dart';
import 'features/content/presentation/pages/feed_page.dart';
import 'features/profile/data/datasources/profile_remote_data_source.dart';
import 'features/profile/data/repositories/profile_repository_impl.dart';
import 'features/profile/domain/repositories/profile_repository.dart';
import 'features/profile/presentation/bloc/profile_bloc.dart';
import 'features/profile/presentation/bloc/profile_event.dart';
import 'features/profile/presentation/bloc/profile_state.dart';
import 'features/profile/presentation/pages/profile_page.dart';
import 'features/payments/data/datasources/payments_remote_data_source.dart';
import 'features/payments/data/repositories/payments_repository_impl.dart';
import 'features/payments/domain/repositories/payments_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();

  final apiClient = ApiClient();
  final secureStorage = SecureStorageService();

  final authRepository = AuthRepositoryImpl(
    remoteDataSource: AuthRemoteDataSourceImpl(apiClient: apiClient),
    localDataSource: AuthLocalDataSourceImpl(secureStorage: secureStorage),
  );

  final communityRepository = CommunityRepositoryImpl(
    remoteDataSource: CommunityRemoteDataSourceImpl(
      apiClient: apiClient,
      secureStorage: secureStorage,
    ),
  );

  final contentRepository = ContentRepositoryImpl(
    remoteDataSource: ContentRemoteDataSourceImpl(
      apiClient: apiClient,
      secureStorage: secureStorage,
    ),
  );

  final profileRepository = ProfileRepositoryImpl(
    remoteDataSource: ProfileRemoteDataSourceImpl(
      apiClient: apiClient,
      secureStorage: secureStorage,
    ),
  );

  final paymentsRepository = PaymentsRepositoryImpl(
    remoteDataSource: PaymentsRemoteDataSourceImpl(
      apiClient: apiClient,
      secureStorage: secureStorage,
    ),
  );

  runApp(SynergyApp(
    authRepository: authRepository,
    communityRepository: communityRepository,
    contentRepository: contentRepository,
    profileRepository: profileRepository,
    paymentsRepository: paymentsRepository,
    secureStorage: secureStorage,
  ));
}

class SynergyApp extends StatelessWidget {
  const SynergyApp({
    super.key,
    required this.authRepository,
    required this.communityRepository,
    required this.contentRepository,
    required this.profileRepository,
    required this.paymentsRepository,
    required this.secureStorage,
  });

  final AuthRepositoryImpl authRepository;
  final CommunityRepositoryImpl communityRepository;
  final ContentRepositoryImpl contentRepository;
  final ProfileRepositoryImpl profileRepository;
  final PaymentsRepositoryImpl paymentsRepository;
  final SecureStorageService secureStorage;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepositoryImpl>.value(value: authRepository),
        RepositoryProvider<CommunityRepository>.value(value: communityRepository),
        RepositoryProvider<ContentRepository>.value(value: contentRepository),
        RepositoryProvider<ProfileRepository>.value(value: profileRepository),
        RepositoryProvider<PaymentsRepository>.value(value: paymentsRepository),
      ],
      child: BlocProvider<AuthBloc>(
        create: (context) => AuthBloc(
          getNonce: GetNonce(authRepository),
          verifySignature: VerifySignature(authRepository),
          checkAuthStatus: CheckAuthStatus(authRepository),
          logout: Logout(authRepository),
          getSavedSession: GetSavedSession(authRepository),
        ),
        child: MaterialApp(
          title: 'Synergy',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF8B5CF6),
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: Colors.black,
            useMaterial3: true,
            fontFamily: 'SF Pro Display',
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF8B5CF6),
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: Colors.black,
            useMaterial3: true,
            fontFamily: 'SF Pro Display',
          ),
          themeMode: ThemeMode.dark,
          initialRoute: '/',
          onGenerateRoute: _onGenerateRoute,
        ),
      ),
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(
          builder: (context) => WelcomePage(secureStorage: secureStorage),
        );
      case '/onboarding':
        return MaterialPageRoute(
          builder: (context) => const OnboardingPage(),
        );
      case '/home':
        return MaterialPageRoute(
          builder: (context) => const HomePage(),
        );
      case '/feed':
        return MaterialPageRoute(
          builder: (context) => BlocProvider<FeedBloc>(
            create: (context) => FeedBloc(
              repository: context.read<ContentRepository>(),
            )..add(const FeedFetchRequested()),
            child: const FeedPage(),
          ),
        );
      case '/communities':
        return MaterialPageRoute(
          builder: (context) => BlocProvider<CommunityBloc>(
            create: (context) => CommunityBloc(
              repository: context.read<CommunityRepository>(),
            )..add(const CommunityFetchRequested()),
            child: const CommunitiesPage(),
          ),
        );
      case '/profile':
        return MaterialPageRoute(
          builder: (context) => BlocProvider<ProfileBloc>(
            create: (context) => ProfileBloc(
              repository: context.read<ProfileRepository>(),
            )..add(const ProfileFetchRequested()),
            child: const ProfilePage(),
          ),
        );
      default:
        return MaterialPageRoute(
          builder: (context) => WelcomePage(secureStorage: secureStorage),
        );
    }
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    _FeedTab(),
    _CommunitiesTab(),
    _ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated) {
          Navigator.of(context).pushReplacementNamed('/');
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border(
              top: BorderSide(
                color: colorScheme.outline.withOpacity(0.1),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavBarItem(
                    icon: Icons.home_rounded,
                    label: 'Feed',
                    isSelected: _currentIndex == 0,
                    onTap: () => setState(() => _currentIndex = 0),
                  ),
                  _NavBarItem(
                    icon: Icons.groups_rounded,
                    label: 'Comunidades',
                    isSelected: _currentIndex == 1,
                    onTap: () => setState(() => _currentIndex = 1),
                  ),
                  _NavBarItem(
                    icon: Icons.person_rounded,
                    label: 'Perfil',
                    isSelected: _currentIndex == 2,
                    onTap: () => setState(() => _currentIndex = 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.4);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedTab extends StatelessWidget {
  const _FeedTab();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'SYNERGY',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 4,
            color: colorScheme.onSurface,
          ),
        ),
        centerTitle: false,
      ),
      body: BlocProvider<FeedBloc>(
        create: (context) => FeedBloc(
          repository: context.read<ContentRepository>(),
        )..add(const FeedFetchRequested()),
        child: const FeedPageContent(),
      ),
    );
  }
}

class _CommunitiesTab extends StatelessWidget {
  const _CommunitiesTab();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Comunidades',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        centerTitle: false,
      ),
      body: BlocProvider<CommunityBloc>(
        create: (context) => CommunityBloc(
          repository: context.read<CommunityRepository>(),
        )..add(const CommunityFetchRequested()),
        child: const CommunitiesPageContent(),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Perfil',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout_rounded, color: colorScheme.onSurface),
            onPressed: () {
              context.read<AuthBloc>().add(const AuthLogoutRequested());
            },
          ),
        ],
      ),
      body: BlocProvider<ProfileBloc>(
        create: (context) => ProfileBloc(
          repository: context.read<ProfileRepository>(),
        )..add(const ProfileFetchRequested()),
        child: const ProfilePageContent(),
      ),
    );
  }
}

class FeedPageContent extends StatelessWidget {
  const FeedPageContent({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FeedBloc, FeedState>(
      builder: (context, state) {
        if (state is FeedLoading) {
          return Center(
            child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
          );
        }

        if (state is FeedError) {
          return Center(
            child: Text(
              state.message,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
            ),
          );
        }

        if (state is FeedLoaded || state is FeedLoadingMore) {
          final posts = state is FeedLoaded ? state.posts : (state as FeedLoadingMore).posts;

          if (posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  Text('Sin contenido', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final post = posts[index];
              return _FeedPostCard(
                communityName: post.communityName,
                author: post.author,
                hasAccess: post.hasAccess,
              );
            },
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

class CommunitiesPageContent extends StatelessWidget {
  const CommunitiesPageContent({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CommunityBloc, CommunityState>(
      builder: (context, state) {
        if (state is CommunityLoading) {
          return Center(
            child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
          );
        }

        if (state is CommunityError) {
          return Center(
            child: Text(
              state.message,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
            ),
          );
        }

        if (state is CommunityLoaded) {
          if (state.communities.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.groups_outlined, size: 64, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  Text('No hay comunidades', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: state.communities.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final community = state.communities[index];
              return _CommunityCard(community: community);
            },
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

class ProfilePageContent extends StatelessWidget {
  const ProfilePageContent({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (context, state) {
        if (state is ProfileLoading) {
          return Center(
            child: CircularProgressIndicator(color: colorScheme.primary),
          );
        }

        if (state is ProfileNotFound) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_outline_rounded, size: 64, color: colorScheme.onSurface.withOpacity(0.2)),
                const SizedBox(height: 24),
                Text('Sin perfil', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                const SizedBox(height: 8),
                Text('Creá tu perfil', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5))),
              ],
            ),
          );
        }

        if (state is ProfileLoaded) {
          final profile = state.profile;
          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 32),
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [colorScheme.primary, colorScheme.secondary],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: Text(
                      profile.pseudonym[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  profile.pseudonym,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                ),
                if (profile.bio != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    profile.bio!,
                    style: TextStyle(fontSize: 14, color: colorScheme.onSurface.withOpacity(0.6)),
                  ),
                ],
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

class _FeedPostCard extends StatelessWidget {
  const _FeedPostCard({required this.communityName, required this.author, required this.hasAccess});

  final String communityName;
  final String author;
  final bool hasAccess;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colorScheme.primary, colorScheme.secondary],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                communityName[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(communityName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                Text(author, style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withOpacity(0.5))),
              ],
            ),
          ),
          Icon(
            hasAccess ? Icons.check_circle : Icons.lock_outline,
            size: 20,
            color: hasAccess ? Colors.green.withOpacity(0.7) : colorScheme.onSurface.withOpacity(0.3),
          ),
        ],
      ),
    );
  }
}

class _CommunityCard extends StatelessWidget {
  const _CommunityCard({required this.community});

  final dynamic community;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colorScheme.primary, colorScheme.secondary],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                community.name[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(community.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                if (community.bio != null)
                  Text(community.bio, style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withOpacity(0.5)), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Icon(
            community.isPublic ? Icons.public_rounded : Icons.lock_rounded,
            size: 16,
            color: community.isPublic ? Colors.green.withOpacity(0.7) : colorScheme.onSurface.withOpacity(0.3),
          ),
        ],
      ),
    );
  }
}