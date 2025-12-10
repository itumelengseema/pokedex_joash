// Base exception class for the application

abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  const AppException(this.message, {this.code, this.details});

  @override
  String toString() =>
      'AppException: $message${code != null ? ' (Code: $code)' : ''}';
}

/// Network related exceptions
class NetworkException extends AppException {
  const NetworkException(super.message, {super.code, super.details});

  @override
  String toString() => 'NetworkException: $message';
}

/// Cache related exceptions
class CacheException extends AppException {
  const CacheException(super.message, {super.code, super.details});

  @override
  String toString() => 'CacheException: $message';
}

/// Authentication exceptions
class AuthException extends AppException {
  const AuthException(super.message, {super.code, super.details});

  @override
  String toString() => 'AuthException: $message';
}

/// Validation exceptions
class ValidationException extends AppException {
  const ValidationException(super.message, {super.code, super.details});

  @override
  String toString() => 'ValidationException: $message';
}

/// Parse/Serialization exceptions
class ParseException extends AppException {
  const ParseException(super.message, {super.code, super.details});

  @override
  String toString() => 'ParseException: $message';
}

/// Firebase/Firestore exceptions
class FirestoreException extends AppException {
  const FirestoreException(super.message, {super.code, super.details});

  @override
  String toString() => 'FirestoreException: $message';
}
