import 'dart:typed_data';

import 'package:meta/meta.dart';

/// A monochrome bitmap sized exactly to an LED badge.
///
/// Pixels are addressed as `(x, y)` with the origin in the top-left corner.
/// A `true` pixel is a lit LED.
///
/// Instances are immutable. Use the encoders ([toHexSegments], [toBytes],
/// [toColumnWords]) to get the data in the shape your badge or protocol
/// expects.
@immutable
class BadgeBitmap {
  const BadgeBitmap._(this.width, this.height, this._pixels);

  /// Creates a bitmap from rows of pixels, top row first.
  ///
  /// Every row must have the same, non-zero length.
  factory BadgeBitmap.fromRows(List<List<bool>> rows) {
    if (rows.isEmpty || rows.first.isEmpty) {
      throw ArgumentError.value(rows, 'rows', 'must not be empty');
    }
    final width = rows.first.length;
    final pixels = Uint8List(width * rows.length);
    for (var y = 0; y < rows.length; y++) {
      final row = rows[y];
      if (row.length != width) {
        throw ArgumentError.value(
          rows,
          'rows',
          'row $y has ${row.length} pixels, expected $width',
        );
      }
      for (var x = 0; x < width; x++) {
        if (row[x]) pixels[y * width + x] = 1;
      }
    }
    return BadgeBitmap._(width, rows.length, pixels);
  }

  /// Creates an all-off bitmap of the given size.
  factory BadgeBitmap.blank({required int width, required int height}) {
    checkBadgeSize(width, height);
    return BadgeBitmap._(width, height, Uint8List(width * height));
  }

  /// Wraps a row-major buffer of `0`/`1` values without copying.
  @internal
  factory BadgeBitmap.fromBuffer(int width, int height, Uint8List pixels) =>
      BadgeBitmap._(width, height, pixels);

  /// Width of the badge, in pixels.
  final int width;

  /// Height of the badge, in pixels.
  final int height;

  final Uint8List _pixels;

  /// Whether the LED at column [x], row [y] is lit.
  bool pixelAt(int x, int y) {
    RangeError.checkValueInInterval(x, 0, width - 1, 'x');
    RangeError.checkValueInInterval(y, 0, height - 1, 'y');
    return _pixels[y * width + x] == 1;
  }

  /// The pixels as rows, top row first.
  List<List<bool>> get rows => List.generate(
        height,
        (y) => List.generate(width, (x) => _pixels[y * width + x] == 1),
        growable: false,
      );

  /// Number of lit pixels.
  int get litPixelCount => _pixels.where((p) => p == 1).length;

  /// Returns a copy with every pixel flipped.
  BadgeBitmap inverted() {
    final flipped = Uint8List(_pixels.length);
    for (var i = 0; i < _pixels.length; i++) {
      flipped[i] = _pixels[i] ^ 1;
    }
    return BadgeBitmap._(width, height, flipped);
  }

  /// Encodes the bitmap as 8-pixel-wide segments, the format many Bluetooth
  /// LED name badges accept.
  ///
  /// The bitmap is split into 8-pixel-wide vertical segments, left to right.
  /// Each segment becomes one hex string with one byte per row, top to
  /// bottom, where the most significant bit is the leftmost pixel. If [width]
  /// is not a multiple of 8, the last segment is padded with unlit pixels.
  ///
  /// For an 11-pixel-tall badge each string is 22 hex digits.
  List<String> toHexSegments() {
    final bytes = toBytes();
    final segments = <String>[];
    for (var start = 0; start < bytes.length; start += height) {
      final buffer = StringBuffer();
      for (var i = start; i < start + height; i++) {
        buffer.write(bytes[i].toRadixString(16).padLeft(2, '0').toUpperCase());
      }
      segments.add(buffer.toString());
    }
    return segments;
  }

  /// The raw bytes behind [toHexSegments]: for each 8-pixel segment, one
  /// byte per row.
  Uint8List toBytes() {
    final segmentCount = (width + 7) ~/ 8;
    final bytes = Uint8List(segmentCount * height);
    for (var s = 0; s < segmentCount; s++) {
      for (var y = 0; y < height; y++) {
        var byte = 0;
        for (var bit = 0; bit < 8; bit++) {
          final x = s * 8 + bit;
          if (x < width && _pixels[y * width + x] == 1) {
            byte |= 0x80 >> bit;
          }
        }
        bytes[s * height + y] = byte;
      }
    }
    return bytes;
  }

  /// Encodes each column as an integer, left to right, where bit `n` is
  /// row `n` (bit 0 is the top row).
  ///
  /// This is the layout used by column-oriented displays and streaming
  /// protocols that send one 16-bit word per column.
  List<int> toColumnWords() => List.generate(width, (x) {
        var word = 0;
        for (var y = 0; y < height; y++) {
          if (_pixels[y * width + x] == 1) word |= 1 << y;
        }
        return word;
      }, growable: false);

  /// Renders the bitmap as text, one line per row, for logs and tests.
  String toAsciiArt({String on = '#', String off = '.'}) {
    final buffer = StringBuffer();
    for (var y = 0; y < height; y++) {
      if (y > 0) buffer.writeln();
      for (var x = 0; x < width; x++) {
        buffer.write(_pixels[y * width + x] == 1 ? on : off);
      }
    }
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BadgeBitmap ||
        other.width != width ||
        other.height != height) {
      return false;
    }
    for (var i = 0; i < _pixels.length; i++) {
      if (_pixels[i] != other._pixels[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(width, height, Object.hashAll(_pixels));

  @override
  String toString() => 'BadgeBitmap(${width}x$height, $litPixelCount lit)';
}

/// Validates a badge size, throwing [ArgumentError] when it is not positive.
@internal
void checkBadgeSize(int width, int height) {
  if (width <= 0) {
    throw ArgumentError.value(width, 'width', 'must be greater than zero');
  }
  if (height <= 0) {
    throw ArgumentError.value(height, 'height', 'must be greater than zero');
  }
}
