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
    WidgetsBinding.instance.addPostFrameCallback((_) => _initAppKit());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          // AuthBloc received successful auth - wallet already navigated
        } else if (state is AuthUnauthenticated) {
          // Logged out - disconnect wallet
          if (_appKitModal.isConnected) {
            _appKitModal.disconnect();
          }
        }
      },
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
            linkMode: false,
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
          getSession: () async => null,
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
    return Column(
      children: [
        Icon(Icons.forum, size: 80, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 24),
        Text('Synergy', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text('Entrá con tu wallet', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Sin email. Sin contraseña. Tu identidad es completamente anónima.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isSigning) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Firmando mensaje...', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(
              'Revisá MetaMask para aprobar',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => setState(() {
                _isSigning = false;
                _pendingAddress = null;
                _retryCount = 0;
              }),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      );
    }

    if (_initError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'No se pudo inicializar la wallet',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                setState(() => _initError = null);
                _initAppKit();
              },
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (!_isInitialized) {
      return const CircularProgressIndicator();
    }

    if (_appKitModal.isConnected) {
      final address = _appKitModal.session?.getAddress(_kNamespace);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('Wallet conectada', style: Theme.of(context).textTheme.titleMedium),
            if (address != null) ...[
              const SizedBox(height: 8),
              Text(
                '${address.substring(0, 6)}...${address.substring(address.length - 4)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => _triggerSiweFlow(address),
                child: const Text('Iniciar sesión'),
              ),
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _appKitModal.disconnect(),
              child: const Text('Usar otra wallet'),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppKitModalConnectButton(appKit: _appKitModal),
          const SizedBox(height: 12),
          Text(
            'Al conectar se te pedirá firmar un mensaje para verificar tu identidad',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}