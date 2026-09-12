# Agent instructions

## Git safety — always ask before restoring

**Never run `git restore`, `git checkout`, `git stash`, `git reset`, `git clean`, or anything else that discards or temporarily removes working-tree changes without asking the user first.**

The user often has uncommitted work in the working tree (changes they forgot to commit). Commands like `git stash` / `git checkout -- <file>` can capture or throw away many unrelated edits, and a failed `stash pop` (e.g. a `pubspec.lock` conflict) leaves the tree in a confusing state. If you need to verify that a change is pre-existing, ask for permission before stashing/restoring — or use a read-only check instead (e.g. `git diff` on the specific file, `git log`, or `git blame`).

## Commit messages

Prefix the subject with a bracketed tag:

```
[Add] Separate Myanmar and Myanmar Nissaya to display them both at the same time
[Fix] Prevent screen lock on index + download page.
```

- **Two tags only: `[Add]` and `[Fix]`.** `[Add]` for new features and capabilities, `[Fix]` for corrections. Write them exactly like that — the history also contains `[FIX]`, `[fix]` and `[Fix]:`, which are drift, not alternatives to copy.
- Follow the tag with a space, then what changed, in sentence case.
- **One line. No newlines, no body.** Keep it short. Some existing subjects run to 133 characters — don't copy that.
- Listing several things is fine, but keep it on the one line, separated by ` - `:

  ```
  [Fix] Desktop UI - drawer nav, library appbar, Vīmaṃsā font control
  ```

- **Never add a signature or trailer.** No `Co-Authored-By`, no `Signed-off-by`, no "Generated with" line, no agent attribution of any kind. Two commits in the history carry Codebuff trailers; do not follow that precedent.
- Don't invent tags from other conventions. This repo does not use `feat:`, `fix:`, `chore:`, or scopes in parentheses.

Adopting the tag is recent and deliberate: 18 of the last 25 non-merge commits use it, against 2 of the 25 before that. Match the recent history, not the old.

## Response format — end with issue and fix

End every response with a short `Issue:` / `Fix:` summary (2–4 lines total) explaining what the problem was and what was changed. Skip it only for trivial one-shot answers.
