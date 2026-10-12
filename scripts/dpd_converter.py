#!/usr/bin/env python3
"""
convert_dpd.py

Restructures a Digital Pali Dictionary (DPD) sqlite export (e.g. dpd-mobile.db)
into an app-friendly schema:

  1. dpd_lookup      -- rebuilt from `lookup`
  2. dpd_headwords    -- rebuilt from `dpd_headwords`, PLUS one extra row per
                          entry in `dpd_roots` (roots are treated as
                          first-class headword-like entries with their own id,
                          instead of duplicating root/family HTML into every
                          word that shares that root).
  3. inflection_templates -- copied verbatim from source (pattern PK, like,
                          data JSON list). Needed to render inflection tables
                          from dpd_headwords.stem + pattern.

Usage:
    python convert_dpd.py dpd-mobile.db dpd-mobile-converted.db

Design notes / assumptions (read before running):

* `dpd_roots` has no numeric id column -- `root` (e.g. "√kar") is its
  natural key. Since roots are now appended as rows to dpd_headwords, each
  root gets a real integer id: max(existing dpd_headwords.id) + 1, 2, 3...
  assigned in alphabetical order of `root` for determinism.
* dpd_lookup.headwords is a single JSON array of ints only. It merges the
  original `headwords` list (already ints -> dpd_headwords.id) with the
  original `roots` list (strings like "√kar") translated through the new
  root -> id mapping, so every entry uniformly points at a dpd_headwords.id.
  If a root string can't be matched to `dpd_roots` (shouldn't normally
  happen), it's left as the original string and a warning is printed.
* dpd_headwords no longer has a root_family_html column. Instead:
    - each real headword's meaning_html still shows a compact inline root
      reference: [root_key(+suffix): root_meaning] -- this is cheap,
      one line, not a duplicated family listing.
    - each *root* gets exactly one dpd_headwords row of its own, whose
      meaning_html contains the fuller root info (meaning, Sanskrit
      cognate, dhatupatha/dhatumanjusa entries, notes) plus the
      pre-rendered family_root.html word list for that root -- stored once,
      not copied into every member word.
* dpd_headwords.meaning_html is a <details>/<summary> block:
    - <summary>: pos (italic) + meaning_1 (bold) + meaning_lit (in
      parentheses) + [root_key(+suffix): root_meaning] if a root exists.
    - hidden body (revealed on expand): grammar, sanskrit,
      "root_key root_sign (root_base) - construction", compound_type
      (compound_construction), and example_1.
* Text fields that already contain inline markup from the source
  (e.g. example_1 has <b>word</b> highlighting) are inserted as-is,
  un-escaped. Plain fields (pos, meaning_1, grammar, ...) are also
  inserted as-is since this is a closed, trusted dataset -- add escaping
  if you ever mix in untrusted user data.
"""

import html
import json
import os
import sqlite3
import sys


# --------------------------------------------------------------------------
# small helpers
# --------------------------------------------------------------------------


def parse_json(val):
    """Best-effort JSON parse; returns [] for None/blank/invalid values."""
    if not val:
        return []
    if isinstance(val, (list, dict)):
        return val
    try:
        return json.loads(val)
    except (json.JSONDecodeError, TypeError):
        return []


def nz(val):
    """Normalize empty/whitespace-only strings to None."""
    if val is None:
        return None
    v = str(val).strip()
    return v if v else None


def build_epd_html(val):
    """Convert lookup.epd JSON [[term, type, meaning], ...] to HTML.

    Output: <b>term</b>: <i>type</i> meaning.<br/>...
    Returns None for empty/invalid input.
    """
    entries = parse_json(val)
    if not entries:
        return None
    parts = []
    for e in entries:
        if not isinstance(e, (list, tuple)) or not e:
            continue
        term = nz(e[0] if len(e) > 0 else None) or ""
        typ = nz(e[1] if len(e) > 1 else None) or ""
        meaning = nz(e[2] if len(e) > 2 else None) or ""
        if not (term or typ or meaning):
            continue
        t = html.escape(term)
        m = html.escape(meaning)
        ty = html.escape(typ)
        if ty:
            parts.append(f"<b>{t}</b>: <i>{ty}</i> {m}.")
        else:
            parts.append(f"<b>{t}</b> {m}.")
    return "<br/>".join(parts) if parts else None


# --------------------------------------------------------------------------
# root id mapping (roots become rows in dpd_headwords)
# --------------------------------------------------------------------------


def build_root_id_map(src):
    max_id = src.execute("SELECT MAX(id) FROM dpd_headwords").fetchone()[0] or 0
    roots = [r["root"] for r in src.execute("SELECT root FROM dpd_roots ORDER BY root")]
    return {root: max_id + i + 1 for i, root in enumerate(roots)}


# --------------------------------------------------------------------------
# 1. dpd_lookup
# --------------------------------------------------------------------------


def build_dpd_lookup(src, out, root_id_map):
    out.execute("DROP TABLE IF EXISTS dpd_lookup")
    out.execute("""
        CREATE TABLE dpd_lookup (
            lookup_key    TEXT,
            headwords     TEXT,  -- JSON array of ints -> dpd_headwords.id
            deconstructor TEXT,
            epd           TEXT   -- pre-rendered HTML from lookup.epd [[term, type, meaning]]
        )
    """)

    cols = [r["name"] for r in src.execute("PRAGMA table_info(lookup)")]
    has_epd = "epd" in cols
    q = "SELECT lookup_key, headwords, roots, deconstructor"
    q += ", epd" if has_epd else ""
    q += " FROM lookup"
    rows = src.execute(q).fetchall()

    unmatched_roots = 0
    payload = []
    for r in rows:
        hw_list = list(parse_json(r["headwords"]))

        for root_key in parse_json(r["roots"]):
            root_id = root_id_map.get(root_key)
            if root_id is not None:
                hw_list.append(root_id)
            else:
                unmatched_roots += 1
                hw_list.append(root_key)  # fallback: keep original string

        deconstructor = nz(r["deconstructor"])
        epd = build_epd_html(r["epd"]) if has_epd else None

        payload.append(
            (
                r["lookup_key"],
                json.dumps(hw_list, ensure_ascii=False) if hw_list else None,
                deconstructor,
                epd,
            )
        )

    out.executemany(
        "INSERT INTO dpd_lookup (lookup_key, headwords, deconstructor, epd) VALUES (?, ?, ?, ?)",
        payload,
    )
    out.execute("CREATE INDEX idx_dpd_lookup_key ON dpd_lookup(lookup_key)")
    print(
        f"dpd_lookup: inserted {len(payload)} rows"
        + (
            f" ({unmatched_roots} root keys could not be matched to dpd_roots)"
            if unmatched_roots
            else ""
        )
    )


# --------------------------------------------------------------------------
# 2/3/4. dpd_headwords -- real headwords
# --------------------------------------------------------------------------


def load_roots(src):
    """root (str, natural key) -> row dict"""
    return {r["root"]: dict(r) for r in src.execute("SELECT * FROM dpd_roots")}


def build_meaning_html(row, roots_by_key):
    pos = nz(row["pos"])
    meaning_1 = nz(row["meaning_1"])
    meaning_2 = nz(row["meaning_2"])
    meaning_lit = nz(row["meaning_lit"])
    root_key = nz(row["root_key"])
    suffix = nz(row["suffix"])

    # ---- summary (always visible) ----
    summary_bits = []
    if pos:
        summary_bits.append(f"<i>{pos}</i>")
    if meaning_1:
        summary_bits.append(f"<b>{meaning_1}</b>")
    if meaning_2:
        summary_bits.append(f"{meaning_2}")
    if meaning_lit:
        summary_bits.append(f"(lit. {meaning_lit})")

    if root_key:
        root_row = roots_by_key.get(root_key)
        root_meaning = nz(root_row["root_meaning"]) if root_row else None
        root_disp = root_key + (f" + {suffix}" if suffix else "")
        if root_meaning:
            summary_bits.append(f"[{root_disp}: {root_meaning}]")
        else:
            summary_bits.append(f"[{root_disp}]")

    summary_html = " ".join(summary_bits) if summary_bits else (row["lemma_1"] or "")

    # ---- hidden detail (revealed on expand) ----
    detail_lines = []

    grammar = nz(row["grammar"])
    if grammar:
        detail_lines.append(f"<div class='dpd-grammar'><b>Grammar:</b> {grammar}</div>")

    sanskrit = nz(row["sanskrit"])
    if sanskrit:
        detail_lines.append(
            f"<div class='dpd-sanskrit'><b>Sanskrit:</b> {sanskrit}</div>"
        )

    if root_key:
        root_row = roots_by_key.get(root_key)
        root_sign = nz(row["root_sign"]) or (
            nz(root_row["root_sign"]) if root_row else None
        )
        root_base = nz(row["root_base"])
        construction = nz(row["construction"])
        root_line = root_key
        if root_sign:
            root_line += f" {root_sign}"
        if root_base:
            root_line += f" ({root_base})"
        if construction:
            root_line += f" - {construction}"
        detail_lines.append(f"<div class='dpd-root'><b>Root:</b> {root_line}</div>")

    compound_type = nz(row["compound_type"])
    if compound_type:
        compound_construction = nz(row["compound_construction"])
        ct_line = compound_type
        if compound_construction:
            ct_line += f" ({compound_construction})"
        detail_lines.append(
            f"<div class='dpd-compound'><b>Compound:</b> {ct_line}</div>"
        )

    example_1 = nz(row["example_1"])
    if example_1:
        detail_lines.append(
            f"<div class='dpd-example'><b>Example:</b> {example_1}</div>"
        )

    detail_html = "".join(detail_lines)

    return (
        "<details class='dpd-meaning'>"
        f"<summary>{summary_html}</summary>"
        f"<div class='dpd-meaning-detail'>{detail_html}</div>"
        "</details>"
    )


def fetch_headword_rows(src, roots_by_key):
    rows = src.execute("SELECT * FROM dpd_headwords").fetchall()
    payload = []
    for row in rows:
        payload.append(
            (
                row["id"],
                row["lemma_1"],
                build_meaning_html(row, roots_by_key),
                nz(row["antonym"]),
                nz(row["synonym"]),
                nz(row["stem"]),
                nz(row["pattern"]),
            )
        )
    return payload


# --------------------------------------------------------------------------
# 5. dpd_headwords -- root rows (one per dpd_roots entry, stored once)
# --------------------------------------------------------------------------


def load_family_root_by_root_key(src):
    out = {}
    for r in src.execute("SELECT * FROM family_root"):
        out.setdefault(r["root_key"], []).append(dict(r))
    return out


def build_root_meaning_html(root_row, family_root_rows):
    root = root_row["root"]
    root_meaning = nz(root_row["root_meaning"])
    root_group = nz(root_row["root_group"])
    root_sign = nz(root_row["root_sign"])
    sanskrit_root = nz(root_row["sanskrit_root"])
    sanskrit_root_meaning = nz(root_row["sanskrit_root_meaning"])

    # ---- summary ----
    summary_bits = [f"<b>{root}</b>"]
    if root_meaning:
        summary_bits.append(root_meaning)
    if sanskrit_root:
        skt = sanskrit_root
        if sanskrit_root_meaning:
            skt += f" ({sanskrit_root_meaning})"
        summary_bits.append(f"[skt. {skt}]")
    summary_html = " ".join(summary_bits)

    # ---- detail ----
    detail_lines = []
    if root_group or root_sign:
        gs = f"{root_group or ''}{root_sign or ''}".strip()
        detail_lines.append(f"<div class='dpd-root-group'><b>Group:</b> {gs}</div>")

    root_example = nz(root_row["root_example"])
    if root_example:
        detail_lines.append(
            f"<div class='dpd-root-example'><b>Example:</b> {root_example}</div>"
        )

    dhatupatha_pali = nz(root_row["dhatupatha_pali"])
    dhatupatha_english = nz(root_row["dhatupatha_english"])
    if dhatupatha_pali or dhatupatha_english:
        line = " - ".join(x for x in (dhatupatha_pali, dhatupatha_english) if x)
        detail_lines.append(
            f"<div class='dpd-dhatupatha'><b>Dhātupāṭha:</b> {line}</div>"
        )

    dhatumanjusa_pali = nz(root_row["dhatumanjusa_pali"])
    dhatumanjusa_english = nz(root_row["dhatumanjusa_english"])
    if dhatumanjusa_pali or dhatumanjusa_english:
        line = " - ".join(x for x in (dhatumanjusa_pali, dhatumanjusa_english) if x)
        detail_lines.append(
            f"<div class='dpd-dhatumanjusa'><b>Dhātumañjūsā:</b> {line}</div>"
        )

    note = nz(root_row["note"])
    if note:
        detail_lines.append(f"<div class='dpd-root-note'><b>Note:</b> {note}</div>")

    root_count = nz(root_row["root_count"])
    if root_count:
        detail_lines.append(
            f"<div class='dpd-root-count'><b>Word count:</b> {root_count}</div>"
        )

    # family word-list -- stored ONCE here on the root's own row
    for fr in family_root_rows or []:
        html = nz(fr.get("html"))
        if html:
            detail_lines.append(html)

    detail_html = "".join(detail_lines)

    return (
        "<details class='dpd-root-meaning'>"
        f"<summary>{summary_html}</summary>"
        f"<div class='dpd-meaning-detail'>{detail_html}</div>"
        "</details>"
    )


def fetch_root_rows(src, root_id_map):
    family_root_by_root_key = load_family_root_by_root_key(src)
    payload = []
    for r in src.execute("SELECT * FROM dpd_roots"):
        root_row = dict(r)
        root = root_row["root"]
        payload.append(
            (
                root_id_map[root],
                root,
                build_root_meaning_html(root_row, family_root_by_root_key.get(root)),
                None,  # antonym
                None,  # synonym
                None,  # stem
                None,  # pattern
            )
        )
    return payload


def build_dpd_headwords(src, out, root_id_map):
    out.execute("DROP TABLE IF EXISTS dpd_headwords")
    out.execute("""
        CREATE TABLE dpd_headwords (
            id           INTEGER PRIMARY KEY,
            lemma_1      TEXT,
            meaning_html TEXT,
            antonym      TEXT,
            synonym      TEXT,
            stem         TEXT,
            pattern      TEXT
        )
    """)

    roots_by_key = load_roots(src)

    headword_payload = fetch_headword_rows(src, roots_by_key)
    root_payload = fetch_root_rows(src, root_id_map)

    all_payload = headword_payload + root_payload
    out.executemany(
        """INSERT INTO dpd_headwords
           (id, lemma_1, meaning_html, antonym, synonym, stem, pattern)
           VALUES (?, ?, ?, ?, ?, ?, ?)""",
        all_payload,
    )
    out.execute("CREATE INDEX idx_dpd_headwords_lemma_1 ON dpd_headwords(lemma_1)")
    print(
        f"dpd_headwords: inserted {len(headword_payload)} headword rows "
        f"+ {len(root_payload)} root rows = {len(all_payload)} total"
    )


# --------------------------------------------------------------------------
# 6. passthrough tables (copied verbatim from source)
# --------------------------------------------------------------------------


def copy_table_verbatim(src, out, table):
    schema_row = src.execute(
        "SELECT sql FROM sqlite_master WHERE type='table' AND name=?", (table,)
    ).fetchone()
    if not schema_row or not schema_row[0]:
        print(f"{table}: not found in source, skipped")
        return
    out.execute(f'DROP TABLE IF EXISTS "{table}"')
    out.execute(schema_row[0])
    rows = src.execute(f'SELECT * FROM "{table}"').fetchall()
    if rows:
        cols = list(rows[0].keys())
        col_list = ", ".join(f'"{c}"' for c in cols)
        placeholders = ", ".join(["?"] * len(cols))
        out.executemany(
            f'INSERT INTO "{table}" ({col_list}) VALUES ({placeholders})',
            [tuple(r) for r in rows],
        )
    for idx in src.execute(
        "SELECT sql FROM sqlite_master WHERE type='index' AND tbl_name=? AND sql IS NOT NULL",
        (table,),
    ).fetchall():
        try:
            out.execute(idx[0])
        except sqlite3.OperationalError:
            pass
    print(f"{table}: copied {len(rows)} rows")


def build_inflection_templates(src, out):
    copy_table_verbatim(src, out, "inflection_templates")


# --------------------------------------------------------------------------
# main
# --------------------------------------------------------------------------


def main():
    if len(sys.argv) < 3:
        print("Usage: python convert_dpd.py <source.db> <output.db>")
        sys.exit(1)

    src_path, out_path = sys.argv[1], sys.argv[2]

    if not os.path.exists(src_path):
        print(f"Source db not found: {src_path}")
        sys.exit(1)

    if os.path.exists(out_path):
        os.remove(out_path)

    src = sqlite3.connect(src_path)
    src.row_factory = sqlite3.Row

    out = sqlite3.connect(out_path)

    root_id_map = build_root_id_map(src)
    build_dpd_headwords(src, out, root_id_map)
    build_dpd_lookup(src, out, root_id_map)
    build_inflection_templates(src, out)

    out.commit()
    src.close()
    out.close()
    print(f"Done. Wrote {out_path}")


if __name__ == "__main__":
    main()
