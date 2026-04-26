import 'package:flutter/material.dart';
import 'package:reown_appkit/reown_appkit.dart';
import '../../../core/constants/api_constants.dart';

class WalletService {
  WalletService._();
  static final WalletService instance = WalletService._();

  ReownAppKitModal? _appKitModal;

  bool get isInitialized => _appKitModal != null && _appKitModal!.status.isInitialized;
  bool get isConnected => _appKitModal?.isConnected ?? false;

  String? get address {
    if (_appKitModal?.session == null) return null;
    return _appKitModal!.session!.getAddress('eip155');
  }

  String get abbreviatedWalletAddress {
    final addr = address;
    if (addr == null || addr.isEmpty) return '';
    if (addr.length <= 10) return addr;
    return '${addr.substring(0, 6)}...${addr.substring(addr.length - 4)}';
  }

  Future<void> init(BuildContext context) async {
    if (_appKitModal != null) return;

    final projectId = ApiConstants.projectId;
    if (projectId.isEmpty) {
      debugPrint('WalletService: REOWN_PROJECT_ID not set');
      return;
    }

    _appKitModal = ReownAppKitModal(
      context: context,
      projectId: projectId,
      metadata: PairingMetadata(
        name: 'Synergy',
        description: 'Anonymous Social Network',
        url: 'https://synergy.app',
        icons: ['https://synergy.app/icon.png'],
        redirect: const Redirect(
          native: 'synergy://',
          universal: 'https://synergy.app',
          linkMode: false,
        ),
      ),
    );

    await _appKitModal!.init();
  }

  Future<void> connect() async {
    if (_appKitModal == null) {
      debugPrint('WalletService: not initialized');
      return;
    }
    await _appKitModal!.openModalView();
  }

  Future<void> disconnect() async {
    if (_appKitModal == null) return;
    await _appKitModal!.disconnect();
  }

  void onModalConnect(void Function(ModalConnect?) callback) {
    _appKitModal?.onModalConnect.subscribe(callback);
  }

  void onModalDisconnect(void Function(ModalDisconnect?) callback) {
    _appKitModal?.onModalDisconnect.subscribe(callback);
  }

  void onModalNetworkChange(void Function(ModalNetworkChange?) callback) {
    _appKitModal?.onModalNetworkChange.subscribe(callback);
  }
}