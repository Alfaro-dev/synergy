import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../constants/api_constants.dart';
import '../errors/exceptions.dart';

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, dynamic>> getNonce() async {
    final response = await _client.get(
      Uri.parse(ApiConstants.nonceEndpoint),
    );
    return _handleAuthResponse(response);
  }

  Future<Map<String, dynamic>> verifySignature({
    required String message,
    required String signature,
  }) async {
    final response = await _client.post(
      Uri.parse(ApiConstants.verifyEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'message': message,
        'signature': signature,
      }),
    );
    return _handleAuthResponse(response);
  }

  Future<Map<String, dynamic>> get({
    required String endpoint,
    required String token,
  }) async {
    final response = await _client.get(
      Uri.parse('${ApiConstants.baseUrl}$endpoint'),
      headers: _authHeaders(token),
    );
    return _handleAuthenticatedResponse(response);
  }

  Future<Map<String, dynamic>> post({
    required String endpoint,
    required String token,
    Map<String, dynamic>? body,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConstants.baseUrl}$endpoint'),
      headers: _authHeaders(token),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleAuthenticatedResponse(response);
  }

  Future<Map<String, dynamic>> patch({
    required String endpoint,
    required String token,
    Map<String, dynamic>? body,
  }) async {
    final response = await _client.patch(
      Uri.parse('${ApiConstants.baseUrl}$endpoint'),
      headers: _authHeaders(token),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleAuthenticatedResponse(response);
  }

  Future<Map<String, dynamic>> put({
    required String endpoint,
    required String token,
    Map<String, dynamic>? body,
  }) async {
    final response = await _client.put(
      Uri.parse('${ApiConstants.baseUrl}$endpoint'),
      headers: _authHeaders(token),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleAuthenticatedResponse(response);
  }

  Future<Map<String, dynamic>> uploadFile({
    required String endpoint,
    required String token,
    required String filePath,
    required String fieldName,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_authHeaders(token));
    request.files.add(await http.MultipartFile.fromPath(
      fieldName,
      filePath,
      contentType: MediaType('application', 'octet-stream'),
    ));

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    return _handleAuthenticatedResponse(response);
  }

  Future<List<int>> getBinary({
    required String endpoint,
    required String token,
  }) async {
    final response = await _client.get(
      Uri.parse('${ApiConstants.baseUrl}$endpoint'),
      headers: _binaryHeaders(token),
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    }

    throw _mapStatusCodeToException(response.statusCode, response.body);
  }

  Map<String, String> _authHeaders(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Map<String, String> _binaryHeaders(String token) => {
        'Authorization': 'Bearer $token',
      };

  Map<String, dynamic> _handleAuthResponse(http.Response response) {
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw _mapStatusCodeToException(response.statusCode, response.body);
  }

  Map<String, dynamic> _handleAuthenticatedResponse(http.Response response) {
    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = response.body;
      if (body.isEmpty) return {};
      return jsonDecode(body) as Map<String, dynamic>;
    }
    throw _mapStatusCodeToException(response.statusCode, response.body);
  }

  AppException _mapStatusCodeToException(int statusCode, String body) {
    Map<String, dynamic> parsedBody;
    try {
      parsedBody = body.isEmpty ? {} : jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      parsedBody = {};
    }

    final error = parsedBody['error'] as String?;

    switch (statusCode) {
      case 400:
        return BadRequestException(error ?? 'Solicitud inválida');
      case 401:
        if (error == 'invalid_nonce') {
          return const InvalidNonceException();
        } else if (error == 'invalid_signature') {
          return const InvalidSignatureException();
        }
        return const UnauthorizedException();
      case 403:
        if (error == 'not_community_creator') {
          return const ForbiddenException('Solo el creador puede hacer esto');
        } else if (error == 'no_active_subscription') {
          return const ForbiddenException('Suscripción no activa');
        }
        return const ForbiddenException();
      case 404:
        return const NotFoundException();
      case 429:
        return const RateLimitException();
      case 500:
        return const ServerException();
      default:
        return ServerException(error ?? 'Error desconocido');
    }
  }

  void dispose() {
    _client.close();
  }
}
