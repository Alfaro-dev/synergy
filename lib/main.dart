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
import 'features/community/presentation/pages/communities_page.dart';
import 'features/content/data/datasources/content_remote_data_source.dart';
import 'features/content/data/repositories/content_repository_impl.dart';
import 'features/content/domain/repositories/content_repository.dart';
import 'features/content/presentation/bloc/feed_bloc.dart';
import 'features/content/presentation/bloc/feed_event.dart';
import 'features/content/presentation/pages/feed_page.dart';
import 'features/profile/data/datasources/profile_remote_data_source.dart';
import 'features/profile/data/repositories/profile_repository_impl.dart';
import 'features/profile/domain/repositories/profile_repository.dart';
import 'features/profile/presentation/bloc/profile_bloc.dart';
import 'features/profile/presentation/bloc/profile_event.dart';
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
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
          ),
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

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated) {
          Navigator.of(context).pushReplacementNamed('/');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Synergy'),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_outline),
              onPressed: () => Navigator.of(context).pushNamed('/profile'),
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                context.read<AuthBloc>().add(const AuthLogoutRequested());
              },
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Bienvenido a Synergy',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/feed'),
                icon: const Icon(Icons.home),
                label: const Text('Ir al Feed'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/communities'),
                icon: const Icon(Icons.people),
                label: const Text('Comunidades'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}