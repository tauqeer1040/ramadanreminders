import { spawn } from 'node:child_process';
import { createRequire } from 'node:module';
import { randomBytes } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const ENV_PATH = path.join(ROOT, 'backend', '.env');

const requireB = createRequire(path.join(ROOT, 'backend', 'package.json'));
const dotenv = requireB('dotenv');
dotenv.config({ path: ENV_PATH });

const FROM_ENV = [
  'TURSO_DATABASE_URL',
  'TURSO_AUTH_TOKEN',
  'FIREBASE_PROJECT_ID',
  'FIREBASE_CLIENT_EMAIL',
  'FIREBASE_PRIVATE_KEY',
  'JOURNAL_ENCRYPTION_SECRET',
  'SUPERWALL_WEBHOOK_SECRET',
  'OPENROUTER_API_KEY',
  'FANAR_API_KEY',
  'FANAR_BASE_URL',
  'AI_POLL_INTERVAL_MS',
  'AI_INITIAL_DELAY_HOURS',
];

function setSecret(name, value) {
  return new Promise((resolve, reject) => {
    const child = spawn(
      'npx',
      ['--no-install', 'wrangler', 'pages', 'secret', 'put', name, '--project-name', 'meowmin'],
      { stdio: ['pipe', 'inherit', 'inherit'], shell: process.platform === 'win32' }
    );
    child.on('error', reject);
    child.stdin.on('error', () => {});
    child.stdin.write(value);
    child.stdin.end();
    child.on('exit', (code) =>
      code === 0 ? resolve() : reject(new Error(`exited with code ${code}`))
    );
  });
}

let internal = process.env.INTERNAL_POLL_SECRET;
if (!internal) {
  internal = randomBytes(32).toString('hex');
  fs.appendFileSync(ENV_PATH, `\nINTERNAL_POLL_SECRET=${internal}\n`);
  console.log('generated INTERNAL_POLL_SECRET -> appended to backend/.env');
}

const entries = [
  ...FROM_ENV.map((k) => [k, process.env[k]]),
  ['INTERNAL_POLL_SECRET', internal],
];

for (const [name, value] of entries) {
  if (!value) {
    console.log(`SKIP ${name} (empty)`);
    continue;
  }
  try {
    await setSecret(name, value);
    console.log(`set ${name}`);
  } catch (e) {
    console.error(`FAILED ${name}: ${e.message}`);
    process.exitCode = 1;
  }
}
