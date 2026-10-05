import 'dart:typed_data';

import 'badge_bitmap.dart';
import 'exceptions.dart';

/// Where content sits horizontally when it is narrower than the badge.
///
/// Content is always centred vertically.
enum BadgeAlignment {
  /// Flush with the left edge.
  left,

  /// Centred, rounding towards the left when the gap is odd.
  center,

  /// Flush with the right edge.
  right,
}

/// A rectangular grid of `0`/`1` pixels, used while composing content.
class PixelMask {
  PixelMask(this.width, this.height) : pixels = Uint8List(width * height);

  final int width;
  final int height;
  final Uint8List pixels;

  bool get isEmpty => !pixels.contains(1);

  void set(int x, int y) => pixels[y * width + x] = 1;

  bool get(int x, int y) => pixels[y * width + x] == 1;

  /// Returns the smallest mask that holds every lit pixel, or `null` when no
  /// pixel is lit.
  PixelMask? trimmed({bool horizontal = true, bool vertical = true}) {
    var left = width, right = -1, top = height, bottom = -1;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (!get(x, y)) continue;
        if (x < left) left = x;
        if (x > right) right = x;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
      }
    }
    if (right < 0) return null;
    if (!horizontal) {
      left = 0;
      right = width - 1;
    }
    if (!vertical) {
      top = 0;
      bottom = height - 1;
    }
    final result = PixelMask(right - left + 1, bottom - top + 1);
    for (var y = top; y <= bottom; y++) {
      for (var x = left; x <= right; x++) {
        if (get(x, y)) result.set(x - left, y - top);
      }
    }
    return result;
  }
}

/// Places [content] on a blank badge, throwing [ContentOverflowException]
/// when it does not fit.
BadgeBitmap placeOnBadge(
  PixelMask content, {
  required int width,
  required int height,
  required BadgeAlignment alignment,
}) {
  if (content.width > width || content.height > height) {
    throw ContentOverflowException(
      requiredWidth: content.width,
      requiredHeight: content.height,
      availableWidth: width,
      availableHeight: height,
    );
  }
  final dx = switch (alignment) {
    BadgeAlignment.left => 0,
    BadgeAlignment.center => (width - content.width) ~/ 2,
    BadgeAlignment.right => width - content.width,
  };
  final dy = (height - content.height) ~/ 2;
  final pixels = Uint8List(width * height);
  for (var y = 0; y < content.height; y++) {
    for (var x = 0; x < content.width; x++) {
      if (content.get(x, y)) pixels[(y + dy) * width + x + dx] = 1;
    }
  }
  return BadgeBitmap.fromBuffer(width, height, pixels);
}

/// Places [content] on a strip [height] pixels tall and exactly as wide as
/// the content, throwing [ContentOverflowException] when it is too tall.
BadgeContent placeInStrip(PixelMask content, {required int height}) {
  if (content.height > height) {
    throw ContentOverflowException(
      requiredWidth: content.width,
      requiredHeight: content.height,
      // A strip has room for any width, so only the height overflows.
      availableWidth: content.width,
      availableHeight: height,
    );
  }
  final width = content.width;
  final dy = (height - content.height) ~/ 2;
  final pixels = Uint8List(width * height);
  for (var y = 0; y < content.height; y++) {
    for (var x = 0; x < width; x++) {
      if (content.get(x, y)) pixels[(y + dy) * width + x] = 1;
    }
  }
  return BadgeContent.fromBuffer(width, height, pixels);
}
