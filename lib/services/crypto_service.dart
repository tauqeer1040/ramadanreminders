import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart' deferred as crypto;
import 'package:flutter_secure_storage/flutter_secure_storage.dart' deferred as fss;
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

class EncryptionNotReadyException implements Exception {
  final String message;
  const EncryptionNotReadyException(this.message);
  @override
  String toString() => 'EncryptionNotReadyException: $message';
}

class CryptoService {
  static const _keyStorageKey = 'journal_encryption_key';
  static const _readyFlag = 'encryption_ready';
  static const _ciphertextVersion = 'v1';
  static late final dynamic _storage;

  static dynamic _secretKey;
  static bool _libsLoaded = false;

  static Future<void> _ensureLibs() async {
    if (!_libsLoaded) {
      await Future.wait([crypto.loadLibrary(), fss.loadLibrary()]);
      _storage = fss.FlutterSecureStorage();
      _libsLoaded = true;
    }
  }

  static Future<void> init() async {
    await _ensureLibs();
    final stored = await _storage.read(key: _keyStorageKey);
    if (stored != null && stored.isNotEmpty) {
      final keyBytes = base64Decode(stored);
      _secretKey = crypto.SecretKey(keyBytes);
    }
  }

  static Future<bool> get isReady async {
    if (_secretKey != null) return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_readyFlag) ?? false;
  }

  static Future<void> fetchAndStoreKey() async {
    await _ensureLibs();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();

    try {
      final token = await user.getIdToken();
      final response = await http.get(
        Uri.parse('${AppConstants.backendUrl}/encryption-key'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final key = body['key'] as String;
        if (key.isNotEmpty) {
          await _storage.write(key: _keyStorageKey, value: key);
          final keyBytes = base64Decode(key);
          _secretKey = crypto.SecretKey(keyBytes);
          await prefs.setBool(_readyFlag, true);
          return;
        }
      }
    } catch (_) {}

    await prefs.setBool(_readyFlag, false);
  }

  static Future<bool> assertReady() async {
    if (_secretKey != null) return true;
    final ready = await isReady;
    if (!ready) throw const EncryptionNotReadyException('Key not available — call fetchAndStoreKey first');
    return true;
  }

  static Future<String> encrypt(String plaintext) async {
    if (plaintext.isEmpty) return plaintext;
    if (_secretKey == null) return plaintext;
    await _ensureLibs();

    final aesGcm = crypto.AesGcm.with256bits();
    final iv = randomBytes(12);
    final secretBox = await aesGcm.encrypt(
      utf8.encode(plaintext),
      secretKey: _secretKey!,
      nonce: iv,
    );

    final combined = {
      'iv': base64Encode(iv),
      'c': base64Encode(secretBox.cipherText),
      't': base64Encode(secretBox.mac.bytes),
    };
    final payload = jsonEncode(combined);
    final encoded = base64Encode(utf8.encode(payload));
    return '$_ciphertextVersion:$encoded';
  }

  static bool _isLegacyFormat(String value) {
    try {
      final decoded = utf8.decode(base64Decode(value));
      if (!decoded.startsWith('{')) return false;
      final map = jsonDecode(decoded);
      return map is Map<String, dynamic> &&
          map.containsKey('iv') &&
          map.containsKey('c') &&
          map.containsKey('t');
    } catch (_) {
      return false;
    }
  }

  static bool isEncrypted(String value) {
    return value.startsWith('$_ciphertextVersion:') || _isLegacyFormat(value);
  }

  static Future<String> decrypt(String ciphertext) async {
    if (ciphertext.isEmpty) return ciphertext;
    if (!isEncrypted(ciphertext)) return ciphertext;
    if (_secretKey == null) return ciphertext;
    await _ensureLibs();

    try {
      final base64Part = ciphertext.startsWith('$_ciphertextVersion:')
          ? ciphertext.substring(_ciphertextVersion.length + 1)
          : ciphertext;
      final combined = jsonDecode(utf8.decode(base64Decode(base64Part))) as Map<String, dynamic>;
      final iv = base64Decode(combined['iv'] as String);
      final cipherText = base64Decode(combined['c'] as String);
      final mac = crypto.Mac(base64Decode(combined['t'] as String));

      final secretBox = crypto.SecretBox(cipherText, nonce: iv, mac: mac);
      final aesGcm = crypto.AesGcm.with256bits();
      final plaintext = await aesGcm.decrypt(secretBox, secretKey: _secretKey!);
      return utf8.decode(plaintext);
    } catch (_) {
      return ciphertext;
    }
  }

  static List<int> randomBytes(int count) {
    final rng = Random.secure();
    return List.generate(count, (_) => rng.nextInt(256));
  }
}
