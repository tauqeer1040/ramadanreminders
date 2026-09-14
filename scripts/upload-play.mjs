// Upload a release AAB to a Google Play track using the Play Developer API.
// Uses the same service account as fastlane supply.
//
// Usage:
//   node scripts/upload-play.mjs check                                   # read-only: show production track state
//   node scripts/upload-play.mjs <track> <path/to/app-release.aab>       # upload AAB to track and commit
//
// Examples:
//   node scripts/upload-play.mjs check
//   node scripts/upload-play.mjs production build/app/outputs/bundle/release/app-release.aab

import fs from "node:fs";
import crypto from "node:crypto";

const SA_PATH = "android/fastlane/play-developer-api.json";
const PACKAGE = "com.taucity.meowmin";
const API = "https://androidpublisher.googleapis.com/androidpublisher/v3";
const UPLOAD_API = "https://androidpublisher.googleapis.com/upload/androidpublisher/v3";
const SCOPE = "https://www.googleapis.com/auth/androidpublisher";

const [, , mode = "check", aabPath, releaseNotesPath] = process.argv;

if (mode !== "check" && !aabPath) {
  console.error("Usage: node scripts/upload-play.mjs <track> <aab> | check");
  process.exit(1);
}

const sa = JSON.parse(fs.readFileSync(SA_PATH, "utf8"));

function b64url(buf) {
  return buf.toString("base64").replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

async function getAccessToken() {
  const iat = Math.floor(Date.now() / 1000);
  const header = b64url(Buffer.from(JSON.stringify({ alg: "RS256", typ: "JWT" })));
  const claims = b64url(
    Buffer.from(
      JSON.stringify({
        iss: sa.client_email,
        scope: SCOPE,
        aud: "https://oauth2.googleapis.com/token",
        iat,
        exp: iat + 3600,
      })
    )
  );
  const signer = crypto.createSign("RSA-SHA256");
  signer.update(`${header}.${claims}`);
  const sig = b64url(signer.sign(sa.private_key));
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${header}.${claims}.${sig}`,
    }),
  });
  if (!res.ok) throw new Error(`Auth failed: ${res.status} ${await res.text()}`);
  return (await res.json()).access_token;
}

async function api(token, method, url, body, headers = {}) {
  const res = await fetch(url, {
    method,
    headers: { Authorization: `Bearer ${token}`, ...headers },
    body,
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`${method} ${url} -> ${res.status}: ${text}`);
  return text ? JSON.parse(text) : {};
}

/**
 * Resumable upload per Google's classic protocol:
 * 1) POST with ?uploadType=resumable + X-Upload-Content-* headers -> 200 + Location (session URL)
 * 2) PUT the bytes to the session URL in chunks with Content-Range; 308 = keep going.
 */
async function uploadBundle(token, editId, aab) {
  const sessionStart = await fetch(
    `${UPLOAD_API}/applications/${PACKAGE}/edits/${editId}/bundles?uploadType=resumable`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "X-Upload-Content-Type": "application/octet-stream",
        "X-Upload-Content-Length": String(aab.length),
        "Content-Length": "0",
      },
    }
  );
  if (!sessionStart.ok) {
    throw new Error(`Upload session start failed: ${sessionStart.status} ${await sessionStart.text()}`);
  }
  const sessionUrl = sessionStart.headers.get("Location");
  if (!sessionUrl) throw new Error("No Location header in resumable session response");

  const CHUNK = 8 * 1024 * 1024; // 8 MB
  let offset = 0;
  while (true) {
    const end = Math.min(offset + CHUNK, aab.length) - 1;
    const chunk = aab.subarray(offset, end + 1);
    const res = await fetch(sessionUrl, {
      method: "PUT",
      headers: {
        "Content-Length": String(chunk.length),
        "Content-Type": "application/octet-stream",
        "Content-Range": `bytes ${offset}-${end}/${aab.length}`,
      },
      body: chunk,
    });
    if (res.status === 308) {
      offset = end + 1;
      console.log(`  uploaded ${offset}/${aab.length} bytes`);
      continue;
    }
    const text = await res.text();
    if (!res.ok) throw new Error(`Chunk upload failed at ${offset}: ${res.status} ${text}`);
    return JSON.parse(text);
  }
}

function summarizeTrack(track) {
  console.log(`Track: ${track.track} | status: ${track.status ?? "(n/a)"}`);
  for (const rel of track.releases ?? []) {
    const codes = (rel.versionCodes ?? []).join(", ");
    console.log(`  Release: name=${rel.name ?? "-"} status=${rel.status} versionCodes=[${codes}]`);
    if (rel.userFraction) console.log(`    staged rollout: ${(rel.userFraction * 100).toFixed(1)}%`);
  }
  if (!track.releases?.length) console.log("  (no releases)");
}

const token = await getAccessToken();
console.log("Authenticated as", sa.client_email);

if (mode === "check") {
  // Read-only: create an edit, read the production track, then delete the edit.
  const edit = await api(token, "POST", `${API}/applications/${PACKAGE}/edits`);
  try {
    const track = await api(
      token,
      "GET",
      `${API}/applications/${PACKAGE}/edits/${edit.id}/tracks/production`
    );
    summarizeTrack(track);
  } catch (err) {
    if (String(err).includes("404")) {
      console.log("Track: production | (no releases yet — track empty)");
    } else {
      throw err;
    }
  } finally {
    await api(token, "DELETE", `${API}/applications/${PACKAGE}/edits/${edit.id}`);
  }
  console.log("\nDone (read-only check, edit discarded).");
  process.exit(0);
}

// ---- Upload mode ----
const aab = fs.readFileSync(aabPath);
console.log(`AAB size: ${(aab.length / 1024 / 1024).toFixed(1)} MB`);

const edit = await api(token, "POST", `${API}/applications/${PACKAGE}/edits`);
console.log("Edit created:", edit.id);

try {
  console.log("Uploading AAB (resumable)...");
  const bundle = await uploadBundle(token, edit.id, aab);
  console.log(`Bundle uploaded: versionCode=${bundle.versionCode}`);

  const releaseNotes = [];
  if (releaseNotesPath && fs.existsSync(releaseNotesPath)) {
    for (const line of fs.readFileSync(releaseNotesPath, "utf8").split("\n")) {
      const m = line.match(/^([a-z]{2}(?:-[A-Z]{2})?)\s*:\s*(.+)$/);
      if (m) releaseNotes.push({ language: m[1], text: m[2] });
    }
  }

  const trackUpdate = {
    track: mode,
    releases: [
      {
        name: `${bundle.versionName ?? ""} (${bundle.versionCode})`,
        versionCodes: [String(bundle.versionCode)],
        status: "completed",
        ...(releaseNotes.length ? { releaseNotes } : {}),
      },
    ],
  };
  await api(
    token,
    "PUT",
    `${API}/applications/${PACKAGE}/edits/${edit.id}/tracks/${encodeURIComponent(mode)}`,
    JSON.stringify(trackUpdate),
    { "Content-Type": "application/json" }
  );
  console.log(`Track "${mode}" updated with versionCode ${bundle.versionCode}`);

  const committed = await api(
    token,
    "POST",
    `${API}/applications/${PACKAGE}/edits/${edit.id}:commit?changesNotSentForReview=false`
  );
  console.log("Edit committed. App version:", committed.appVersion?.versionCode ?? "(pending)");
  console.log("\n✅ Upload complete — release should appear in Play Console shortly.");
  console.log("   Production rollouts to existing users go live after Google review.");
} catch (err) {
  console.error("Upload failed, discarding edit:", String(err));
  await api(token, "DELETE", `${API}/applications/${PACKAGE}/edits/${edit.id}`).catch(() => {});
  process.exit(1);
}
