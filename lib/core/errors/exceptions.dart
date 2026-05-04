sealed class AppException {
  const AppException(this.message);
  final String message;

  @override
  String toString() => message;
}

final class NetworkException extends AppException {
  const NetworkException([super.message = 'Sin conexión a internet']);
}

final class ServerException extends AppException {
  const ServerException([super.message = 'Error del servidor']);
}

final class BadRequestException extends AppException {
  const BadRequestException([super.message = 'Solicitud inválida']);
}

final class InvalidNonceException extends AppException {
  const InvalidNonceException() : super('Nonce expirado o ya utilizado');
}

final class InvalidSignatureException extends AppException {
  const InvalidSignatureException() : super('La firma no corresponde a la wallet');
}

final class RateLimitException extends AppException {
  const RateLimitException([super.message = 'Demasiadas peticiones']);
}

final class TokenExpiredException extends AppException {
  const TokenExpiredException() : super('Sesión expirada');
}

final class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message = 'No autorizado']);
}

final class ForbiddenException extends AppException {
  const ForbiddenException([super.message = 'Acceso denegado']);
}

final class NotFoundException extends AppException {
  const NotFoundException([super.message = 'Recurso no encontrado']);
}

final class TokenRevokedException extends AppException {
  const TokenRevokedException() : super('Sesión revocada');
}

final class ServerBusyException extends AppException {
  const ServerBusyException([super.message = 'Servidor ocupado, intenta más tarde']);
}

final class ContentRemovedException extends AppException {
  const ContentRemovedException() : super('Contenido removido por violar términos');
}

final class DuplicatePostException extends AppException {
  const DuplicatePostException() : super('Este contenido ya fue publicado');
}

final class IpfsUnavailableException extends AppException {
  const IpfsUnavailableException([super.message = 'Error de conexión con IPFS']);
}

final class InternalException extends AppException {
  const InternalException([super.message = 'Error interno del servidor']);
}
