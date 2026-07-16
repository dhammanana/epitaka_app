#!/bin/bash
# Rebuild epitaka_vec.db from vec0 virtual table format → regular tables
# compatible with the sqlite_vector dart package (sqlite.ai).
#
# The sqlite_vector API uses:
#   - Regular tables with BLOB embedding columns
#   - vector_init() to register the column
#   - vector_full_scan() for search
#
# Usage: ./convert_vec_db.sh [source_db] [dest_db]

set -euo pipefail

SRC_DB="${1:-$PWD/assets/db/epitaka_vec.db}"
DST_DB="${2:-$PWD/assets/db/epitaka_vec_converted.db}"
VEC0_DYLIB="/tmp/venv_sqlitevec/lib/python3.10/site-packages/sqlite_vec/vec0.dylib"
TMP_SQL="/tmp/convert_vec_db.sql"

if [ ! -f "$SRC_DB" ]; then
    echo "❌ Source database not found: $SRC_DB"
    exit 1
fi

if [ ! -f "$VEC0_DYLIB" ]; then
    echo "❌ vec0 extension not found at $VEC0_DYLIB"
    exit 1
fi

echo "📂 Source: $SRC_DB"
echo "   Destination: $DST_DB"
echo "   vec0: $VEC0_DYLIB"

# ── Detect format ──────────────────────────────────────────────
echo "🔍 Detecting format…"

IS_VEC0=$(sqlite3 "$SRC_DB" <<EOF
.load '$VEC0_DYLIB'
SELECT name FROM sqlite_master WHERE type='table' AND name='chunk_vectors';
EOF
)

IS_CHUNKS=$(sqlite3 "$SRC_DB" <<EOF
SELECT name FROM sqlite_master WHERE type='table' AND name='chunks';
EOF
)

# ── Generate INSERT SQL from source ────────────────────────────
if [ -n "$IS_CHUNKS" ]; then
    echo "   Format: OLD (single chunks table)"
    COUNT=$(sqlite3 "$SRC_DB" "SELECT COUNT(*) FROM chunks;")
    echo "   Rows: $COUNT"

    echo "📖 Generating INSERT SQL from old format…"
    sqlite3 "$SRC_DB" <<EOF
.load '$VEC0_DYLIB'
.mode list
.output '$TMP_SQL'
SELECT 'INSERT INTO chunks(chunk_id, book_id, start_para, end_para, start_line, end_line, token_count, line_count, embedding) VALUES(' ||
    chunk_id || ', ''' || book_id || ''', ' ||
    start_para || ', ' || end_para || ', ' ||
    start_line || ', ' || end_line || ', ' ||
    token_count || ', ' || line_count || ', ' ||
    'X''' || hex(embedding) || ''');'
FROM chunks
ORDER BY chunk_id;
EOF

elif [ -n "$IS_VEC0" ]; then
    echo "   Format: VEC0 (chunk_vectors + chunk_metadata)"
    COUNT=$(sqlite3 "$SRC_DB" <<EOF
.load '$VEC0_DYLIB'
SELECT COUNT(*) FROM chunk_metadata;
EOF
)
    echo "   Rows: $COUNT"

    echo "📖 Generating INSERT SQL from vec0 format…"
    sqlite3 "$SRC_DB" <<EOF
.load '$VEC0_DYLIB'
.mode list
.output '$TMP_SQL'
SELECT 'INSERT INTO chunks(chunk_id, book_id, start_para, end_para, start_line, end_line, token_count, line_count, embedding) VALUES(' ||
    v.chunk_id || ', ''' || m.book_id || ''', ' ||
    m.start_para || ', ' || m.end_para || ', ' ||
    m.start_line || ', ' || m.end_line || ', ' ||
    m.token_count || ', ' || m.line_count || ', ' ||
    'X''' || hex(v.embedding) || ''');'
FROM chunk_vectors AS v
INNER JOIN chunk_metadata AS m ON v.chunk_id = m.chunk_id
ORDER BY v.chunk_id;
EOF

else
    echo "❌ Unknown database format"
    exit 1
fi

INSERT_COUNT=$(grep -c '^INSERT' "$TMP_SQL" || true)
echo "   Generated $INSERT_COUNT INSERT statements"

# ── Create new database ────────────────────────────────────────
echo "💾 Creating new database: $DST_DB"
rm -f "$DST_DB"

sqlite3 "$DST_DB" <<EOF
PRAGMA journal_mode=OFF;
PRAGMA synchronous=OFF;

CREATE TABLE chunks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    chunk_id INTEGER NOT NULL,
    book_id TEXT NOT NULL,
    start_para INTEGER NOT NULL,
    end_para INTEGER NOT NULL,
    start_line INTEGER NOT NULL,
    end_line INTEGER NOT NULL,
    token_count INTEGER NOT NULL,
    line_count INTEGER NOT NULL,
    embedding BLOB NOT NULL
);

CREATE INDEX idx_chunks_book_id ON chunks(book_id);
CREATE INDEX idx_chunks_chunk_id ON chunks(chunk_id);
EOF

# ── Bulk insert ─────────────────────────────────────────────────
echo "📝 Inserting $INSERT_COUNT rows…"
{
    echo 'BEGIN TRANSACTION;'
    cat "$TMP_SQL"
    echo 'COMMIT;'
} | sqlite3 "$DST_DB"
echo "   ✓ Insert complete"

# ── Verify ──────────────────────────────────────────────────────
VERIFIED=$(sqlite3 "$DST_DB" "SELECT COUNT(*) FROM chunks")
echo ""
echo "✅ Conversion complete!"
echo "   Source: $SRC_DB ($(du -h "$SRC_DB" | cut -f1))"
echo "   Dest:   $DST_DB ($(du -h "$DST_DB" | cut -f1))"
echo "   Rows:   $VERIFIED"

# Copy over the old file to replace it
if [ "$DST_DB" != "$SRC_DB" ]; then
    echo ""
    echo "📋 Replacing source database…"
    cp "$DST_DB" "$SRC_DB"
fi

rm -f "$TMP_SQL"
echo ""
echo "🎉 Done! Database now has a regular 'chunks' table with BLOB embeddings."
echo "   Compatible with sqlite_vector dart package API."
