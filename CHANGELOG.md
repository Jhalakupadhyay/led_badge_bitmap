## 0.1.0

* Initial release.
* `BadgeBitmapGenerator` for any badge width and height, with a
  `standard` preset for 44x11 badges.
* `fromText` renders with the built-in 8x11 bitmap font.
* `fromStyledText` renders with any Flutter `TextStyle`.
* `fromImage` converts PNG, JPEG, GIF, BMP, WebP and more, with
  `ImageFit` and `ImageInk` options.
* `ContentOverflowException` reports the required and available size when
  content does not fit.
* `BadgeBitmap` encoders: `toHexSegments`, `toBytes`, `toColumnWords`,
  `toAsciiArt` and `inverted`.
