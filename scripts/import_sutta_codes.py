# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""Import sutta-code lookup data into the headings table of an epitaka.db.

Pipeline: DPD sheet + epitaka.db -> scripts/build_sutta_codes.py ->
assets/sutta_codes.tsv -> THIS script -> headings.sc_id.

`headings.sc_id` becomes the single source of truth for "Go to sutta".
Each mapped `(book_id, para_id)` row holds a space-separated token cell:

    mn10
    thi28 thig2.10 thi2.10
    an1 an1.1-10 >an1.1
    an1.98-139 >an1.98
    an1.188-197 an1.188-267 +an1.188 +an1.189 ...

Grammar (the app's sutta_code_service.dart implements the same contract):

- every token is a lower-case normalised sutta code (`mn10`, `an1.1-10`);
- `>` marks a single sutta inside a split DPD range (the TSV `range_code`
  column is non-empty). Range members only resolve as an exact match and
  show `AN1.5 (AN1.1-10)`;
- `+` marks a kept-range member: it has no row of its own, so it shows
  the covering range (`an1.188` shows `AN1.188-267`), but unlike `>` it
  is listed in prefix matches;
- `=` marks an alias token: SuttaCentral's code for a DPD sutta
  (`=thig2.10`, `=an3.185`) or a range dash (`=an3.183-352`). `=` tokens
  never count as covering ranges. A row holding one shows
  `DPD = SC` (`THI28 = THIG2.10`, `AN3.184 = AN3.183-352`), where DPD is
  the row's first plain code;
- the DPD code of an alias row sorts first among the plain codes, so the
  app finds it without extra marks (a samyutta code sharing the
  paragraph, e.g. `sn39` next to `sn39.1`, keeps its own plain label);
- a DPD range dash carrying its own SuttaCentral alt keeps the alt as a
  `=alt` suffix payload (`an5.303-1151=an5.303` shows
  `AN5.303-1151 = AN5.303`). Payloads never combine with prefix marks;
- token order per cell: DPD codes first (`key.upper() == display_code`),
  then other non-member keys (real SuttaCentral codes before synthetic
  `thi`/`th` respellings), then marked keys, each in TSV file order, so
  the first tokens are the row's primary (display) codes;
- rows with no TSV mapping are left untouched (Vinaya, Abhidhamma and
  Milindapanhha keep the SuttaCentral ids already on their headings).

Snapped members are relocated onto their true level-10 paragraphs: the
TSV snaps some range members up to a heading-run top (e.g. `an1.1` onto
the `A-i` nipata row para 3) while the other members already resolve to
the level-10 rows titled with the sutta number — rows the app queries.
For each `>`/`+` member on a level<10 row, the level-10 row in the same
book whose integer title is the member number, and whose ancestors hold
a DPD range covering it, receives the key as `>`; the key is removed
from its old cell (emptied cells are written as NULL). A DPD range whose
moved members unanimously sit under one level<10 parent follows them to
that parent (the vagga row); if the parent already carries the range,
the key is simply dropped from the old cell. Ambiguous keys
stay where the TSV put them and are reported.

Usage:

    # Validate the TSV only (no database needed):
    uv run scripts/import_sutta_codes.py --check

    # Verify every TSV target exists in a database (read-only):
    uv run scripts/import_sutta_codes.py --check --db /path/to/epitaka.db

    # Write into a database (makes a timestamped .bak copy first):
    uv run scripts/import_sutta_codes.py --db /path/to/epitaka.db --write
"""

import argparse
import re
import shutil
import sqlite3
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path

TSV_COLUMNS = ('code', 'book_id', 'para_id', 'display', 'title', 'range', 'alt')
MEMBER_MARK = '>'
KEPT_MARK = '+'
ALIAS_MARK = '='
TOKEN_RE = re.compile(r'^[a-z0-9.~-]+$')


def fail(message: str) -> None:
    print(f'ERROR: {message}', file=sys.stderr)
    sys.exit(1)


def parse_tsv(path: Path) -> list[dict]:
    rows = []
    with open(path, encoding='utf-8', newline='') as f:
        for lineno, line in enumerate(f, 1):
            line = line.rstrip('\r\n')
            if not line or line.startswith('#'):
                continue
            cols = line.split('\t')
            if len(cols) < 5:
                fail(f'{path}:{lineno}: only {len(cols)} columns')
            try:
                para_id = int(cols[2])
            except ValueError:
                fail(f'{path}:{lineno}: para_id is not an int: {cols[2]!r}')
            rows.append({
                'key': cols[0],
                'book_id': cols[1],
                'para_id': para_id,
                'display': cols[3],
                'title': cols[4],
                'range': cols[5] if len(cols) > 5 else '',
                'alt': cols[6] if len(cols) > 6 else '',
            })
    if not rows:
        fail(f'{path}: no data rows')
    return rows


def _is_synthetic_alias(token: str, cell_tokens: set[str]) -> bool:
    """True when [token] is a DPD-style respelling of a SuttaCentral code.

    build_sutta_codes.py derives `thi2.10` from sheet code `thig2.10`
    (and `th1.1` from `thag1.1`). The synthetic form sorts after the real
    SuttaCentral code so the app's `DPD = SC` label shows the real one.
    """
    if token.startswith('thig') or token.startswith('thag'):
        return False
    if token.startswith('thi'):
        return 'thig' + token[3:] in cell_tokens
    if token.startswith('th'):
        return 'thag' + token[2:] in cell_tokens
    return False


def build_cells(rows: list[dict]) -> dict[tuple[str, int], str]:
    """Group TSV keys by target row into sc_id token cells.

    Every key is classified from its TSV display value (see the module
    docstring for the marker grammar). Returns {(book_id, para_id): cell}.
    Raises on duplicate keys, a key claimed by two rows, or a key whose
    display matches nothing in its own cell (which would mean the app
    could not reconstruct the TSV label from the cell alone).
    """
    by_target: dict[tuple[str, int], list[dict]] = defaultdict(list)
    seen: dict[str, tuple[str, int]] = {}
    for row in rows:
        key = row['key']
        target = (row['book_id'], row['para_id'])
        if key in seen and seen[key] != target:
            fail(f'duplicate key {key!r} for {seen[key]} and {target}')
        seen[key] = target
        by_target[target].append(row)

    cells = {}
    for target, entries in by_target.items():
        plain_uppers = set()
        dash_uppers = set()
        for e in entries:
            if not e['range'] and e['display'] == e['key'].upper():
                if '-' in e['key']:
                    dash_uppers.add(e['display'])
                else:
                    plain_uppers.add(e['display'])
        dpd_primary, dpd, other = [], [], []
        members, kept, eq_dash, eq_plain = [], [], [], []
        for e in entries:
            key = e['key']
            if not TOKEN_RE.match(key):
                fail(f'key {key!r} is not a plain lower-case code token')
            if e['range']:
                members.append(MEMBER_MARK + key)
            elif key.upper() == e['display']:
                if e['alt']:
                    # A DPD code with its own SuttaCentral alt: the row's
                    # display-bearer (`thi28`, `sn39.1`). A range dash keeps
                    # the alt as a suffix payload (`an5.303-1151=an5.303`)
                    # showing `AN5.303-1151 = AN5.303`; a plain code sorts
                    # first so the app finds it (`SN39.1 = SN39.1-15`).
                    if '-' in key:
                        payload = e['alt'].lower()
                        if not TOKEN_RE.match(payload):
                            fail(
                                f'alt payload {payload!r} for {key!r} '
                                f'is not a code',
                            )
                        dpd_primary.append(f'{key}{ALIAS_MARK}{payload}')
                    else:
                        dpd_primary.append(key)
                else:
                    dpd.append(key)
            elif e['display'] in dash_uppers and '-' not in key:
                # Kept-range member: no row of its own, shows the range.
                kept.append(KEPT_MARK + key)
            elif e['display'] in plain_uppers:
                if '-' in key or e['alt']:
                    # SuttaCentral alias: a range dash for a DPD sutta
                    # (`=an3.183-352`) or a plain code shown as `DPD = SC`
                    # (`=thig2.10`, `=an3.185`).
                    (eq_dash if '-' in key else eq_plain).append(
                        ALIAS_MARK + key,
                    )
                else:
                    # A distinct sutta sharing the paragraph (e.g. the
                    # nipata `an3` with its first sutta `an3.1`).
                    other.append(key)
            else:
                fail(
                    f'key {key!r} at {target}: display {e["display"]!r} '
                    f'matches no code in its own cell',
                )
        # Synthetic thi/th aliases (derived from a real thig/thag code in
        # the same cell) sort after it, so the app label shows the real
        # SuttaCentral code: `THI28 = THIG2.10`, not `THI28 = THI2.10`.
        present = set(
            [cell_key(t) for t in dpd_primary]
            + dpd
            + other
            + [t[1:] for t in eq_plain],
        )
        eq_real = [t for t in eq_plain if not _is_synthetic_alias(t[1:], present)]
        eq_synth = [t for t in eq_plain if _is_synthetic_alias(t[1:], present)]
        tokens = (
            dpd_primary + dpd + other + eq_dash + eq_real + eq_synth + kept + members
        )
        cells[target] = ' '.join(tokens)
    return cells


def cell_key(token: str) -> str:
    """The lookup code a token cell entry matches on (markers removed)."""
    if token[:1] in (MEMBER_MARK, KEPT_MARK, ALIAS_MARK):
        token = token[1:]
    head, sep, _ = token.partition(ALIAS_MARK)
    return head if sep else token


def check_tsv(tsv_path: Path) -> dict[tuple[str, int], str]:
    rows = parse_tsv(tsv_path)
    cells = build_cells(rows)
    marked = [t for c in cells.values() for t in c.split() if t[:1] in '>+=']
    n_multi = sum(1 for c in cells.values() if ' ' in c)
    print(f'TSV rows (lookup keys): {len(rows)}')
    print(f'Target heading rows:    {len(cells)}')
    print(f'Marked keys (>/+/=):    {len(marked)}')
    print(f'Rows with >1 key:       {n_multi}')
    return cells


def open_db(path: str) -> sqlite3.Connection:
    db_path = Path(path)
    if not db_path.is_file():
        fail(f'database not found: {path}')
    conn = sqlite3.connect(str(db_path))
    cols = {r[1] for r in conn.execute('PRAGMA table_info(headings)')}
    missing = {'book_id', 'para_id', 'sc_id'} - cols
    if missing:
        fail(f'headings table lacks column(s): {", ".join(sorted(missing))}')
    return conn


def verify_targets(
    conn: sqlite3.Connection,
    cells: dict[tuple[str, int], str],
) -> list[tuple[str, int]]:
    """Every TSV target must be an existing headings row. Returns orphans."""
    orphans = []
    for book_id, para_id in cells:
        hit = conn.execute(
            'SELECT 1 FROM headings WHERE book_id = ? AND para_id = ?',
            (book_id, para_id),
        ).fetchone()
        if hit is None:
            orphans.append((book_id, para_id))
    return orphans


def _parse_range(token: str) -> tuple[str, int, int] | None:
    """Numeric bounds of a range token (`an1.1-10` -> (`an1.`, 1, 10))."""
    if '-' not in token:
        return None
    left, _, right = token.partition('-')
    m = re.fullmatch(r'(.*?)(\d+)', left)
    if not m or not right.isdigit():
        return None
    return m.group(1), int(m.group(2)), int(right)


def _covers(range_token: str, key: str) -> bool:
    """Whether range token [range_token] covers member code [key]."""
    if range_token == key:
        return True
    parsed = _parse_range(range_token)
    if parsed is None:
        return False
    stem, first, last = parsed
    m = re.fullmatch(re.escape(stem) + r'(\d+)', key)
    return m is not None and first <= int(m.group(1)) <= last


def _dpd_ranges(cell: str) -> list[str]:
    """True DPD ranges in a token cell: unmarked dashes (payload dashes
    count; `=` alias dashes never cover anything)."""
    out = []
    for token in cell.split():
        if token[:1] == ALIAS_MARK:
            continue
        key = cell_key(token)
        if '-' in key:
            out.append(key)
    return out


def relocate_members(
    cells: dict[tuple[str, int], str],
    conn: sqlite3.Connection,
) -> tuple[dict[tuple[str, int], str | None], list[str]]:
    """Move snapped members onto their true level-10 paragraphs.

    The TSV snaps some range members up to a heading-run top (e.g. `an1.1`
    onto the `A-i` nipata row para 3) while their true paragraph is the
    level-10 row titled with the sutta number (para 5, title "1") — the
    same rows the other members already resolve to. Those level-10 rows
    are what the app queries, so without this the moved keys stay
    invisible and the left-behind `NULL` rows stay empty.

    For each `>`/`+` member on a level<10 row, the level-10 row in the
    same book whose integer title is the member number — and whose
    ancestors (up to 3 up) hold a DPD range covering it — receives the
    key as `>`; the key is removed from its old cell. Cells emptied by a
    move become None (written as NULL). Ambiguous or colliding keys are
    reported and left in place.
    """
    info: dict[tuple[str, int], dict] = {}
    for book_id, para_id, level, title, parent, sc_id in conn.execute(
        'SELECT book_id, para_id, level, title, parent, sc_id FROM headings',
    ):
        info[(book_id, para_id)] = {
            'level': level,
            'title': title or '',
            'parent': parent,
            'sc_id': sc_id or '',
        }

    def cell_of(target: tuple[str, int]) -> str:
        if target in cells and cells[target]:
            return cells[target]  # type: ignore[return-value]
        return info.get(target, {}).get('sc_id', '')

    def ancestors(target: tuple[str, int]) -> list[tuple[str, int]]:
        out, seen = [], {target}
        book_id, para_id = target
        for _ in range(3):
            parent = info.get((book_id, para_id), {}).get('parent')
            if not parent or (book_id, parent) in seen:
                return out
            seen.add((book_id, parent))
            out.append((book_id, parent))
            para_id = parent
        return out

    def covers_from(target: tuple[str, int], key: str) -> bool:
        return any(_covers(r, key) for r in _dpd_ranges(cell_of(target)))

    moves: list[tuple[str, tuple[str, int], tuple[str, int]]] = []
    skipped: list[str] = []
    out: dict[tuple[str, int], str | None] = dict(cells)
    placed: dict[str, tuple[str, int]] = {}
    for target, cell in cells.items():
        for token in cell.split():
            if token[:1] not in (MEMBER_MARK, KEPT_MARK):
                continue
            key = cell_key(token)
            m = re.fullmatch(r'(.*?)(\d+)', key)
            level = info.get(target, {}).get('level')
            if (
                m is None
                or level is None
                or level >= 10
                or key in placed
            ):
                continue
            number = int(m.group(2))
            candidates = [
                t
                for t, row in info.items()
                if t[0] == target[0]
                and t != target
                and row['level'] == 10
                and row['title'].strip().isdigit()
                and int(row['title'].strip()) == number
                and any(covers_from(a, key) for a in ancestors(t))
            ]
            if len(candidates) != 1:
                if candidates:
                    skipped.append(
                        f'{key}: ambiguous level-10 rows '
                        f'{[p for _, p in candidates]}',
                    )
                continue
            dest = candidates[0]
            if key in [cell_key(t) for t in cell_of(dest).split()]:
                skipped.append(f'{key}: already on {dest[0]} {dest[1]}')
                continue
            moves.append((key, target, dest))
            placed[key] = dest

    for key, src, dest in moves:
        src_tokens = [t for t in out[src].split() if cell_key(t) != key]  # type: ignore[union-attr]
        out[src] = ' '.join(src_tokens) or None
        dest_tokens = cell_of(dest).split()
        dest_tokens.append(f'{MEMBER_MARK}{key}')
        out[dest] = ' '.join(dest_tokens)

    # Ranges follow their members: a DPD range token whose moved members
    # unanimously sit under one level<10 parent moves to that parent (the
    # vagga row) — e.g. `an1.1-10` from the nipata row to para 4. If the
    # parent already carries the range (its old sc_id), the key is simply
    # dropped from the old cell.
    def plain_tokens(target: tuple[str, int]) -> list[str]:
        cell = out.get(target)
        if not cell:
            cell = cell_of(target)
        return cell.split()

    def has_payload(token: str) -> bool:
        core = token[1:] if token[:1] in (MEMBER_MARK, KEPT_MARK, ALIAS_MARK) else token
        return '=' in core

    range_moves: list[tuple[str, tuple[str, int], tuple[str, int]]] = []
    holders: dict[str, list[tuple[str, int]]] = {}
    for target, cell in list(out.items()):
        if not cell:
            continue
        for token in cell.split():
            if token[:1] in (MEMBER_MARK, KEPT_MARK, ALIAS_MARK):
                continue
            key = cell_key(token)
            if '-' not in key or has_payload(token):
                continue
            holders.setdefault(key, []).append(target)
    for range_key, range_holders in holders.items():
        member_parents = []
        for mkey, _, dest in moves:
            if _covers(range_key, mkey):
                parent = info.get(dest, {}).get('parent')
                plevel = (
                    info.get((dest[0], parent), {}).get('level')
                    if parent else None
                )
                if parent and (plevel is None or plevel < 10):
                    member_parents.append((dest[0], parent))
        parents = sorted(set(member_parents))
        if len(parents) != 1:
            continue
        parent = parents[0]
        for holder in range_holders:
            if holder == parent:
                continue
            if range_key not in [cell_key(t) for t in plain_tokens(parent)]:
                out[parent] = ' '.join(plain_tokens(parent) + [range_key])
            src_tokens = [
                t for t in (out.get(holder) or '').split()
                if cell_key(t) != range_key
            ]
            out[holder] = ' '.join(src_tokens) or None
            range_moves.append((range_key, holder, parent))

    report = [
        f'MOVED {key} {src[0]} {src[1]} -> {dest[0]} {dest[1]}'
        for key, src, dest in moves
    ]
    report += [
        f'MOVED-RANGE {key} {src[0]} {src[1]} -> {dest[0]} {dest[1]}'
        for key, src, dest in range_moves
    ]
    report += [f'SKIPPED {s}' for s in skipped]
    return out, report


def main() -> None:
    parser = argparse.ArgumentParser(
        description='Import sutta_codes.tsv into headings.sc_id.',
    )
    parser.add_argument(
        '--tsv', default='assets/sutta_codes.tsv',
        help='TSV built by scripts/build_sutta_codes.py',
    )
    parser.add_argument('--db', help='epitaka.db file to verify or write')
    parser.add_argument(
        '--check', action='store_true',
        help='validate only (default when --write is absent)',
    )
    parser.add_argument(
        '--write', action='store_true',
        help='UPDATE headings.sc_id in --db (makes a .bak copy first)',
    )
    parser.add_argument(
        '--allow-orphans', action='store_true',
        help='with --write, write matched rows even if some TSV targets '
             'have no headings row (listed, exit 1)',
    )
    args = parser.parse_args()

    tsv_path = Path(args.tsv)
    if not tsv_path.is_file():
        fail(f'TSV not found: {tsv_path}')
    cells = check_tsv(tsv_path)

    if args.db is None:
        if args.write:
            fail('--write needs --db')
        return

    conn = open_db(args.db)
    try:
        orphans = verify_targets(conn, cells)
        if orphans:
            print(f'ORPHANS: {len(orphans)} TSV targets have no headings row:')
            for book_id, para_id in orphans[:20]:
                keys = cells[(book_id, para_id)].split()
                print(f'  {book_id} {para_id}: {" ".join(keys[:5])}')
            if len(orphans) > 20:
                print(f'  … and {len(orphans) - 20} more')
        if not args.write:
            cells, report = relocate_members(cells, conn)
            moves = [line for line in report if line.startswith('MOVED')]
            print(f'Level-10 relocation preview: {len(moves)} moves.')
            for line in report[:30]:
                print(f'  {line}')
            if len(report) > 30:
                print(f'  … and {len(report) - 30} more')
            if orphans:
                sys.exit(1)
            print(f'All {len(cells)} targets exist in {args.db}.')
            return
        if orphans and not args.allow_orphans:
            fail('aborting without writing (use --allow-orphans to skip them)')
        cells, report = relocate_members(cells, conn)
        moves = [line for line in report if line.startswith('MOVED')]
        print(f'Relocating {len(moves)} snapped members to level-10 rows.')

        stamp = datetime.now().strftime('%Y%m%d-%H%M%S')
        backup = f'{args.db}.bak-{stamp}'
        conn.close()
        shutil.copy2(args.db, backup)
        print(f'Backup: {backup}')
        conn = open_db(args.db)
        with conn:
            for (book_id, para_id), cell in cells.items():
                if (book_id, para_id) in set(orphans):
                    continue
                conn.execute(
                    'UPDATE headings SET sc_id = ? '
                    'WHERE book_id = ? AND para_id = ?',
                    (cell, book_id, para_id),
                )
        # Read-back verification: every TSV key in exactly one row.
        wanted: dict[str, tuple[str, int]] = {}
        for (book_id, para_id), cell in cells.items():
            for token in (cell or '').split():
                wanted[cell_key(token)] = (book_id, para_id)
        got: dict[str, list[tuple[str, int]]] = defaultdict(list)
        for book_id, para_id, sc_id in conn.execute(
            "SELECT book_id, para_id, sc_id FROM headings "
            "WHERE sc_id IS NOT NULL AND sc_id != ''",
        ):
            for token in sc_id.split():
                got[cell_key(token)].append((book_id, para_id))
        bad = 0
        for key, target in wanted.items():
            rows = got.get(key, [])
            if rows != [target]:
                print(f'MISMATCH: {key!r} -> {rows} (want [{target}])')
                bad += 1
        if bad:
            fail(f'{bad} keys misplaced after write')
        print(f'Wrote {len(cells)} token cells to {args.db}.')
        if orphans:
            print(f'WARNING: {len(orphans)} orphan targets skipped (--allow-orphans).')
    finally:
        conn.close()


if __name__ == '__main__':
    main()
