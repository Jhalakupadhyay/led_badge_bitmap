/// Base class for every error raised while generating a badge bitmap.
///
/// Catch this type to handle all generation failures in one place, or catch
/// a subclass to react to a specific failure.
sealed class BadgeBitmapException implements Exception {
  const BadgeBitmapException(this.message);

  /// A human-readable description of the failure.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when the rendered text or image does not fit inside the badge.
///
/// [requiredWidth] and [requiredHeight] describe the size the content needs,
/// so callers can tell the user how much to shorten the text or which badge
/// size would work.
final class ContentOverflowException extends BadgeBitmapException {
  ContentOverflowException({
    required this.requiredWidth,
    required this.requiredHeight,
    required this.availableWidth,
    required this.availableHeight,
  }) : super(
          'Content needs ${requiredWidth}x$requiredHeight pixels but the '
          'badge is only ${availableWidth}x$availableHeight.',
        );

  /// Width, in pixels, the content needs.
  final int requiredWidth;

  /// Height, in pixels, the content needs.
  final int requiredHeight;

  /// Width, in pixels, of the badge.
  final int availableWidth;

  /// Height, in pixels, of the badge.
  final int availableHeight;

  /// Whether the content is wider than the badge.
  bool get overflowsWidth => requiredWidth > availableWidth;

  /// Whether the content is taller than the badge.
  bool get overflowsHeight => requiredHeight > availableHeight;
}

/// Thrown when text contains characters the built-in badge font cannot draw.
final class UnsupportedCharacterException extends BadgeBitmapException {
  UnsupportedCharacterException(this.characters)
      : super(
          'The built-in badge font has no glyph for: '
          '${characters.map((c) => '"$c"').join(', ')}.',
        );

  /// The distinct characters that have no glyph, in order of appearance.
  final List<String> characters;
}

/// Thrown when image bytes cannot be decoded.
final class ImageDecodeException extends BadgeBitmapException {
  const ImageDecodeException([
    super.message = 'The image data could not be decoded. Supported formats '
        'include PNG, JPEG, GIF, BMP, WebP, TGA, TIFF, ICO and PSD.',
  ]);
}

/// Thrown when the input has nothing to draw, such as empty text or an image
/// with no lit pixels after thresholding.
final class EmptyContentException extends BadgeBitmapException {
  const EmptyContentException(super.message);
}
