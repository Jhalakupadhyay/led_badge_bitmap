import 'badge_font.dart';
import 'exceptions.dart';
import 'layout.dart';

/// Width given to glyphs with no lit pixels, such as a space.
const int _blankGlyphWidth = 3;

/// Unlit columns inserted between neighbouring glyphs.
const int _glyphSpacing = 1;

/// Renders [text] with the built-in 8x11 badge font.
///
/// Each glyph is trimmed to its lit columns and separated from the next by a
/// single unlit column. The result is always [badgeFontHeight] rows tall; it
/// is only trimmed vertically when [maxHeight] is smaller than the font.
PixelMask renderBuiltInText(
  String text, {
  required int maxHeight,
  required bool skipUnsupportedCharacters,
}) {
  if (text.isEmpty) {
    throw const EmptyContentException('Text must not be empty.');
  }

  final glyphs = <List<List<bool>>>[];
  final unsupported = <String>{};
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    final hex = badgeFontGlyphs[char];
    if (hex == null) {
      unsupported.add(char);
      continue;
    }
    glyphs.add(_trimGlyph(_decodeGlyph(hex)));
  }
  if (unsupported.isNotEmpty && !skipUnsupportedCharacters) {
    throw UnsupportedCharacterException(unsupported.toList());
  }
  if (glyphs.isEmpty) {
    throw const EmptyContentException(
      'Text has no characters the built-in badge font can draw.',
    );
  }

  final width = glyphs.fold<int>(0, (sum, g) => sum + g.first.length) +
      _glyphSpacing * (glyphs.length - 1);
  final mask = PixelMask(width, badgeFontHeight);
  var offset = 0;
  for (final glyph in glyphs) {
    for (var y = 0; y < badgeFontHeight; y++) {
      for (var x = 0; x < glyph[y].length; x++) {
        if (glyph[y][x]) mask.set(offset + x, y);
      }
    }
    offset += glyph.first.length + _glyphSpacing;
  }

  if (maxHeight >= badgeFontHeight) return mask;
  // Short badges can still show text whose lit rows fit, e.g. digits.
  return mask.trimmed(horizontal: false) ?? PixelMask(width, 0);
}

List<List<bool>> _decodeGlyph(String hex) =>
    List.generate(badgeFontHeight, (y) {
      final byte = int.parse(hex.substring(y * 2, y * 2 + 2), radix: 16);
      return List.generate(
        badgeFontGlyphWidth,
        (x) => (byte >> (badgeFontGlyphWidth - 1 - x)) & 1 == 1,
      );
    });

List<List<bool>> _trimGlyph(List<List<bool>> glyph) {
  bool columnLit(int x) => glyph.any((row) => row[x]);

  var left = 0;
  while (left < badgeFontGlyphWidth && !columnLit(left)) {
    left++;
  }
  if (left == badgeFontGlyphWidth) {
    return List.generate(
      badgeFontHeight,
      (_) => List.filled(_blankGlyphWidth, false),
    );
  }
  var right = badgeFontGlyphWidth - 1;
  while (!columnLit(right)) {
    right--;
  }
  return [for (final row in glyph) row.sublist(left, right + 1)];
}
