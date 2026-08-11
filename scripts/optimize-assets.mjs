import { readFileSync, writeFileSync, readdirSync, statSync } from 'node:fs';
import { join, extname } from 'node:path';
import sharp from 'sharp';

const ASSETS_DIR = 'C:/Users/tau/code/ramadan_app/assets/photos';

const stats = { original: 0, optimized: 0, files: 0 };

async function optimizeImage(filePath) {
  const ext = extname(filePath).toLowerCase();
  if (!['.png', '.jpg', '.jpeg', '.webp', '.svg'].includes(ext)) return;
  
  try {
    const before = statSync(filePath).size;
    stats.original += before;
    
    const outputDir = filePath.replace(/\.png$/i, '.webp').replace(/\.(jpg|jpeg)$/i, '.webp');
    const outputPath = ext === '.webp' ? filePath : outputDir;
    
    let result;
    if (ext === '.png') {
      // Convert PNG to WebP with aggressive compression
      result = await sharp(filePath)
        .webp({ quality: 80, effort: 6, alphaQuality: 80 })
        .toBuffer();
    } else if (ext === '.jpg' || ext === '.jpeg') {
      // Optimize JPEG
      result = await sharp(filePath)
        .jpeg({ quality: 75, progressive: true, mozjpeg: true })
        .toBuffer();
    } else if (ext === '.webp') {
      // Re-encode existing WebP with better compression
      result = await sharp(filePath)
        .webp({ quality: 75, effort: 6 })
        .toBuffer();
    }
    
    if (result && result.length < before) {
      const targetPath = ext === '.webp' ? filePath : outputPath;
      writeFileSync(targetPath, result);
      const after = result.length;
      stats.optimized += (before - after);
      stats.files++;
      
      const savings = ((before - after) / before * 100).toFixed(1);
      console.log(`  ${filePath.split('/').pop()}: ${(before/1024).toFixed(0)}KB → ${(after/1024).toFixed(0)}KB (-${savings}%)`);
    } else {
      console.log(`  ${filePath.split('/').pop()}: already optimized`);
    }
  } catch (err) {
    console.error(`  Error: ${filePath.split('/').pop()}: ${err.message}`);
  }
}

async function processDir(dir) {
  const entries = readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = join(dir, entry.name);
    if (entry.isDirectory()) {
      await processDir(fullPath);
    } else {
      await optimizeImage(fullPath);
    }
  }
}

console.log('Optimizing images...');
await processDir(ASSETS_DIR);

console.log(`\nResults:`);
console.log(`  Files optimized: ${stats.files}`);
console.log(`  Original total: ${(stats.original/1024/1024).toFixed(1)} MB`);
console.log(`  Space saved: ${(stats.optimized/1024/1024).toFixed(1)} MB`);
