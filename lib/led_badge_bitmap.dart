/// Generate monochrome bitmaps for LED name badges from text or images.
///
/// Start with [BadgeBitmapGenerator]:
///
/// ```dart
/// const generator = BadgeBitmapGenerator(width: 44, height: 11);
/// final bitmap = generator.fromText('Hello');
/// print(bitmap.toAsciiArt());
///
/// // Content wider than the badge, for scrolling.
/// final strip = generator.renderText('Hello World');
/// ```
library;

import 'src/generator.dart';

export 'src/badge_bitmap.dart' show BadgeBitmap, BadgeContent;
export 'src/badge_mode.dart';
export 'src/exceptions.dart';
export 'src/generator.dart';
export 'src/image_renderer.dart' show ImageFit, ImageInk;
export 'src/layout.dart' show BadgeAlignment;
