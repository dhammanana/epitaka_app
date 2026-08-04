#!/bin/bash

PUBSPEC="pubspec.yaml"
ASSET_DIR="android/packs/core_db/src/main/assets"
DATA_DIR="../data"

CURRENT=$(grep '^version:' "$PUBSPEC" | sed -E 's/.*\+([0-9]+).*/\1/')

if [ -z "$CURRENT" ]; then
    echo "Could not find version build number."
    exit 1
fi

NEXT=$((CURRENT + 1))

sed -i '' -E "s/^version: (.*)\+[0-9]+/version: \1+$NEXT/" "$PUBSPEC"

echo "Building version with build number: $NEXT"

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

# Build AAB
flutter build appbundle \
  --release \
  --flavor prod \
  --target-platform android-arm64
