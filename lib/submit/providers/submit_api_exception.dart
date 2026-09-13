class SubmitApiException implements Exception {
  final int statusCode;
  final String message;
  const SubmitApiException(this.statusCode, this.message);

  @override
  String toString() => 'SubmitApiException($statusCode): $message';
}
