// Shared daily-verse pool + rotation picker for fallback ("suggested") decks.
//
// Previously decks.js and quran.js each kept a private 9-verse array and
// picked 3 CONSECUTIVE verses by day — consecutive days shared 2 of 3 cards,
// so users saw the same insight ("fa inna ma'al usri yusra") almost every
// launch. This module fixes that:
//
//   * One shared pool (27 verses — decks.js and quran.js both import from
//     here; add new copy in ONE place).
//   * pickDisjointTriple(): picks 3 EQUIDISTANT verses (stride = pool/3), so
//     each rotation step yields a completely different trio. Consecutive
//     decks share ZERO verses.
//   * rotationIndexFor(): deterministic per user+launch — advances one step
//     per launch (not per day), so every launch gets a fresh deck.

const DAILY_VERSES = [
  // Hardship & ease
  {
    reference: '94:5', english: 'Indeed, with hardship comes ease.',
    story: 'The Prophet ﷺ received these words in Mecca, in some of the hardest years of his life — and ease did come.',
    storyReference: 'Surah Ash-Sharh', lesson: 'Hard seasons end; keep walking.',
    taskTitle: 'Name one ease', taskDescription: 'Write down one small ease hidden inside today.',
  },
  {
    reference: '2:286', english: 'Allah does not burden a soul beyond what it can bear.',
    story: 'Prophet Yunus, alone in the belly of the whale, in total darkness — and even that was not beyond bearing.',
    storyReference: 'Surah Al-Anbiya', lesson: 'You were built for this weight.',
    taskTitle: 'Carry one thing', taskDescription: 'Pick the single heaviest task today and do just that one.',
  },
  {
    reference: '39:53', english: 'Do not despair of the mercy of Allah.',
    story: 'Musa stood before the sea with an army behind him — and the sea split.',
    storyReference: 'Surah Az-Zumar', lesson: 'No dead end is final with Allah.',
    taskTitle: 'Return once', taskDescription: 'Make one sincere du’a for the thing you gave up on.',
  },
  {
    reference: '65:3', english: 'And whoever relies upon Allah — He is sufficient for them.',
    story: 'Hajar ran between Safa and Marwa with a crying infant — and Zamzam burst forth where she least expected.',
    storyReference: 'Surah At-Talaq', lesson: 'Effort plus trust opens doors.',
    taskTitle: 'Delegate one worry', taskDescription: 'Hand one worry to Allah today and act on what you can.',
  },
  {
    reference: '3:139', english: 'Do not lose heart, nor grieve — you will be superior, if you are believers.',
    story: 'After the losses at Uhud, the believers were told not to grieve — and they rose again.',
    storyReference: 'Surah Aal-Imran', lesson: 'Setbacks are chapters, not endings.',
    taskTitle: 'Reframe one loss', taskDescription: 'Write what one recent setback taught you.',
  },
  {
    reference: '2:152', english: 'So remember Me; I will remember you.',
    story: 'Maryam, alone in childbirth pain, was told to shake the palm tree — remembrance met provision.',
    storyReference: 'Surah Al-Baqarah', lesson: 'One remembrance is never one-sided.',
    taskTitle: 'Remember once', taskDescription: 'Say one dhikr slowly, meaning every word.',
  },
  {
    reference: '13:28', english: 'Verily, in the remembrance of Allah do hearts find rest.',
    story: 'Yusuf, betrayed and imprisoned for years, kept a tranquil heart — and walked out to honor.',
    storyReference: 'Surah Ar-Ra’d', lesson: 'Calm is a practice, not a place.',
    taskTitle: 'Two quiet minutes', taskDescription: 'Sit still for two minutes and remember Allah.',
  },
  {
    reference: '20:114', english: 'My Lord, increase me in knowledge.',
    story: 'Musa traveled far simply to learn from Khidr — knowledge was worth the journey.',
    storyReference: 'Surah Ta-Ha', lesson: 'Keep learning, one verse at a time.',
    taskTitle: 'Learn one ayah', taskDescription: 'Read one ayah with its meaning today.',
  },
  {
    reference: '55:13', english: 'So which of the favors of your Lord would you deny?',
    story: 'Ibrahim was thrown into fire for his faith — and the fire was made cool and safe for him.',
    storyReference: 'Surah Ar-Rahman', lesson: 'Count favors before fears.',
    taskTitle: 'List three favors', taskDescription: 'Write three blessings you used today.',
  },
  // Patience & trust
  {
    reference: '2:153', english: 'Seek help through patience and prayer.',
    story: 'The believers at Badr were outnumbered three to one — patience and prayer preceded the victory.',
    storyReference: 'Surah Al-Baqarah', lesson: 'Steadiness is a weapon.',
    taskTitle: 'One patient act', taskDescription: 'Choose the harder, calmer response once today.',
  },
  {
    reference: '94:6', english: 'Indeed, with hardship will come ease — again.',
    story: 'The verse repeats the ease twice in one breath: after every difficulty, another ease. Ayah 6 answers ayah 5.',
    storyReference: 'Surah Ash-Sharh', lesson: 'Ease is promised twice.',
    taskTitle: 'Expect the second ease', taskDescription: 'Name the ease you are still waiting for — and expect it.',
  },
  {
    reference: '12:87', english: 'Do not despair of relief from Allah.',
    story: 'Yaqub, blind from grief, still told his sons not to despair — and years later the family was reunited.',
    storyReference: 'Surah Yusuf', lesson: 'Hope is a discipline.',
    taskTitle: 'Hold one hope', taskDescription: 'Write one outcome you have not given up on.',
  },
  {
    reference: '14:7', english: 'If you are grateful, I will surely increase you.',
    story: 'One sentence of shukr, and the promise of increase — the story of every harvest and every heartbeat.',
    storyReference: 'Surah Ibrahim', lesson: 'Gratitude multiplies.',
    taskTitle: 'Count twice', taskDescription: 'List two blessings you rarely notice.',
  },
  {
    reference: '8:46', english: 'Be patient and steadfast — Allah is with the steadfast.',
    story: 'The army that held its line at Badr held its faith too — companionship with Allah was the promise.',
    storyReference: 'Surah Al-Anfal', lesson: 'Hold the line.',
    taskTitle: 'Stand firm once', taskDescription: 'Return to one commitment you almost dropped.',
  },
  {
    reference: '3:200', english: 'Be steadfast; Allah does not waste the reward of the doers of good.',
    story: 'The closing verse of Aal-Imran sends the believers off with patience — nothing honest is ever wasted.',
    storyReference: 'Surah Aal-Imran', lesson: 'Your effort is banked.',
    taskTitle: 'Bank one deed', taskDescription: 'Do one quiet good deed nobody will see.',
  },
  // Mercy & forgiveness
  {
    reference: '7:23', english: 'Our Lord, we have wronged ourselves — have mercy on us.',
    story: 'Adam’s first words after the mistake were not excuses — they were a direct ask for mercy.',
    storyReference: 'Surah Al-A’raf', lesson: 'Return quickly.',
    taskTitle: 'Return once', taskDescription: 'Make istighfar for one specific thing today.',
  },
  {
    reference: '11:114', english: 'Good deeds remove bad deeds.',
    story: 'After listing grave sins, the surah pivots: one good deed erases. The ledger is always open.',
    storyReference: 'Surah Hud', lesson: 'One deed can flip the page.',
    taskTitle: 'Flip one page', taskDescription: 'Do one good deed deliberately as a reset.',
  },
  {
    reference: '4:110', english: 'Whoever does wrong and then replaces it with good — Allah is Forgiving, Merciful.',
    story: 'The verse does not end at the wrong; it ends at the replacement. Allah loves the return.',
    storyReference: 'Surah An-Nisa', lesson: 'Replace, don’t just regret.',
    taskTitle: 'Replace one thing', taskDescription: 'Swap one bad habit-hour with one good act today.',
  },
  {
    reference: '25:70', english: 'Whoever turns back and does righteousness — their deeds will be transformed.',
    story: 'Tawbah does not just delete; it transforms. The worst chapters become the best lessons.',
    storyReference: 'Surah Al-Furqan', lesson: 'Your past can become good.',
    taskTitle: 'Reframe the past', taskDescription: 'Write how one past mistake made you better.',
  },
  {
    reference: '16:97', english: 'Whoever does good, believer or not — We will give them a good life.',
    story: 'A promise of hayatan tayyibah — a life that feels good on the inside, not just looks good outside.',
    storyReference: 'Surah An-Nahl', lesson: 'Good living follows good doing.',
    taskTitle: 'Design one hour', taskDescription: 'Spend one hour exactly as your best self would.',
  },
  // Gratitude & presence
  {
    reference: '14:34', english: 'If you tried to count Allah’s favors, you could not.',
    story: 'The arithmetic of blessings fails on purpose — you run out of numbers before He runs out of gifts.',
    storyReference: 'Surah Ibrahim', lesson: 'The count never ends.',
    taskTitle: 'Count anyway', taskDescription: 'Start counting and stop at ten — notice what surfaced.',
  },
  {
    reference: '2:172', english: 'Eat of the good things We have provided, and be grateful.',
    story: 'Even eating is worship when it begins with recognition of the Provider.',
    storyReference: 'Surah Al-Baqarah', lesson: 'Every meal is a reminder.',
    taskTitle: 'Bless one meal', taskDescription: 'Pause before one meal and name the chain of provision.',
  },
  {
    reference: '102:1', english: 'Competition in increase diverts you.',
    story: 'The surah names the distraction: more, more, more — until the grave. Awareness breaks the spell.',
    storyReference: 'Surah At-Takathur', lesson: 'Notice the race you’re in.',
    taskTitle: 'Exit one race', taskDescription: 'Opt out of one comparison today — delete, mute, or release it.',
  },
  {
    reference: '87:8', english: 'We will ease you toward the easy way.',
    story: 'Allah does not just show the path — He sands it smooth for the one who turns to Him.',
    storyReference: 'Surah Al-A’la', lesson: 'The way gets easier as you walk it.',
    taskTitle: 'Take one step', taskDescription: 'Do the smallest next step of one hard goal.',
  },
  {
    reference: '65:2', english: 'Whoever is mindful of Allah — He makes a way out for them.',
    story: 'The divorce verses contain a universal promise: taqwa opens exits you didn’t know existed.',
    storyReference: 'Surah At-Talaq', lesson: 'A door exists.',
    taskTitle: 'Look for the exit', taskDescription: 'Write one stuck situation — and one possible door.',
  },
  {
    reference: '29:69', english: 'Those who strive for Us — We will guide them to Our ways.',
    story: 'The effort comes first, the map comes after. Guidance is given to the walkers.',
    storyReference: 'Surah Al-Ankabut', lesson: 'Move and the map appears.',
    taskTitle: 'Walk one stretch', taskDescription: 'Spend 15 minutes on the thing you keep planning.',
  },
  {
    reference: '20:25', english: 'My Lord, expand for me my chest and ease my task.',
    story: 'Musa’s first du’a at the burning bush was not for victory — it was for capacity. Then came everything else.',
    storyReference: 'Surah Ta-Ha', lesson: 'Ask for capacity first.',
    taskTitle: 'Ask for room', taskDescription: 'Make this du’a before your hardest task today.',
  },
];

module.exports = { DAILY_VERSES };

/**
 * Pick a fully disjoint trio: index k gives verses [k, k+N/3, k+2N/3] of the
 * pool. Striding by N/3 means consecutive k values share zero verses, and
 * each k covers a unique third of the pool. With N=27 there are 9 distinct
 * trios — 27 cards before any verse repeats, and NO card overlaps between
 * consecutive launches.
 */
function pickDisjointTriple(k) {
  const n = DAILY_VERSES.length;
  const stride = Math.floor(n / 3); // 9 with the 27-verse pool
  const base = ((k % stride) + stride) % stride;
  return [0, 1, 2].map((i) => DAILY_VERSES[base + i * stride]);
}

/**
 * Deterministic per-user rotation index that advances once per LAUNCH.
 * launchSeq: an increasing counter per user (see decks.getTodayDeck — it
 * derives this from the user's total deck history, so a brand-new counter
 * column is not needed).
 */
function rotationIndexFor(uid, launchSeq) {
  let h = 2166136261;
  const s = String(uid);
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619) >>> 0;
  }
  return (h + (Number(launchSeq) || 0)) >>> 0;
}

module.exports.pickDisjointTriple = pickDisjointTriple;
module.exports.rotationIndexFor = rotationIndexFor;
