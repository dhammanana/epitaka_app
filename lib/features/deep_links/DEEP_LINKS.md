# Deep links & shareable book links

## Link formats

The app copies shareable links in an **app-link** format. The website serves
the same content under its canonical **web** format. The two differ only in
the path prefix — everything after it is identical.

| Purpose | Format |
| --- | --- |
| Shareable app link (what the app copies) | `https://epitaka.org/app/{lang}/{bookId}/{heading-slug}#{paraId}-{lineId}` |
| Legacy app link (still handled, no slug) | `https://epitaka.org/app/{bookId}/{paraId}/{lineId}` |
| Website canonical URL | `https://epitaka.org/{lang}/book/{bookId}/{heading-slug}#{paraId}-{lineId}` |

Example:

```
https://epitaka.org/app/en/dn1/the-net-of-views-123#123-45
→ (web) https://epitaka.org/en/book/dn1/the-net-of-views-123#123-45
```

Where:

- `{lang}` — translation language the link was copied in (e.g. `en`, `vi`,
  `my`, `si`, `th`, `lo`).
- `{bookId}` — the book's stable id (e.g. `dn1`).
- `{heading-slug}` — the nearest section heading, lowercased with spaces
  turned into hyphens, suffixed with its `para_id` (the "heading-para_id"
  part), e.g. `the-net-of-views-123`. Optional — omitted when the reader has
  no heading for the position.
- `#paraId-lineId` — exact paragraph (and optional line) to open. The line
  part is optional (`#123` alone is valid).

## Behavior

- **Mobile with the app installed:** tapping an `/app/...` link opens the app
  (Android App Links / iOS Universal Links). Android verification is anchored
  on the `https://epitaka.org/app/` path prefix, so `/app/{lang}/…` links are
  covered too.
- **Plain browser (or no app):** the website rewrites `/app/...` to its
  canonical `/book/...` URL and shows the web reader at the same passage.

## Website redirect for `/app/...`

When a request comes in under `/app/`, rewrite the prefix and keep everything
after it untouched:

| Incoming | Outgoing |
| --- | --- |
| `/app/{lang}/{bookId}/{slug}` | `/{lang}/book/{bookId}/{slug}` |
| `/app/{lang}/{bookId}` | `/{lang}/book/{bookId}` |
| `/app/{bookId}/{paraId}/{lineId}` (legacy) | `/{lang}/book/{bookId}#{paraId}-{lineId}` (web picks `{lang}`) |
| `/app/reader/{bookId}` (legacy) | `/{lang}/book/{bookId}` |

**Important:** the URL fragment (`#paraId-lineId`) is never sent to the
server, and an HTTP redirect without a fragment drops it — which would lose
the exact passage. The rewrite must therefore be **client-side** (a JS/meta
redirect in the page served at `/app/...`, or the web app's router rewrites
the path in the browser) so `location.hash` is preserved. A server-side 301
is fine for the path part but the page that handles it must bounce the
browser to the `/book/...` URL including the original fragment.

The `/app/...` paths must keep being served (not 404) so that:

- Android App Links / iOS Universal Links verification
  (`/.well-known/assetlinks.json`, `/.well-known/apple-app-site-association`)
  keeps working, and
- browsers can run the client-side redirect above.
