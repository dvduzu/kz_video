class BilibiliApiException implements Exception {
  final int? code;
  final String message;
  final String? path;
  const BilibiliApiException(this.message, {this.code, this.path});

  @override
  String toString() => 'BilibiliApiException(${path ?? ''} code=$code): $message';
}

class NetworkException implements Exception {
  final String message;
  final Object? cause;
  const NetworkException(this.message, {this.cause});

  @override
  String toString() => 'NetworkException: $message';
}

class AuthException implements Exception {
  final String message;
  final int? code;
  const AuthException(this.message, {this.code});

  @override
  String toString() => 'AuthException(${code ?? ''}): $message';
}

class RiskControlException implements Exception {
  final String message;
  final String? path;
  const RiskControlException(this.message, {this.path});

  @override
  String toString() => 'RiskControlException($path): $message';
}

class ParseException implements Exception {
  final String message;
  final Object? source;
  const ParseException(this.message, {this.source});

  @override
  String toString() => 'ParseException: $message';
}