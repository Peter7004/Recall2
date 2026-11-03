import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'thumbnail_queue.dart';

class PdfThumbnail extends StatefulWidget {
  const PdfThumbnail({super.key, required this.page, required this.queue});
  final PdfPage page;
  final ThumbnailQueue<ui.Image> queue;
  @override
  State<PdfThumbnail> createState() => _PdfThumbnailState();
}

class _PdfThumbnailState extends State<PdfThumbnail> {
  ThumbnailJob<ui.Image>? _job;
  ui.Image? _image;
  bool _loading = true;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    final page = widget.page;
    final generation = ++_generation;
    final stopped = Completer<void>();
    PdfPageRenderCancellationToken? cancellation;
    _job = widget.queue.submit(() async {
      final loaded = await page.waitForLoaded(cancelLoading: stopped.future);
      if (loaded == null || stopped.isCompleted) return null;
      cancellation = loaded.createCancellationToken();
      if (loaded.width <= 0 ||
          loaded.height <= 0 ||
          !loaded.width.isFinite ||
          !loaded.height.isFinite) {
        throw const FormatException('Invalid PDF page dimensions');
      }
      final scale = math.min(160 / loaded.width, 210 / loaded.height);
      final width = (loaded.width * scale).ceil().clamp(1, 160);
      final height = (loaded.height * scale).ceil().clamp(1, 210);
      return loaded.renderForDisplay(
          width: width,
          height: height,
          fullWidth: width.toDouble(),
          fullHeight: height.toDouble(),
          backgroundColor: 0xFFFFFFFF,
          priority: PdfPageRenderPriority.low,
          cancellationToken: cancellation,
          pixelSizeThreshold: 210);
    }, onCancel: () {
      if (!stopped.isCompleted) stopped.complete();
      cancellation?.cancel();
    });
    _acceptImage(_job!.future, generation);
  }

  void _acceptImage(Future<ui.Image?> future, int generation) {
    unawaited(future.then<void>((image) {
      if (!mounted || generation != _generation) {
        image?.dispose();
        return;
      }
      setState(() {
        _image = image;
        _loading = false;
      });
    }, onError: (Object _, StackTrace __) {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }));
  }

  @override
  void didUpdateWidget(PdfThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.page, widget.page) ||
        oldWidget.queue != widget.queue) {
      _job?.cancel();
      _image?.dispose();
      _image = null;
      _loading = true;
      _start();
    }
  }

  @override
  void dispose() {
    _generation++;
    _job?.cancel();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
      color: Colors.white,
      child: _image != null
          ? RawImage(image: _image, fit: BoxFit.contain)
          : _loading
              ? const Center(
                  child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator()))
              : Center(
                  child: TextButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('미리보기 재시도'),
                      onPressed: () {
                        setState(() => _loading = true);
                        _start();
                      })));
}
