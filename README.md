# led_badge_bitmap

Turn text or images into monochrome bitmaps for LED name badges.

You give it the badge's width and height in pixels plus some text or an
image. It returns a bitmap of exactly that size. If the content doesn't fit,
it throws an error that says how much space the content needed.

## Features

- Works with any badge size. A `standard` preset covers the common 44x11 badge.
- Text in the built-in 8x11 bitmap font. This is synchronous and doesn't need
  the Flutter engine.
- Text in any Flutter `TextStyle`, so you can use your app's fonts.
- Images in PNG, JPEG, GIF, BMP, WebP, TGA, TIFF, ICO or PSD format. Empty
  space around the image is cropped automatically.
- Typed errors: `ContentOverflowException`, `UnsupportedCharacterException`,
  `ImageDecodeException` and `EmptyContentException`.
- Content strips of any width for scrolling badges, with the same encoders.
- `BadgeMode` names the display modes badges support, with their codes.
- Output as hex segments, raw bytes, column words, or ASCII art.

## Installation

```sh
flutter pub add led_badge_bitmap
```

## Usage

### Text

```dart
import 'package:led_badge_bitmap/led_badge_bitmap.dart';

const generator = BadgeBitmapGenerator(width: 44, height: 11);

final bitmap = generator.fromText('Hello');
print(bitmap.toAsciiArt());
```

To use your own font, call `fromStyledText`. It needs the Flutter engine, so
call `WidgetsFlutterBinding.ensureInitialized()` first, or run it inside a
widget:

```dart
final bitmap = await generator.fromStyledText(
  'Hello',
  style: const TextStyle(fontFamily: 'PixelOperator', fontSize: 11),
);
```

### Images

```dart
final Uint8List bytes = await pickedFile.readAsBytes();

final bitmap = generator.fromImage(bytes);
```

`ImageFit` sets how the image is scaled to the badge:

| `fit`                 | Behaviour                                                                 |
| --------------------- | ------------------------------------------------------------------------- |
| `fitHeight` (default) | Scales the image to the badge height. Throws if it ends up wider than the badge. |
| `contain`             | Scales the image to fit inside the badge. Never overflows.                |
| `none`                | Keeps the original pixel size, for ready-made pixel art. Throws if larger. |

`ImageInk` sets which pixels light up:

| `ink`            | Lit pixels                                                    |
| ---------------- | ------------------------------------------------------------- |
| `auto` (default) | `opaque` for images with transparency, otherwise `dark`.      |
| `dark`           | Dark pixels. Use for black logos on white.                    |
| `light`          | Light pixels. Use for white logos on black.                   |
| `opaque`         | Any non-transparent pixel. Use for icons and clipart.         |

Use `threshold` (0 to 1, default 0.5) to make the cutoff stricter or looser.

`fromImage` runs synchronously. For large photos, run it with `Isolate.run`
so the UI doesn't stall:

```dart
final bitmap = await Isolate.run(() => generator.fromImage(bytes));
```

### Handling content that doesn't fit

```dart
try {
  final bitmap = generator.fromText(userInput);
} on ContentOverflowException catch (e) {
  showError('Too long: needs ${e.requiredWidth}px, badge has ${e.availableWidth}px.');
} on UnsupportedCharacterException catch (e) {
  showError('Cannot display: ${e.characters.join(' ')}');
} on BadgeBitmapException catch (e) {
  showError(e.message);
}
```

`BadgeBitmapException` is a sealed class, so a `switch` on it must cover every
error type.

### Content wider than the badge

LED badges scroll long content, so it does not have to fit. The `render`
methods return a `BadgeContent` strip that is as tall as the badge and as
wide as the content needs:

```dart
final strip = generator.renderText('Hello World');
strip.width;           // 74, wider than the 44-pixel badge
strip.height;          // 11
strip.toHexSegments(); // same encoders as BadgeBitmap

final styled = await generator.renderStyledText('Hello World');
final banner = generator.renderImage(bytes);
```

They only throw `ContentOverflowException` when the content is taller than
the badge. In `renderImage`, `fitHeight` and `contain` both scale the image to
the badge height, and `none` keeps its original size.

### Display modes

`BadgeMode` lists the display modes built into common LED name badges.
Each mode has the `code` badges use for it:

| Mode        | Code   | What it looks like                                             |
| ----------- | ------ | -------------------------------------------------------------- |
| `left`      | `0x00` | Content enters from the right edge and scrolls left.           |
| `right`     | `0x01` | Content enters from the left edge and scrolls right.           |
| `up`        | `0x02` | Content enters from the bottom edge and scrolls up.            |
| `down`      | `0x03` | Content enters from the top edge and scrolls down.             |
| `fixed`     | `0x04` | Content stays still and centred, so it must fit the badge.     |
| `animation` | `0x05` | Content is split into badge-wide pages shown one by one.       |
| `snowflake` | `0x06` | Rows fall into place from the top, then fall away.             |
| `picture`   | `0x07` | Two lines move outward from the centre and reveal the content. |
| `laser`     | `0x08` | A beam sweeps across and draws the content column by column.   |

```dart
final mode = BadgeMode.fromCode(0x00); // BadgeMode.left
mode.code;                              // 0
```

`fromCode` throws an `ArgumentError` for codes outside `0x00` to `0x08`.

### Using the bitmap

```dart
bitmap.width;              // 44
bitmap.pixelAt(3, 5);      // true if the LED is lit
bitmap.rows;               // List<List<bool>>, top row first

bitmap.toHexSegments();    // ['0038...', ...] 8-column segments
bitmap.toBytes();          // Uint8List of the same data
bitmap.toColumnWords();    // one int per column, bit 0 = top row
bitmap.inverted();         // background lit, content dark
```

`toHexSegments` cuts the bitmap into 8-pixel-wide strips, from left to right.
Each strip has one byte per row, and the leftmost pixel is the most
significant bit. Many Bluetooth LED name badges accept data in this format.

## Roadmap

This is an early version. The `from` methods return a single badge-sized
frame and throw `ContentOverflowException` when content is wider than the
badge, while the `render` methods return content strips of any width. The
next releases will:

- only enforce the badge size in `fixed` mode,
- generate animation frames for common badge modes (left, right, up, down,
  fixed, flash, marquee and more),
- build ready-to-send Bluetooth packets for common LED badges.

Progress is tracked in the
[issues](https://github.com/Jhalakupadhyay/led_badge_bitmap/issues).

## Example

The [example app](example/) lets you set the badge size, type text or pick an
image, and see a live LED preview.

## License

Apache License 2.0.
