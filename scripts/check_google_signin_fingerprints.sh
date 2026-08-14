#!/bin/bash
# Prints the signing-certificate fingerprints that Google Sign-In
# (Credential Manager on Android) cares about.
#
# Google Play services issues an ID token only when the calling app's
# package + signing-certificate fingerprint is registered in a Google Cloud
# "Android" OAuth client. If the production app's certificate fingerprint
# isn't registered, login works in debug but fails in production — this
# script makes it easy to see exactly which fingerprint Google sees.
#
# Usage:
#   ./scripts/check_google_signin_fingerprints.sh [path/to/app-release.apk]
#
# With an APK (the artifact you actually ship), prints the certificate that
# devices see. Without one, prints the debug and upload keystore fingerprints.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

keytool_fingerprints() {
  # $1 = keystore path, $2 = alias, $3 = storepass
  keytool -list -v -keystore "$1" -storepass "$3" -alias "$2" 2>/dev/null \
    | grep -E "^\s+(SHA1|SHA256):" | sed 's/^[[:space:]]*//'
}

echo "── Debug keystore (used by 'flutter run' / debug builds) ──────────────"
DEBUG_KEY="$HOME/.android/debug.keystore"
if [ -f "$DEBUG_KEY" ]; then
  keytool_fingerprints "$DEBUG_KEY" androiddebugkey android
  echo "(Package: whichever flavor you run — com.dn.epitaka or com.dn.epitaka.dev)"
else
  echo "not found at $DEBUG_KEY"
fi

echo ""
echo "── Upload keystore (signs the AAB/APK for release) ────────────────────"
KEY_PROPS="$ROOT_DIR/android/key.properties"
if [ -f "$KEY_PROPS" ]; then
  ALIAS=$(grep '^keyAlias' "$KEY_PROPS" | cut -d= -f2-)
  SPASS=$(grep '^storePassword' "$KEY_PROPS" | cut -d= -f2-)
  SFILE_RAW=$(grep '^storeFile' "$KEY_PROPS" | cut -d= -f2-)
  # key.properties is read from android/ — resolve relative paths the same way.
  if [[ "$SFILE_RAW" == /* ]]; then
    SFILE="$SFILE_RAW"
  else
    SFILE="$ROOT_DIR/android/$SFILE_RAW"
  fi
  if [ ! -f "$SFILE" ]; then
    # Fall back to common locations if the configured path is stale.
    for cand in "$ROOT_DIR/android/upload-keystore.jks" "$ROOT_DIR/upload-keystore.jks"; do
      [ -f "$cand" ] && SFILE="$cand" && break
    done
  fi
  if [ -f "$SFILE" ]; then
    keytool_fingerprints "$SFILE" "$ALIAS" "$SPASS"
  else
    echo "keystore not found (looked for: $SFILE_RAW → $SFILE)"
  fi
else
  echo "no android/key.properties — CI-only signing"
fi

echo ""
echo "── Play App Signing key (what Play-distributed installs actually see) ──"
echo "Google Play re-signs AABs with its own key, so for Play installs the"
echo "fingerprint to register is the 'App signing key certificate' from"
echo "Play Console → Setup → App signing — NOT the upload keystore above."
echo "If you distribute the APK directly (sideload), the upload keystore IS"
echo "what devices see."

APK="${1:-}"
if [ -n "$APK" ]; then
  APKSIGNER=""
  for a in "$HOME/Library/Android/sdk/build-tools/"*/apksigner \
           "$ANDROID_HOME/build-tools/"*/apksigner; do
    [ -x "$a" ] && APKSIGNER="$a" && break
  done
  if [ -z "$APKSIGNER" ]; then
    APKSIGNER="$(command -v apksigner || true)"
  fi
  echo ""
  echo "── Certificate inside $APK (what Google actually sees) ────────────────"
  if [ -n "$APKSIGNER" ] && [ -f "$APK" ]; then
    "$APKSIGNER" verify --print-certs "$APK" | grep -E "SHA-1|SHA-256"
  else
    echo "apksigner not found or APK missing"
  fi
fi
