class DatabaseInitException implements Exception {
  DatabaseInitException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'DatabaseInitException($message)';
}
