#!/usr/bin/env bash
# Exit immediately if a command exits with a non-zero status
set -e

# ── Configuration ────────────────────────────────────────────────────────────
# This script lives inside epitaka_app/scripts/, but the .db source files live
# one level up, outside the git repo, at ../data/. Zips are written to
# ../data/assets/. The hash manifest is kept INSIDE epitaka_app so it's
# tracked by git and persists across runs (used to skip unchanged files).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"          # epitaka_app/
DATA_DIR="$(cd "$APP_DIR/../data" && pwd)"       # ../data/ (sibling of epitaka_app)
TARGET_DIR="$DATA_DIR/assets"                    # ../data/assets/
HASH_FILE="$TARGET_DIR/.db_upload_hashes.json"      # tracked in git, inside epitaka_app
RELEASE_TAG="latest"

# ── 1. Verify required tools ─────────────────────────────────────────────────
if ! command -v gh &> /dev/null; then
    echo "❌ Error: 'gh' CLI tool is not installed or not in PATH."
    exit 1
fi
if ! command -v shasum &> /dev/null && ! command -v sha256sum &> /dev/null; then
    echo "❌ Error: neither 'shasum' nor 'sha256sum' is available."
    exit 1
fi
if ! command -v jq &> /dev/null; then
    echo "❌ Error: 'jq' is not installed or not in PATH (needed for hash tracking)."
    exit 1
fi
HAVE_PV=0
if command -v pv &> /dev/null; then
    HAVE_PV=1
else
    echo "ℹ️  'pv' not found — uploads will run without a progress bar."
    echo "    Install it for progress feedback: brew install pv"
fi

hash_of() {
    if command -v sha256sum &> /dev/null; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

# ── 2. Check if there are any matching database files ───────────────────────
shopt -s nullglob
db_files=("$DATA_DIR"/epitaka*.db)
if [ ${#db_files[@]} -eq 0 ]; then
    echo "⚠️  No files matching 'epitaka*.db' found in $DATA_DIR."
    exit 0
fi

# ── 3. Prepare output directory and hash manifest ────────────────────────────
mkdir -p "$TARGET_DIR"
if [ ! -f "$HASH_FILE" ]; then
    echo "{}" > "$HASH_FILE"
fi

total_files=${#db_files[@]}
current_count=0
uploaded_count=0
skipped_count=0

echo "🚀 Checking $total_files database file(s) for changes..."
echo "   Source: $DATA_DIR"
echo "   Output: $TARGET_DIR"
echo "========================================================="

for f in "${db_files[@]}"; do
    current_count=$((current_count + 1))
    file_name="$(basename "$f")"
    base_name="${file_name%.db}"
    zip_file="$TARGET_DIR/${base_name}.zip"

    echo "🔍 [$current_count/$total_files] Checking: $file_name"

    new_hash="$(hash_of "$f")"
    old_hash="$(jq -r --arg k "$file_name" '.[$k] // empty' "$HASH_FILE")"

    if [ "$new_hash" == "$old_hash" ] && [ -f "$zip_file" ]; then
        echo "   ⏭️  No changes detected — skipping."
        skipped_count=$((skipped_count + 1))
        echo "---------------------------------------------------------"
        continue
    fi

    # Compress the file (quietly, suppressing internal zip verbose logs)
    echo "   -> Compressing into $zip_file..."
    rm -f "$zip_file"
    (cd "$DATA_DIR" && zip -q -r "$zip_file" "$file_name")

    # Upload to GitHub Release with a real progress bar.
    # `gh` itself gives no byte-level feedback when piping through some
    # shells, so if `pv` is available we stream the file through it and
    # feed gh via stdin (gh supports "-#name" to name a stdin asset).
    echo "   -> Uploading to GitHub release '$RELEASE_TAG'..."
    zip_size="$(du -h "$zip_file" | cut -f1)"
    echo "      ($zip_size)"
    if [ "$HAVE_PV" -eq 1 ]; then
        pv "$zip_file" | gh release upload "$RELEASE_TAG" "-#${base_name}.zip" --clobber
    else
        gh release upload "$RELEASE_TAG" "$zip_file" --clobber
    fi

    # Record the new hash only after a successful upload
    tmp_file="$(mktemp)"
    jq --arg k "$file_name" --arg v "$new_hash" '.[$k] = $v' "$HASH_FILE" > "$tmp_file"
    mv "$tmp_file" "$HASH_FILE"

    uploaded_count=$((uploaded_count + 1))
    echo "   ✅ Successfully processed $file_name"
    echo "---------------------------------------------------------"
done

echo "🎉 Done. $uploaded_count uploaded, $skipped_count skipped (unchanged) out of $total_files total."
