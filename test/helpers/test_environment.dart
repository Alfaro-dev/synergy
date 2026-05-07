import 'dart:io';

class TestConfig {
  TestConfig._({
    required this.baseUrl,
    required this.shouldSkipOnCI,
    this.maxRetries = 3,
    this.retryDelayMs = 1000,
  });

  final String baseUrl;
  final bool shouldSkipOnCI;
  final int maxRetries;
  final int retryDelayMs;

  bool get isCI => Platform.environment.containsKey('CI');

  static TestConfig get current {
    final isCI = Platform.environment.containsKey('CI');
    final env = Platform.environment['TEST_ENV'] ?? 'production';

    switch (env) {
      case 'local':
        return TestConfig._(
          baseUrl: 'http://localhost:8080',
          shouldSkipOnCI: false,
        );
      case 'production':
      default:
        return TestConfig._(
          baseUrl: 'https://sinergia-backend-production.up.railway.app',
          shouldSkipOnCI: isCI,
          maxRetries: 5,
        );
    }
  }
}

class RetryHelper {
  static Future<T> withRetry<T>(
    Future<T> Function() fn, {
    int maxAttempts = 3,
    Duration delay = const Duration(seconds: 1),
    String? description,
  }) async {
    Exception? lastError;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await fn();
      } on Exception catch (e) {
        lastError = e;

        if (attempt < maxAttempts) {
          await Future.delayed(delay * attempt);
        }
      }
    }

    throw Exception(
      'Failed after $maxAttempts attempts${description != null ? ': $description' : ''}: $lastError',
    );
  }
}
