const db = require('../lib/db');
const { awardStarsSchema, claimBonusSchema } = require('../lib/validation');

module.exports = function (app) {
  app.post('/api/v2/stars/bonus', async (req, res) => {
    try {
      const parsed = claimBonusSchema.safeParse(req.body);
      if (!parsed.success) {
        return res.status(400).json({ error: 'Validation failed', details: parsed.error.flatten().fieldErrors });
      }
      const { bonus } = parsed.data;

      const uid = req.uid;
      const userResult = await db.execute({
        sql: 'SELECT claimed_bonuses, stars FROM users WHERE id = ?',
        args: [uid],
      });
      if (!userResult.rows.length) return res.status(404).json({ error: 'User not found' });

      const claimed = JSON.parse(userResult.rows[0].claimed_bonuses ?? '[]');
      if (claimed.includes(bonus)) {
        return res.status(409).json({ error: 'Bonus already claimed' });
      }

      claimed.push(bonus);
      const newStars = (userResult.rows[0].stars ?? 0) + 100;
      await db.execute({
        sql: 'UPDATE users SET stars = ?, claimed_bonuses = ? WHERE id = ?',
        args: [newStars, JSON.stringify(claimed), uid],
      });

      res.json({ success: true, stars: newStars, bonus });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.post('/api/v2/stars/award', async (req, res) => {
    try {
      const parsed = awardStarsSchema.safeParse(req.body);
      if (!parsed.success) {
        return res.status(400).json({ error: 'Validation failed', details: parsed.error.flatten().fieldErrors });
      }
      const { action } = parsed.data;
      const uid = req.uid;

      const userResult = await db.execute({
        sql: 'SELECT stars, claimed_bonuses, daily_award_date, daily_award_count FROM users WHERE id = ?',
        args: [uid],
      });
      if (!userResult.rows.length) return res.status(404).json({ error: 'User not found' });

      const user = userResult.rows[0];
      let awardAmount = 0;

      switch (action) {
        case 'onboarding_complete': {
          const claimed = JSON.parse(user.claimed_bonuses ?? '[]');
          if (claimed.includes('onboarding')) {
            return res.status(409).json({ error: 'Onboarding bonus already claimed' });
          }
          awardAmount = 130;
          claimed.push('onboarding');
          await db.execute({
            sql: 'UPDATE users SET stars = COALESCE(stars, 0) + ?, claimed_bonuses = ? WHERE id = ?',
            args: [awardAmount, JSON.stringify(claimed), uid],
          });
          break;
        }
        case 'quran_read': {
          const today = new Date().toISOString().slice(0, 10);
          const lastDate = user.daily_award_date || '';
          let dailyCount = lastDate === today ? (user.daily_award_count || 0) : 0;
          if (dailyCount >= 3) {
            return res.status(429).json({ error: 'Daily limit reached (3 per day)' });
          }
          awardAmount = 3;
          dailyCount += 1;
          await db.execute({
            sql: 'UPDATE users SET stars = COALESCE(stars, 0) + ?, daily_award_date = ?, daily_award_count = ? WHERE id = ?',
            args: [awardAmount, today, dailyCount, uid],
          });
          break;
        }
        default:
          return res.status(400).json({ error: 'Invalid action' });
      }

      const starResult = await db.execute({
        sql: 'SELECT stars FROM users WHERE id = ?',
        args: [uid],
      });

      res.json({ success: true, stars: starResult.rows[0]?.stars ?? 0, action, awarded: awardAmount });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });
};
