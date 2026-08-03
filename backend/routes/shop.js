const express = require('express');
const db = require('../lib/db');
const { purchaseItemSchema } = require('../lib/validation');
const { assetRoot } = require('../lib/runtime');

const SHOP_ASSETS_DIR = assetRoot();

const shopItems = [
  { id: 'shop_1',  name: 'Delicate Translucent Flower', cost: 100 },
  { id: 'shop_2',  name: 'Orange Bloom',                 cost: 100 },
  { id: 'shop_3',  name: 'Ethereal Flower in Motion',    cost: 100 },
  { id: 'shop_4',  name: 'Ethereal Flower',              cost: 100 },
  { id: 'shop_5',  name: 'Ethereal Flower V2',           cost: 100 },
  { id: 'shop_6',  name: 'Glowing Flower',               cost: 100 },
  { id: 'shop_7',  name: 'Translucent Flower',           cost: 100 },
  { id: 'shop_8',  name: 'Ethereal Bloom',               cost: 100 },
  { id: 'shop_9',  name: 'Ethereal Bloom V2',            cost: 100 },
  { id: 'shop_10', name: 'Ethreial Bloom',               cost: 100 },
  { id: 'shop_11', name: 'Radiant Flower Glow',          cost: 100 },
  { id: 'shop_12', name: 'Ethereal Bloom V3',            cost: 100 },
  { id: 'shop_13', name: 'Scratch Card 1',               cost: 100 },
  { id: 'shop_14', name: 'Scratch Card 2',               cost: 100 },
  { id: 'shop_15', name: 'Scratch Card 3',               cost: 100 },
  { id: 'shop_16', name: 'Scratch Card 4',               cost: 100 },
  { id: 'shop_17', name: 'Scratch Card 5',               cost: 100 },
  { id: 'shop_18', name: 'Scratch Card 6',               cost: 100 },
  { id: 'shop_19', name: 'Scratch Card 7',               cost: 100 },
  { id: 'shop_20', name: 'Scratch Card 8',               cost: 100 },
  { id: 'shop_21', name: 'Scratch Card 9',               cost: 100 },
];

const baseAssetUrl = (id) => ({
  thumbnailUrl: `/assets/shop/thumbs/${id}.webp`,
  imageUrl: `/assets/shop/full/${id}.webp`,
});

module.exports = function (app) {
  if (SHOP_ASSETS_DIR) {
    app.use('/assets', express.static(SHOP_ASSETS_DIR));
  }

  app.get('/api/v2/shop/items', (req, res) => {
    const items = shopItems.map((item) => ({
      ...item,
      ...baseAssetUrl(item.id),
    }));
    res.json({ items });
  });

  app.post('/api/v2/shop/purchase', async (req, res) => {
    try {
      const parsed = purchaseItemSchema.safeParse(req.body);
      if (!parsed.success) {
        return res.status(400).json({ error: 'Validation failed', details: parsed.error.flatten().fieldErrors });
      }
      const { itemId } = parsed.data;

      const item = shopItems.find(i => i.id === itemId);
      if (!item) return res.status(404).json({ error: 'Item not found' });

      const uid = req.uid;
      const userResult = await db.execute({
        sql: 'SELECT stars, purchases FROM users WHERE id = ?',
        args: [uid],
      });
      if (!userResult.rows.length) return res.status(404).json({ error: 'User not found' });

      const currentStars = userResult.rows[0].stars ?? 0;
      if (currentStars < item.cost) {
        return res.status(402).json({ error: 'Insufficient stars' });
      }

      const newStars = currentStars - item.cost;
      const existingPurchases = JSON.parse(userResult.rows[0].purchases ?? '[]');
      if (!existingPurchases.includes(itemId)) {
        existingPurchases.push(itemId);
      }

      await db.execute({
        sql: 'UPDATE users SET stars = ?, purchases = ? WHERE id = ?',
        args: [newStars, JSON.stringify(existingPurchases), uid],
      });

      res.json({ success: true, stars: newStars });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });
};
