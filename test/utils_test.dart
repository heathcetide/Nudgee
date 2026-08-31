import 'package:flutter_test/flutter_test.dart';

import 'package:nudgee/core/utils/date_utils.dart';
import 'package:nudgee/core/utils/number_utils.dart';
import 'package:nudgee/core/utils/validator_utils.dart';

void main() {
  group('LingDateUtils', () {
    test('formatDate uses default pattern', () {
      expect(
        LingDateUtils.formatDate(DateTime(2024, 1, 5)),
        '2024-01-05',
      );
    });

    test('formatRelative returns 刚刚 for recent dates', () {
      final now = DateTime(2024, 6, 1, 12, 0, 0);
      expect(
        LingDateUtils.formatRelative(now.add(const Duration(seconds: 10)),
            now: now),
        '刚刚',
      );
    });

    test('formatRelative returns 分钟前', () {
      final now = DateTime(2024, 6, 1, 12, 0, 0);
      expect(
        LingDateUtils.formatRelative(now.subtract(const Duration(minutes: 5)),
            now: now),
        '5 分钟前',
      );
    });

    test('isToday / isYesterday / isThisYear', () {
      final now = DateTime(2024, 6, 1, 12, 0, 0);
      expect(LingDateUtils.isToday(now, now), isTrue);
      expect(
        LingDateUtils.isYesterday(now.subtract(const Duration(days: 1)), now),
        isTrue,
      );
      expect(LingDateUtils.isThisYear(DateTime(2024, 1, 1), now), isTrue);
      expect(LingDateUtils.isThisYear(DateTime(2023, 1, 1), now), isFalse);
    });

    test('formatFileSize', () {
      expect(LingDateUtils.formatFileSize(0), '0 B');
      expect(LingDateUtils.formatFileSize(1500), '1.5 KB');
    });

    test('formatDuration', () {
      expect(
        LingDateUtils.formatDuration(const Duration(hours: 1, minutes: 23)),
        '1h 23m',
      );
      expect(
        LingDateUtils.formatDuration(const Duration(minutes: 23, seconds: 45)),
        '23m 45s',
      );
      expect(
        LingDateUtils.formatDuration(const Duration(seconds: 45)),
        '45s',
      );
    });

    test('daysBetween', () {
      expect(
        LingDateUtils.daysBetween(DateTime(2024, 1, 1), DateTime(2024, 1, 5)),
        4,
      );
    });

    test('parse round-trips', () {
      final parsed = LingDateUtils.parse('2024-06-01');
      expect(parsed.year, 2024);
      expect(parsed.month, 6);
      expect(parsed.day, 1);
    });
  });

  group('LingValidator', () {
    test('isPhone validates China mobile numbers', () {
      expect(LingValidator.isPhone('13812345678'), isTrue);
      expect(LingValidator.isPhone('12345678901'), isFalse);
      expect(LingValidator.isPhone(''), isFalse);
    });

    test('isEmail', () {
      expect(LingValidator.isEmail('a@b.com'), isTrue);
      expect(LingValidator.isEmail('not-an-email'), isFalse);
    });

    test('isUrl', () {
      expect(LingValidator.isUrl('https://example.com'), isTrue);
      expect(LingValidator.isUrl('not-a-url'), isFalse);
    });

    test('isIdCard', () {
      expect(LingValidator.isIdCard('110101199003077314'), isTrue);
      expect(LingValidator.isIdCard('11010119900307731X'), isTrue);
      expect(LingValidator.isIdCard('123'), isFalse);
    });

    test('isUsername', () {
      expect(LingValidator.isUsername('hello_world123'), isTrue);
      expect(LingValidator.isUsername('ab'), isFalse);
    });

    test('isIPv4', () {
      expect(LingValidator.isIPv4('192.168.1.1'), isTrue);
      expect(LingValidator.isIPv4('999.1.1.1'), isFalse);
    });

    test('isHexColor', () {
      expect(LingValidator.isHexColor('#fff'), isTrue);
      expect(LingValidator.isHexColor('#FFAABB'), isTrue);
      expect(LingValidator.isHexColor('zzz'), isFalse);
    });

    test('form validators return null on success', () {
      expect(LingValidator.required('value'), isNull);
      expect(LingValidator.phone('13812345678'), isNull);
      expect(LingValidator.email('a@b.com'), isNull);
      expect(LingValidator.minLength('abc', 3), isNull);
      expect(LingValidator.maxLength('abc', 5), isNull);
      expect(LingValidator.range('abcd', 3, 5), isNull);
    });

    test('form validators return message on failure', () {
      expect(LingValidator.required(''), isNotNull);
      expect(LingValidator.phone('123'), isNotNull);
      expect(LingValidator.minLength('a', 3), isNotNull);
      expect(LingValidator.maxLength('abcdef', 5), isNotNull);
      expect(LingValidator.range('a', 3, 5), isNotNull);
    });
  });

  group('LingNumberUtils', () {
    test('formatNumber groups thousands', () {
      expect(LingNumberUtils.formatNumber(1234), '1,234');
      expect(LingNumberUtils.formatNumber(1000000), '1,000,000');
    });

    test('formatCompact', () {
      expect(LingNumberUtils.formatCompact(1234), '1.2K');
      expect(LingNumberUtils.formatCompact(1000000), '1M');
    });

    test('formatMoney', () {
      expect(LingNumberUtils.formatMoney(1234.5), '¥1,234.50');
    });

    test('percent', () {
      expect(LingNumberUtils.percent(0.65), '65.0%');
    });

    test('round', () {
      expect(LingNumberUtils.round(1.2345, 2), 1.23);
    });

    test('clamp', () {
      expect(LingNumberUtils.clamp(15, 0, 10), 10);
      expect(LingNumberUtils.clamp(-5, 0, 10), 0);
      expect(LingNumberUtils.clamp(5, 0, 10), 5);
    });
  });
}
