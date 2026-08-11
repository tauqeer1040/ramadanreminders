import { readFileSync, writeFileSync, readdirSync, statSync, unlinkSync } from 'node:fs';
import { join, extname, basename } from 'node:path';
import sharp from 'sharp';

const ASSETS_DIR = 'C:/Users/tau/code/ramadan_app/assets/photos';
const stats = { converted: 0, skipped: 0, originalBytes: 0, newBytes: 0 };

async function convertPngToWebp(filePath) {
  const ext = extname(filePath).toLowerCase();
  if (ext !== '.png') return;
  
  try {
    const before = statSync(filePath).size;
    const webpPath = filePath.replace(/\.png$/i, '.webp');
    
    // Skip if WebP already exists and is smaller
    try {
      const existing = statSync(webpPath);
      if (existing.size < before * 0.8) {
        console.log(`  ${basename(filePath)}: WebP already exists, skipping`);
        stats.skipped++;
        return;
      }
    } catch {}
    
    const result = await sharp(filePath)
      .webp({ quality: 80, effort: 6, alphaQuality: 80 })
      .toBuffer();
    
    if (result.length < before) {
      writeFileSync(webpPath, result);
      stats.converted++;
      stats.originalBytes += before;
      stats.newBytes += result.length;
      const savings = ((before - result.length) / before * 100).toFixed(1);
      console.log(`  ${basename(filePath)}: ${(before/1024).toFixed(0)}KB → ${(result.length/1024).toFixed(0)}KB (-${savings}%)`);
    } else {
      console.log(`  ${basename(filePath)}: already optimal`);
    }
  } catch (err) {
    console.error(`  Error: ${basename(filePath)}: ${err.message}`);
  }
}

async function processDir(dir) {
  const entries = readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = join(dir, entry.name);
    if (entry.isDirectory()) {
      await processDir(fullPath);
    } else {
      await convertPngToWebp(fullPath);
    }
  }
}

console.log('Converting PNGs to WebP...');
await processDir(ASSETS_DIR);

console.log(`\nResults:`);
console.log(`  Converted: ${stats.converted} files`);
console.log(`  Skipped: ${stats.skipped} files`);
console.log(`  Original: ${(stats.originalBytes/1024/1024).toFixed(1)} MB`);
console.log(`  New: ${(stats.newBytes/1024/1024).toFixed(1)} MB`);
console.log(`  Saved: ${((stats.originalBytes - stats.newBytes)/1024/1024).toFixed(1)} MB`);
