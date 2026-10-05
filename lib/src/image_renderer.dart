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
  /// For a badge-sized bitmap, throws [ContentOverflowException] when the
  /// scaled content is wider than the badge, i.e. the image is too wide for
  /// the badge's ratio. A content strip takes whatever width it needs.
  fitHeight,

  /// Scales the content down (or up) until it fits inside the badge, keeping
  /// its aspect ratio. Never overflows.
  ///
  /// A content strip has no width limit, so there this matches [fitHeight].
  contain,

  /// Uses the content at its original pixel size, for images already drawn
  /// as pixel art.
  ///
  /// Throws [ContentOverflowException] when the content is larger than the
  /// badge. A content strip only checks the height.
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
///
/// A `null` [width] means the content may be as wide as it needs, as for a
/// content strip; only [height] is then enforced.
PixelMask imageToMask(
  Uint8List bytes, {
  required int? width,
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
        final heightScale = height / contentHeight;
        final scale = width == null
            ? heightScale
            : math.min(width / contentWidth, heightScale);
        return (
          width == null
              ? math.max(1, (contentWidth * scale).round())
              : (contentWidth * scale).round().clamp(1, width),
          (contentHeight * scale).round().clamp(1, height),
        );
      }(),
  };
  if ((width != null && targetWidth > width) || targetHeight > height) {
    throw ContentOverflowException(
      requiredWidth: targetWidth,
      requiredHeight: targetHeight,
      // A strip has room for any width, so only the height overflows.
      availableWidth: width ?? targetWidth,
      availableHeight: height,
    );
  }

  // Area-average the ink levels into the target grid, then threshold. Each
  // target pixel covers a fractional span of source pixels, and source
  // pixels on a span edge count by how much of them falls inside it.
  final rowWeights = _spanWeights(top, contentHeight, targetHeight);
  final columnWeights = _spanWeights(left, contentWidth, targetWidth);
  final area = contentWidth / targetWidth * (contentHeight / targetHeight);
  // Tolerance for rounding in the fractional weights.
  final minimum = cutoff * area - 1e-6;
  final mask = PixelMask(targetWidth, targetHeight);
  for (var ty = 0; ty < targetHeight; ty++) {
    for (var tx = 0; tx < targetWidth; tx++) {
      var sum = 0.0;
      for (final (y, rowWeight) in rowWeights[ty]) {
        for (final (x, columnWeight) in columnWeights[tx]) {
          sum += level[y * image.width + x] * rowWeight * columnWeight;
        }
      }
      if (sum >= minimum) mask.set(tx, ty);
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

/// Splits [sourceLength] source pixels starting at [start] into
/// [targetLength] equal spans, returning for each span the source indices it
/// overlaps and by how much (from 0 to 1).
List<List<(int, double)>> _spanWeights(
  int start,
  int sourceLength,
  int targetLength,
) {
  final step = sourceLength / targetLength;
  return List.generate(targetLength, (t) {
    final from = t * step;
    final to = (t + 1) * step;
    final weights = <(int, double)>[];
    for (var s = from.floor(); s < to.ceil() && s < sourceLength; s++) {
      final overlap = math.min(to, s + 1.0) - math.max(from, s.toDouble());
      if (overlap > 0) weights.add((start + s, overlap));
    }
    return weights;
  }, growable: false);
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
