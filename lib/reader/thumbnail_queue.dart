import 'dart:async';
import 'dart:collection';

class ThumbnailJob<T> {
  ThumbnailJob._(this._owner, this._action, this._onCancel);
  final ThumbnailQueue<T> _owner;
  final Future<T?> Function() _action;
  final void Function()? _onCancel;
  final _result = Completer<T?>();
  bool _cancelled = false;
  Future<T?> get future => _result.future;
  void cancel() => _owner._cancel(this);
}

/// No image cache: visible cells own their images. Queued offscreen work is
/// removed immediately; late results from cancelled work are explicitly freed.
class ThumbnailQueue<T> {
  ThumbnailQueue({this.concurrency = 2, required this.discard})
      : assert(concurrency > 0);
  final int concurrency;
  final void Function(T) discard;
  final _pending = Queue<ThumbnailJob<T>>();
  final _running = <ThumbnailJob<T>>{};
  bool _disposed = false;
  int get activeCount => _running.length;
  int get pendingCount => _pending.length;

  ThumbnailJob<T> submit(Future<T?> Function() action,
      {void Function()? onCancel}) {
    final job = ThumbnailJob<T>._(this, action, onCancel);
    if (_disposed) {
      _cancel(job);
      return job;
    }
    _pending.add(job);
    _drain();
    return job;
  }

  void _cancel(ThumbnailJob<T> job) {
    if (job._cancelled) return;
    job._cancelled = true;
    _pending.remove(job);
    try {
      job._onCancel?.call();
    } catch (_) {/* Best effort engine cancellation. */}
    if (!job._result.isCompleted) job._result.complete(null);
  }

  void _drain() {
    while (!_disposed && _running.length < concurrency && _pending.isNotEmpty) {
      final job = _pending.removeFirst();
      if (job._cancelled) continue;
      _running.add(job);
      unawaited(_run(job));
    }
  }

  Future<void> _run(ThumbnailJob<T> job) async {
    try {
      final value = await job._action();
      if (job._cancelled || _disposed) {
        if (value != null) discard(value);
      } else if (!job._result.isCompleted) {
        job._result.complete(value);
      }
    } catch (error, trace) {
      if (!job._result.isCompleted) job._result.completeError(error, trace);
    } finally {
      _running.remove(job);
      _drain();
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final job in [..._pending, ..._running]) {
      _cancel(job);
    }
    _pending.clear();
  }
}
