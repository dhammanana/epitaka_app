# ePitaka on Flathub

This directory contains everything needed to publish **ePitaka** on
[Flathub](https://flathub.org) — the official Flatpak store — including the
automation that publishes every new release automatically.

## How Flathub works (read this first)

Flathub has **no "upload binary" API**. Flathub's own build farm compiles
your app from a `flatpak-builder` manifest that lives in a GitHub repo under
the `flathub/` organisation (`flathub/org.epitaka.Epitaka`). The manifest
points at your source repo (`github.com/dhammanana/epitaka_app`) at a pinned
tag + commit. So:

- `build_app.yml` is **not** touched for Flatpak — Flathub builds on their
  infrastructure, not your CI.
- Publishing is done by **merging a change to the flathub repo**, not by
  uploading artifacts.

## Files

| File | Purpose |
|---|---|
| `org.epitaka.Epitaka.yml` | The flatpak-builder manifest |
| `org.epitaka.Epitaka.desktop` | Desktop entry (renamed to the app ID) |
| `org.epitaka.Epitaka.metainfo.xml` | AppStream metadata (required) |
| `fetch-core-dbs.sh` | Downloads the core DBs into `assets/db` during the build (same logic as the CI workflow) |

The app ID `org.epitaka.Epitaka` maps to the domain `epitaka.org` (reverse
DNS), which you must control and serve over HTTPS — reviewers will check it.

## Before submitting — fill in the placeholders

1. **`org.epitaka.Epitaka.metainfo.xml`**
   - Replace the `PLACEHOLDER.invalid` screenshot URL with a real screenshot
     hosted at a stable URL (a raw GitHub URL pinned to a tag/commit, or on
     `epitaka.org`). Graphical apps are required to have screenshots.
   - Set the real release date for the latest release (the value must not be
     in the future), and adjust the developer `<name>` if you prefer
     something other than the GitHub username.
2. Verify `https://epitaka.org` resolves and serves over HTTPS.
3. Confirm you're happy with the license declaration: the repo is
   **CC-BY-NC-4.0** (`project_license` above). NC licenses are redistributable
   and accepted on Flathub, but reviewers may ask about it.
4. Note: the app includes an AI chat feature. Flathub has a Generative AI
   policy; if reviewers raise it, be ready to explain the feature and that
   the app/code itself is not AI-generated.

## 1. Test the build locally (recommended before submitting)

```bash
flatpak install -y flathub org.flatpak.Builder
flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Build + install + run
flatpak run --command=flathub-build org.flatpak.Builder --install org.epitaka.Epitaka.yml
flatpak run org.epitaka.Epitaka

# Lint the manifest and the generated repo (fix every error/warning)
flatpak run --command=flatpak-builder-lint org.flatpak.Builder manifest org.epitaka.Epitaka.yml
flatpak run --command=flatpak-builder-lint org.flatpak.Builder repo repo

# Validate the metainfo file
flatpak run --command=flatpak-builder-lint org.flatpak.Builder appstream org.epitaka.Epitaka.metainfo.xml
```

## 2. Submit (one-time, manual review)

1. Fork `flathub/flathub` (uncheck "Copy the master branch only") and clone:
   `git clone --branch=new-pr git@github.com:<you>/flathub.git && cd flathub && git checkout -b add-epitaka`
2. Add the 4 files from this directory (manifest, desktop, metainfo,
   `fetch-core-dbs.sh`) — keep them at the repo root, next to the manifest.
3. Commit, push, and open a PR **against the `new-pr` base branch** of
   `flathub/flathub`, titled **"Add org.epitaka.Epitaka"**.
4. Answer reviewer comments. Test builds can be started by commenting
   `bot, build`. **Do not close/reopen the PR** during review.
5. On approval, Flathub creates `flathub/org.epitaka.Epitaka` and invites you
   as a maintainer (accept within a week; 2FA required).

## 3. After approval — first publish + automatic updates

1. Push the same 4 files to the **master** branch of
   `flathub/org.epitaka.Epitaka`. Every merge/push to master triggers an
   **official build** that Flathub publishes automatically (usually within
   1–2 hours). No action needed for future releases.

2. **Automatic updates (zero maintenance):** the manifest already contains
   `x-checker-data` on the git source. Flathub's **External Data Checker**
   runs on every flathub repo every ~2 hours; when you push a new `v*` tag
   upstream it opens a PR bumping `tag` + `commit`. **Merge that PR** and the
   new version is built and published. Optionally enable automerge in
   `flathub.json` (`"automerge-flathubbot-prs": true`) — requires a linter
   exception request, and only after the app is verified.

### Optional: instant updates on tag push (skip if the 2 h checker is enough)

To publish ~immediately when you tag a release, instead of waiting for the
checker:

1. In this repo: `epitaka_app/.github/workflows/flathub-update.yml` already
   fires on `v*` tags and dispatches the flathub repo — it is guarded to only
   run once you add the secret. Add a PAT with **write access to
   `flathub/org.epitaka.Epitaka`** as the `FLATHUB_TRIGGER_TOKEN` secret
   (Settings → Secrets → Actions).
2. In the flathub repo, opt out of the global checker
   (`flathub.json`, next to the manifest):
   ```json
   { "disable-external-data-checker": true }
   ```
3. In the flathub repo, add `.github/workflows/update.yaml`:
   ```yaml
   name: Update on upstream tag
   on:
     repository_dispatch:
       types: [trigger-workflow]
   jobs:
     update:
       runs-on: ubuntu-latest
       if: github.repository_owner == 'flathub'
       steps:
         - uses: actions/checkout@v4
         - uses: docker://ghcr.io/flathub/flatpak-external-data-checker:latest
           env:
             GIT_AUTHOR_NAME: Flatpak External Data Checker
             GIT_COMMITTER_NAME: Flatpak External Data Checker
             GIT_AUTHOR_EMAIL: 41898282+github-actions[bot]@users.noreply.github.com
             GIT_COMMITTER_EMAIL: 41898282+github-actions[bot]@users.noreply.github.com
             EMAIL: 41898282+github-actions[bot]@users.noreply.github.com
             GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
           with:
             args: --update --never-fork org.epitaka.Epitaka.yml
         - uses: peter-evans/create-pull-request@v7
           with:
             branch: update-flatpak
             title: Update org.epitaka.Epitaka
             body: Automatic update from the external data checker.
             delete-branch: true
   ```

## Per-release checklist

1. Tag the release `vX.Y.Z` (this also triggers your existing
   `build_app.yml` AppImage/tar.gz builds — unchanged).
2. Add a `<release version="X.Y.Z" date="…">` entry to the metainfo (or the
   checker PR can carry it) — AppStream validation needs the latest version
   present.
3. Update the Flutter SDK module version in the manifest when Flutter stable
   advances (optional; keep in sync with your local SDK).
4. Merge the update PR in the flathub repo → Flathub publishes.

## Useful links

- Flathub submission docs: https://docs.flathub.org/docs/for-app-authors/submission
- Metainfo guidelines: https://docs.flathub.org/docs/for-app-authors/metainfo-guidelines
- App maintenance & updates: https://docs.flathub.org/docs/for-app-authors/maintenance
- Reference manifest (Flutter app on Flathub): https://github.com/flathub/app.towdow.TowDow
