const crypto = require('crypto');

const ALGORITHM = 'aes-256-gcm';
const IV_LENGTH = 16;
const TAG_LENGTH = 16;
const C_VERSION = 'v1';

function getDerivedKey(uid) {
  const secret = process.env.JOURNAL_ENCRYPTION_SECRET;
  if (!secret) throw new Error('JOURNAL_ENCRYPTION_SECRET not configured');
  return crypto.createHmac('sha256', secret).update(uid).digest().subarray(0, 32);
}

function encrypt(plaintext, uid) {
  if (!plaintext) return plaintext;
  const key = getDerivedKey(uid);
  const iv = crypto.randomBytes(IV_LENGTH);
  const cipher = crypto.createCipheriv(ALGORITHM, key, iv);
  let encrypted = cipher.update(plaintext, 'utf8', 'base64');
  encrypted += cipher.final('base64');
  const tag = cipher.getAuthTag().toString('base64');
  return `${C_VERSION}:${iv.toString('base64')}:${encrypted}:${tag}`;
}

function isEncrypted(value) {
  if (typeof value !== 'string') return false;
  if (value.startsWith(`${C_VERSION}:`)) return true;
  // Legacy: 3 colon-separated base64 parts (iv:ct:tag, no version prefix)
  const parts = value.split(':');
  return parts.length === 3;
}

function _parseParts(ciphertext) {
  const parts = ciphertext.split(':');
  if (parts.length === 4 && parts[0] === C_VERSION) {
    return { iv: Buffer.from(parts[1], 'base64'), encrypted: parts[2], tag: Buffer.from(parts[3], 'base64') };
  }
  if (parts.length === 3) {
    return { iv: Buffer.from(parts[0], 'base64'), encrypted: parts[1], tag: Buffer.from(parts[2], 'base64') };
  }
  return null;
}

function decrypt(ciphertext, uid) {
  if (!ciphertext) return ciphertext;
  if (typeof ciphertext !== 'string') return ciphertext;
  if (!isEncrypted(ciphertext)) return ciphertext;
  const parsed = _parseParts(ciphertext);
  if (!parsed) return ciphertext;
  try {
    const key = getDerivedKey(uid);
    const decipher = crypto.createDecipheriv(ALGORITHM, key, parsed.iv);
    decipher.setAuthTag(parsed.tag);
    let decrypted = decipher.update(parsed.encrypted, 'base64', 'utf8');
    decrypted += decipher.final('utf8');
    return decrypted;
  } catch {
    return ciphertext;
  }
}

module.exports = { encrypt, decrypt, isEncrypted };
