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
import 'features/auth/domain/usecases/logout.dart';
import 'features/auth/domain/usecases/verify_signature.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/pages/onboarding_page.dart';
import 'features/auth/presentation/pages/welcome_page.dart';
import 'features/community/presentation/pages/communities_page.dart';
import 'features/content/presentation/pages/feed_page.dart';
import 'features/profile/presentation/pages/profile_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  runApp(const SynergyApp());
}

class SynergyApp extends StatefulWidget {
  const SynergyApp({super.key});

  @override
  State<SynergyApp> createState() => _SynergyAppState();
}

class _SynergyAppState extends State<SynergyApp> {
  late final ApiClient _apiClient;
  late final SecureStorageService _secureStorage;
  late final AuthRepositoryImpl _authRepository;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient();
    _secureStorage = SecureStorageService();
    _authRepository = AuthRepositoryImpl(
      remoteDataSource: AuthRemoteDataSourceImpl(apiClient: _apiClient),
      localDataSource: AuthLocalDataSourceImpl(secureStorage: _secureStorage),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<AuthRepositoryImpl>.value(
      value: _authRepository,
      child: BlocProvider<AuthBloc>(
        create: (context) => AuthBloc(
          getNonce: GetNonce(_authRepository),
          verifySignature: VerifySignature(_authRepository),
          checkAuthStatus: CheckAuthStatus(_authRepository),
          logout: Logout(_authRepository),
        )..add(const AuthCheckRequested()),
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
          builder: (context) => BlocProvider<AuthBloc>(
            create: (context) => AuthBloc(
              getNonce: GetNonce(context.read<AuthRepositoryImpl>()),
              verifySignature: VerifySignature(context.read<AuthRepositoryImpl>()),
              checkAuthStatus: CheckAuthStatus(context.read<AuthRepositoryImpl>()),
              logout: Logout(context.read<AuthRepositoryImpl>()),
            )..add(const AuthCheckRequested()),
            child: const WelcomePage(),
          ),
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
          builder: (context) => const FeedPage(),
        );
      case '/communities':
        return MaterialPageRoute(
          builder: (context) => const CommunitiesPage(),
        );
      case '/profile':
        return MaterialPageRoute(
          builder: (context) => const ProfilePage(),
        );
      default:
        return MaterialPageRoute(
          builder: (context) => const WelcomePage(),
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
