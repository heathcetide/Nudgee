/// String / regex validation utilities.
///
/// Provides two flavors of API:
/// * `is*` predicates returning `bool` (e.g. [isEmail], [isPhone]).
/// * Form-helper validators returning `String?` (null = valid, otherwise
///   the error message) — e.g. [email], [phone], [required].
class LingValidator {
  LingValidator._();

  // ── Predicates ───────────────────────────────────────────────────────

  /// China mobile phone number: starts with 1, 11 digits, valid 2nd-digit
  /// prefix (3-9).
  static bool isPhone(String value) =>
      RegExp(r'^1[3-9]\d{9}$').hasMatch(value.trim());

  /// Standard email address.
  static bool isEmail(String value) =>
      RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(value.trim());

  /// HTTP(S) URL.
  static bool isUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  /// Chinese national ID card (15 or 18 digits, last may be `X`).
  static bool isIdCard(String value) {
    final v = value.trim().toUpperCase();
    if (v.length != 15 && v.length != 18) return false;
    if (v.length == 15) {
      return RegExp(r'^\d{15}$').hasMatch(v);
    }
    return RegExp(r'^\d{17}[\dX]$').hasMatch(v);
  }

  /// Password with length in `[minLength, maxLength]`.
  static bool isPassword(String value, {int minLength = 8, int maxLength = 32}) {
    final v = value.trim();
    return v.length >= minLength && v.length <= maxLength;
  }

  /// Username: 3-20 chars of letters / digits / underscores.
  static bool isUsername(String value) =>
      RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(value.trim());

  /// Chinese postal code (6 digits).
  static bool isPostalCode(String value) =>
      RegExp(r'^\d{6}$').hasMatch(value.trim());

  /// IPv4 address.
  static bool isIPv4(String value) {
    final parts = value.trim().split('.');
    if (parts.length != 4) return false;
    for (final p in parts) {
      final n = int.tryParse(p);
      if (n == null || n < 0 || n > 255) return false;
    }
    return true;
  }

  /// Hex color (`#RGB` / `#RRGGBB`, optional leading `#`).
  static bool isHexColor(String value) =>
      RegExp(r'^#?([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6})$').hasMatch(value.trim());

  // ── Form validators (return null on success, error message otherwise) ──

  /// Validate a phone number.
  static String? phone(String value) =>
      isPhone(value) ? null : '请输入正确的手机号';

  /// Validate an email address.
  static String? email(String value) =>
      isEmail(value) ? null : '请输入正确的邮箱地址';

  /// Require a non-empty value.
  static String? required(String value, {String label = '此项'}) =>
      value.trim().isEmpty ? '$label不能为空' : null;

  /// Require at least [min] characters.
  static String? minLength(String value, int min, {String label = '此项'}) =>
      value.trim().length < min ? '$label至少需要$min个字符' : null;

  /// Require at most [max] characters.
  static String? maxLength(String value, int max, {String label = '此项'}) =>
      value.trim().length > max ? '$label不能超过$max个字符' : null;

  /// Require length within `[min, max]`.
  static String? range(String value, int min, int max, {String label = '此项'}) {
    final len = value.trim().length;
    if (len < min) return '$label至少需要$min个字符';
    if (len > max) return '$label不能超过$max个字符';
    return null;
  }
}
