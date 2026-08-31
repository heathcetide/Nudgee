/// Number / money / percentage formatting utilities.
class LingNumberUtils {
  LingNumberUtils._();

  /// Format [amount] as a money string: `¥1,234.50`.
  static String formatMoney(
    double amount, {
    int decimals = 2,
    String symbol = '¥',
  }) {
    final fixed = amount.toStringAsFixed(decimals);
    final parts = fixed.split('.');
    final intPart = _groupThousands(parts[0]);
    final decPart = parts.length > 1 ? parts[1] : '';
    final value = decPart.isEmpty ? intPart : '$intPart.$decPart';
    return '$symbol$value';
  }

  /// Group an integer with thousands separators: `1234` → `1,234`.
  static String formatNumber(int num) => _groupThousands(num.toString());

  /// Compact notation: `1234` → `1.2K`, `1000000` → `1M`.
  static String formatCompact(int num) {
    if (num < 1000) return num.toString();
    const units = <String>['', 'K', 'M', 'B', 'T'];
    var value = num.toDouble();
    var idx = 0;
    while (value >= 1000 && idx < units.length - 1) {
      value /= 1000;
      idx++;
    }
    final formatted = value >= 100 || value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$formatted${units[idx]}';
  }

  /// Round [value] to [decimals] decimal places.
  static double round(double value, int decimals) {
    final factor = _pow10(decimals);
    return (value * factor).roundToDouble() / factor;
  }

  /// Format a fraction as a percentage: `0.65` → `65.0%`.
  static String percent(double value, {int decimals = 1}) =>
      '${(value * 100).toStringAsFixed(decimals)}%';

  /// Clamp [value] to `[min, max]`.
  static int clamp(int value, int min, int max) =>
      value < min ? min : (value > max ? max : value);

  // ── Private helpers ──────────────────────────────────────────────────

  static String _groupThousands(String intStr) {
    final isNegative = intStr.startsWith('-');
    final digits = isNegative ? intStr.substring(1) : intStr;
    final buffer = StringBuffer();
    var count = 0;
    for (var i = digits.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
      count++;
    }
    final grouped = buffer.toString().split('').reversed.join();
    return isNegative ? '-$grouped' : grouped;
  }

  static int _pow10(int n) {
    var v = 1;
    for (var i = 0; i < n; i++) {
      v *= 10;
    }
    return v;
  }
}
