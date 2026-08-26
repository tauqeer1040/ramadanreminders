const db = require('../lib/db');
const { upsertUser } = require('../lib/users');
const { upsertStreak, linkFriends, getFriendStreak, getFriendInfo } = require('../lib/invites');
const { syncStreakSchema, acceptInviteSchema } = require('../lib/validation');

module.exports = function (app) {
  app.post('/api/v2/streaks/sync', async (req, res) => {
    const parsed = syncStreakSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Validation failed', details: parsed.error.flatten().fieldErrors });
    }
    const uid = req.uid;
    try {
      await upsertStreak(uid, parsed.data.streak);
      res.json({ success: true });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.post('/api/v2/invites/accept', async (req, res) => {
    const parsed = acceptInviteSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Validation failed', details: parsed.error.flatten().fieldErrors });
    }
    const { inviterUid, myName, myCat } = parsed.data;
    const uid = req.uid;
    if (inviterUid === uid) {
      return res.status(400).json({ error: 'Cannot invite yourself' });
    }
    try {
      if (myName || myCat) {
        await upsertUser(uid, myName, null, myCat);
      }
      await linkFriends(uid, inviterUid);
      const inviter = await getFriendInfo(uid);
      res.json({
        success: true,
        inviter: inviter || { displayName: null, catName: null },
      });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.get('/api/v2/streaks/friend', async (req, res) => {
    const uid = req.uid;
    try {
      const friend = await getFriendStreak(uid);
      if (!friend) return res.json({ linked: false });
      res.json({ linked: true, streak: friend.streak, updatedAt: friend.updatedAt });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.get('/api/v2/friends/info', async (req, res) => {
    const uid = req.uid;
    try {
      const friend = await getFriendInfo(uid);
      if (!friend) return res.json({ linked: false });
      res.json({ linked: true, uid: friend.uid, displayName: friend.displayName, catName: friend.catName });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });
};
