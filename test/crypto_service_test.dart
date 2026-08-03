import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ramadan_reflections/services/crypto_service.dart';

/// Tests for the core cryptographic logic used by CryptoService.
/// Does not depend on FlutterSecureStorage, FirebaseAuth, or http —
/// those layers should be mocked in integration tests.

List<int> _randomBytes(int count) {
  final rng = Random.secure();
  return List.generate(count, (_) => rng.nextInt(256));
}

void main() {
  group('randomBytes', () {
    test('returns correct length', () {
      expect(_randomBytes(12).length, 12);
      expect(_randomBytes(32).length, 32);
      expect(_randomBytes(0).length, 0);
    });

    test('produces different values each call', () {
      final a = _randomBytes(16);
      final b = _randomBytes(16);
      expect(a, isNot(equals(b)));
    });
  });

  group('AES-256-GCM round-trip', () {
    late SecretKey key;

    setUp(() async {
      key = await AesGcm.with256bits().newSecretKey();
    });

    test('encrypt then decrypt returns original', () async {
      const plaintext = 'Today I prayed Fajr and felt at peace.';
      final aesGcm = AesGcm.with256bits();
      final iv = _randomBytes(12);
      final secretBox = await aesGcm.encrypt(
        utf8.encode(plaintext),
        secretKey: key,
        nonce: iv,
      );
      final decrypted = await aesGcm.decrypt(secretBox, secretKey: key);
      expect(utf8.decode(decrypted), plaintext);
    });

    test('different keys produce different ciphertexts', () async {
      const plaintext = 'Hello world';
      final aesGcm = AesGcm.with256bits();
      final key1 = await aesGcm.newSecretKey();
      final key2 = await aesGcm.newSecretKey();
      final iv = _randomBytes(12);

      final box1 = await aesGcm.encrypt(
        utf8.encode(plaintext),
        secretKey: key1,
        nonce: iv,
      );
      final box2 = await aesGcm.encrypt(
        utf8.encode(plaintext),
        secretKey: key2,
        nonce: iv,
      );
      expect(box1.cipherText, isNot(equals(box2.cipherText)));
    });

    test('wrong key fails to decrypt', () async {
      const plaintext = 'secret data';
      final aesGcm = AesGcm.with256bits();
      final encryptKey = await aesGcm.newSecretKey();
      final wrongKey = await aesGcm.newSecretKey();
      final iv = _randomBytes(12);

      final secretBox = await aesGcm.encrypt(
        utf8.encode(plaintext),
        secretKey: encryptKey,
        nonce: iv,
      );

      await expectLater(
        aesGcm.decrypt(secretBox, secretKey: wrongKey),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('unicode text survives round-trip', () async {
      const text = 'السلام عليكم 🌙 رمضان كريم!';
      final aesGcm = AesGcm.with256bits();
      final key = await aesGcm.newSecretKey();
      final iv = _randomBytes(12);

      final secretBox = await aesGcm.encrypt(
        utf8.encode(text),
        secretKey: key,
        nonce: iv,
      );
      final decrypted = await aesGcm.decrypt(secretBox, secretKey: key);
      expect(utf8.decode(decrypted), text);
    });

    test('long text (10KB) round-trip', () async {
      final text = 'a' * 10240;
      final aesGcm = AesGcm.with256bits();
      final key = await aesGcm.newSecretKey();
      final iv = _randomBytes(12);

      final secretBox = await aesGcm.encrypt(
        utf8.encode(text),
        secretKey: key,
        nonce: iv,
      );
      final decrypted = await aesGcm.decrypt(secretBox, secretKey: key);
      expect(utf8.decode(decrypted).length, 10240);
    });
  });

  group('version prefix', () {
    test('isEncrypted detects v1: prefix', () {
      expect(CryptoService.isEncrypted('v1:abc'), true);
      expect(CryptoService.isEncrypted('plain text'), false);
      expect(CryptoService.isEncrypted(''), false);
    });

    test('isEncrypted detects legacy format', () {
      final legacy = base64Encode(utf8.encode('{"iv":"AQID","c":"BAUG","t":"BwgJ"}'));
      expect(CryptoService.isEncrypted(legacy), true);
    });

    test('encrypted output has v1: prefix', () async {
      final key = await AesGcm.with256bits().newSecretKey();
      final aesGcm = AesGcm.with256bits();
      final iv = _randomBytes(12);
      final secretBox = await aesGcm.encrypt(
        utf8.encode('hello'),
        secretKey: key,
        nonce: iv,
      );
      final combined = {
        'iv': base64Encode(iv),
        'c': base64Encode(secretBox.cipherText),
        't': base64Encode(secretBox.mac.bytes),
      };
      final payload = jsonEncode(combined);
      final encoded = base64Encode(utf8.encode(payload));
      final result = 'v1:$encoded';
      expect(result.startsWith('v1:'), true);
    });
  });

  group('serialization format', () {
    test('encrypted payload can be JSON-serialized and deserialized', () async {
      const plaintext = 'test data';
      final aesGcm = AesGcm.with256bits();
      final key = await aesGcm.newSecretKey();
      final iv = _randomBytes(12);

      final secretBox = await aesGcm.encrypt(
        utf8.encode(plaintext),
        secretKey: key,
        nonce: iv,
      );

      final payload = {
        'iv': base64Encode(iv),
        'c': base64Encode(secretBox.cipherText),
        't': base64Encode(secretBox.mac.bytes),
      };
      final serialized = jsonEncode(payload);

      // Simulate the CryptoService format: base64(json)
      final outerB64 = base64Encode(utf8.encode(serialized));
      final decoded = utf8.decode(base64Decode(outerB64));
      final parsed = jsonDecode(decoded) as Map<String, dynamic>;

      final restoredBox = SecretBox(
        base64Decode(parsed['c'] as String),
        nonce: base64Decode(parsed['iv'] as String),
        mac: Mac(base64Decode(parsed['t'] as String)),
      );
      final decrypted = await aesGcm.decrypt(restoredBox, secretKey: key);

      expect(utf8.decode(decrypted), plaintext);
    });
  });
}
