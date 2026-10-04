/// Generate monochrome bitmaps for LED name badges from text or images.
///
/// Start with [BadgeBitmapGenerator]:
///
/// ```dart
/// const generator = BadgeBitmapGenerator(width: 44, height: 11);
/// final bitmap = generator.fromText('Hello');
/// print(bitmap.toAsciiArt());
/// ```
library;

import 'src/generator.dart';

export 'src/badge_bitmap.dart' show BadgeBitmap;
export 'src/exceptions.dart';
export 'src/generator.dart';
export 'src/image_renderer.dart' show ImageFit, ImageInk;
export 'src/layout.dart' show BadgeAlignment;
