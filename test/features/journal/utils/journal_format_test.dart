import 'package:flutter_test/flutter_test.dart';
import 'package:tonkatsu_box/features/journal/utils/journal_format.dart';

void main() {
  group('formatClock', () {
    test('shows minutes and seconds under an hour', () {
      expect(formatClock(Duration.zero), '0:00');
      expect(formatClock(const Duration(seconds: 7)), '0:07');
      expect(formatClock(const Duration(minutes: 4, seconds: 7)), '4:07');
      expect(formatClock(const Duration(minutes: 59, seconds: 59)), '59:59');
    });

    test('adds hours from one hour up', () {
      expect(formatClock(const Duration(hours: 1)), '1:00:00');
      expect(
        formatClock(const Duration(hours: 12, minutes: 3, seconds: 9)),
        '12:03:09',
      );
    });

    test('clamps a negative duration to zero', () {
      expect(formatClock(const Duration(seconds: -5)), '0:00');
    });
  });
}
