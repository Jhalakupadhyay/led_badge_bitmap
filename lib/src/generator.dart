import 'dart:typed_data';

import 'package:flutter/painting.dart';

import 'badge_bitmap.dart';
import 'badge_font.dart';
import 'exceptions.dart';
import 'image_renderer.dart';
import 'layout.dart';
import 'styled_text_renderer.dart';
import 'text_renderer.dart';

/// Generates [BadgeBitmap]s for a badge of a fixed size.
///
/// ```dart
/// const generator = BadgeBitmapGenerator(width: 44, height: 11);
///
/// final text = generator.fromText('Hello');
/// final logo = generator.fromImage(pngBytes);
/// ```
///
/// Every method returns a bitmap exactly [width] x [height] pixels, or throws
/// a [BadgeBitmapException] (most often a [ContentOverflowException]) when
/// the content cannot fit.
class BadgeBitmapGenerator {
  /// Creates a generator for a badge [width] pixels wide and [height] pixels
  /// tall. Both must be greater than zero.
  const BadgeBitmapGenerator({required this.width, required this.height})
      : assert(width > 0, 'width must be greater than zero'),
        assert(height > 0, 'height must be greater than zero');

  /// A generator for the common 44x11 LED name badge.
  static const BadgeBitmapGenerator standard =
      BadgeBitmapGenerator(width: 44, height: 11);

  /// Width of the badge, in pixels.
  final int width;

  /// Height of the badge, in pixels.
  final int height;

  /// Every character the built-in font used by [fromText] can draw.
  static Set<String> get supportedCharacters => badgeFontGlyphs.keys.toSet();

  /// Renders [text] with the built-in 8x11 bitmap font.
  ///
  /// This is synchronous and needs no Flutter binding. The text is drawn on
  /// a single line and centred vertically.
  ///
  /// Throws:
  /// * [ContentOverflowException] if the text is wider than the badge, or
  ///   taller (the font is 11 pixels tall; on shorter badges only the lit
  ///   rows count).
  /// * [UnsupportedCharacterException] if the text has characters outside
  ///   [supportedCharacters], unless [skipUnsupportedCharacters] is true.
  /// * [EmptyContentException] if [text] is empty or nothing drawable remains.
  BadgeBitmap fromText(
    String text, {
    BadgeAlignment alignment = BadgeAlignment.center,
    bool skipUnsupportedCharacters = false,
  }) {
    checkBadgeSize(width, height);
    final mask = renderBuiltInText(
      text,
      maxHeight: height,
      skipUnsupportedCharacters: skipUnsupportedCharacters,
    );
    return placeOnBadge(
      mask,
      width: width,
      height: height,
      alignment: alignment,
    );
  }

  /// Renders [text] with a Flutter [style], so you can use any font your app
  /// has loaded.
  ///
  /// When [style] has no `fontSize`, the badge [height] is used. Pixels whose
  /// coverage is at least [threshold] (0 to 1) are lit; lower it for thin
  /// fonts. The text is trimmed to its lit pixels before the fit check.
  ///
  /// Requires the Flutter engine, so call it after
  /// `WidgetsFlutterBinding.ensureInitialized()` (or inside a widget test).
  ///
  /// Throws [ContentOverflowException] if the rendered text does not fit, and
  /// [EmptyContentException] if [text] has no visible pixels.
  Future<BadgeBitmap> fromStyledText(
    String text, {
    TextStyle? style,
    double threshold = 0.5,
    BadgeAlignment alignment = BadgeAlignment.center,
  }) async {
    checkBadgeSize(width, height);
    _checkThreshold(threshold);
    final effectiveStyle = (style ?? const TextStyle()).copyWith(
      fontSize: style?.fontSize ?? height.toDouble(),
    );
    final mask = await renderStyledText(
      text,
      style: effectiveStyle,
      threshold: threshold,
    );
    return placeOnBadge(
      mask,
      width: width,
      height: height,
      alignment: alignment,
    );
  }

  /// Converts an encoded image (PNG, JPEG, GIF, BMP, WebP and others) into a
  /// badge bitmap.
  ///
  /// Empty space around the subject is cropped first, then the content is
  /// scaled according to [fit]. [ink] chooses which pixels light up, and a
  /// pixel lights when its ink level is at least [threshold] (0 to 1). For
  /// animated GIFs only the first frame is used.
  ///
  /// This runs synchronously and can take a while for large photos; use
  /// `Isolate.run` to keep the UI responsive.
  ///
  /// Throws:
  /// * [ContentOverflowException] if the image does not fit the badge with
  ///   the chosen [fit]. With the default [ImageFit.fitHeight] that means the
  ///   image is too wide for the badge's aspect ratio.
  /// * [ImageDecodeException] if [bytes] is not a supported image.
  /// * [EmptyContentException] if no pixels would be lit.
  BadgeBitmap fromImage(
    Uint8List bytes, {
    ImageFit fit = ImageFit.fitHeight,
    ImageInk ink = ImageInk.auto,
    double threshold = 0.5,
    BadgeAlignment alignment = BadgeAlignment.center,
  }) {
    checkBadgeSize(width, height);
    _checkThreshold(threshold);
    final mask = renderImage(
      bytes,
      width: width,
      height: height,
      fit: fit,
      ink: ink,
      threshold: threshold,
    );
    return placeOnBadge(
      mask,
      width: width,
      height: height,
      alignment: alignment,
    );
  }

  static void _checkThreshold(double threshold) {
    if (threshold <= 0 || threshold > 1) {
      throw RangeError.value(
        threshold,
        'threshold',
        'must be greater than 0 and at most 1',
      );
    }
  }
}
