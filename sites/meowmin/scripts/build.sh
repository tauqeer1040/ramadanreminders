#!/usr/bin/env bash
set -euo pipefail

# Builds the Meowmin Flutter web app into landing/public/app, then builds the
# Astro site. Self-contained: installs a pinned Flutter SDK into the Netlify
# build cache when missing, so no external setup is needed.

FLUTTER_VERSION="${FLUTTER_VERSION:-3.44.0}"
FLUTTER_ARCHIVE="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${FLUTTER_ARCHIVE}"

# Persistent across Netlify builds; fall back to a user-local cache.
if [ -d "/opt/build/cache" ]; then
  CACHE_ROOT="${CACHE_ROOT:-/opt/build/cache}"
else
  CACHE_ROOT="${CACHE_ROOT:-$HOME/.cache}"
fi
FLUTTER_ROOT="${FLUTTER_ROOT:-$CACHE_ROOT/flutter}"
FLUTTER_BIN="$FLUTTER_ROOT/bin/flutter"

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

if [ ! -x "$FLUTTER_BIN" ]; then
  echo "==> Installing Flutter SDK $FLUTTER_VERSION"
  mkdir -p "$(dirname "$FLUTTER_ROOT")"
  tmp="$(mktemp -d)"
  curl -fsSL "$FLUTTER_URL" -o "$tmp/flutter.tar.xz"
  tar -xJf "$tmp/flutter.tar.xz" -C "$tmp"
  mv "$tmp/flutter" "$FLUTTER_ROOT"
  rm -rf "$tmp"
fi

export PATH="$FLUTTER_ROOT/bin:$PATH"

echo "==> Building Flutter web app"
"$FLUTTER_BIN" config --no-analytics >/dev/null 2>&1 || true
"$FLUTTER_BIN" pub get
"$FLUTTER_BIN" build web --release --base-href /app/

echo "==> Copying app into Astro public dir"
rm -rf landing/public/app
mkdir -p landing/public/app
cp -r build/web/* landing/public/app/

echo "==> Building Astro site"
cd landing
npm ci
npm run build
