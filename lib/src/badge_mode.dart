/// How a badge shows its content.
///
/// These are the display modes built into the firmware of common Bluetooth
/// LED name badges. Each mode has the [code] those badges use for it, so the
/// same value can describe a preview and the data sent to a badge.
enum BadgeMode {
  /// Content enters from the right edge and scrolls to the left.
  left(0x00),

  /// Content enters from the left edge and scrolls to the right.
  right(0x01),

  /// Content enters from the bottom edge and scrolls up.
  up(0x02),

  /// Content enters from the top edge and scrolls down.
  down(0x03),

  /// Content stays still, centred on the badge, so it must fit the badge.
  fixed(0x04),

  /// Content is split into badge-wide pages that are shown one after
  /// another.
  animation(0x05),

  /// The rows of the content fall into place from the top, then fall away.
  snowflake(0x06),

  /// Two lines move outward from the centre and reveal the content behind
  /// them.
  picture(0x07),

  /// A beam sweeps across the badge and draws the content column by column.
  laser(0x08);

  const BadgeMode(this.code);

  /// The code badges use for this mode, from `0x00` to `0x08`.
  final int code;

  /// Returns the mode with the given [code].
  ///
  /// Throws an [ArgumentError] if no mode has that code.
  static BadgeMode fromCode(int code) {
    for (final mode in values) {
      if (mode.code == code) return mode;
    }
    throw ArgumentError.value(
      code,
      'code',
      'is not a badge mode code; expected 0x00 to 0x08',
    );
  }
}
