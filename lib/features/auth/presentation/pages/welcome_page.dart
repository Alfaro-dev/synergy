import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:reown_appkit/reown_appkit.dart';
import '../../../../core/constants/api_constants.dart';

// ─── Constantes centralizadas ───────────────────────────────────────────────
const _kChainId     = '11155111';
const _kChainIdHex  = '0xaa36a7';
const _kChainIdCaip = 'eip155:11155111';
const _kNamespace   = 'eip155';
const _kProjectId   = '3759eb76e8b571340bf95642e3dffb65';
const _kDomain      = 'sinergia-backend-production.up.railway.app';
const _kAppUrl      = 'https://sinergia-backend-production.up.railway.app';
const _kRpcUrl      = 'https://rpc.sepolia.org';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  late final ReownAppKitModal _appKitModal;
  bool _isInitialized = false;
  String? _initError;
  bool _isSigning = false;
  String? _pendingAddress;
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
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

  Future<void> _initAppKit() async {
    try {
      final appKit = ReownAppKit(
        core: ReownCore(projectId: _kProjectId, logLevel: LogLevel.all),
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
          signOut: () async => true,
          enabled: false,
        ),
        logLevel: LogLevel.all,
        disconnectOnDispose: true,
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
      if (mounted) setState(() => _initError = e.toString());
    }
  }

  // ─── Issued At con 3 decimales (ms) — el backend no acepta microsegundos ──
  // DateTime.now().toUtc().toIso8601String() da microsegundos: 2026-04-26T02:56:36.430017Z
  // El backend espera milisegundos:                            2026-04-26T02:56:36.430Z
  String _issuedAt() {
    final now = DateTime.now().toUtc();
    final ms = now.millisecond.toString().padLeft(3, '0');
    final base = now.toIso8601String().split('.')[0]; // '2026-04-26T02:56:36'
    return '${base}.${ms}Z';
  }

  // ─── Chains de la sesión ───────────────────────────────────────────────────
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
      // 1. Nonce
      final nonceRes = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/auth/nonce'),
      );
      if (nonceRes.statusCode != 200) {
        throw Exception('No se pudo obtener el nonce del servidor');
      }
      final nonce = (jsonDecode(nonceRes.body) as Map<String, dynamic>)['nonce'] as String;

      // 2. Switch a Sepolia
      await _switchToSepolia();

      // 3. Mensaje SIWE — formato EIP-4361 exacto
      // IMPORTANTE: el address va exactamente como lo devuelve MetaMask
      // El personal_sign firma el mensaje con ese mismo address
      // Issued At con milisegundos (3 decimales), no microsegundos (6 decimales)
      final message = _buildSiweMessage(address, nonce);
      debugPrint('[Synergy] SIWE message:\n$message');

      // 4. Firma en CAIP-2
      // params: [message, address] — orden correcto para personal_sign
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

      debugPrint('[Synergy] Firma: $signature');

      // 5. Verify
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

  String _buildSiweMessage(String address, String nonce) {
    // EIP-4361 exacto — lista de líneas unidas con \n, sin \n al final
    // Líneas vacías ('') generan los \n\n requeridos antes y después del statement
    return [
      '$_kDomain wants you to sign in with your Ethereum account:',
      address,
      '',                    // línea en blanco antes del statement
      'Sign in to Sinergia',
      '',                    // línea en blanco después del statement
      'URI: $_kAppUrl',
      'Version: 1',
      'Chain ID: $_kChainId',
      'Nonce: $nonce',
      'Issued At: ${_issuedAt()}',  // 3 decimales: 2026-04-26T02:56:36.430Z
    ].join('\n');
  }

  // ─── Event handlers ────────────────────────────────────────────────────────

  void _onModalConnect(ModalConnect? event) {
    debugPrint('[Synergy] _onModalConnect');
    if (event == null || !mounted) return;
    final address = event.session.getAddress(_kNamespace);
    if (address == null) return;
    debugPrint('[Synergy] Wallet conectada: $address');
    // Auto-lanzar SIWE — un solo click para el usuario
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

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildHeader(context),
              const SizedBox(height: 48),
              _buildContent(context),
            ],
          ),
        ),
      ),
    );
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
      return Column(
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
      );
    }

    if (_initError != null) {
      return Column(
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
      );
    }

    if (!_isInitialized) {
      return const CircularProgressIndicator();
    }

    // Conectado pero canceló la firma — botón manual de reintento
    if (_appKitModal.isConnected) {
      final address = _appKitModal.session?.getAddress(_kNamespace);
      return Column(
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
      );
    }

    // Estado inicial — un click → conecta → SIWE automático
    return Column(
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
    );
  }
}