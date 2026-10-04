import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:led_badge_bitmap/led_badge_bitmap.dart';

void main() {
  group('fromText', () {
    test('renders the built-in font pixel for pixel', () {
      const generator = BadgeBitmapGenerator(width: 12, height: 11);

      final bitmap = generator.fromText('Hi');

      expect(
        bitmap.toAsciiArt(),
        '............\n'
        '##...##..##.\n'
        '##...##..##.\n'
        '##...##.....\n'
        '##...##.###.\n'
        '#######..##.\n'
        '##...##..##.\n'
        '##...##..##.\n'
        '##...##..##.\n'
        '##...##.####\n'
        '............',
      );
    });

    test('returns a bitmap of exactly the badge size', () {
      final bitmap = BadgeBitmapGenerator.standard.fromText('Hi');

      expect(bitmap.width, 44);
      expect(bitmap.height, 11);
    });

    test('aligns text horizontally and centres it vertically', () {
      const generator = BadgeBitmapGenerator(width: 20, height: 15);

      final left = generator.fromText('-', alignment: BadgeAlignment.left);
      final center = generator.fromText('-');
      final right = generator.fromText('-', alignment: BadgeAlignment.right);

      // '-' is 7 lit columns on font row 5; the 11-row font starts at row 2.
      expect(_litColumns(left), [for (var x = 0; x < 7; x++) x]);
      expect(_litColumns(center), [for (var x = 6; x < 13; x++) x]);
      expect(_litColumns(right), [for (var x = 13; x < 20; x++) x]);
      expect(_litRows(center), [7]);
    });

    test('throws ContentOverflowException when text is too wide', () {
      final error = _expectThrows<ContentOverflowException>(
        () => BadgeBitmapGenerator.standard.fromText('Hello World'),
      );

      expect(error.availableWidth, 44);
      expect(error.requiredWidth, greaterThan(44));
      expect(error.overflowsWidth, isTrue);
      expect(error.overflowsHeight, isFalse);
    });

    test('accepts text that exactly fills the width', () {
      const generator = BadgeBitmapGenerator(width: 12, height: 11);

      expect(() => generator.fromText('Hi'), returnsNormally);
      expect(
        () => const BadgeBitmapGenerator(width: 11, height: 11).fromText('Hi'),
        throwsA(isA<ContentOverflowException>()),
      );
    });

    test('uses only lit rows on badges shorter than the font', () {
      const generator = BadgeBitmapGenerator(width: 10, height: 1);

      expect(generator.fromText('-').litPixelCount, 7);
      final error = _expectThrows<ContentOverflowException>(
        () => generator.fromText('H'),
      );
      expect(error.requiredHeight, 9);
      expect(error.overflowsHeight, isTrue);
    });

    test('throws on unsupported characters unless asked to skip them', () {
      final error = _expectThrows<UnsupportedCharacterException>(
        () => BadgeBitmapGenerator.standard.fromText('Hi ☃ ☃ €'),
      );
      expect(error.characters, ['☃', '€']);

      final bitmap = BadgeBitmapGenerator.standard.fromText(
        'Hi☃',
        skipUnsupportedCharacters: true,
      );
      expect(bitmap, BadgeBitmapGenerator.standard.fromText('Hi'));
    });

    test('throws EmptyContentException for empty text', () {
      expect(
        () => BadgeBitmapGenerator.standard.fromText(''),
        throwsA(isA<EmptyContentException>()),
      );
      expect(
        () => BadgeBitmapGenerator.standard.fromText(
          '☃',
          skipUnsupportedCharacters: true,
        ),
        throwsA(isA<EmptyContentException>()),
      );
    });

    test('renders whitespace-only text as a blank badge', () {
      expect(BadgeBitmapGenerator.standard.fromText('   ').litPixelCount, 0);
    });

    test('rejects non-positive badge sizes', () {
      // ignore: prefer_const_constructors
      expect(
        () => BadgeBitmapGenerator(width: 0, height: 11).fromText('A'),
        throwsA(anyOf(isA<AssertionError>(), isA<ArgumentError>())),
      );
    });

    test('exposes the supported character set', () {
      expect(BadgeBitmapGenerator.supportedCharacters, contains('A'));
      expect(BadgeBitmapGenerator.supportedCharacters, isNot(contains('☃')));
    });
  });

  group('fromStyledText', () {
    testWidgets('renders text that fits', (tester) async {
      final bitmap = await tester.runAsync(
        () => BadgeBitmapGenerator.standard.fromStyledText(
          'AB',
          style: const TextStyle(fontSize: 10),
        ),
      );

      expect(bitmap!.width, 44);
      expect(bitmap.height, 11);
      expect(bitmap.litPixelCount, greaterThan(0));
    });

    testWidgets('throws ContentOverflowException when text is too wide',
        (tester) async {
      Object? error;
      await tester.runAsync(() async {
        try {
          await BadgeBitmapGenerator.standard.fromStyledText('ABCDEFGHIJ');
        } catch (e) {
          error = e;
        }
      });

      expect(error, isA<ContentOverflowException>());
      expect(
          (error! as ContentOverflowException).requiredWidth, greaterThan(44));
    });

    testWidgets('throws ContentOverflowException when font is too tall',
        (tester) async {
      Object? error;
      await tester.runAsync(() async {
        try {
          await BadgeBitmapGenerator.standard.fromStyledText(
            'A',
            style: const TextStyle(fontSize: 30),
          );
        } catch (e) {
          error = e;
        }
      });

      expect(error, isA<ContentOverflowException>());
      expect((error! as ContentOverflowException).overflowsHeight, isTrue);
    });
  });
}

T _expectThrows<T>(void Function() body) {
  try {
    body();
  } catch (e) {
    expect(e, isA<T>());
    return e as T;
  }
  fail('Expected $T to be thrown');
}

List<int> _litColumns(BadgeBitmap bitmap) => [
      for (var x = 0; x < bitmap.width; x++)
        if (bitmap.rows.any((row) => row[x])) x,
    ];

List<int> _litRows(BadgeBitmap bitmap) => [
      for (var y = 0; y < bitmap.height; y++)
        if (bitmap.rows[y].contains(true)) y,
    ];
