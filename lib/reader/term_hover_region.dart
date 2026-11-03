import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

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
      this.highlightAll = false});
  final bool highlightAll;
  final Object cacheKey;
  final Object? viewToken;
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

  @override
  void initState() {
    super.initState();
    if (widget.highlightAll) _loadAll();
  }

  Future<void> _loadAll() async {
    final request = ++_allRequest;
    try {
      final areas = await (_areas ??= widget.loadAreas());
      if (mounted && widget.highlightAll && request == _allRequest) {
        setState(() => _all = areas);
      }
    } catch (_) {
      if (mounted && request == _allRequest) {
        _areas = null;
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
    if (oldWidget.cacheKey != widget.cacheKey ||
        oldWidget.viewToken != widget.viewToken) {
      _timer?.cancel();
      _request++;
      _active = null;
    }
    if (oldWidget.cacheKey != widget.cacheKey ||
        oldWidget.highlightAll != widget.highlightAll) {
      _allRequest++;
      _all = const [];
      _active = null;
      _timer?.cancel();
      _request++;
      if (oldWidget.cacheKey != widget.cacheKey) _areas = null;
      if (widget.highlightAll) _loadAll();
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
        final areas = await (_areas ??= widget.loadAreas());
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
        _areas = null;
        if (mounted && request == _request) setState(() => _active = null);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _request++;
    _allRequest++;
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
