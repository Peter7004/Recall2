import 'dart:async';

class ReaderLearningStorageException implements Exception {
  const ReaderLearningStorageException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The guard covers the entire read-latest / mutate / durable-write operation.
abstract interface class LearningWriteGuard {
  Future<T> exclusive<T>(Future<T> Function() action);
  Future<T> read<T>(Future<T> Function() action);
  Stream<void> get changes;
  void didChange();
}
