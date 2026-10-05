import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:led_badge_bitmap/led_badge_bitmap.dart';

/// Encodes a PNG of [width]x[height] filled with [color].
Uint8List _solidPng(int width, int height, img.Color color) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  img.fill(image, color: color);
  return img.encodePng(image);
}

final _black = img.ColorRgba8(0, 0, 0, 255);

void main() {
  const generator = BadgeBitmapGenerator.standard;

  group('BadgeContent', () {
    // A 10x2 strip: the top row has columns 0 and 9 lit, the bottom row is
    // fully lit.
    final content = BadgeContent.fromRows([
      [true, false, false, false, false, false, false, false, false, true],
      List.filled(10, true),
    ]);

    test('has the same encoders as BadgeBitmap', () {
      final bitmap = BadgeBitmap.fromRows(content.rows);

      expect(content.toHexSegments(), ['80FF', '40C0']);
      expect(content.toBytes(), bitmap.toBytes());
      expect(content.toColumnWords(), [3, 2, 2, 2, 2, 2, 2, 2, 2, 3]);
      expect(content.toAsciiArt(), '#........#\n##########');
      expect(content.litPixelCount, 12);
    });

    test('inverted flips every pixel', () {
      expect(content.inverted().litPixelCount, 20 - content.litPixelCount);
      expect(content.inverted().inverted(), content);
    });

    test('pixelAt checks bounds', () {
      expect(content.pixelAt(9, 0), isTrue);
      expect(() => content.pixelAt(10, 0), throwsRangeError);
    });

    test('fromRows rejects ragged or empty input', () {
      expect(
        () => BadgeContent.fromRows([
          [true],
          [true, false],
        ]),
        throwsArgumentError,
      );
      expect(() => BadgeContent.fromRows([]), throwsArgumentError);
    });

    test('is never equal to a BadgeBitmap with the same pixels', () {
      final rows = content.rows;

      expect(BadgeContent.fromRows(rows), content);
      expect(BadgeContent.fromRows(rows).hashCode, content.hashCode);
      expect(content, isNot(BadgeBitmap.fromRows(rows)));
    });
  });

  group('renderText', () {
    test('returns a strip wider than the badge for long text', () {
      final strip = generator.renderText('Hello World');

      expect(strip.width, greaterThan(44));
      expect(strip.height, 11);
      expect(
        () => generator.fromText('Hello World'),
        throwsA(isA<ContentOverflowException>()),
      );
    });

    test('is exactly as wide as the text and matches fromText pixels', () {
      const fitted = BadgeBitmapGenerator(width: 12, height: 11);

      final strip = fitted.renderText('Hi');

      expect(strip.width, 12);
      expect(strip.toAsciiArt(), fitted.fromText('Hi').toAsciiArt());
    });

    test('centres text vertically on taller badges', () {
      final strip =
          const BadgeBitmapGenerator(width: 4, height: 15).renderText('-');

      // '-' is lit on font row 5; the 11-row font starts at row 2.
      expect(strip.width, 7);
      expect(strip.height, 15);
      expect(
        [
          for (var y = 0; y < strip.height; y++)
            if (strip.rows[y].contains(true)) y,
        ],
        [7],
      );
    });

    test('throws ContentOverflowException only for height', () {
      const short = BadgeBitmapGenerator(width: 10, height: 1);

      expect(short.renderText('------').litPixelCount, 6 * 7);
      expect(
        () => short.renderText('H'),
        throwsA(
          isA<ContentOverflowException>()
              .having((e) => e.requiredHeight, 'requiredHeight', 9)
              .having((e) => e.overflowsHeight, 'overflowsHeight', isTrue)
              .having((e) => e.overflowsWidth, 'overflowsWidth', isFalse),
        ),
      );
    });

    test('reports unsupported characters and empty text', () {
      expect(
        () => generator.renderText('Hi ☃'),
        throwsA(isA<UnsupportedCharacterException>()),
      );
      expect(
        generator.renderText('Hi☃', skipUnsupportedCharacters: true),
        generator.renderText('Hi'),
      );
      expect(
        () => generator.renderText(''),
        throwsA(isA<EmptyContentException>()),
      );
    });
  });

  group('renderStyledText', () {
    testWidgets('returns a strip wider than the badge for long text',
        (tester) async {
      final strip = await tester.runAsync(
        () => generator.renderStyledText('ABCDEFGHIJ'),
      );

      expect(strip!.width, greaterThan(44));
      expect(strip.height, 11);
      expect(strip.litPixelCount, greaterThan(0));
    });

    testWidgets('throws ContentOverflowException when font is too tall',
        (tester) async {
      Object? error;
      await tester.runAsync(() async {
        try {
          await generator.renderStyledText(
            'A',
            style: const TextStyle(fontSize: 30),
          );
        } catch (e) {
          error = e;
        }
      });

      expect(error, isA<ContentOverflowException>());
      expect((error! as ContentOverflowException).overflowsHeight, isTrue);
      expect((error! as ContentOverflowException).overflowsWidth, isFalse);
    });
  });

  group('renderImage', () {
    test('fitHeight scales wide images to the badge height', () {
      final bytes = _solidPng(100, 10, _black);

      final strip = generator.renderImage(bytes);

      // 100x10 scaled to height 11 is 110x11.
      expect(strip.width, 110);
      expect(strip.height, 11);
      expect(strip.litPixelCount, 110 * 11);
    });

    test('contain also fills the height, since there is no width limit', () {
      final bytes = _solidPng(100, 10, _black);

      expect(
        generator.renderImage(bytes, fit: ImageFit.contain),
        generator.renderImage(bytes),
      );
    });

    test('none keeps the original size and only checks the height', () {
      final wide = generator.renderImage(
        _solidPng(60, 5, _black),
        fit: ImageFit.none,
      );
      expect(wide.width, 60);
      expect(wide.height, 11);
      expect(wide.litPixelCount, 60 * 5);

      expect(
        () => generator.renderImage(
          _solidPng(10, 12, _black),
          fit: ImageFit.none,
        ),
        throwsA(
          isA<ContentOverflowException>()
              .having((e) => e.requiredHeight, 'requiredHeight', 12)
              .having((e) => e.overflowsWidth, 'overflowsWidth', isFalse),
        ),
      );
    });

    test('reports blank images, invalid bytes and bad thresholds', () {
      expect(
        () => generator.renderImage(
          _solidPng(10, 10, img.ColorRgba8(255, 255, 255, 255)),
        ),
        throwsA(isA<EmptyContentException>()),
      );
      expect(
        () => generator.renderImage(Uint8List.fromList([1, 2, 3, 4])),
        throwsA(isA<ImageDecodeException>()),
      );
      expect(
        () => generator.renderImage(_solidPng(4, 4, _black), threshold: 0),
        throwsRangeError,
      );
    });
  });
}
