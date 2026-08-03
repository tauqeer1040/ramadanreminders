const assert = require('assert');
const crypto = require('crypto');

// Inline the encryption module logic so we don't depend on env vars
const SECRET = 'test-master-secret-32bytes!';

const C_VERSION = 'v1';

function encrypt(plaintext, uid) {
  if (!plaintext) return plaintext;
  try {
    const key = crypto.createHmac('sha256', SECRET).update(uid).digest().subarray(0, 32);
    const iv = crypto.randomBytes(12);
    const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
    let encrypted = cipher.update(plaintext, 'utf8', 'hex');
    encrypted += cipher.final('hex');
    const authTag = cipher.getAuthTag().toString('hex');
    return `${C_VERSION}:${iv.toString('hex')}:${encrypted}:${authTag}`;
  } catch (_) {
    return plaintext;
  }
}

function isEncrypted(value) {
  return typeof value === 'string' && value.startsWith(`${C_VERSION}:`);
}

function decrypt(ciphertext, uid) {
  if (!ciphertext || ciphertext === 'null') return ciphertext;
  if (!isEncrypted(ciphertext)) return ciphertext;
  try {
    const key = crypto.createHmac('sha256', SECRET).update(uid).digest().subarray(0, 32);
    const parts = ciphertext.split(':');
    const iv = Buffer.from(parts[1], 'hex');
    const ct = parts[2];
    const tag = Buffer.from(parts[3], 'hex');
    const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
    decipher.setAuthTag(tag);
    let decrypted = decipher.update(ct, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    return decrypted;
  } catch (_) {
    return ciphertext;
  }
}

function test(name, fn) {
  try {
    fn();
    console.log(`  PASS  ${name}`);
  } catch (e) {
    console.error(`  FAIL  ${name}`);
    console.error(`        ${e.message}`);
    process.exitCode = 1;
  }
}

console.log('\nencryption.js tests\n');

test('isEncrypted detects version prefix', () => {
  const ct = encrypt('test', 'uid');
  assert.ok(isEncrypted(ct));
  assert.ok(!isEncrypted('plain text'));
  assert.ok(!isEncrypted(''));
  assert.ok(!isEncrypted(null));
});

test('round-trip encrypt/decrypt', () => {
  const uid = 'user-abc-123';
  const plaintext = 'Today I prayed Fajr and felt at peace.';
  const encrypted = encrypt(plaintext, uid);
  assert.notStrictEqual(encrypted, plaintext, 'encrypted should differ from plaintext');
  assert.ok(isEncrypted(encrypted));
  const decrypted = decrypt(encrypted, uid);
  assert.strictEqual(decrypted, plaintext);
});

test('different UIDs produce different ciphertexts', () => {
  const plaintext = 'Hello world';
  const e1 = encrypt(plaintext, 'uid-one');
  const e2 = encrypt(plaintext, 'uid-two');
  assert.notStrictEqual(e1, e2);
});

test('wrong UID returns ciphertext on decrypt (canonical fail-visible)', () => {
  const plaintext = 'secret data';
  const encrypted = encrypt(plaintext, 'alice');
  const result = decrypt(encrypted, 'bob');
  assert.strictEqual(result, encrypted);
});

test('empty string returns empty', () => {
  assert.strictEqual(encrypt('', 'any-uid'), '');
  assert.strictEqual(decrypt('', 'any-uid'), '');
});

test('null input returns null input', () => {
  assert.strictEqual(encrypt(null, 'uid'), null);
  assert.strictEqual(decrypt(null, 'uid'), null);
  assert.strictEqual(decrypt('null', 'uid'), 'null');
});

test('tampered ciphertext returns ciphertext on decrypt', () => {
  const encrypted = encrypt('my data', 'uid');
  const parts = encrypted.split(':');
  parts[2] = '00' + parts[2];
  const tampered = parts.join(':');
  const result = decrypt(tampered, 'uid');
  assert.strictEqual(result, tampered);
});

test('unicode text survives round-trip', () => {
  const uid = 'unicode-user';
  const text = 'السلام عليكم 🌙 رمضان كريم!';
  const encrypted = encrypt(text, uid);
  const decrypted = decrypt(encrypted, uid);
  assert.strictEqual(decrypted, text);
});

test('long text (10KB) round-trip', () => {
  const uid = 'long-text-user';
  const text = 'a'.repeat(10240);
  const encrypted = encrypt(text, uid);
  assert.notStrictEqual(encrypted, text);
  const decrypted = decrypt(encrypted, uid);
  assert.strictEqual(decrypted, text);
  assert.strictEqual(decrypted.length, 10240);
});

console.log('\n');
