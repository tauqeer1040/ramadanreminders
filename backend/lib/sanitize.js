const LEADING_EMOJI_RE = /^[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}\u{2B00}-\u{2BFF}\u{2190}-\u{21FF}\u{2300}-\u{23FF}\u{2B50}\u{200D}]+/u;

function stripLeadingEmoji(value) {
  if (typeof value !== 'string') return value;
  return value.replace(LEADING_EMOJI_RE, '').trim();
}

const EMOJI_TEXT_FIELDS = ['insight', 'explanation', 'story', 'lesson'];

function sanitizeInsightCards(cards) {
  if (!Array.isArray(cards)) return cards;
  return cards.map((card) => {
    const clean = { ...card };
    for (const field of EMOJI_TEXT_FIELDS) {
      clean[field] = stripLeadingEmoji(clean[field]);
    }
    return clean;
  });
}

module.exports = { stripLeadingEmoji, sanitizeInsightCards, EMOJI_TEXT_FIELDS };
