const AI_INITIAL_DELAY_HOURS = Math.max(0, Number(process.env.AI_INITIAL_DELAY_HOURS || 0));

function getInitialAiScheduleSql() {
  if (AI_INITIAL_DELAY_HOURS <= 0) {
    return 'CURRENT_TIMESTAMP';
  }
  return `DATETIME('now', '+${AI_INITIAL_DELAY_HOURS} hours')`;
}

module.exports = { getInitialAiScheduleSql };
