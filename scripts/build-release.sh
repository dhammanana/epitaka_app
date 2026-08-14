#!/bin/bash

PUBSPEC="pubspec.yaml"
ASSET_DIR="android/packs/core_db/src/main/assets"
DATA_DIR="../data"
CHANGELOG_FILE="assets/changelog.md"

CURRENT=$(grep '^version:' "$PUBSPEC" | sed -E 's/.*\+([0-9]+).*/\1/')

if [ -z "$CURRENT" ]; then
    echo "Could not find version build number."
    exit 1
fi

NEXT=$((CURRENT + 1))

VERSION=$(grep '^version:' "$PUBSPEC" | sed -E 's/version: ([0-9.]+)\+.*/\1/')

# Remove stray 0-byte databases from the bundled assets. An empty db file in
# assets/db/ gets copied by the app on first launch (ensureBundledDatabases)
# and then blocks the real install-time asset-pack copy, leaving fresh
# installs with an empty database.
find assets/db -name '*.db' -size 0 -delete 2>/dev/null || true

sed -i '' -E "s/^version: (.*)\\+[0-9]+/version: \\1+$NEXT/" "$PUBSPEC"

echo "Building version with build number: $NEXT"

# ── Generate changelog (release notes) ────────────────────────────────────
# Collect commit messages since the last release tag and bundle them into
# assets/changelog.md, which the app shows in a "What's New" dialog after
# the update is installed. The same text is printed below for pasting into
# the Google Play release notes.
PREV_TAG=$(git describe --tags --abbrev=0 2>/dev/null || true)

if [ -n "$PREV_TAG" ]; then
    CHANGES=$(git log --no-merges --format='- %s' "$PREV_TAG..HEAD" 2>/dev/null || true)
fi
if [ -z "$CHANGES" ]; then
    # No tag yet (first release) or no commits after the tag — fall back to
    # the most recent commits.
    CHANGES=$(git log --no-merges -15 --format='- %s' 2>/dev/null || true)
fi

{
    echo "## What's new in version $VERSION (build $NEXT)"
    echo ""
    echo "$CHANGES"
} > "$CHANGELOG_FILE"

echo ""
echo "────────────────────────── Release notes ──────────────────────────"
echo "Version $VERSION (build $NEXT)"
echo ""
echo "$CHANGES"
echo "───────────────────────────────────────────────────────────────────"
echo ""

# Copy core databases into Android asset pack
mkdir -p "$ASSET_DIR"

for file in epitaka.db epitaka_en.db dpd-dictionary.db; do
    if [ ! -f "$DATA_DIR/$file" ]; then
        echo "ERROR: $DATA_DIR/$file not found"
        exit 1
    fi

    cp "$DATA_DIR/$file" "$ASSET_DIR/$file"
    echo "Copied $file"
done

# Clean stale build outputs. Without this, Gradle's incremental build can
# reuse cached native libraries from a previous release, so the freshly
# compiled Dart code (libapp.so) never makes it into the AAB and the upload
# looks like a new version while still containing old code.
flutter clean

# Build AAB
flutter build appbundle \
  --release \
  --flavor prod \
  --target-platform android-arm64
