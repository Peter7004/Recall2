import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const recallLogoAsset = 'web/branding/recall-logo.png';
const recallStartupDuration = Duration(milliseconds: 700);
const _sourceSize = 1254.0;
// Viewport crops preserve the supplied artwork and lettering without a font substitute.
const _bookRegion = Rect.fromLTWH(380, 294, 568, 495);
const _wordmarkRegion = Rect.fromLTWH(344, 794, 570, 163);
const _fullRegion = Rect.fromLTWH(340, 290, 608, 676);

class _LogoRegion extends StatelessWidget {
  const _LogoRegion({required this.region});
  final Rect region;

  @override
  Widget build(BuildContext context) => ClipRect(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: region.width,
            height: region.height,
            child: Stack(children: [
              Positioned(
                left: -region.left,
                top: -region.top,
                width: _sourceSize,
                height: _sourceSize,
                child: Image(
                  image: kIsWeb
                      ? NetworkImage(Uri.base
                          .resolve('branding/recall-logo.png')
                          .toString())
                      : const AssetImage(recallLogoAsset),
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                  excludeFromSemantics: true,
                ),
              ),
            ]),
          ),
        ),
      );
}

class RecallHeaderBrand extends StatelessWidget {
  const RecallHeaderBrand({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Recall',
        image: true,
        child: const SizedBox(
          height: 44,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox.square(
                dimension: 38, child: _LogoRegion(region: _bookRegion)),
            SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                    width: 94,
                    height: 27,
                    child: _LogoRegion(region: _wordmarkRegion)),
                SizedBox(height: 2),
                Text('영어·전기공학 사전',
                    style: TextStyle(
                        color: Color(0xFF666570),
                        fontSize: 9,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ]),
        ),
      );
}

class RecallLoadingScreen extends StatelessWidget {
  const RecallLoadingScreen({super.key, this.animate = true});
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    return ColoredBox(
      color: Colors.white,
      child: Semantics(
        label: 'Recall 로딩 중',
        liveRegion: true,
        child: LayoutBuilder(builder: (context, constraints) {
          final width = math
              .min(
                  228.0,
                  math.min(
                      constraints.maxWidth - 64,
                      (constraints.maxHeight - 64) *
                          _fullRegion.width /
                          _fullRegion.height))
              .clamp(0.0, 228.0)
              .toDouble();
          return Center(
            child: TweenAnimationBuilder<double>(
              tween:
                  Tween(begin: animate && !reducedMotion ? 0.0 : 1.0, end: 1.0),
              duration: recallStartupDuration,
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Opacity(
                opacity: 0.35 + 0.65 * value,
                child: Transform.translate(
                    offset: Offset(0, 8 * (1 - value)), child: child),
              ),
              child: SizedBox(
                width: width,
                height: width * _fullRegion.height / _fullRegion.width,
                child: const _LogoRegion(region: _fullRegion),
              ),
            ),
          );
        }),
      ),
    );
  }
}
