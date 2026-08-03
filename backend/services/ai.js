const FANAR_BASE_URL = process.env.FANAR_BASE_URL || 'https://api.fanar.qa';
const FANAR_API_KEY = process.env.FANAR_API_KEY;
const FANAR_MODEL = process.env.FANAR_MODEL || 'Fanar';

const OPENROUTER_MODELS = [
  'stepfun/step-3.5-flash:free',
  'arcee-ai/trinity-large-preview:free',
  'google/gemma-3-27b-it:free',
  'google/gemma-3-12b-it:free',
  'meta-llama/llama-3.3-70b-instruct:free',
  'nousresearch/hermes-3-llama-3.1-405b:free',
  'mistralai/mistral-small-3.1-24b-instruct:free',
];

function parseAiJson(rawText) {
  let raw = rawText || '';
  if (raw.includes('```json')) raw = raw.split('```json')[1].split('```')[0].trim();
  else if (raw.includes('```')) raw = raw.split('```')[1].split('```')[0].trim();
  return JSON.parse(raw);
}

async function callFanarRaw(prompt, temperature = 0.2) {
  if (!FANAR_API_KEY) {
    throw new Error('FANAR_API_KEY is missing');
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 15000);

  const res = await fetch(`${FANAR_BASE_URL}/v1/chat/completions`, {
    signal: controller.signal,
    method: 'POST',
    headers: {
      Authorization: `Bearer ${FANAR_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: FANAR_MODEL,
      messages: [{ role: 'user', content: prompt }],
      temperature,
    }),
  });

  clearTimeout(timeout);

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Fanar AI request failed (${res.status}): ${body.slice(0, 300)}`);
  }

  const data = await res.json();
  return data.choices?.[0]?.message?.content || '';
}

async function callFanar(prompt) {
  const raw = await callFanarRaw(prompt);
  return parseAiJson(raw);
}

async function callOpenRouterRaw(prompt) {
  if (!process.env.OPENROUTER_API_KEY) {
    throw new Error('OPENROUTER_API_KEY is missing');
  }

  let lastError = null;
  for (const model of OPENROUTER_MODELS) {
    try {
      const res = await fetch('https://openrouter.ai/api/v1/chat/completions', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${process.env.OPENROUTER_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model,
          messages: [{ role: 'user', content: prompt }],
        }),
      });

      if (!res.ok) {
        lastError = new Error(`OpenRouter ${model} failed with ${res.status}`);
        continue;
      }

      const data = await res.json();
      return data.choices?.[0]?.message?.content || '';
    } catch (error) {
      lastError = error;
    }
  }

  throw lastError || new Error('All OpenRouter models failed');
}

async function callOpenRouter(prompt) {
  const raw = await callOpenRouterRaw(prompt);
  return parseAiJson(raw);
}

async function callAIRaw(prompt, temperature = 0.2) {
  try {
    return await callFanarRaw(prompt, temperature);
  } catch (fanarError) {
    console.warn('[AI] Fanar failed, falling back to OpenRouter:', fanarError.message);
  }

  return await callOpenRouterRaw(prompt);
}

async function callAI(prompt) {
  try {
    return await callFanar(prompt);
  } catch (fanarError) {
    console.warn('[AI] Fanar failed, falling back to OpenRouter:', fanarError.message);
  }

  try {
    return await callOpenRouter(prompt);
  } catch (openrouterError) {
    console.error('[AI] OpenRouter failed:', openrouterError.message);
    throw openrouterError;
  }
}

module.exports = {
  callAI,
  callAIRaw,
  callFanarRaw,
  callOpenRouterRaw,
  callFanar,
  callOpenRouter,
  parseAiJson,
};
