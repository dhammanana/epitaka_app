#!/bin/bash
# Package the Flutter Linux release bundle as a Debian package (.deb).
#
# Usage: install/linux/build-deb.sh <version> [bundle-dir] [output-file]
#   version      Debian package version, e.g. 1.0.21 (from pubspec.yaml)
#   bundle-dir   defaults to build/linux/x64/release/bundle
#   output-file  defaults to epitaka-linux-x64.deb
#
# Run from the repository root, after `flutter build linux --release`.
#
# Layout: the whole Flutter bundle goes to /opt/epitaka unchanged, because the
# executable finds its resources by relative path — data/ must stay a sibling
# of the binary and lib/ is resolved through the RPATH $ORIGIN/lib baked in by
# the Flutter build. Splitting it across /usr/bin and /usr/lib would break both.
# /usr/bin/epitaka is a symlink so the app is on PATH and the Exec= line in the
# shared desktop entry (install/linux/epitaka.desktop) resolves unchanged.

set -euo pipefail

VERSION="${1:?usage: build-deb.sh <version> [bundle-dir] [output-file]}"
BUNDLE_DIR="${2:-build/linux/x64/release/bundle}"
OUTPUT="${3:-epitaka-linux-x64.deb}"

ARCH=$(dpkg --print-architecture)
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

if [ ! -x "$BUNDLE_DIR/epitaka" ]; then
  echo "ERROR: $BUNDLE_DIR/epitaka not found — run 'flutter build linux --release' first" >&2
  exit 1
fi

# ── Payload ───────────────────────────────────────────────────────────────
install -d "$STAGE/opt/epitaka" "$STAGE/usr/bin" \
           "$STAGE/usr/share/applications" \
           "$STAGE/usr/share/icons/hicolor/512x512/apps"

cp -a "$BUNDLE_DIR/." "$STAGE/opt/epitaka/"
ln -s /opt/epitaka/epitaka "$STAGE/usr/bin/epitaka"

cp install/linux/epitaka.desktop "$STAGE/usr/share/applications/epitaka.desktop"
cp assets/icon.png "$STAGE/usr/share/icons/hicolor/512x512/apps/epitaka.png"

# ── Control file ──────────────────────────────────────────────────────────
# Installed-Size is in KiB and is what apt reports as the disk footprint.
INSTALLED_SIZE=$(du -sk "$STAGE" | cut -f1)

# Runtime counterparts of the -dev packages the Linux build needs, listed as
# alternatives because Debian/Ubuntu renamed several of them with a 't64'
# suffix in the 64-bit time_t transition (Ubuntu 24.04 / Debian trixie ship
# libasound2t64, older releases ship libasound2). apt picks whichever exists,
# so one .deb installs on both.
#
# Deliberately NOT generated with dpkg-shlibdeps: it emits tight '>=' bounds
# taken from the build machine's library versions, which would make a package
# built on the newest CI runner refuse to install on any older distribution.
install -d "$STAGE/DEBIAN"
cat > "$STAGE/DEBIAN/control" <<EOF
Package: epitaka
Version: $VERSION
Architecture: $ARCH
Maintainer: Dhammanana <dhammanana@users.noreply.github.com>
Installed-Size: $INSTALLED_SIZE
Section: education
Priority: optional
Homepage: https://github.com/dhammanana/epitaka_app
Depends: libc6, libstdc++6, libgtk-3-0 | libgtk-3-0t64, libglib2.0-0 | libglib2.0-0t64, liblzma5, libasound2 | libasound2t64, libgstreamer1.0-0, libgstreamer-plugins-base1.0-0, libsecret-1-0, libjsoncpp25 | libjsoncpp26 | libjsoncpp1
Description: ePitaka - Tipitaka Reader in Multiple Languages
 ePitaka is a reader for the Pali canon with side-by-side translations,
 an integrated Pali-English dictionary and full-text search across the
 Tipitaka in multiple languages and scripts.
EOF

# No postinst/postrm needed: desktop-file-utils and hicolor-icon-theme install
# dpkg triggers on /usr/share/applications and /usr/share/icons/hicolor, so the
# menu entry and icon cache are refreshed automatically.

# ── Build ─────────────────────────────────────────────────────────────────
# --root-owner-group makes every file root:root without needing fakeroot.
# The payload is ~700MB of SQLite databases, so xz compression takes a few
# minutes; it is worth it because the databases compress very well.
dpkg-deb --build --root-owner-group -Zxz "$STAGE" "$OUTPUT"

dpkg-deb --info "$OUTPUT"
ls -la "$OUTPUT"
