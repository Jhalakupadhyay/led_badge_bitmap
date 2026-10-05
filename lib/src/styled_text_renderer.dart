import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'exceptions.dart';
import 'layout.dart';

/// Renders [text] with a Flutter [TextStyle], so any font the app has
/// loaded can be used.
///
/// The result is trimmed to the lit pixels on both axes.
Future<PixelMask> styledTextToMask(
  String text, {
  required TextStyle style,
  required double threshold,
}) async {
  if (text.isEmpty) {
    throw const EmptyContentException('Text must not be empty.');
  }

  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: style.copyWith(color: const Color(0xFF000000)),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  final width = painter.width.ceil();
  final height = painter.height.ceil();
  if (width == 0 || height == 0) {
    painter.dispose();
    throw const EmptyContentException('Text rendered to an empty area.');
  }

  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), Offset.zero);
  painter.dispose();
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  if (data == null) {
    throw const EmptyContentException('Text could not be rasterised.');
  }

  // Text is drawn opaque on a transparent canvas, so alpha is the coverage.
  final cutoff = (threshold * 255).round();
  final mask = PixelMask(width, height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (data.getUint8((y * width + x) * 4 + 3) >= cutoff) mask.set(x, y);
    }
  }
  final trimmed = mask.trimmed();
  if (trimmed == null) {
    throw const EmptyContentException(
      'Text has no visible pixels. It may be only whitespace.',
    );
  }
  return trimmed;
}
