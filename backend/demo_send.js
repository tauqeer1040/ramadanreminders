const PORT = 3007;
const BASE = 'http://localhost:' + PORT;

async function run() {
  // 1. Upsert a demo user first
  console.log('\n--- Upserting user profile ---');
  const userRes = await fetch(BASE + '/api/v2/user/upsert', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ uid: 'demo_user', displayName: 'Tauqeer', email: 'tau@test.com' })
  });
  console.log('User upsert:', await userRes.json());

  // 2. Post 3 journals with that user linked
  const journals = [
    { id: '2026-03-24T08:00:00Z', uid: 'demo_user', text: 'I feel very grateful today for the opportunity to pray Fajr in the mosque. The peace I felt was incredible.' },
    { id: '2026-03-24T14:00:00Z', uid: 'demo_user', text: 'Struggling with patience today at work. My colleagues are being difficult but I am trying my best to keep my fast with a smile.' },
    { id: '2026-03-24T21:00:00Z', uid: 'demo_user', text: 'I am thinking about how to help the poor this Ramadan. I want to donate a portion of my savings to a local food bank.' }
  ];

  console.log('\n--- Posting journals ---');
  for (const j of journals) {
    const r = await fetch(BASE + '/api/v2/journal', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(j)
    });
    console.log(j.id, '->', await r.json());
  }

  // 3. Wait 35 seconds for poller to finish all 3
  console.log('\n--- Waiting 35s for AI poller to process... ---');
  await new Promise(r => setTimeout(r, 35000));

  // 4. Fetch the full journal list for the user
  console.log('\n--- Fetching user journals ---');
  const listRes = await fetch(BASE + '/api/v2/user/demo_user/journals');
  const list = await listRes.json();
  for (const j of list) {
    console.log('\nJournal:', j.id, '| Status:', j.status);
    if (j.suggestedTasks && j.suggestedTasks.length > 0) {
      console.log('  Suggested Tasks:');
      j.suggestedTasks.forEach((t, i) => console.log('    ' + (i+1) + '. ' + t.title + ' — ' + t.description));
      console.log('  Task Tags:', j.taskTags.join(', '));
    } else {
      console.log('  (AI still pending or failed)');
    }
  }

  // 5. Check user profile
  console.log('\n--- Fetching user profile ---');
  const profileRes = await fetch(BASE + '/api/v2/user/demo_user');
  const profile = await profileRes.json();
  console.log('Name:', profile.display_name);
  console.log('Journal Count:', profile.journal_count);
  console.log('Relevant Tags:', profile.relevant_tags);
}

run().catch(console.error);
