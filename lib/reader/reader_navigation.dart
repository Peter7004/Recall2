import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One-based physical PDF page numbers, not printed page labels.
class ReaderPageDialog extends StatefulWidget {
  const ReaderPageDialog(
      {super.key, required this.page, required this.pageCount});
  final int page, pageCount;

  @override
  State<ReaderPageDialog> createState() => _ReaderPageDialogState();
}

class _ReaderPageDialogState extends State<ReaderPageDialog> {
  late final _input = TextEditingController(text: '${widget.page}')
    ..selection =
        TextSelection(baseOffset: 0, extentOffset: '${widget.page}'.length);
  String? _error;

  void _submit() {
    final text = _input.text.trim();
    final page = RegExp(r'^[0-9]+$').hasMatch(text) ? int.tryParse(text) : null;
    if (page == null || page < 1 || page > widget.pageCount) {
      setState(() => _error = '1부터 ${widget.pageCount} 사이의 정수를 입력해 주세요.');
      return;
    }
    Navigator.of(context).pop(page);
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('페이지로 이동'),
        content: SizedBox(
            width: 320,
            child: TextField(
              controller: _input,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.go,
              decoration: InputDecoration(
                  labelText: 'PDF 페이지 번호',
                  helperText: '전체 ${widget.pageCount}쪽 · 책에 인쇄된 쪽수와 다를 수 있습니다.',
                  helperMaxLines: 2,
                  errorText: _error,
                  errorMaxLines: 2),
              onSubmitted: (_) => _submit(),
            )),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소')),
          FilledButton(onPressed: _submit, child: const Text('이동')),
        ],
      );
}

/// A document-page rail, independent of page layout and zoom. Dragging previews
/// the destination; only release navigates, avoiding a render on every update.
class ReaderPageRail extends StatefulWidget {
  const ReaderPageRail(
      {super.key,
      required this.page,
      required this.pageCount,
      required this.onNavigate});
  final int page, pageCount;
  final ValueChanged<int> onNavigate;

  @override
  State<ReaderPageRail> createState() => _ReaderPageRailState();
}

class _ReaderPageRailState extends State<ReaderPageRail> {
  int? _preview;
  bool _cancelled = false;

  int _pageAt(double y, double height) {
    final extent = height - 48;
    if (extent <= 0 || widget.pageCount <= 1) return 1;
    final fraction = ((y - 24) / extent).clamp(0.0, 1.0);
    return (1 + fraction * (widget.pageCount - 1)).round();
  }

  void _navigate(int page) =>
      widget.onNavigate(page.clamp(1, widget.pageCount));

  @override
  Widget build(BuildContext context) {
    if (widget.pageCount <= 1) return const SizedBox.shrink();
    final page = (_preview ?? widget.page).clamp(1, widget.pageCount);
    return LayoutBuilder(builder: (context, constraints) {
      final height = constraints.maxHeight;
      if (height < 48) return const SizedBox.shrink();
      final color = Theme.of(context).colorScheme;
      return Semantics(
          label: '페이지 탐색',
          value: '$page / ${widget.pageCount}',
          increasedValue: page < widget.pageCount
              ? '${page + 1} / ${widget.pageCount}'
              : null,
          decreasedValue: page > 1 ? '${page - 1} / ${widget.pageCount}' : null,
          onIncrease:
              page < widget.pageCount ? () => _navigate(page + 1) : null,
          onDecrease: page > 1 ? () => _navigate(page - 1) : null,
          child: Focus(
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                final target = switch (event.logicalKey) {
                  LogicalKeyboardKey.arrowDown => page + 1,
                  LogicalKeyboardKey.arrowUp => page - 1,
                  LogicalKeyboardKey.home => 1,
                  LogicalKeyboardKey.end => widget.pageCount,
                  _ => null,
                };
                if (target == null) return KeyEventResult.ignored;
                _navigate(target);
                return KeyEventResult.handled;
              },
              child: ExcludeSemantics(
                  child: Listener(
                      onPointerDown: (_) => _cancelled = false,
                      onPointerCancel: (_) => _cancelled = true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) => _navigate(
                            _pageAt(details.localPosition.dy, height)),
                        onVerticalDragStart: (details) => setState(() =>
                            _preview =
                                _pageAt(details.localPosition.dy, height)),
                        onVerticalDragUpdate: (details) => setState(() =>
                            _preview =
                                _pageAt(details.localPosition.dy, height)),
                        onVerticalDragEnd: (_) {
                          final target = _preview;
                          setState(() => _preview = null);
                          if (target != null && !_cancelled) _navigate(target);
                        },
                        onVerticalDragCancel: () =>
                            setState(() => _preview = null),
                        child: Stack(children: [
                          Positioned(
                              right: 22,
                              top: 24,
                              bottom: 24,
                              child: Container(
                                  width: 4, color: color.outlineVariant)),
                          Positioned(
                              right: 0,
                              top: (height - 48) *
                                  (page - 1) /
                                  (widget.pageCount - 1),
                              width: 48,
                              height: 48,
                              child: Material(
                                  color: _preview == null
                                      ? color.surfaceContainerHighest
                                      : color.primary,
                                  elevation: 2,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Center(
                                      child: FittedBox(
                                          child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Text(
                                        _preview == null
                                            ? '$page'
                                            : '$page / ${widget.pageCount}',
                                        style: TextStyle(
                                            color: _preview == null
                                                ? color.onSurface
                                                : color.onPrimary)),
                                  ))))),
                        ]),
                      )))));
    });
  }
}
