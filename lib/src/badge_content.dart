part of 'badge_bitmap.dart';

/// A monochrome content strip as tall as the badge and as wide as its
/// content needs.
///
/// Unlike a [BadgeBitmap], a strip can be wider than the badge. Badges show
/// long content by scrolling it, so a strip is the source those frames are
/// cut from.
///
/// Pixels are addressed as `(x, y)` with the origin in the top-left corner.
/// A `true` pixel is a lit LED. Instances are immutable and offer the same
/// encoders as [BadgeBitmap].
@immutable
class BadgeContent with _PixelGrid {
  const BadgeContent._(this.width, this.height, this._pixels);

  /// Creates a strip from rows of pixels, top row first.
  ///
  /// Every row must have the same, non-zero length.
  factory BadgeContent.fromRows(List<List<bool>> rows) {
    final (width, pixels) = _parseRows(rows);
    return BadgeContent._(width, rows.length, pixels);
  }

  /// Wraps a row-major buffer of `0`/`1` values without copying.
  @internal
  factory BadgeContent.fromBuffer(int width, int height, Uint8List pixels) =>
      BadgeContent._(width, height, pixels);

  /// Width of the content, in pixels. May be larger than the badge.
  @override
  final int width;

  /// Height of the strip, in pixels. Always the badge height.
  @override
  final int height;

  @override
  final Uint8List _pixels;

  /// Returns a copy with every pixel flipped.
  BadgeContent inverted() => BadgeContent._(width, height, _invertedPixels());

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BadgeContent ||
        other.width != width ||
        other.height != height) {
      return false;
    }
    return _samePixels(other);
  }

  @override
  int get hashCode => _pixelHash;

  @override
  String toString() => 'BadgeContent(${width}x$height, $litPixelCount lit)';
}
