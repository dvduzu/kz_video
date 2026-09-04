class BilibiliApiException implements Exception {
  final int? code;
  final String message;
  final String? path;
  const BilibiliApiException(this.message, {this.code, this.path});

  @override
  String toString() => 'BilibiliApiException(${path ?? ''} code=$code): $message';
}