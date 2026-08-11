/**
 * Converts shop image assets to WebP thumbnails + full-size.
 *
 * Usage: node convert_shop_assets.js
 *
 * Expects source images in:
 *   ../assets/photos/images/*.webp, *.jpeg
 *   ../assets/photos/images/scratchCards/*.webp
 *
 * Outputs to:
 *   ./public/assets/shop/thumbs/{id}.webp   (200px tall)
 *   ./public/assets/shop/full/{id}.webp     (original aspect, WebP)
 */

const fs = require('fs');
const path = require('path');
const sharp = require('sharp');

const SOURCE_FLOWERS = path.join(__dirname, '..', 'assets', 'photos', 'images');
const SOURCE_SCRATCH = path.join(__dirname, '..', 'assets', 'photos', 'images', 'scratchCards');
const OUT_DIR = path.join(__dirname, 'public', 'assets', 'shop');

const items = [
  // flowers
  { id: 'shop_1', file: 'Delicate Translucent Flower.webp' },
  { id: 'shop_2', file: 'DelicateOrangeFlowerinBloom.jpeg' },
  { id: 'shop_3', file: 'Ethereal Flower in Motion.webp' },
  { id: 'shop_4', file: 'Ethereal Flower.webp' },
  { id: 'shop_5', file: 'Ethereal Flower(1).webp' },
  { id: 'shop_6', file: 'Ethereal Glowing Flower.webp' },
  { id: 'shop_7', file: 'Ethereal Translucent Flower.webp' },
  { id: 'shop_8', file: 'EtherealFlower.jpeg' },
  { id: 'shop_9', file: 'EtherealFlower-1-.jpeg' },
  { id: 'shop_10', file: 'ethreialbloom1.jpeg' },
  { id: 'shop_11', file: 'Radiant Flower Glow.webp' },
  { id: 'shop_12', file: 'Z5u14ZbqstJ9-Dkw_EtherealFlower-1-.jpeg' },
  // scratch cards
  { id: 'shop_13', file: 'scratch.webp' },
  { id: 'shop_14', file: 'scratch (2).webp' },
  { id: 'shop_15', file: 'scratch (3).webp' },
  { id: 'shop_16', file: 'scratch (4).webp' },
  { id: 'shop_17', file: 'scratch (5).webp' },
  { id: 'shop_18', file: 'scratch (6).webp' },
  { id: 'shop_19', file: 'scratch (7).webp' },
  { id: 'shop_20', file: 'scratch (8).webp' },
  { id: 'shop_21', file: 'scratch (9).webp' },
];

async function convert() {
  const thumbsDir = path.join(OUT_DIR, 'thumbs');
  const fullDir = path.join(OUT_DIR, 'full');
  fs.mkdirSync(thumbsDir, { recursive: true });
  fs.mkdirSync(fullDir, { recursive: true });

  let ok = 0, skip = 0, fail = 0;

  for (const item of items) {
    const num = parseInt(item.id.split('_')[1], 10);
    const srcDir = num <= 12 ? SOURCE_FLOWERS : SOURCE_SCRATCH;

    // Also handle by checking file extension ranges
    const src = path.join(srcDir, item.file);

    if (!fs.existsSync(src)) {
      console.log(`  SKIP  ${item.id} — source not found: ${item.file}`);
      skip++;
      continue;
    }

    try {
      const img = sharp(src);

      // Full-res WebP (quality 75)
      await img.clone().webp({ quality: 75 }).toFile(path.join(fullDir, `${item.id}.webp`));

      // Thumbnail 200px tall
      await img.clone()
        .resize({ height: 200, fit: 'inside', withoutEnlargement: true })
        .webp({ quality: 75 })
        .toFile(path.join(thumbsDir, `${item.id}.webp`));

      console.log(`  OK    ${item.id} → ${item.file}`);
      ok++;
    } catch (err) {
      console.error(`  FAIL  ${item.id} — ${err.message}`);
      fail++;
    }
  }

  console.log(`\nDone: ${ok} converted, ${skip} skipped, ${fail} failed`);
}

convert().catch(console.error);
