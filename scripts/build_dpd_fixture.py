# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""Build test/fixtures/dpd_mini.sql: a small slice of the DPD mobile database.

Every row is copied from a real dpd-mobile.db, so the tests see the export's
real shapes (empty strings, JSON columns, sutta codes in upper case).

    uv run scripts/build_dpd_fixture.py --db ~/.local/share/com.dn.epitaka/dpd-mobile.db

Re-run when the DPD export's schema changes, then re-run the DPD tests.
"""

import argparse
import json
import sqlite3
from pathlib import Path

# The 25 benchmark words of thread 20261013_dpd_mobile_integration
# (15 frequent, 5 long compounds, 5 with no headword).
BENCH_WORDS = [
    "ti", "ca", "na", "vā", "pana", "hoti", "taṃ", "evaṃ", "tattha", "so",
    "pe", "nāma", "kho", "hi", "vuttaṃ",
    "paṭisandhikkhaṇe", "ārammaṇapaccayena", "upanissayapaccayena",
    "anantarapaccayena", "cittasamuṭṭhānaṃ",
    "panā", "tatthā", "footnote", "tiādīni", "vuttan",
]

# One real key for each case the tests cover. The comment names the column
# that makes the key worth having.
EXTRA_WORDS = [
    "dhamma",  # many headwords, external dictionary entries
    "satipaṭṭhāna",  # suggestion prefix "satip"
    "kammaṃ",  # fuzzy rescue for "kammam"; every row sharing its key joins
    "DN1",  # sutta code, stored upper case; sutta_info
    "anugā",  # roots
    "abba",  # deconstructor
    "tithī",  # variant
    "virocatī",  # see
    "rokho",  # spelling
    "word family",  # help
    "neut",  # abbrev
    "sandhi",  # abbrev_other
    "weed",  # epd
]

TABLES = [
    "db_info", "lookup", "dpd_headwords", "dpd_roots", "inflection_templates",
    "family_root", "family_word", "family_compound", "family_idiom",
    "family_set", "sutta_info", "dict_meta", "dict_entries",
]


def placeholders(values):
    return ",".join("?" * len(values))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", required=True, type=Path)
    parser.add_argument(
        "--out", type=Path, default=Path("test/fixtures/dpd_mini.sql")
    )
    args = parser.parse_args()

    src = sqlite3.connect(f"file:{args.db}?mode=ro", uri=True)
    dst = sqlite3.connect(":memory:")

    for (sql,) in src.execute(
        "SELECT sql FROM sqlite_master WHERE type='table' AND name IN "
        f"({placeholders(TABLES)})",
        TABLES,
    ):
        dst.execute(sql)

    def copy(table, where, params=()):
        rows = src.execute(f"SELECT * FROM {table} WHERE {where}", params).fetchall()
        if rows:
            dst.executemany(
                f"INSERT OR IGNORE INTO {table} VALUES ({placeholders(rows[0])})",
                rows,
            )
        return rows

    # all_decon_no_headwords alone is 15 MB; the app reads none of the long
    # values.
    copy("db_info", "length(value) < 1000")
    copy("dict_meta", "1")

    words = BENCH_WORDS + EXTRA_WORDS
    copy("lookup", f"lookup_key IN ({placeholders(words)})", words)
    copy(
        "lookup",
        "fuzzy_key = (SELECT fuzzy_key FROM lookup WHERE lookup_key = 'kammaṃ')",
    )

    ids = set()
    root_keys = set()
    for headwords, roots in dst.execute("SELECT headwords, roots FROM lookup"):
        if headwords:
            ids.update(json.loads(headwords))
        if roots:
            root_keys.update(json.loads(roots))
    ids = sorted(ids)
    headwords = copy("dpd_headwords", f"id IN ({placeholders(ids)})", ids)

    columns = [d[1] for d in src.execute("PRAGMA table_info(dpd_headwords)")]
    col = {name: i for i, name in enumerate(columns)}
    lemmas, patterns, word_families = set(), set(), set()
    compound_families, idioms, sets, root_families = set(), set(), set(), set()
    for row in headwords:
        lemmas.add(row[col["lemma_1"]])
        if row[col["root_key"]]:
            root_keys.add(row[col["root_key"]])
            root_families.add((row[col["root_key"]], row[col["family_root"]]))
        if row[col["pattern"]]:
            patterns.add(row[col["pattern"]])
        if row[col["family_word"]]:
            word_families.add(row[col["family_word"]])
        compound_families.update((row[col["family_compound"]] or "").split())
        idioms.update((row[col["family_idioms"]] or "").split())
        sets.update(s for s in (row[col["family_set"]] or "").split("; ") if s)

    def copy_in(table, column, values):
        values = sorted(values)
        if values:
            copy(table, f'"{column}" IN ({placeholders(values)})', values)

    copy_in("dpd_roots", "root", root_keys)
    for root_key, family in sorted(root_families):
        copy("family_root", "root_key = ? AND root_family = ?", (root_key, family))
    copy_in("inflection_templates", "pattern", patterns)
    copy_in("family_word", "word_family", word_families)
    copy_in("family_compound", "compound_family", compound_families)
    copy_in("family_idiom", "idiom", idioms)
    copy_in("family_set", "set", sets)
    copy_in("sutta_info", "dpd_sutta", lemmas)

    # One entry per external dictionary: a fixture word where the dictionary
    # has one, else its shortest real entry.
    for (dict_id,) in src.execute("SELECT dict_id FROM dict_meta ORDER BY dict_id"):
        rows = copy(
            "dict_entries",
            f"dict_id = ? AND word IN ({placeholders(words)}) ORDER BY word LIMIT 1",
            [dict_id, *words],
        )
        if not rows:
            copy(
                "dict_entries",
                "dict_id = ? ORDER BY length(definition_html), id LIMIT 1",
                (dict_id,),
            )

    for (sql,) in src.execute(
        "SELECT sql FROM sqlite_master WHERE type='index' AND sql IS NOT NULL"
    ):
        dst.execute(sql)
    dst.commit()

    args.out.parent.mkdir(parents=True, exist_ok=True)
    with open(args.out, "w", encoding="utf-8", newline="\n") as f:
        for line in dst.iterdump():
            f.write(line + "\n")

    for table in TABLES:
        (n,) = dst.execute(f"SELECT count(*) FROM {table}").fetchone()
        print(f"{table}: {n}")
    print(f"wrote {args.out} ({args.out.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
