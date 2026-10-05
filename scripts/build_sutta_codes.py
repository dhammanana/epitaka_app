# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""Build assets/sutta_codes.tsv: sutta code -> ePitaka book/paragraph.

Joins the public DPD sutta sheet with an ePitaka content database. All matching
happens here so the app only does a dictionary lookup.

    uv run scripts/build_sutta_codes.py --db ~/.local/share/com.dn.epitaka/epitaka.db

Re-run whenever a new epitaka.db or a changed sheet is released: the map stores
the database's para_ids.

The TSV is an intermediate: scripts/import_sutta_codes.py loads it into the
headings.sc_id token cells of the shipped epitaka.db, which is what the app's
"Go to sutta" queries (no TSV ships with the app).
"""

import argparse
import csv
import io
import re
import sqlite3
import sys
import urllib.request
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

SHEET_URL = (
    "https://docs.google.com/spreadsheets/d/"
    "1sR8NT204STTwOoDrr9GBjhXVYEn0qqZTxgjoLKMmaaE/export?format=csv"
)
REQUIRED_COLUMNS = ("dpd_code", "dpd_sutta", "cst_file", "cst_paranum", "sc_code")
REQUIRED_TABLES = ("books", "headings", "sentences")

# Key classes; lower wins when two rows claim one code.
DPD_EXACT, SC_EXACT, DPD_RANGE, SC_RANGE = range(4)


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    sys.exit(1)


def normalise(code: str) -> str:
    return re.sub(r"\s+", "", code).lower().replace("–", "-").replace("—", "-")


def natural_key(text: str) -> list:
    return [int(p) if p.isdigit() else p for p in re.split(r"(\d+)", text)]


def load_csv_text(csv_path: str | None) -> tuple[str, str]:
    if csv_path:
        with open(Path(csv_path), encoding="utf-8", newline="") as f:
            return f.read(), csv_path
    request = urllib.request.Request(SHEET_URL, headers={"User-Agent": "epitaka-build"})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return response.read().decode("utf-8"), SHEET_URL
    except OSError as error:
        fail(f"could not download the DPD sheet: {error}")
    raise AssertionError  # unreachable, fail() exits


def parse_sheet(text: str) -> list[dict]:
    reader = csv.DictReader(io.StringIO(text, newline=""))
    missing = [c for c in REQUIRED_COLUMNS if c not in (reader.fieldnames or [])]
    if missing:
        fail(
            "not the expected CSV: header lacks "
            + ", ".join(missing)
            + " (a login or error page instead of the sheet?)"
        )
    rows = [r for r in reader if (r["dpd_code"] or "").strip()]
    if not rows:
        fail("not the expected CSV: no rows with a dpd_code")
    return rows


def open_db(path: str) -> sqlite3.Connection:
    db_path = Path(path).expanduser()
    if not db_path.is_file():
        fail(f"database not found: {db_path}")
    conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    have = {
        r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")
    }
    missing = [t for t in REQUIRED_TABLES if t not in have]
    if missing:
        fail(f"database lacks table(s): {', '.join(missing)}")
    return conn


def range_codes(code_with_dash: str) -> list[str]:
    """DPD's generate_range_of_sutta_codes: 'SN12.5-8' -> SN12.5 ... SN12.8."""
    if "." not in code_with_dash:
        return []
    base, _, tail = code_with_dash.partition(".")
    base += "."
    try:
        first, last = tail.split("-")
        first_n, last_n = int(first), int(last)
    except ValueError:
        return []
    return [f"{base}{n}" for n in range(first_n, last_n + 1)]


def is_vagga(row: dict) -> bool:
    names = [row["dpd_sutta"], row.get("dpd_sutta_var", "")]
    if any("vagga" in n or "vaggo" in n for n in names if n):
        return True
    return "-" in row["dpd_code"] and bool(
        row.get("cst_vagga") or row.get("sc_vagga") or row.get("bjt_vagga")
    )


def is_samyutta(row: dict) -> bool:
    if not (row["dpd_sutta"] and row["dpd_code"]):
        return False
    if "." in row["dpd_code"] or "-" in row["dpd_code"]:
        return False
    return re.sub(r" \d+$", "", row["dpd_sutta"]).endswith("saṃyutta")


def is_nipata(row: dict) -> bool:
    if not (row["dpd_sutta"] and row["dpd_code"]):
        return False
    if "." in row["dpd_code"] or "-" in row["dpd_code"]:
        return False
    names = [row["dpd_sutta"], row.get("dpd_sutta_var", "")]
    return any("nipāta" in n for n in names if n)


def is_chapter(row: dict) -> bool:
    return is_vagga(row) or is_samyutta(row) or is_nipata(row)


def expand_keys(row: dict) -> list[tuple[str, int]]:
    """DPD's make_list_of_sutta_codes, with the class of each key."""
    dpd = row["dpd_code"].strip()
    keys = [(dpd, DPD_EXACT)]
    if "-" in dpd:
        keys += [(k, DPD_RANGE) for k in range_codes(dpd)]
    sc = (row["sc_code"] or "").strip()
    if sc and not is_chapter(row):
        keys.append((sc, SC_EXACT))
        if "-" in sc:
            keys += [(k, SC_RANGE) for k in range_codes(sc)]
        # DPD tests the prefix case-sensitively, but the sheet stores 'thag1.1'
        # in lower case, so the alias would never fire there.
        for sc_prefix, dpd_prefix in (("thag", "th"), ("thig", "thi")):
            if sc.lower().startswith(sc_prefix):
                synthetic = dpd_prefix + sc[len(sc_prefix) :]
                keys.append((synthetic, SC_EXACT))
                if "-" in synthetic:
                    keys += [(k, SC_RANGE) for k in range_codes(synthetic)]
                break
    return [(normalise(k), cls) for k, cls in keys]


class Locator:
    def __init__(self, conn: sqlite3.Connection):
        self.conn = conn
        self.books_by_vri: dict[str, list[str]] = defaultdict(list)
        for vri_id, book_id in conn.execute(
            "SELECT vri_id, book_id FROM books WHERE vri_id IS NOT NULL AND vri_id != ''"
        ):
            self.books_by_vri[vri_id].append(book_id)
        # book_id -> {para_id: (level, lower sc_id)} for headings (level < 10)
        self.headings: dict[str, dict[int, tuple[int, str]]] = defaultdict(dict)
        # (book_id, lower sc_id) -> [(level, para_id)]
        self.by_sc: dict[tuple[str, str], list[tuple[int, int]]] = defaultdict(list)
        for book_id, para_id, level, sc_id in conn.execute(
            "SELECT book_id, para_id, level, sc_id FROM headings WHERE level < 10"
        ):
            self.headings[book_id][para_id] = (level, (sc_id or "").lower())
            if sc_id:
                self.by_sc[(book_id, sc_id.lower())].append((level, para_id))
        self._para_index: dict[str, tuple[dict, dict]] = {}
        self._all_paras: dict[str, set[int]] = {}
        self._spans: dict[str, list[tuple[int, int, int]]] = {}

    def para_index(self, book_id: str) -> tuple[dict, dict]:
        if book_id not in self._para_index:
            exact: dict[str, set[int]] = defaultdict(set)
            first: dict[str, set[int]] = defaultdict(set)
            for para_id, vripara in self.conn.execute(
                "SELECT para_id, vripara FROM sentences WHERE book_id=? AND vripara != ''",
                (book_id,),
            ):
                exact[vripara].add(para_id)
                m = re.match(r"\d+", vripara)
                if m:
                    first[m.group()].add(para_id)
            self._para_index[book_id] = (exact, first)
        return self._para_index[book_id]

    def para_ids(self, book_id: str) -> set[int]:
        if book_id not in self._all_paras:
            self._all_paras[book_id] = {
                r[0]
                for r in self.conn.execute(
                    "SELECT DISTINCT para_id FROM sentences WHERE book_id=?", (book_id,)
                )
            }
        return self._all_paras[book_id]

    def spans(self, book_id: str) -> list[tuple[int, int, int]]:
        """(first number, last number, para_id) per numbered paragraph; a
        peyyāla paragraph can carry a range such as '651-662'."""
        if book_id not in self._spans:
            found = []
            for para_id, vripara in self.conn.execute(
                "SELECT para_id, MIN(vripara) FROM sentences "
                "WHERE book_id=? AND vripara != '' GROUP BY para_id",
                (book_id,),
            ):
                m = re.match(r"(\d+)(?:-(\d+))?", vripara)
                if m:
                    found.append((int(m.group(1)), int(m.group(2) or m.group(1)), para_id))
            self._spans[book_id] = found
        return self._spans[book_id]

    def para_for_number(self, book_id: str, number: int, anchor: int) -> int | None:
        """The first paragraph at or after anchor whose number span holds number."""
        hits = [p for a, b, p in self.spans(book_id) if a <= number <= b and p >= anchor]
        return min(hits) if hits else None

    def last_number(self, book_id: str) -> int:
        return max((b for _, b, _ in self.spans(book_id)), default=0)

    def sc_heading(self, book_id: str, sc_code: str) -> int | None:
        """The topmost heading carrying sc_code (mn10 has sub-headings sharing it)."""
        found = self.by_sc.get((book_id, sc_code.lower()))
        return min(found)[1] if found else None

    def heading_above(self, book_id: str, para_id: int) -> int | None:
        above = [p for p in self.headings[book_id] if p <= para_id]
        return max(above) if above else None

    def snap(self, book_id: str, para_id: int) -> tuple[int, set[int]]:
        """Top of the run of headings directly above the paragraph, and that run."""
        heads = self.headings[book_id]
        present = self.para_ids(book_id)
        top, run = para_id, set()
        if para_id in heads:
            run.add(para_id)
        q = para_id - 1
        while True:
            # The content DB leaves gaps in para_id between a heading and its
            # first numbered paragraph (S-i 139 -> 141), so step over them.
            while q > 0 and q not in present and q not in heads:
                q -= 1
            if q not in heads:
                break
            top = q
            run.add(q)
            q -= 1
        return top, run

    def locate(self, row: dict) -> tuple[tuple[str, int] | None, str, str, int]:
        """Returns (book_id, para_id) or None, the route, a note, and the
        paragraph found before snapping back to its headings."""
        vri = re.sub(r"^romn/|\.xml$", "", (row["cst_file"] or "").strip())
        books = self.books_by_vri.get(vri)
        if not books:
            return None, "unresolved", f"no ePitaka book for cst_file {row['cst_file']!r}", 0
        sc = (row["sc_code"] or "").strip()
        paranum = (row["cst_paranum"] or "").strip()
        chapter = is_chapter(row)

        chosen: tuple[str, int] | None = None
        route = ""
        if paranum:
            first_m = re.match(r"\d+", paranum)
            candidates = []
            for book_id in books:
                exact, first = self.para_index(book_id)
                paras = set(exact.get(paranum, ()))
                if first_m:
                    paras |= first.get(first_m.group(), set())
                candidates += [(book_id, p) for p in paras]
            if len(candidates) == 1:
                chosen, route = candidates[0], "paragraph"
            elif len(candidates) > 1:
                best = None
                for book_id in books:
                    h = self.sc_heading(book_id, sc) if sc else None
                    if h is None:
                        continue
                    after = [c for c in candidates if c[0] == book_id and c[1] > h]
                    if after:
                        best = min(after, key=lambda c: c[1])
                        break
                if best is None:
                    return None, "unresolved", (
                        f"{len(candidates)} paragraphs numbered {paranum!r} and no "
                        f"heading with sc_id {sc!r} to choose"
                    ), 0
                chosen, route = best, "paragraph+heading"
        if chosen is None:
            for book_id in books:
                h = self.sc_heading(book_id, sc) if sc else None
                if h is not None:
                    chosen, route = (book_id, h), "heading"
                    break
        if chosen is None and "." not in sc and "-" not in sc and sc:
            heads = self.headings[books[0]]
            if heads:
                chosen, route = (books[0], min(heads)), "whole-book"
        if chosen is None:
            return None, "unresolved", f"no paragraph {paranum!r} and no heading sc_id {sc!r}", 0

        book_id, para_id = chosen
        top, _ = self.snap(book_id, para_id)
        note = ""
        if not chapter and sc and route != "heading":
            # Only a heading that names another sutta proves the paragraph wrong.
            # A heading with no sc_id, or SC numbering that is offset from DPD's
            # (SN45.171 -> sn45.170), says nothing, so the paragraph stands.
            above = self.heading_above(book_id, para_id)
            above_sc = self.headings[book_id][above][1] if above is not None else ""
            h = self.sc_heading(book_id, sc)
            if above_sc == sc.lower():
                top, _ = self.snap(book_id, above)
            elif above_sc and h is not None:
                top, _ = self.snap(book_id, h)
                note = (
                    f"paragraph gave {para_id} under sc_id {above_sc!r}, "
                    f"heading sc_id {sc!r} is at {h}"
                )
                route = "override"
        return (book_id, top), route, note, para_id

    def range_members(
        self, row: dict, book_id: str, anchor: int, next_paranum: int | None
    ) -> dict[str, int] | None:
        """Paragraph of each sutta in a DPD range such as AN1.1-10, or None.

        Trusted only when the range holds exactly one paragraph number per
        sutta: the next sheet row in the file starts right after it (or the
        book ends there). 34 SN ranges fail this and keep the range heading.
        """
        m = re.match(r"^(.+\.)(\d+)-(\d+)$", row["dpd_code"].strip())
        p0 = re.match(r"\d+", (row["cst_paranum"] or "").strip())
        if not m or not p0:
            return None
        base, first, last = m.group(1), int(m.group(2)), int(m.group(3))
        start, count = int(p0.group()), last - first + 1
        end = next_paranum if next_paranum is not None else self.last_number(book_id) + 1
        if end != start + count:
            return None
        members = {}
        for k in range(count):
            para = self.para_for_number(book_id, start + k, anchor)
            if para is None:
                return None
            members[normalise(f"{base}{first + k}")] = self.snap(book_id, para)[0]
        return members


def next_paranum(rows: list[dict], index: int) -> int | None:
    """First paragraph number of the next row from the same CST file."""
    cst_file = rows[index]["cst_file"]
    for row in rows[index + 1 :]:
        if row["cst_file"] != cst_file:
            return None
        m = re.match(r"\d+", (row["cst_paranum"] or "").strip())
        if m:
            return int(m.group())
    return None


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Build assets/sutta_codes.tsv from the DPD sheet and an epitaka.db."
    )
    parser.add_argument("--db", required=True, help="an ePitaka epitaka.db (read only)")
    parser.add_argument("--csv", help="a saved copy of the DPD sheet instead of downloading")
    parser.add_argument("--out", default="assets/sutta_codes.tsv")
    args = parser.parse_args()

    text, source = load_csv_text(args.csv)
    source_label = source if source == SHEET_URL else Path(source).name
    rows = parse_sheet(text)
    conn = open_db(args.db)
    locator = Locator(conn)

    routes: Counter = Counter()
    unresolved: list[str] = []
    overrides: list[str] = []
    # code -> (class, row index, target, display, title, range display)
    best: dict[str, tuple] = {}
    ranges_split = ranges_kept = 0
    for index, row in enumerate(rows):
        target, route, note, anchor = locator.locate(row)
        routes[route] += 1
        display = row["dpd_code"].strip()
        if target is None:
            unresolved.append(f"{display}: {note}")
            continue
        if route == "override":
            overrides.append(f"{display}: {note}")
        title = re.sub(r" \d+$", "", (row["dpd_sutta"] or "").strip())
        members = None
        if "-" in display and route.startswith("paragraph"):
            members = locator.range_members(
                row, target[0], anchor, next_paranum(rows, index)
            )
            if members is None:
                ranges_kept += 1
            else:
                ranges_split += 1
        for key, cls in expand_keys(row):
            if not key:
                continue
            if cls == DPD_RANGE and members and key in members:
                entry = (cls, index, (target[0], members[key]), key.upper(), title, display)
            else:
                entry = (cls, index, target, display, title, "")
            if key not in best or entry[:2] < best[key][:2]:
                best[key] = entry

    # Show a row's SuttaCentral code next to its DPD code (THI28 = THIG2.10),
    # but only where that code is accepted and opens the same place.
    alt_codes: dict[int, str] = {}
    for index, row in enumerate(rows):
        sc = (row["sc_code"] or "").strip()
        dpd = normalise(row["dpd_code"])
        if not sc or normalise(sc) == dpd or dpd not in best:
            continue
        sc_entry = best.get(normalise(sc))
        if sc_entry and sc_entry[1] == index and sc_entry[2] == best[dpd][2]:
            alt_codes[index] = sc.upper()

    out = Path(args.out)
    lines = [
        f"# Built {datetime.now(timezone.utc):%Y-%m-%d} from {source_label} and "
        f"{Path(args.db).name}; "
        f"{len(rows)} sheet rows, {len(best)} codes. "
        "Columns: code, book_id, para_id, display_code, title, range_code "
        "(set when the code is one sutta inside a DPD range), alt_code (the "
        "row's SuttaCentral code when it differs and opens the same place). "
        "Regenerate with "
        "scripts/build_sutta_codes.py whenever epitaka.db changes."
    ]
    for key in sorted(best, key=natural_key):
        _, index, (book_id, para_id), display, title, range_code = best[key]
        alt = "" if range_code else alt_codes.get(index, "")
        lines.append(
            f"{key}\t{book_id}\t{para_id}\t{display}\t{title}\t{range_code}\t{alt}"
        )
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="")

    print(f"Sheet rows with a dpd_code: {len(rows)}")
    print("Rows per route:")
    for route, count in sorted(routes.items()):
        print(f"  {route}: {count}")
    print(f"Unresolved rows ({len(unresolved)}), dropped from the map:")
    for line in unresolved:
        print(f"  {line}")
    print(
        f"DPD ranges opening at each sutta's paragraph: {ranges_split}; "
        f"at the range heading (paragraph count does not match): {ranges_kept}"
    )
    print(f"Rows shown with their SuttaCentral code as well: {len(alt_codes)}")
    print(f"Cross-check overrides ({len(overrides)}):")
    for line in overrides:
        print(f"  {line}")
    print(f"Wrote {len(best)} codes to {out}")


if __name__ == "__main__":
    main()
