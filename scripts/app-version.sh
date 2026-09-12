#!/usr/bin/env bash
# Resolve the version every platform's build should stamp into its binary, and
# print it as env lines for "$GITHUB_ENV".
#
#   scripts/app-version.sh >> "$GITHUB_ENV"
#
# The release tag outranks pubspec.yaml for the version NAME. v1.1.1 was tagged
# on a pubspec that still read 1.1.0, so every artefact of that release called
# itself 1.1.0 — and the desktop update check, which compares the running
# version against the latest GitHub tag, told every user to update to the
# release they already had. On a manual dispatch there is no tag, so pubspec
# stays the source.
#
# The build NUMBER always comes from pubspec: it is the Play Store versionCode
# and the Windows FILEVERSION's fourth field, and tags carry no equivalent.

set -euo pipefail

PUBSPEC_VERSION=$(grep -E '^version:' pubspec.yaml | head -n 1 | cut -d':' -f2- | tr -d '[:space:]')
if [ -z "$PUBSPEC_VERSION" ]; then
  echo "ERROR: could not parse version from pubspec.yaml" >&2
  exit 1
fi

APP_VERSION="${PUBSPEC_VERSION%%+*}"
APP_BUILD_NUMBER="${PUBSPEC_VERSION#*+}"
if [ "$APP_BUILD_NUMBER" = "$PUBSPEC_VERSION" ]; then
  APP_BUILD_NUMBER=0
fi

case "${GITHUB_REF:-}" in
  refs/tags/v*) APP_VERSION="${GITHUB_REF#refs/tags/v}" ;;
esac

echo "APP_VERSION=$APP_VERSION"
echo "APP_BUILD_NUMBER=$APP_BUILD_NUMBER"
