const db = require('../lib/db');

module.exports = function (app) {
  app.get('/api/v2/app-version', async (req, res) => {
    try {
      const cfg = await db.execute("SELECT key, value FROM app_config");
      const result = {};
      for (const row of cfg.rows) result[row.key] = row.value;
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.get('/api/v2/ayah', async (req, res) => {
    const { ref } = req.query;
    if (!ref) return res.status(400).json({ error: 'Missing ref' });

    try {
      let ayahKey = ref;
      let url = '';

      if (ref === 'random') {
        url = 'https://api.alquran.cloud/v1/ayah/random/editions/quran-uthmani,en.transliteration,en.sahih';
      } else {
        const match = String(ref).match(/(\d+)[\s:]+(\d+)/);
        if (match) ayahKey = `${match[1]}:${match[2]}`;
        url = `https://api.alquran.cloud/v1/ayah/${ayahKey}/editions/quran-uthmani,en.transliteration,en.sahih`;
      }

      const textRes = await fetch(url);
      if (!textRes.ok) throw new Error('Failed to fetch from AlQuran Cloud');
      const textJson = await textRes.json();
      const ayahData = textJson.data;
      const arabicAyah = ayahData[0];
      const transliterationAyah = ayahData[1];
      const englishAyah = ayahData[2];
      const actualAyahNumber = arabicAyah.number;

      const audioRes = await fetch(`https://api.alquran.cloud/v1/ayah/${actualAyahNumber}/ar.alafasy`);
      const audioJson = await audioRes.json();

      res.json({
        arabic: arabicAyah.text,
        transliteration: transliterationAyah.text,
        english: englishAyah.text,
        surah: arabicAyah.surah.englishName,
        ayahNumber: arabicAyah.numberInSurah,
        audioUrl: audioJson.data.audio,
      });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });
};
