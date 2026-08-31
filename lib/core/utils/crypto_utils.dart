import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart';
import 'package:uuid/uuid.dart';

/// Cryptographic utility helpers.
///
/// Provides hashing (MD5/SHA/HMAC), symmetric AES encryption, Base64
/// helpers, and random key / UUID generation. All methods are static and
/// synchronous where possible.
class LingCryptoUtils {
  LingCryptoUtils._();

  static final _random = Random.secure();
  static const _uuid = Uuid();

  // ── Hashing ───────────────────────────────────────────────────────────

  /// MD5 hash of [input] (hex string).
  static String md5(String input) {
    return crypto.md5.convert(utf8.encode(input)).toString();
  }

  /// SHA-256 hash of [input] (hex string).
  static String sha256(String input) {
    return crypto.sha256.convert(utf8.encode(input)).toString();
  }

  /// SHA-512 hash of [input] (hex string).
  static String sha512(String input) {
    return crypto.sha512.convert(utf8.encode(input)).toString();
  }

  /// HMAC-SHA256 of [data] using [key] (hex string).
  static String hmacSha256(String key, String data) {
    final hmac = crypto.Hmac(crypto.sha256, utf8.encode(key));
    return hmac.convert(utf8.encode(data)).toString();
  }

  // ── AES (symmetric) ───────────────────────────────────────────────────

  /// Encrypt [plaintext] with AES using [key] (16/24/32 chars).
  ///
  /// When [iv] is omitted a random 16-byte IV is generated and prepended
  /// to the ciphertext (separated by `:`) so the same value can be passed
  /// back to [aesDecrypt]. Returns a Base64 string.
  static String aesEncrypt(String plaintext, String key, {String? iv}) {
    final encrypter = _buildEncrypter(key);
    final ivBytes = iv != null ? IV.fromBase64(iv) : _generateIv();
    final encrypted = encrypter.encrypt(plaintext, iv: ivBytes);
    if (iv != null) return encrypted.base64;
    // Prepend IV so decrypt can recover it.
    return '${ivBytes.base64}:${encrypted.base64}';
  }

  /// Decrypt a Base64 [ciphertext] produced by [aesEncrypt].
  ///
  /// When [iv] is omitted the value is expected to contain the prepended
  /// IV (`<iv>:<ciphertext>`).
  static String aesDecrypt(String ciphertext, String key, {String? iv}) {
    final encrypter = _buildEncrypter(key);
    if (iv != null) {
      return encrypter.decrypt(Encrypted.fromBase64(ciphertext), iv: IV.fromBase64(iv));
    }
    final parts = ciphertext.split(':');
    if (parts.length != 2) {
      throw ArgumentError('ciphertext must be "<iv>:<data>" when iv is omitted');
    }
    return encrypter.decrypt(
      Encrypted.fromBase64(parts[1]),
      iv: IV.fromBase64(parts[0]),
    );
  }

  static Encrypter _buildEncrypter(String key) {
    final keyBytes = utf8.encode(key);
    if (![16, 24, 32].contains(keyBytes.length)) {
      throw ArgumentError('AES key must be 16, 24, or 32 bytes (got ${keyBytes.length})');
    }
    return Encrypter(AES(Key(keyBytes)));
  }

  static IV _generateIv() => IV.fromSecureRandom(16);

  // ── Base64 ────────────────────────────────────────────────────────────

  /// Base64-encode a UTF-8 string.
  static String base64Encode(String input) {
    return base64.encode(utf8.encode(input));
  }

  /// Base64-decode to a UTF-8 string.
  static String base64Decode(String input) {
    return utf8.decode(base64.decode(input));
  }

  // ── Random / UUID ─────────────────────────────────────────────────────

  /// Generate a cryptographically-secure random key of [length] bytes
  /// (default 32) returned as a Base64 string.
  static String generateRandomKey({int length = 32}) {
    final bytes = List<int>.generate(length, (_) => _random.nextInt(256));
    return base64.encode(bytes);
  }

  /// Generate a v4 UUID string.
  static String generateUUID() => _uuid.v4();
}
