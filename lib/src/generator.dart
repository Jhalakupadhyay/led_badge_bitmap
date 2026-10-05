import 'dart:typed_data';

import 'package:flutter/painting.dart';

import 'badge_bitmap.dart';
import 'badge_font.dart';
import 'exceptions.dart';
import 'image_renderer.dart';
import 'layout.dart';
import 'styled_text_renderer.dart';
import 'text_renderer.dart';

/// Generates [BadgeBitmap]s and [BadgeContent] strips for a badge of a fixed
/// size.
///
/// ```dart
/// const generator = BadgeBitmapGenerator(width: 44, height: 11);
///
/// final text = generator.fromText('Hello');
/// final logo = generator.fromImage(pngBytes);
/// final strip = generator.renderText('Hello World');
/// ```
///
/// The `from` methods return a bitmap exactly [width] x [height] pixels, or
/// throw a [BadgeBitmapException] (most often a [ContentOverflowException])
/// when the content cannot fit.
///
/// The `render` methods return a [BadgeContent] strip [height] pixels tall
/// and as wide as the content needs, for badges that scroll. They only throw
/// [ContentOverflowException] when the content is taller than the badge.
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
    final mask = await _styledTextMask(text, style, threshold);
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
    final mask = imageToMask(
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

  /// Renders [text] with the built-in 8x11 bitmap font into a strip as wide
  /// as the text needs.
  ///
  /// Works like [fromText], except that text wider than the badge is kept
  /// whole instead of throwing. The strip is [height] pixels tall with the
  /// text centred vertically.
  ///
  /// Throws:
  /// * [ContentOverflowException] if the text is taller than the badge (the
  ///   font is 11 pixels tall; on shorter badges only the lit rows count).
  /// * [UnsupportedCharacterException] if the text has characters outside
  ///   [supportedCharacters], unless [skipUnsupportedCharacters] is true.
  /// * [EmptyContentException] if [text] is empty or nothing drawable remains.
  BadgeContent renderText(
    String text, {
    bool skipUnsupportedCharacters = false,
  }) {
    checkBadgeSize(width, height);
    final mask = renderBuiltInText(
      text,
      maxHeight: height,
      skipUnsupportedCharacters: skipUnsupportedCharacters,
    );
    return placeInStrip(mask, height: height);
  }

  /// Renders [text] with a Flutter [style] into a strip as wide as the text
  /// needs.
  ///
  /// Works like [fromStyledText], except that text wider than the badge is
  /// kept whole instead of throwing.
  ///
  /// Requires the Flutter engine, so call it after
  /// `WidgetsFlutterBinding.ensureInitialized()` (or inside a widget test).
  ///
  /// Throws [ContentOverflowException] if the rendered text is taller than
  /// the badge, and [EmptyContentException] if [text] has no visible pixels.
  Future<BadgeContent> renderStyledText(
    String text, {
    TextStyle? style,
    double threshold = 0.5,
  }) async {
    checkBadgeSize(width, height);
    final mask = await _styledTextMask(text, style, threshold);
    return placeInStrip(mask, height: height);
  }

  /// Converts an encoded image (PNG, JPEG, GIF, BMP, WebP and others) into a
  /// strip as wide as the scaled image needs.
  ///
  /// Works like [fromImage], except that the badge width is not a limit:
  /// [ImageFit.fitHeight] and [ImageFit.contain] both scale the content to
  /// the badge height, and [ImageFit.none] keeps its original size.
  ///
  /// Throws:
  /// * [ContentOverflowException] if the image is taller than the badge,
  ///   which can only happen with [ImageFit.none].
  /// * [ImageDecodeException] if [bytes] is not a supported image.
  /// * [EmptyContentException] if no pixels would be lit.
  BadgeContent renderImage(
    Uint8List bytes, {
    ImageFit fit = ImageFit.fitHeight,
    ImageInk ink = ImageInk.auto,
    double threshold = 0.5,
  }) {
    checkBadgeSize(width, height);
    _checkThreshold(threshold);
    final mask = imageToMask(
      bytes,
      width: null,
      height: height,
      fit: fit,
      ink: ink,
      threshold: threshold,
    );
    return placeInStrip(mask, height: height);
  }

  Future<PixelMask> _styledTextMask(
    String text,
    TextStyle? style,
    double threshold,
  ) {
    _checkThreshold(threshold);
    final effectiveStyle = (style ?? const TextStyle()).copyWith(
      fontSize: style?.fontSize ?? height.toDouble(),
    );
    return styledTextToMask(
      text,
      style: effectiveStyle,
      threshold: threshold,
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
