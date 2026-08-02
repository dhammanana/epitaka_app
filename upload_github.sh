#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# Configuration
TARGET_DIR="assets"
RELEASE_TAG="latest"

# 1. Verify GitHub CLI tool is installed
if ! command -v gh &> /dev/null; then
    echo "❌ Error: 'gh' CLI tool is not installed or not in PATH."
    exit 1
fi

# 2. Check if there are any matching database files
shopt -s nullglob
db_files=(epitaka*.db)
if [ ${#db_files[@]} -eq 0 ]; then
    echo "⚠️  No files matching 'epitaka*.db' found in the current directory."
    exit 0
fi

# 3. Create the output directory
mkdir -p "$TARGET_DIR"

total_files=${#db_files[@]}
current_count=0

echo "🚀 Starting compression and upload for $total_files database files..."
echo "========================================================="

# 4. Loop through each database file
for f in "${db_files[@]}"; do
    current_count=$((current_count + 1))
    base_name="${f%.db}"
    zip_file="$TARGET_DIR/${base_name}.zip"
    
    echo "📦 [$current_count/$total_files] Processing: $f"
    
    # Compress the file (quietly, suppressing internal zip verbose logs)
    echo "   -> Compressing into $zip_file..."
    zip -q -r "$zip_file" "$f"
    
    # Upload to GitHub Release with progress and clobber (overwrite) flags
    echo "   -> Uploading to GitHub release '$RELEASE_TAG'..."
    gh release upload "$RELEASE_TAG" "$zip_file" --clobber 
    echo "   ✅ Successfully processed $f"
    echo "---------------------------------------------------------"
done

echo "🎉 All $total_files files have been successfully zipped and uploaded!"
