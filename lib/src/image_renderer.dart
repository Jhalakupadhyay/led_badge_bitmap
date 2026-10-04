import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'exceptions.dart';
import 'layout.dart';

/// How an image is scaled onto the badge.
enum ImageFit {
  /// Scales the content so it fills the badge height, keeping its aspect
  /// ratio.
  ///
  /// Throws [ContentOverflowException] when the scaled content is wider than
  /// the badge, i.e. the image is too wide for the badge's ratio.
  fitHeight,

  /// Scales the content down (or up) until it fits inside the badge, keeping
  /// its aspect ratio. Never overflows.
  contain,

  /// Uses the content at its original pixel size, for images already drawn
  /// as pixel art.
  ///
  /// Throws [ContentOverflowException] when the content is larger than the
  /// badge.
  none,
}

/// Which pixels of an image become lit LEDs.
enum ImageInk {
  /// Uses [opaque] for images with transparency and [dark] otherwise.
  auto,

  /// Dark pixels are lit. Transparent areas count as background.
  dark,

  /// Light pixels are lit. Transparent areas count as background.
  light,

  /// Every non-transparent pixel is lit, regardless of colour.
  opaque,
}

/// Images are downscaled to at most this many pixels on their longest side
/// before processing, which keeps memory bounded for large photos.
const int _maxWorkingSize = 1024;

/// Converts encoded image [bytes] into a mask sized for the badge.
PixelMask renderImage(
  Uint8List bytes, {
  required int width,
  required int height,
  required ImageFit fit,
  required ImageInk ink,
  required double threshold,
}) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    decoded = null;
  }
  if (decoded == null) throw const ImageDecodeException();

  var image = decoded;
  final longest = math.max(image.width, image.height);
  if (longest > _maxWorkingSize) {
    image = img.copyResize(
      image,
      width: image.width >= image.height ? _maxWorkingSize : null,
      height: image.height > image.width ? _maxWorkingSize : null,
      interpolation: img.Interpolation.average,
    );
  }

  final mode = ink == ImageInk.auto
      ? (_hasTransparency(image) ? ImageInk.opaque : ImageInk.dark)
      : ink;
  final level = _inkLevels(image, mode);
  final cutoff = (threshold * 255).round();

  // Crop to the lit content so padding around the subject is ignored.
  var left = image.width, right = -1, top = image.height, bottom = -1;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      if (level[y * image.width + x] < cutoff) continue;
      if (x < left) left = x;
      if (x > right) right = x;
      if (y < top) top = y;
      if (y > bottom) bottom = y;
    }
  }
  if (right < 0) {
    throw const EmptyContentException(
      'The image has no pixels to light. Try a different `ink` mode or '
      '`threshold`.',
    );
  }
  final contentWidth = right - left + 1;
  final contentHeight = bottom - top + 1;

  final (targetWidth, targetHeight) = switch (fit) {
    ImageFit.none => (contentWidth, contentHeight),
    ImageFit.fitHeight => (
        math.max(1, (contentWidth * height / contentHeight).round()),
        height,
      ),
    ImageFit.contain => () {
        final scale = math.min(width / contentWidth, height / contentHeight);
        return (
          (contentWidth * scale).round().clamp(1, width),
          (contentHeight * scale).round().clamp(1, height),
        );
      }(),
  };
  if (targetWidth > width || targetHeight > height) {
    throw ContentOverflowException(
      requiredWidth: targetWidth,
      requiredHeight: targetHeight,
      availableWidth: width,
      availableHeight: height,
    );
  }

  // Area-average the ink levels into the target grid, then threshold.
  final mask = PixelMask(targetWidth, targetHeight);
  for (var ty = 0; ty < targetHeight; ty++) {
    final y0 = top + ty * contentHeight ~/ targetHeight;
    final y1 = math.max(y0 + 1, top + (ty + 1) * contentHeight ~/ targetHeight);
    for (var tx = 0; tx < targetWidth; tx++) {
      final x0 = left + tx * contentWidth ~/ targetWidth;
      final x1 =
          math.max(x0 + 1, left + (tx + 1) * contentWidth ~/ targetWidth);
      var sum = 0;
      for (var y = y0; y < y1; y++) {
        for (var x = x0; x < x1; x++) {
          sum += level[y * image.width + x];
        }
      }
      if (sum >= cutoff * (y1 - y0) * (x1 - x0)) mask.set(tx, ty);
    }
  }
  if (mask.isEmpty) {
    throw EmptyContentException(
      'The image lost all detail when scaled to ${targetWidth}x$targetHeight. '
      'Try a lower `threshold` or a simpler image.',
    );
  }
  return mask;
}

bool _hasTransparency(img.Image image) {
  if (!image.hasAlpha) return false;
  for (final pixel in image) {
    if (pixel.aNormalized < 1) return true;
  }
  return false;
}

/// Returns how strongly each pixel should be lit, from 0 to 255.
Uint8List _inkLevels(img.Image image, ImageInk mode) {
  final levels = Uint8List(image.width * image.height);
  for (final pixel in image) {
    final alpha = image.hasAlpha ? pixel.aNormalized.toDouble() : 1.0;
    final luminance = 0.299 * pixel.rNormalized +
        0.587 * pixel.gNormalized +
        0.114 * pixel.bNormalized;
    final level = switch (mode) {
      // Composite over white so transparent areas read as background.
      ImageInk.dark => 1 - (luminance * alpha + (1 - alpha)),
      // Composite over black for the same reason.
      ImageInk.light => luminance * alpha,
      ImageInk.opaque || ImageInk.auto => alpha,
    };
    levels[pixel.y * image.width + pixel.x] =
        (level * 255).round().clamp(0, 255);
  }
  return levels;
}
