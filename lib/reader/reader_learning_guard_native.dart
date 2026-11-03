import 'dart:async';
import 'reader_learning_guard.dart';

final LearningWriteGuard learningWriteGuard = _ProcessLearningGuard();

/// All Reader instances in the UI isolate share this queue. No plugin/data change.
class _ProcessLearningGuard implements LearningWriteGuard {
  Future<void> _tail = Future<void>.value();
  final _changes = StreamController<void>.broadcast();
  @override
  Stream<void> get changes => _changes.stream;
  @override
  void didChange() => _changes.add(null);
  @override
  Future<T> read<T>(Future<T> Function() action) => exclusive(action);
  @override
  Future<T> exclusive<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }
}
