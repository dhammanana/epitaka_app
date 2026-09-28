#!/bin/bash
# Measure cold-start → first-book-open latency on macOS.
#
# Launches the app with `flutter run -d macos`, then opens a book through the
# `epitaka://` deep link — the same code path a library/book row tap uses
# (readerTabsProvider.openTab + navigate to /reader) — so the full timeline is
# measured without any manual clicking.
#
# Prints every [STARTUP] milestone logged by lib/core/utils/startup_timing.dart
# plus the reader's own [LOAD]/[TAB_SW] lines for the opened book.
#
# Usage: scripts/measure-startup.sh [bookId]      (default: Vin-i)
set -uo pipefail

BOOK_ID="${1:-Vin-i}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG="${TMPDIR:-/tmp}/epitaka-startup.log"
cd "$ROOT"

if pgrep -f "epitaka.app/Contents/MacOS/epitaka" >/dev/null; then
  echo "ePitaka is already running — quit it first: a running instance would"
  echo "receive the deep link and the freshly built one would never be measured."
  exit 1
fi

: >"$LOG"
echo "Building and launching (log: $LOG)…"
flutter run -d macos --debug >"$LOG" 2>&1 &
FLUTTER_PID=$!
trap 'kill "$FLUTTER_PID" 2>/dev/null' EXIT

wait_for() { # pattern, timeout_seconds
  local i=0
  while [ "$i" -lt "$2" ]; do
    grep -q "$1" "$LOG" && return 0
    sleep 1
    i=$((i + 1))
  done
  return 1
}

if ! wait_for 'first frame painted' 900; then
  echo "Timed out waiting for the first frame. Tail of log:"
  tail -30 "$LOG"
  exit 1
fi
echo "First frame painted; letting startup settle…"
wait_for 'index gate opened' 180 || sleep 5

echo "Opening book '$BOOK_ID' via deep link…"
open "epitaka://reader/$BOOK_ID"

wait_for 'book first visible' 90 || echo "(book content log not seen within 90s)"

echo
echo "──────── [STARTUP] timeline ────────"
grep '\[STARTUP\]' "$LOG" | sed -E 's/.*(\[STARTUP\])/\1/'
echo
echo "──────── reader [LOAD] / [TAB_SW] ────────"
grep -E '\[(LOAD|TAB_SW)\]' "$LOG" | sed -E 's/.*(\[(LOAD|TAB_SW)\])/\1/'
