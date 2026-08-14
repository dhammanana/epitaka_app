#!/usr/bin/env python3
"""
Convert markdown-style emphasis in translation databases to HTML tags.

Translation text produced by AI may contain `**bold**` and `*italic*`
markdown markers, but the app renders HTML (`<b>`, `<i>`, `<u>`, `<h1-6>`)
via ReadingParagraph._parseHtml. This script rewrites the `translation`
column of every `sentences` row so asterisk emphasis becomes HTML:

    **bold**          -> <b>bold</b>
    *italic*          -> <i>italic</i>
    ***bold italic*** -> <b><i>bold italic</i></b>

Existing HTML tags are left untouched, and unmatched asterisks (single `*`
with no closing pair, `**` with no pair, etc.) are left as-is.

Usage:
    python3 convert_markdown_translations.py [--dry-run] [data_dir]

Default data dir is ../data (the sibling directory of the app repo, where
build-release.sh and db_uploader.sh also expect the source .db files).

The script processes every `epitaka_??.db` (two-letter language suffix)
found there, e.g. epitaka_en.db, epitaka_vi.db, … (epitaka.db without a
language suffix, and epitaka_vec*.db, are skipped).

Run with --dry-run first to preview how many rows would change without
writing anything.
"""

import glob
import os
import re
import sqlite3
import sys

# Emphasis matching is intentionally single-line (no re.DOTALL): a lone `*`
# should not accidentally pair with a `*` dozens of lines away.
_TRIPLE = re.compile(r'\*\*\*(.+?)\*\*\*')  # ***bold italic***
_DOUBLE = re.compile(r'\*\*(.+?)\*\*')      # **bold**
_SINGLE = re.compile(r'\*(.+?)\*')          # *italic*


def markdown_to_html(text: str) -> str:
    """Convert `**…**` / `*…*` emphasis to `<b>` / `<i>` tags."""
    # Triple first so `***x***` becomes <b><i>x</i></b>, not <b>*x</b>*.
    text = _TRIPLE.sub(r'<b><i>\1</i></b>', text)
    text = _DOUBLE.sub(r'<b>\1</b>', text)
    text = _SINGLE.sub(r'<i>\1</i>', text)
    return text


def find_translation_dbs(data_dir: str) -> list:
    """Return the epitaka_??.db files in data_dir, sorted by name."""
    return sorted(glob.glob(os.path.join(data_dir, 'epitaka_??.db')))


def convert_db(path: str, dry_run: bool) -> int:
    """Convert the translation column of every sentences row in one .db.

    Returns the number of rows changed. Runs in a single transaction so an
    interruption never leaves the file half-converted.
    """
    conn = sqlite3.connect(path)
    try:
        total = conn.execute('SELECT COUNT(*) FROM sentences').fetchone()[0]
        rows = conn.execute(
            'SELECT book_id, para_id, line_id, translation FROM sentences '
            'WHERE translation IS NOT NULL AND translation LIKE \'%*%\''
        )
        changed = 0
        updates = []
        for book_id, para_id, line_id, translation in rows:
            new = markdown_to_html(translation)
            if new != translation:
                updates.append((new, book_id, para_id, line_id))
                changed += 1

        if not dry_run and updates:
            conn.executemany(
                'UPDATE sentences SET translation = ? '
                'WHERE book_id = ? AND para_id = ? AND line_id = ?',
                updates,
            )
            conn.commit()
    finally:
        conn.close()

    print(f'   {path}')
    print(f'     total rows: {total}')
    print(f'     changed:    {changed} '
          f'({"dry-run — not written" if dry_run else "written"})')
    return changed


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith('-')]
    dry_run = '--dry-run' in sys.argv[1:]

    script_dir = os.path.dirname(os.path.abspath(__file__))
    app_dir = os.path.dirname(script_dir)          # epitaka_app/
    default_data = os.path.join(os.path.dirname(app_dir), 'data')  # ../data
    data_dir = args[0] if args else default_data

    if not os.path.isdir(data_dir):
        print(f'❌ Data directory not found: {data_dir}')
        print('   Run this script from the project root (epitaka_app/)')
        return 1

    dbs = find_translation_dbs(data_dir)
    if not dbs:
        print(f'⚠️  No files matching epitaka_??.db found in {data_dir}')
        return 0

    print(f'{"🔍 Dry-run — no files will be modified" if dry_run else "🔧 Converting"} '
          f'{len(dbs)} database(s) in {data_dir}')
    print('=' * 60)

    total_changed = 0
    for db in dbs:
        total_changed += convert_db(db, dry_run)

    print('=' * 60)
    if dry_run:
        print(f'✅ Dry-run complete: {total_changed} rows would change. '
              'Re-run without --dry-run to apply.')
    else:
        print(f'🎉 Done: {total_changed} rows updated.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
