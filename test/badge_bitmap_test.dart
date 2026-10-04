import 'package:flutter_test/flutter_test.dart';
import 'package:led_badge_bitmap/led_badge_bitmap.dart';

void main() {
  // A 10x2 bitmap: the top row has columns 0 and 9 lit, the bottom row is
  // fully lit.
  final bitmap = BadgeBitmap.fromRows([
    [true, false, false, false, false, false, false, false, false, true],
    List.filled(10, true),
  ]);

  test('toHexSegments packs 8-column segments, one byte per row', () {
    // Segment 0: 10000000, 11111111. Segment 1 (padded): 01000000, 11000000.
    expect(bitmap.toHexSegments(), ['80FF', '40C0']);
    expect(bitmap.toBytes(), [0x80, 0xFF, 0x40, 0xC0]);
  });

  test('toColumnWords sets bit n for row n', () {
    expect(bitmap.toColumnWords(), [3, 2, 2, 2, 2, 2, 2, 2, 2, 3]);
  });

  test('inverted flips every pixel', () {
    final inverted = bitmap.inverted();

    expect(inverted.litPixelCount, 20 - bitmap.litPixelCount);
    expect(inverted.inverted(), bitmap);
  });

  test('toAsciiArt draws one line per row', () {
    expect(bitmap.toAsciiArt(), '#........#\n##########');
  });

  test('pixelAt checks bounds', () {
    expect(bitmap.pixelAt(9, 0), isTrue);
    expect(() => bitmap.pixelAt(10, 0), throwsRangeError);
  });

  test('fromRows rejects ragged or empty input', () {
    expect(
      () => BadgeBitmap.fromRows([
        [true],
        [true, false],
      ]),
      throwsArgumentError,
    );
    expect(() => BadgeBitmap.fromRows([]), throwsArgumentError);
  });

  test('blank creates an unlit bitmap', () {
    final blank = BadgeBitmap.blank(width: 44, height: 11);

    expect(blank.litPixelCount, 0);
    expect(blank.toHexSegments(), List.filled(6, '0' * 22));
  });

  test('equality compares size and pixels', () {
    expect(
      BadgeBitmap.blank(width: 2, height: 2),
      BadgeBitmap.fromRows([
        [false, false],
        [false, false],
      ]),
    );
    expect(
      BadgeBitmap.blank(width: 2, height: 2),
      isNot(BadgeBitmap.blank(width: 4, height: 1)),
    );
  });
}
