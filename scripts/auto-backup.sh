#!/bin/bash
# Daily auto-backup: commit all changes and push to GitHub.
# Schedule with Windows Task Scheduler (daily at 11 PM).

set -e

cd "$(dirname "$0")/.."

# Nothing to do if working tree is clean
if git diff --quiet HEAD && [ -z "$(git ls-files --others --exclude-standard)" ]; then
  echo "[$(date)] Nothing to commit."
  exit 0
fi

git add -A
git commit -m "auto: daily backup $(date +%Y-%m-%d)"
git push origin main

echo "[$(date)] Pushed to GitHub."
