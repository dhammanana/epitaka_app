#!/bin/bash

PUBSPEC="pubspec.yaml"

CURRENT=$(grep '^version:' "$PUBSPEC" | sed -E 's/.*\+([0-9]+).*/\1/')

if [ -z "$CURRENT" ]; then
    echo "Could not find version build number."
    exit 1
fi

NEXT=$((CURRENT + 1))

sed -i '' -E "s/^version: (.*)\+[0-9]+/version: \1+$NEXT/" "$PUBSPEC"

echo "Building version with build number: $NEXT"

flutter build appbundle --release
