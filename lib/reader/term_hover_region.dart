import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

enum TermAnalysisStatus { idle, loading, ready, unavailable, error }

@immutable
class TermAnalysisState {
  const TermAnalysisState(this.status, {this.matchCount = 0, this.message});
  final TermAnalysisStatus status;
  final int matchCount;
  final String? message;

  @override
  bool operator ==(Object other) =>
      other is TermAnalysisState &&
      other.status == status &&
      other.matchCount == matchCount &&
      other.message == message;
  @override
  int get hashCode => Object.hash(status, matchCount, message);
}

/// Extraction cannot provide usable text (not a successful zero-match lookup).
class TermTextUnavailable implements Exception {
  const TermTextUnavailable(this.message);
  final String message;
  @override
  String toString() => message;
}

class TermHoverArea {
  const TermHoverArea(this.term, this.rects);
  final String term;

  /// Normalized page coordinates, preserving separate lines/fragments.
  final List<Rect> rects;
}

Rect normalizedPageRect(Rect rect, Size pageSize) => Rect.fromLTRB(
    rect.left / pageSize.width,
    rect.top / pageSize.height,
    rect.right / pageSize.width,
    rect.bottom / pageSize.height);

/// Mouse annotation only: no gesture recognizer and no selection mutation.
class TermHoverRegion extends StatefulWidget {
  const TermHoverRegion(
      {super.key,
      required this.cacheKey,
      required this.loadAreas,
      this.viewToken,
      this.retryToken,
      this.onAnalysisChanged,
      this.highlightAll = false});
  final bool highlightAll;
  final Object cacheKey;
  final Object? viewToken;
  final Object? retryToken;
  final ValueChanged<TermAnalysisState>? onAnalysisChanged;
  final Future<List<TermHoverArea>> Function() loadAreas;
  @override
  State<TermHoverRegion> createState() => _TermHoverRegionState();
}

class _TermHoverRegionState extends State<TermHoverRegion> {
  Future<List<TermHoverArea>>? _areas;
  TermHoverArea? _active;
  Timer? _timer;
  int _request = 0;
  int _allRequest = 0;
  List<TermHoverArea> _all = const [];
  int _generation = 0;
  TermAnalysisState _analysis =
      const TermAnalysisState(TermAnalysisStatus.idle);

  void _report(TermAnalysisState state) {
    _analysis = state;
    final generation = _generation;
    final viewToken = widget.viewToken;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          generation == _generation &&
          viewToken == widget.viewToken) {
        widget.onAnalysisChanged?.call(state);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<List<TermHoverArea>> _load() => _areas ??= _extract(_generation);

  Future<List<TermHoverArea>> _extract(int generation) async {
    _report(const TermAnalysisState(TermAnalysisStatus.loading));
    try {
      final areas = await widget.loadAreas();
      if (mounted && generation == _generation) {
        _report(TermAnalysisState(TermAnalysisStatus.ready,
            matchCount: areas.length));
      }
      return areas;
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _active = null;
          _all = const [];
        });
        _report(TermAnalysisState(
          error is TermTextUnavailable
              ? TermAnalysisStatus.unavailable
              : TermAnalysisStatus.error,
          message: error is TermTextUnavailable
              ? error.message
              : '단어 강조 분석에 실패했습니다. 다시 시도해 주세요.',
        ));
      }
      rethrow;
    }
  }

  Future<void> _retry() async {
    try {
      await _load();
    } catch (_) {/* Reported by _extract. */}
  }

  @override
  void initState() {
    super.initState();
    _report(_analysis);
    if (widget.highlightAll) _loadAll();
  }

  Future<void> _loadAll() async {
    final request = ++_allRequest;
    try {
      final areas = await _load();
      if (mounted && widget.highlightAll && request == _allRequest) {
        setState(() => _all = areas);
      }
    } catch (_) {
      if (mounted && request == _allRequest) {
        setState(() => _all = const []);
      }
    }
  }

  void _clear() {
    _timer?.cancel();
    _request++;
    if (mounted && _active != null) setState(() => _active = null);
  }

  @override
  void didUpdateWidget(TermHoverRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    final invalidated = oldWidget.cacheKey != widget.cacheKey ||
        oldWidget.retryToken != widget.retryToken;
    if (invalidated ||
        oldWidget.viewToken != widget.viewToken ||
        oldWidget.highlightAll != widget.highlightAll) {
      _timer?.cancel();
      _request++;
      _allRequest++;
      _active = null;
      if (invalidated || oldWidget.highlightAll != widget.highlightAll) {
        _all = const [];
      }
      if (invalidated) {
        _generation++;
        _areas = null;
        _report(const TermAnalysisState(TermAnalysisStatus.idle));
      } else {
        _report(_analysis);
      }
      if (widget.highlightAll) {
        _loadAll();
      } else if (oldWidget.retryToken != widget.retryToken) {
        // Explicit retries do not require mouse movement or activate a hover.
        _retry();
      }
    } else if (oldWidget.onAnalysisChanged == null &&
        widget.onAnalysisChanged != null) {
      _report(_analysis);
    }
  }

  void _hover(PointerHoverEvent event, Size size) {
    if (widget.highlightAll ||
        event.kind != PointerDeviceKind.mouse ||
        size.isEmpty) {
      return;
    }
    _timer?.cancel();
    final request = ++_request;
    final point = Offset(event.localPosition.dx / size.width,
        event.localPosition.dy / size.height);
    _timer = Timer(const Duration(milliseconds: 40), () async {
      try {
        final areas = await _load();
        if (!mounted || request != _request) return;
        TermHoverArea? hit;
        for (final area in areas) {
          if (area.rects.any((rect) => rect.contains(point))) {
            hit = area;
            break;
          }
        }
        if (!identical(hit, _active)) setState(() => _active = hit);
      } catch (_) {
        if (mounted && request == _request) setState(() => _active = null);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _request++;
    _allRequest++;
    _generation++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final size = constraints.biggest;
        return MouseRegion(
            opaque: false,
            hitTestBehavior: HitTestBehavior.translucent,
            onHover: (event) => _hover(event, size),
            onExit: (_) => _clear(),
            child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) => _clear(),
                child: IgnorePointer(
                    child: CustomPaint(
                        painter: TermHoverPainter(
                            widget.highlightAll ? null : _active,
                            areas: widget.highlightAll ? _all : const []),
                        size: size))));
      });
}

class TermHoverPainter extends CustomPainter {
  const TermHoverPainter(this.area, {this.areas = const []});
  final List<TermHoverArea> areas;
  final TermHoverArea? area;
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = const Color(0x66FFCC33);
    final border = Paint()
      ..color = const Color(0xFFCB9200)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final rect
        in [...areas, if (area != null) area!].expand((item) => item.rects)) {
      final scaled = Rect.fromLTRB(
          rect.left * size.width,
          rect.top * size.height,
          rect.right * size.width,
          rect.bottom * size.height);
      canvas.drawRect(scaled, fill);
      canvas.drawRect(scaled, border);
    }
  }

  @override
  bool shouldRepaint(TermHoverPainter oldDelegate) =>
      !identical(area, oldDelegate.area) ||
      !identical(areas, oldDelegate.areas);
}
