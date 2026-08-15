# Agent instructions

## Git safety — always ask before restoring

**Never run `git restore`, `git checkout`, `git stash`, `git reset`, `git clean`, or anything else that discards or temporarily removes working-tree changes without asking the user first.**

The user often has uncommitted work in the working tree (changes they forgot to commit). Commands like `git stash` / `git checkout -- <file>` can capture or throw away many unrelated edits, and a failed `stash pop` (e.g. a `pubspec.lock` conflict) leaves the tree in a confusing state. If you need to verify that a change is pre-existing, ask for permission before stashing/restoring — or use a read-only check instead (e.g. `git diff` on the specific file, `git log`, or `git blame`).
