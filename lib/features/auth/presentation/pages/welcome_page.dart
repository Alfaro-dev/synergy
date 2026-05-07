import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:reown_appkit/reown_appkit.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/secure_storage_service.dart';
import '../../domain/entities/auth_session.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../../../profile/domain/repositories/profile_repository.dart';
import '../../../profile/presentation/bloc/profile_bloc.dart';
import '../../../profile/presentation/bloc/profile_event.dart';
import '../../../profile/presentation/bloc/profile_state.dart';

// ─── Constantes centralizadas ───────────────────────────────────────────────
const _kChainId     = '11155111';
const _kChainIdHex  = '0xaa36a7';
const _kChainIdCaip = 'eip155:11155111';
const _kNamespace   = 'eip155';
const _kDomain      = 'sinergia-backend-production.up.railway.app';
const _kAppUrl      = 'https://sinergia-backend-production.up.railway.app';
const _kRpcUrl      = 'https://rpc.sepolia.org';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key, required this.secureStorage});

  final SecureStorageService secureStorage;

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  late final ReownAppKitModal _appKitModal;
  late final SecureStorageService _secureStorage;
  bool _isInitialized = false;
  String? _initError;
  bool _isSigning = false;
  int _retryCount = 0;
  String? _pendingAddress;

  @override
  void initState() {
    super.initState();
    _secureStorage = widget.secureStorage;
    ReownAppKitModalNetworks.addSupportedNetworks(_kNamespace, [
      ReownAppKitModalNetworkInfo(
        name: 'Sepolia',
        chainId: _kChainId,
        currency: 'SepoliaETH',
        rpcUrl: _kRpcUrl,
        explorerUrl: 'https://sepolia.etherscan.io',
        isTestNetwork: true,
      ),
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAppKit();
      context.read<AuthBloc>().add(const AuthCheckRequested());
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProfileBloc>(
      create: (context) => ProfileBloc(
        repository: context.read<ProfileRepository>(),
      ),
      child: MultiBlocListener(
        listeners: [
          BlocListener<AuthBloc, AuthState>(
            listener: (context, state) async {
              if (state is AuthAuthenticated) {
                final isNew = await SecureStorageService.instance.isNewUser();
                if (isNew) {
                  if (context.mounted) {
                    Navigator.of(context).pushReplacementNamed('/profile-setup');
                  }
                } else {
                  context.read<ProfileBloc>().add(const ProfileFetchRequested());
                }
              } else if (state is AuthUnauthenticated && state.fromExplicitLogout) {
                if (_appKitModal.isConnected) {
                  _appKitModal.disconnect();
                }
              }
            },
          ),
          BlocListener<ProfileBloc, ProfileState>(
            listener: (context, state) {
              if (state is ProfileLoaded) {
                Navigator.of(context).pushReplacementNamed('/home');
              } else if (state is ProfileNotFound) {
                Navigator.of(context).pushReplacementNamed('/profile-setup');
              }
            },
          ),
        ],
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 48),
                  _buildContent(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _initAppKit() async {
    try {
      final appKit = ReownAppKit(
        core: ReownCore(projectId: ApiConstants.projectId, logLevel: LogLevel.all),
        metadata: const PairingMetadata(
          name: 'Sinergia',
          description: 'Comunidades privadas y anónimas',
          url: _kAppUrl,
          icons: ['$_kAppUrl/icon.png'],
          redirect: Redirect(
            native: 'synergy://',
            universal: _kAppUrl,
            linkMode: true,
          ),
        ),
      );

_appKitModal = ReownAppKitModal(
        context: context,
        appKit: appKit,
        siweConfig: SIWEConfig(
          getNonce: () async => '',
          getMessageParams: () async => const SIWEMessageArgs(
            domain: _kDomain,
            uri: _kAppUrl,
          ),
          createMessage: (args) => SIWEUtils.formatMessage(args),
          verifyMessage: (_) async => true,
          getSession: () async {
            final session = await _secureStorage.getSession();
            if (session == null) return null;
            final address = session.walletAddress;
            if (address == null || address.isEmpty) return null;
            return SIWESession(
              address: address,
              chains: ['eip155:11155111'],
            );
          },
          signOut: () async {
            debugPrint('[Synergy] SIWE signOut called - NOT clearing secure storage (app manages session)');
            return true;
          },
          enabled: false,
        ),
        logLevel: LogLevel.all,
        disconnectOnDispose: false,
      );

      _appKitModal.onModalConnect.subscribe(_onModalConnect);
      _appKitModal.onModalUpdate.subscribe(_onModalUpdate);
      _appKitModal.onModalNetworkChange.subscribe(_onModalNetworkChange);
      _appKitModal.onModalDisconnect.subscribe(_onModalDisconnect);
      _appKitModal.onModalError.subscribe(_onModalError);
      _appKitModal.onSessionExpireEvent.subscribe(_onSessionExpire);
      _appKitModal.onSessionUpdateEvent.subscribe(_onSessionUpdate);

      await _appKitModal.init();
      if (mounted) setState(() => _isInitialized = true);
    } on PlatformException catch (e) {
      debugPrint('PlatformException durante init: ${e.code} - ${e.message}');
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('AppKit init error: $e');
      if (mounted) setState(() {
        _initError = e.toString();
        _isInitialized = true;
      });
    }
  }

  String _issuedAt() {
    final now = DateTime.now().toUtc();
    final ms = now.millisecond.toString().padLeft(3, '0');
    final base = now.toIso8601String().split('.')[0];
    return '$base.${ms}Z';
  }

  List<String> _getSessionChains() {
    try {
      final ns = _appKitModal.session?.namespaces;
      if (ns != null && ns[_kNamespace] != null) {
        return ns[_kNamespace]!.chains ?? [];
      }
    } catch (_) {}
    return [];
  }

  Future<void> _switchToSepolia() async {
    final sessionChains = _getSessionChains();
    if (sessionChains.contains(_kChainIdCaip)) {
      debugPrint('[Synergy] Sepolia ya en sesión');
      return;
    }

    String originChain = _kChainIdCaip;
    if (sessionChains.isNotEmpty) {
      originChain = sessionChains.contains('eip155:1')
          ? 'eip155:1'
          : sessionChains.first;
    }

    debugPrint('[Synergy] Switch a Sepolia desde $originChain');
    try {
      await _appKitModal.request(
        topic: _appKitModal.session?.topic,
        chainId: originChain,
        request: SessionRequestParams(
          method: 'wallet_switchEthereumChain',
          params: [{'chainId': _kChainIdHex}],
        ),
      );
      debugPrint('[Synergy] Switch exitoso');
    } catch (switchError) {
      debugPrint('[Synergy] Switch falló, intentando add: $switchError');
      try {
        await _appKitModal.request(
          topic: _appKitModal.session?.topic,
          chainId: originChain,
          request: SessionRequestParams(
            method: 'wallet_addEthereumChain',
            params: [
              {
                'chainId': _kChainIdHex,
                'chainName': 'Sepolia Testnet',
                'nativeCurrency': {
                  'name': 'SepoliaETH',
                  'symbol': 'ETH',
                  'decimals': 18,
                },
                'rpcUrls': [_kRpcUrl],
                'blockExplorerUrls': ['https://sepolia.etherscan.io'],
              }
            ],
          ),
        );
      } catch (addError) {
        debugPrint('[Synergy] add también falló: $addError');
      }
    }
  }

  Future<void> _triggerSiweFlow(String address) async {
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    setState(() => _isSigning = true);

    try {
      final nonceRes = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/auth/nonce'),
      );
      if (nonceRes.statusCode != 200) {
        throw Exception('No se pudo obtener el nonce del servidor');
      }
      final nonce = (jsonDecode(nonceRes.body) as Map<String, dynamic>)['nonce'] as String;

      await _switchToSepolia();

      final message = _buildSiweMessage(address, nonce);
      debugPrint('[Synergy] SIWE message:\n$message');

      String signature;
      try {
        signature = await _appKitModal.request(
          topic: _appKitModal.session?.topic,
          chainId: _kChainIdCaip,
          request: SessionRequestParams(
            method: 'personal_sign',
            params: [message, address],
          ),
        );
      } on JsonRpcError catch (e) {
        debugPrint('[Synergy] JsonRpcError: code=${e.code} msg=${e.message}');
        if (e.code == 1 && e.message == 'Invalid Id' && _retryCount < 2) {
          _pendingAddress = address;
          _retryCount++;
          signature = await _appKitModal.request(
            topic: _appKitModal.session?.topic,
            chainId: _kChainIdCaip,
            request: SessionRequestParams(
              method: 'personal_sign',
              params: [message, address],
            ),
          );
        } else {
          throw Exception('La conexión se interrumpió. Por favor intentá de nuevo.');
        }
      }

      final verifyRes = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/auth/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': message, 'signature': signature}),
      );

      debugPrint('[Synergy] verify status: ${verifyRes.statusCode}');
      debugPrint('[Synergy] verify body: ${verifyRes.body}');

      if (verifyRes.statusCode == 200) {
        final data = jsonDecode(verifyRes.body) as Map<String, dynamic>;
        final isNewUser = data['is_new_user'] as bool? ?? false;
        final token = data['token'] as String?;
        final expiresAt = data['expires_at'] as int?;

        log('[WelcomePage] Saving token to secure storage...');
        if (token != null && expiresAt != null) {
          log('[WelcomePage] token length: ${token.length}, expiresAt raw from server: $expiresAt');
          final expiresAtDateTime = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
          log('[WelcomePage] expiresAt converted: millisecondsSinceEpoch=${expiresAtDateTime.millisecondsSinceEpoch}');
          final session = AuthSession(
            token: token,
            expiresAt: expiresAtDateTime,
            isNewUser: isNewUser,
            walletAddress: address,
          );
          await _secureStorage.saveSession(session);
          log('[WelcomePage] All values saved to secure storage');
        } else {
          log('[WelcomePage] ERROR: token or expiresAt is null!');
        }

        // Notify AuthBloc of successful sign in
        context.read<AuthBloc>().add(AuthSignResult(
          message: message,
          signature: signature,
        ));

        if (isNewUser) {
          navigator.pushReplacementNamed('/onboarding');
        } else {
          navigator.pushReplacementNamed('/home');
        }
      } else {
        final errorData = jsonDecode(verifyRes.body) as Map<String, dynamic>;
        final errorCode = errorData['error'] as String? ?? 'unknown';
        throw Exception(_friendlyError(errorCode));
      }
    } catch (e) {
      debugPrint('[Synergy] SIWE flow error: $e');
      final userMessage = e is Exception
          ? e.toString().replaceFirst('Exception: ', '')
          : 'Error inesperado al iniciar sesión';
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(userMessage), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSigning = false;
          _pendingAddress = null;
          _retryCount = 0;
        });
      }
    }
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'invalid_nonce':
        return 'La sesión expiró. Por favor intentá de nuevo.';
      case 'invalid_signature':
        return 'Firma inválida. Por favor intentá de nuevo.';
      case 'invalid_message':
        return 'Error al construir el mensaje. Por favor intentá de nuevo.';
      default:
        return 'Error al iniciar sesión. Por favor intentá de nuevo.';
    }
  }

  String _toChecksumAddress(String address) {
    return EthereumAddress.fromHex(address).eip55With0x;
  }

  String _buildSiweMessage(String address, String nonce) {
    final checksumAddr = _toChecksumAddress(address);
    return [
      '$_kDomain wants you to sign in with your Ethereum account:',
      checksumAddr,
      '',
      'Sign in to Sinergia',
      '',
      'URI: $_kAppUrl',
      'Version: 1',
      'Chain ID: $_kChainId',
      'Nonce: $nonce',
      'Issued At: ${_issuedAt()}',
    ].join('\n');
  }

  void _onModalConnect(ModalConnect? event) {
    debugPrint('[Synergy] _onModalConnect');
    if (event == null || !mounted) return;
    final address = event.session.getAddress(_kNamespace);
    if (address == null) return;
    debugPrint('[Synergy] Wallet conectada: $address');
    _triggerSiweFlow(address);
  }

  void _onModalUpdate(ModalConnect? event) {
    if (mounted) setState(() {});
  }

  void _onModalNetworkChange(ModalNetworkChange? event) {
    debugPrint('[Synergy] _onModalNetworkChange: ${event?.eventName}');
    if (mounted) setState(() {});
  }

  void _onModalDisconnect(ModalDisconnect? event) {
    debugPrint('[Synergy] _onModalDisconnect');
    if (mounted) setState(() {});
  }

  void _onModalError(ModalError? event) {
    debugPrint('[Synergy] _onModalError: ${event?.message}');
    if (mounted) setState(() {});
  }

  void _onSessionExpire(SessionExpire? event) {
    debugPrint('[Synergy] _onSessionExpire');
    _pendingAddress = _appKitModal.session?.getAddress(_kNamespace);
    _retryCount = 0;
    if (mounted) setState(() {});
  }

  void _onSessionUpdate(SessionUpdate? event) {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _appKitModal.onModalConnect.unsubscribe(_onModalConnect);
    _appKitModal.onModalUpdate.unsubscribe(_onModalUpdate);
    _appKitModal.onModalNetworkChange.unsubscribe(_onModalNetworkChange);
    _appKitModal.onModalDisconnect.unsubscribe(_onModalDisconnect);
    _appKitModal.onModalError.unsubscribe(_onModalError);
    _appKitModal.onSessionExpireEvent.unsubscribe(_onSessionExpire);
    _appKitModal.onSessionUpdateEvent.unsubscribe(_onSessionUpdate);
    _appKitModal.dispose();
    super.dispose();
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primary,
                colorScheme.secondary,
              ],
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Icon(
            Icons.forum_rounded,
            size: 44,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'SYNERGY',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: 6,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isSigning) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          children: [
            const SizedBox(height: 48),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Firmando...',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Revisá tu wallet',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 32),
            TextButton(
              onPressed: () => setState(() {
                _isSigning = false;
                _pendingAddress = null;
                _retryCount = 0;
              }),
              child: Text(
                'Cancelar',
                style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
              ),
            ),
          ],
        ),
      );
    }

    if (_initError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          children: [
            const SizedBox(height: 48),
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: colorScheme.error,
            ),
            const SizedBox(height: 24),
            Text(
              'Error de conexión',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No se pudo inicializar',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () {
                setState(() => _initError = null);
                _initAppKit();
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
      );
    }

    if (!_isInitialized) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: colorScheme.primary.withOpacity(0.5),
        ),
      );
    }

    if (_appKitModal.isConnected) {
      final address = _appKitModal.session?.getAddress(_kNamespace);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          children: [
            const SizedBox(height: 48),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.check_circle_outline_rounded,
                size: 28,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Wallet conectada',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            if (address != null) ...[
              const SizedBox(height: 8),
              Text(
                '${address.substring(0, 6)}...${address.substring(address.length - 4)}',
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                  color: colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _triggerSiweFlow(address),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Entrar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _appKitModal.disconnect(),
                child: Text(
                  'Usar otra wallet',
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: AppKitModalConnectButton(
              appKit: _appKitModal,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Conectá tu wallet para empezar',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }
}