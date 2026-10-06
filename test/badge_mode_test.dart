import 'package:flutter_test/flutter_test.dart';
import 'package:led_badge_bitmap/led_badge_bitmap.dart';

void main() {
  group('BadgeMode', () {
    test('uses the badge firmware code for each mode', () {
      expect({
        for (final mode in BadgeMode.values) mode: mode.code
      }, {
        BadgeMode.left: 0x00,
        BadgeMode.right: 0x01,
        BadgeMode.up: 0x02,
        BadgeMode.down: 0x03,
        BadgeMode.fixed: 0x04,
        BadgeMode.animation: 0x05,
        BadgeMode.snowflake: 0x06,
        BadgeMode.picture: 0x07,
        BadgeMode.laser: 0x08,
      });
    });

    test('fromCode(mode.code) returns the same mode for every mode', () {
      for (final mode in BadgeMode.values) {
        expect(BadgeMode.fromCode(mode.code), mode);
      }
    });

    test('fromCode throws ArgumentError for unknown codes', () {
      for (final code in [-1, 0x09, 0x0F, 0xFF]) {
        expect(
          () => BadgeMode.fromCode(code),
          throwsA(
            isA<ArgumentError>()
                .having((e) => e.name, 'name', 'code')
                .having((e) => e.invalidValue, 'invalidValue', code),
          ),
        );
      }
    });
  });
}
