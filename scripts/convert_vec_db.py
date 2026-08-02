#!/usr/bin/env python3
"""
Convert epitaka_vec.db from vec0 virtual table format (open-source sqlite-vec)
to regular table format compatible with the sqlite_vector Dart package (sqlite.ai).

Usage:
    python3 convert_vec_db.py [old_db] [new_db]

The original database uses:
    CREATE VIRTUAL TABLE chunks USING vec0(
        embedding INT8[640],
        chunk_id INTEGER, book_id INTEGER, ...
    )

The new database uses:
    CREATE TABLE chunks (
        chunk_id INTEGER PRIMARY KEY,
        book_id INTEGER, ...,
        embedding BLOB
    )

Embeddings are stored as raw INT8 bytes (same format as vec0's internal format).
sqlite_vector supports INT8 via vector_as_i8() / vector_full_scan().
"""

import os
import struct
import shutil
import sys
import sqlite3

try:
    import sqlite_vec
except ImportError:
    print("❌ sqlite-vec Python package not found.")
    print("   Install with: pip install sqlite-vec")
    sys.exit(1)


def main() -> None:
    old_path = sys.argv[1] if len(sys.argv) > 1 else "assets/db/epitaka_vec.db"
    new_path = sys.argv[2] if len(sys.argv) > 2 else "assets/db/epitaka_vec_converted.db"

    # Validate input paths
    for p in [old_path, new_path]:
        if not os.path.exists(os.path.dirname(p)) and os.path.dirname(p):
            print(f"❌ Directory does not exist: {os.path.dirname(p)}")
            print(f"   Run this script from the project root (epitaka_app/)")
            sys.exit(1)

    # ── Step 1: Open old database with sqlite-vec extension ─────
    print(f"📂 Opening old database: {old_path}")
    old_conn = sqlite3.connect(old_path)
    # sqlite_vec.load() handles extension loading internally —
    # no need to call enable_load_extension() manually.
    sqlite_vec.load(old_conn)

    # Verify the vec0 table exists
    schema_rows = old_conn.execute(
        "SELECT type, sql FROM sqlite_master WHERE name='chunks'"
    ).fetchall()
    if not schema_rows:
        print("❌ 'chunks' table not found in database!")
        old_conn.close()
        sys.exit(1)

    table_type, create_sql = schema_rows[0]
    print(f"   Table type: {table_type}")
    print(f"   CREATE SQL: {create_sql}")

    # ── Step 2: Read all rows from the vec0 virtual table ───────
    print("📖 Reading all rows from vec0 chunks table…")
    rows = old_conn.execute("""
        SELECT rowid, chunk_id, book_id, start_para, end_para,
               start_line, end_line, token_count, line_count, embedding
        FROM chunks
        ORDER BY rowid
    """).fetchall()
    print(f"   Read {len(rows)} rows")

    if len(rows) == 0:
        print("❌ No rows found in chunks table!")
        old_conn.close()
        sys.exit(1)

    # Inspect first embedding to determine dimensions and type
    first_embedding = rows[0][9]
    dims = len(first_embedding) if isinstance(first_embedding, bytes) else 0
    print(f"   Embedding dimensions: {dims}")
    print(f"   Embedding byte count: {len(first_embedding)} bytes")

    sample_vals = list(struct.unpack(f"{dims}b", first_embedding))[:5]
    print(f"   Sample values: {sample_vals}")

    # ── Step 3: Create new database with regular table ──────────
    print(f"💾 Creating new database: {new_path}")
    new_conn = sqlite3.connect(new_path)
    new_conn.execute("PRAGMA journal_mode=WAL")
    new_conn.execute("PRAGMA foreign_keys=ON")

    new_conn.execute("""
        CREATE TABLE chunks (
            chunk_id INTEGER PRIMARY KEY,
            book_id INTEGER NOT NULL,
            start_para INTEGER NOT NULL,
            end_para INTEGER NOT NULL,
            start_line INTEGER NOT NULL,
            end_line INTEGER NOT NULL,
            token_count INTEGER NOT NULL,
            line_count INTEGER NOT NULL,
            embedding BLOB NOT NULL
        )
    """)

    # Create index on book_id for faster filtering
    new_conn.execute(
        "CREATE INDEX idx_chunks_book_id ON chunks(book_id)"
    )

    # ── Step 4: Insert all rows ─────────────────────────────────
    # The embedding from vec0 is raw INT8[640] bytes.
    # sqlite_vector stores INT8 in the same raw format (just the bytes),
    # so we copy them directly. No format conversion needed.
    print("📝 Inserting rows…")
    insert_sql = """
        INSERT INTO chunks (chunk_id, book_id, start_para, end_para,
                            start_line, end_line, token_count, line_count,
                            embedding)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    """

    inserted = 0
    for row in rows:
        (rowid, chunk_id, book_id, start_para, end_para,
         start_line, end_line, token_count, line_count, embedding) = row

        new_conn.execute(insert_sql, (
            chunk_id, book_id, start_para, end_para,
            start_line, end_line, token_count, line_count,
            embedding  # raw INT8 bytes — same format as sqlite_vector
        ))
        inserted += 1

        if inserted % 10000 == 0:
            print(f"   Progress: {inserted} rows…")

    new_conn.commit()

    # ── Step 5: Verify the new database ─────────────────────────
    count = new_conn.execute("SELECT COUNT(*) FROM chunks").fetchone()[0]
    new_conn.close()
    old_conn.close()

    print(f"\n✅ Conversion complete!")
    print(f"   Old database: {old_path}")
    print(f"   New database: {new_path}")
    print(f"   Rows copied: {count}")
    print(f"   Embedding: INT8[{dims}] stored as raw BLOB")
    print(f"   File size: {get_file_size(new_path)}")

    # Copy the new file over the old one so the Flutter app finds it
    # at the expected path.
    if new_path != old_path:
        print(f"\n📋 Replacing old database…")
        shutil.copy2(new_path, old_path)
        print(f"   Copied {new_path} -> {old_path}")

    print(f"\n🎉 Done! The app can now open the database as a regular table.")


def get_file_size(path: str) -> str:
    size = os.path.getsize(path)
    for unit in ("B", "KB", "MB", "GB"):
        if size < 1024:
            return f"{size:.1f} {unit}"
        size /= 1024
    return f"{size:.1f} TB"


if __name__ == "__main__":
    main()
