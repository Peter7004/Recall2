import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;
import 'reader_learning_guard.dart';

final LearningWriteGuard learningWriteGuard = _WebLearningGuard();

/// Origin-wide Web Lock: shared by all tabs running the current writer protocol.
/// Old app tabs must be reloaded: code that ignores locks cannot be coordinated.
class _WebLearningGuard implements LearningWriteGuard {
  static const _lockName = 'recall.reader.learning.v1.write';
  static const _preferenceKey = 'flutter.recall.reader.learning.v1';
  late final StreamController<void> _changes = StreamController<void>.broadcast(
      onListen: () => web.window.addEventListener('storage', _storageListener),
      onCancel: () =>
          web.window.removeEventListener('storage', _storageListener));
  late final JSFunction _storageListener = ((web.StorageEvent event) {
    if (event.key == _preferenceKey || event.key == null) _changes.add(null);
  }).toJS;
  web.LockManager? get _manager {
    final value = web.window.navigator.getProperty<JSAny?>('locks'.toJS);
    return value == null || value.isUndefined ? null : value as web.LockManager;
  }

  @override
  Stream<void> get changes => _changes.stream;
  @override
  void didChange() => _changes.add(null);
  @override
  Future<T> read<T>(Future<T> Function() action) =>
      _manager == null ? action() : exclusive(action);
  @override
  Future<T> exclusive<T>(Future<T> Function() action) async {
    final manager = _manager;
    if (manager == null) {
      throw const ReaderLearningStorageException(
          '현재 환경에서는 안전한 동시 저장을 지원하지 않습니다. 최신 브라우저의 HTTPS 주소에서 열어 주세요. 기존 기록은 유지됩니다.');
    }
    final abort = web.AbortController();
    final timeout = Timer(const Duration(seconds: 15), () => abort.abort());
    late T result;
    Object? actionError;
    StackTrace? actionTrace;
    final callback = ((web.Lock? _) {
      timeout.cancel();
      return (() async {
        try {
          result = await action();
        } catch (error, trace) {
          actionError = error;
          actionTrace = trace;
        }
        return null;
      })()
          .toJS;
    }).toJS;
    try {
      await manager
          .request(
              _lockName,
              web.LockOptions(mode: 'exclusive', signal: abort.signal),
              callback)
          .toDart;
    } catch (_) {
      throw const ReaderLearningStorageException(
          '다른 Recall 화면의 저장을 기다리지 못했습니다. 다른 탭도 새로고침한 뒤 다시 시도해 주세요. 기존 기록은 변경하지 않았습니다.');
    } finally {
      timeout.cancel();
    }
    if (actionError != null) {
      Error.throwWithStackTrace(actionError!, actionTrace!);
    }
    return result;
  }
}
