import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  ApiConstants._();

  static String get baseUrl => dotenv.get(
        'API_BASE',
        fallback: 'https://sinergia-backend-production.up.railway.app',
      );
  static String get projectId => dotenv.get('REOWN_PROJECT_ID', fallback: '');

  static String get authPrefix => '$baseUrl/auth';
  static String get nonceEndpoint => '$authPrefix/nonce';
  static String get verifyEndpoint => '$authPrefix/verify';

  static const Duration nonceTtl = Duration(minutes: 5);
  static const Duration tokenTtl = Duration(hours: 1);
  static const Duration rateLimitWindow = Duration(minutes: 5);

  static const int maxNonceRequests = 10;
}
