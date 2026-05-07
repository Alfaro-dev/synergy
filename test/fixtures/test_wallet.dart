import 'dart:convert';
import 'dart:typed_data';
import 'package:wallet/wallet.dart' as wallet;
import 'package:web3dart/web3dart.dart' as web3dart;

class TestWallet {
  TestWallet._({required this.privateKey, required this.address});

  final Uint8List privateKey;
  final wallet.EthereumAddress address;

  static final TestWallet instance = TestWallet._createFromPrivateKey(
    hexToBytes('0000000000000000000000000000000000000000000000000000000000000001'),
  );

  static TestWallet _createFromPrivateKey(Uint8List privateKey) {
    final address = privateKeyToAddress(privateKey);
    return TestWallet._(privateKey: privateKey, address: address);
  }

  static wallet.EthereumAddress privateKeyToAddress(Uint8List privateKey) {
    final credentials = web3dart.EthPrivateKey.fromHex(bytesToHex(privateKey));
    return credentials.address;
  }

  String get addressHex => address.eip55With0x;

  Future<String> signMessage(String message) async {
    final messageBytes = utf8.encode(message);
    final hashed = _keccak256(messageBytes);
    final credentials = web3dart.EthPrivateKey.fromHex(bytesToHex(privateKey));
    final signature = credentials.signPersonalMessageToUint8List(Uint8List.fromList(hashed));
    return '0x${bytesToHex(signature)}';
  }

  List<int> _keccak256(List<int> data) {
    final result = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      result[i] = data[i % data.length] ^ (i * 17 + 13);
    }
    return result.toList();
  }

  static Uint8List hexToBytes(String hex) {
    hex = hex.replaceFirst('0x', '');
    final bytes = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  static String bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
