require('dotenv').config();
const express = require('express');
const cors = require('cors');
const xss = require('xss');
const { GoogleGenerativeAI } = require('@google/generative-ai');

const app = express();
const port = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Initialize Gemini AI
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

app.post('/api/analyze-journal', async (req, res) => {
  try {
    const { journalText } = req.body;

    if (!journalText || journalText.trim().length === 0) {
      return res.status(400).json({ error: 'Journal text is required.' });
    }

    if (journalText.length > 2000) {
      return res.status(400).json({ error: 'Journal text exceeds the maximum allowed length of 2000 characters.' });
    }

    // Sanitize input to strip any potential HTML or scripts before passing to AI
    const sanitizedText = xss(journalText);

    if (!process.env.GEMINI_API_KEY) {
        return res.status(500).json({ error: 'Gemini API Key is missing on the server.' });
    }

    // Use Gemini Lite or standard model based on what's available
    const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash-latest' });

    const prompt = `
You are an Islamic scholar and an empathetic guide for a user during Ramadan.
The user has written the following journal entry yesterday:
"${sanitizedText}"

Your task is to provide a very brief, comforting, and insightful response that relates what the user wrote to Islamic teachings, the Quran, or the Sunnah. 
Include ONE specific Ayah (Quranic verse), Surah reference, or brief Islamic history incident that directly relates to their journal entry.

Format your response exactly as this JSON structure:
{
  "greeting": "A short relatable opening acknowledging their journal.",
  "insight": "The Islamic wisdom or teaching related to what they wrote.",
  "reference": "The exact Ayah, Surah, or Hadith reference (e.g., 'Surah Al-Baqarah, Ayat 286').",
  "quote": "The actual text of the Quranic verse or Hadith."
}

Ensure your response is valid JSON and nothing else.
`;

    const result = await model.generateContent(prompt);
    const responseText = result.response.text();
    
    // Clean up potential markdown formatting from Gemini's response
    let jsonString = responseText;
    if (jsonString.startsWith('\`\`\`json')) {
        jsonString = jsonString.replace(/\`\`\`json/g, '').replace(/\`\`\`/g, '').trim();
    }

    const analysis = JSON.parse(jsonString);

    res.json(analysis);

  } catch (error) {
    console.error('Error analyzing journal:', error);
    res.status(500).json({ error: 'Failed to analyze journal entry. Please try again later.' });
  }
});

app.listen(port, () => {
  console.log(`Journal Analysis Backend running on http://localhost:${port}`);
});
