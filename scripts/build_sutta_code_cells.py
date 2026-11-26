# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""Build assets/sutta_code_cells.tsv: the sutta codes that ship with the app.

An installed epitaka.db can carry codes from an older DPD sheet (its `sn45.172`
is the Yogasutta, DPD's is the Oghasutta), and a new database is a large
download. The app reads these cells instead of the database's own codes for the
books the DPD sheet covers. It uses a cell only where the database's heading
title is the same, so a database with other paragraph numbers keeps its own
codes.

Steps, all on a throw-away copy of the database (the real one is only read):

  1. copy epitaka.db with SQLite's backup call,
  2. clear `headings.sc_id` in every book the TSV covers,
  3. run scripts/import_sutta_codes.py --write on the copy,
  4. write book_id, para_id, title and the cell of each coded heading.

Run scripts/build_sutta_codes.py first; it writes the TSV this script reads:

    uv run scripts/build_sutta_codes.py --db <epitaka.db> --out /tmp/sutta_codes.tsv
    uv run scripts/build_sutta_code_cells.py --db <epitaka.db> --tsv /tmp/sutta_codes.tsv
"""

import argparse
import sqlite3
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

IMPORT_SCRIPT = Path(__file__).with_name("import_sutta_codes.py")


def tsv_books(tsv: Path) -> set[str]:
    """Books that have a mapped paragraph in the TSV (book_id, then para_id)."""
    books: set[str] = set()
    for line in tsv.read_text(encoding="utf-8").splitlines():
        if line.startswith("#") or not line.strip():
            continue
        parts = line.split("\t")
        if len(parts) >= 3 and parts[2].isdigit():
            books.add(parts[1])
    return books


def main() -> None:
    parser = argparse.ArgumentParser(description=(__doc__ or "").split("\n")[0])
    parser.add_argument("--db", required=True, help="an ePitaka epitaka.db (read only)")
    parser.add_argument("--tsv", required=True, help="TSV from build_sutta_codes.py")
    parser.add_argument("--out", default="assets/sutta_code_cells.tsv")
    args = parser.parse_args()

    tsv = Path(args.tsv)
    books = sorted(tsv_books(tsv))
    if not books:
        sys.exit(f"ERROR: no mapped books in {tsv}")

    with tempfile.TemporaryDirectory() as tmp:
        copy = Path(tmp) / "epitaka.db"
        source = sqlite3.connect(f"file:{args.db}?mode=ro", uri=True)
        target = sqlite3.connect(copy)
        source.backup(target)
        source.close()
        marks = ",".join("?" * len(books))
        with target:
            cleared = target.execute(
                f"UPDATE headings SET sc_id = NULL WHERE book_id IN ({marks})",
                books,
            ).rowcount
        target.close()
        print(f"{len(books)} books, {cleared} old code cells cleared on the copy")

        result = subprocess.run(
            [sys.executable, str(IMPORT_SCRIPT), "--tsv", str(tsv),
             "--db", str(copy), "--write"],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            print(result.stdout[-2000:], result.stderr[-2000:], sep="\n")
            sys.exit("ERROR: the import failed on the copy")

        conn = sqlite3.connect(f"file:{copy}?mode=ro", uri=True)
        cells: dict[tuple[str, int], tuple[str, str]] = {}
        # Lowest level first: one cell per paragraph, from its highest heading.
        for book_id, para_id, title, sc_id in conn.execute(
            f"SELECT book_id, para_id, COALESCE(title, ''), sc_id FROM headings "
            f"WHERE book_id IN ({marks}) AND sc_id IS NOT NULL AND sc_id != '' "
            f"ORDER BY book_id, para_id, level",
            books,
        ):
            cells.setdefault((book_id, para_id), (title, sc_id))
        conn.close()

    stamp = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    lines = [
        "# Sutta code cells for the books in the DPD sutta sheet: "
        "book_id, para_id, heading title, token cell.",
        f"# Built {stamp} by scripts/build_sutta_code_cells.py from {tsv.name} "
        f"and a copy of {Path(args.db).name}.",
        "# DPD codes follow the CST numbering. The app uses a cell only where the "
        "database's heading title is the same.",
    ]
    for (book_id, para_id), (title, cell) in sorted(cells.items()):
        title = title.replace("\t", " ").replace("\n", " ")
        lines.append(f"{book_id}\t{para_id}\t{title}\t{cell}")
    out = Path(args.out)
    out.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print(f"Wrote {len(cells)} cells to {out}")


if __name__ == "__main__":
    main()
