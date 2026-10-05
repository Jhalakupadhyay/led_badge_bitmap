import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:led_badge_bitmap/led_badge_bitmap.dart';

/// Encodes a PNG of [width]x[height] filled with [background], with a
/// [foreground] rectangle drawn from ([x1], [y1]) to ([x2], [y2]) inclusive.
Uint8List _png({
  required int width,
  required int height,
  img.Color? background,
  img.Color? foreground,
  int x1 = 0,
  int y1 = 0,
  int? x2,
  int? y2,
}) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  img.fill(image, color: background ?? img.ColorRgba8(255, 255, 255, 255));
  if (foreground != null) {
    img.fillRect(
      image,
      x1: x1,
      y1: y1,
      x2: x2 ?? width - 1,
      y2: y2 ?? height - 1,
      color: foreground,
    );
  }
  return img.encodePng(image);
}

final _black = img.ColorRgba8(0, 0, 0, 255);
final _white = img.ColorRgba8(255, 255, 255, 255);
final _transparent = img.ColorRgba8(0, 0, 0, 0);

void main() {
  const generator = BadgeBitmapGenerator.standard;

  group('fromImage', () {
    test('crops padding and scales the content to the badge height', () {
      // A 40x20 black block surrounded by white padding.
      final bytes = _png(
        width: 100,
        height: 60,
        foreground: _black,
        x1: 30,
        y1: 20,
        x2: 69,
        y2: 39,
      );

      final bitmap = generator.fromImage(bytes);

      // 40x20 scaled to height 11 is 22x11, centred on the 44-wide badge.
      expect(bitmap.litPixelCount, 22 * 11);
      expect(bitmap.pixelAt(11, 0), isTrue);
      expect(bitmap.pixelAt(32, 10), isTrue);
      expect(bitmap.pixelAt(10, 5), isFalse);
      expect(bitmap.pixelAt(33, 5), isFalse);
    });

    test('throws ContentOverflowException when the image is too wide', () {
      final bytes = _png(width: 100, height: 10, foreground: _black);

      expect(
        () => generator.fromImage(bytes),
        throwsA(
          isA<ContentOverflowException>()
              .having((e) => e.requiredWidth, 'requiredWidth', 110)
              .having((e) => e.requiredHeight, 'requiredHeight', 11),
        ),
      );
    });

    test('contain shrinks wide images to fit instead of throwing', () {
      final bytes = _png(width: 100, height: 10, foreground: _black);

      final bitmap = generator.fromImage(bytes, fit: ImageFit.contain);

      expect(bitmap.litPixelCount, 44 * 4);
    });

    test('none keeps pixel art at its original size', () {
      final exact = _png(width: 44, height: 11, foreground: _black);
      expect(
        generator.fromImage(exact, fit: ImageFit.none).litPixelCount,
        44 * 11,
      );

      final tooBig = _png(width: 45, height: 11, foreground: _black);
      expect(
        () => generator.fromImage(tooBig, fit: ImageFit.none),
        throwsA(isA<ContentOverflowException>()),
      );
    });

    test('auto ink lights opaque pixels of transparent images', () {
      // A white shape on a transparent background would vanish in dark mode.
      final bytes = _png(
        width: 20,
        height: 20,
        background: _transparent,
        foreground: _white,
        x1: 5,
        y1: 5,
        x2: 14,
        y2: 14,
      );

      expect(generator.fromImage(bytes).litPixelCount, 11 * 11);
      expect(
        () => generator.fromImage(bytes, ink: ImageInk.dark),
        throwsA(isA<EmptyContentException>()),
      );
    });

    test('light ink lights bright pixels', () {
      final bytes = _png(
        width: 20,
        height: 20,
        background: _black,
        foreground: _white,
        x1: 5,
        y1: 5,
        x2: 14,
        y2: 14,
      );

      expect(
        generator.fromImage(bytes, ink: ImageInk.light).litPixelCount,
        11 * 11,
      );
    });

    test('keeps symmetric shapes symmetric when the scale is uneven', () {
      // A 61-pixel circle scaled to 11 rows is about 5.5 source pixels per
      // LED, so whole-pixel bins would sample its two halves differently.
      final image = img.Image(width: 66, height: 66, numChannels: 4);
      img.fill(image, color: _white);
      img.fillCircle(image, x: 33, y: 33, radius: 30, color: _black);

      final bitmap = generator.fromImage(img.encodePng(image));
      final rows =
          bitmap.rows.map((row) => row.sublist(16, 27)).toList(growable: false);

      expect(bitmap.litPixelCount, greaterThan(0));
      expect(rows.reversed.toList(), rows, reason: 'top and bottom match');
      expect(
        [for (final row in rows) row.reversed.toList()],
        rows,
        reason: 'left and right match',
      );
    });

    test('throws EmptyContentException for a blank image', () {
      expect(
        () => generator.fromImage(_png(width: 10, height: 10)),
        throwsA(isA<EmptyContentException>()),
      );
    });

    test('throws ImageDecodeException for invalid bytes', () {
      expect(
        () => generator.fromImage(Uint8List.fromList([1, 2, 3, 4])),
        throwsA(isA<ImageDecodeException>()),
      );
    });

    test('rejects thresholds outside (0, 1]', () {
      final bytes = _png(width: 10, height: 10, foreground: _black);

      expect(
        () => generator.fromImage(bytes, threshold: 0),
        throwsRangeError,
      );
      expect(
        () => generator.fromImage(bytes, threshold: 1.5),
        throwsRangeError,
      );
    });
  });
}
