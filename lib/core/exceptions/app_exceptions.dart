/// Eccezione base dell'applicazione
class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  
  AppException(this.message, {this.code, this.originalError});
  
  @override
  String toString() => message;
}

/// Eccezione di autenticazione
class AuthException extends AppException {
  AuthException(super.message, {super.code, super.originalError});
}

/// Eccezione di database
class DatabaseException extends AppException {
  DatabaseException(super.message, {super.code, super.originalError});
}

/// Eccezione di rete
class NetworkException extends AppException {
  NetworkException(super.message, {super.code, super.originalError});
}

/// Eccezione di validazione
class ValidationException extends AppException {
  ValidationException(super.message, {super.code, super.originalError});
}

/// Eccezione di permessi
class PermissionException extends AppException {
  PermissionException(super.message, {super.code, super.originalError});
}

/// Eccezione risorsa non trovata
class NotFoundException extends AppException {
  NotFoundException(super.message, {super.code, super.originalError});
}

/// Eccezione di storage
class StorageException extends AppException {
  StorageException(super.message, {super.code, super.originalError});
}

/// Eccezione di upload storage
class StorageUploadException extends AppException {
  StorageUploadException(super.message, {super.code, super.originalError});
}
