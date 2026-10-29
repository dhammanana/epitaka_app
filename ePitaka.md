# Add Your App — ePitaka answers

## The Basics

### App Name

**ePitaka** (styled "ePitaka" — no short nickname in common use yet).

### One-Line Summary

A free, offline Tipiṭaka reader for desktop and mobile that shows full DPD definitions for any word you tap, with sentence-level Pāḷi and translations side by side in over 20 languages, and AI study tools for asking questions about what you read.

### Who Makes It

Developed and maintained by **dhammañāṇa** (GitHub user `dhammanana`). (Location not stated — to be filled in by the developer.)

### Website

https://epitaka.org (the site also hosts the online reader the app's deep links open into).

### Docs or Help Site

Help lives inside the app: a Settings → Help screen and an in-app Feature Guide (with a startup wizard for new users). No separate docs site yet.

### Source Code

https://github.com/dhammanana/epitaka_app

Open source, licence **CC-BY-NC-4.0** (see LICENSE in the repo).

### Cost

Completely free. No paid version, no in-app purchases, no ads. The AI features (Vīmaṃsā Q&A, Gavesanā search, Translation Builder) use your own API key by default (Gemini/OpenAI/Claude/DeepSeek/OpenRouter), and there is a built-in default provider so basic Q&A works out of the box.

### Contact

Email **epitaka.org@gmail.com** (there is an in-app feedback tile that opens it with details attached).

### Bug Reports

https://github.com/dhammanana/epitaka_app/issues — or the in-app Help/feedback screen (email), plus Google Forms reachable from inside DPD entries for dictionary correction reports.

---

## Platforms and Install

### Platforms

- **Windows** — MSIX for the Microsoft Store, plus an NSIS installer from GitHub releases.
- **macOS** — DMG from GitHub releases.
- **Linux** — .deb, AppImage, and Flatpak on Flathub: https://flathub.org/apps/org.epitaka.Epitaka
- **iPhone / iPad** — distributed as an .ipa (store distribution to be confirmed by the developer).
- **Android** — .apk/.aab from GitHub releases and the Play Store (store link to be confirmed).
- **Other** — online reader at https://epitaka.org (the companion website, separate codebase from this repo).

### Store Links

- Microsoft Store: https://apps.microsoft.com/detail/9nr3sjfr6cf9
- Mac App Store: not listed
- Apple App Store: (link — to be filled in)
- Google Play Store: https://play.google.com/store/apps/details?id=com.dn.epitaka
- F-Droid: not listed
- Flatpak **(Flathub): https://flathub.org/apps/org.epitaka.Epitaka**
- Chrome/Firefox/Edge Add-ons: not applicable
- **GitHub releases page: https://github.com/dhammanana/epitaka_app/releases** (all installers + every translation/dictionary database)
- Direct download: same as the GitHub releases page.

### Install Instructions

Everything the app needs to work is downloaded in-app on first run, so installation is just installing the package for your platform — installers are on the GitHub releases page for platforms without a store.

1. **Windows** — download the installer from GitHub releases (Microsoft Store build is distributed through the Store itself), run it, and follow the usual Windows prompts.
2. **macOS** — download the .dmg, drag ePitaka to Applications.
3. **Linux** — either `flatpak install flathub org.epitaka.Epitaka` from Flathub, install the .deb with your package manager, or download and run the AppImage.
4. **Android** — download and open the .apk from GitHub releases (allow installing from unknown sources if you do this outside a store), or get it from the Play Store.
5. **iPhone / iPad** — install the .ipa per the developer's instructions.

No dependencies to install yourself: SQLite, all fonts, and rendering libraries are bundled. On first start a **setup wizard** walks you through the compulsory downloads listed under *Offline Use* below — this is the "separate data download" the template asks about, and it is large (roughly 1 GB in total if you include the optional semantic-search model).

### Offline Use

Yes — the app is designed for offline use. On first start the wizard guides you through:

1. **epitaka.db** — the main Pāḷi Tipiṭaka with the reading index (about 139 MB zip → ~500 MB installed). Compulsory.
2. **English translation** — doubles as the corpus for the AI Q&A. Compulsory.
3. **DPD Pāḷi Dictionary** (`dpd-mobile.db`, about 210 MB). Compulsory.
4. **Embeddings model** (optional, about 409 MB) — enables semantic search for Gavesanā.

After that the app runs with no internet connection (downloads with checksum verification, resumable). Additional translation databases for other languages are downloaded from the app's own manifest, and the Translation Builder can produce new ones entirely offline.

### Updates

- **Store builds** (Microsoft Store, Flathub, Play Store) update through the store.
- **Side-loaded desktop builds** check the GitHub releases page on launch and show a dismissible notice with a button that opens the release page in your browser.
- On Android/iOS, updates follow the store/release channel you installed from.
- Translation databases, DPD, and change notes ("What's New") update through the app itself — see *Getting the Latest DPD*.

---

## About the App

### What Does It Do?

ePitaka is a reader for the Pāḷi Canon that puts everything one step away from the text. You pick a book from a library tree, open it in a paragraph-based reading view with sentence-level Pāḷi and translation lines, and tap any Pāḷi word to get the full Digital Pāḷi Dictionary entry in a side panel (desktop) or a bottom sheet (phone). On your first day you can read the Tipiṭaka in your language, look up every word it contains, search across all books (full-text, fuzzy, or regex), bookmark and highlight passages, have the app read the text aloud with word-sync highlighting, and jump straight to any sutta by code ("MN10", "AN1.5"). Beyond that it is an AI study station: ask questions about what you are reading (Vīmaṃsā), describe what you are looking for and let it search the Canon (Gavesanā), or build a brand-new translation into your language (Translation Builder).

### Who Is It For?

Pāḷi students at every level will use DPD through the tap-to-lookup flow; meditators reading suttas in their own language benefit from the parallel translations; teachers and translators get the ~40-language parallel texts, commentaries and translations, the Translation Builder, and a local MCP server so they can use the Tipiṭaka with Claude Desktop and other tools; monastics and students of multiple traditions benefit from the multi-script support (Pāḷi in Saṅgha-tradition scripts such as Myanmar, Thai, Tai Tham, Lao, Khmer, Sinhala, Devanagari, Tibetan, Brahmi, Tamil, and Chakma).

### Main Features

- Full Chaṭṭha Saṅgāyana Tipiṭaka, paragraph-based reading view
- Sentence-level parallel Pāḷi and translation lines
- Full DPD on tap of any word (with the deconstructor, grammar dictionary, inflection tables, roots, frequency, sutta examples and per-word audio)
- Full-text (FTS5), fuzzy and regex search over Pāḷi and translations
- Pāḷi displayed in ~18 scripts, with instant script conversion
- Reading annotations: highlights, notes, bookmarks, with cloud sync (Google sign-in)
- TTS read-aloud with word-sync highlighting
- AI Q&A with citations (Vīmaṃsā), AI search over local books (Gavesanā)
- Translation Builder — create a new translation database in your language entirely on-device
- MCP server — expose the Tipiṭaka to Claude Desktop/other MCP clients over the network
- "Go to sutta" — jump by sutta code (MN10, AN1.5, THI28…)
- External .mdx/.mdd dictionary import
- Deep links (epitaka://) and universal links to the website's reader pages
- Startup wizard, in-app Feature Guide, "What's New" per release

### Texts and Content

- **Full Chaṭṭha Saṅgāyana Tipiṭaka** (main `epitaka.db`, built with the project's own tooling) including commentaries.
- **Translations in 21 language packages**, downloaded from the app's live manifest: English, Sinhala, Thai, Myanmar (including **Myanmar Nissaya**), Lao, Tamil, Vietnamese, German, Portuguese, Japanese, Khmer, Russian, Chinese, Hindi, Indonesian, Korean, Nepali, Bengali, Spanish, French. Built with the on-device Translation Builder (default Gemini).
- **DPD** as a full "mobile" database (see *How DPD Is Used*), plus the ability to import external MDX dictionaries.
- Study-guide summaries and book outlines (bundled or fetched from the website's `epitaka.org` API fallback again).

### Languages

- **Interface:** English, Vietnamese, Myanmar, Sinhala, Lao, Thai.
- **Pāḷi scripts:** Roman, Sinhala, Devanagari, Thai, Lao, Myanmar (Pyidaungsu), Khmer, Bengali, Gurmukhi, Gujarati, Tai Tham, Telugu, Kannada, Malayalam, Brahmi, Tibetan, Cyrillic, Tamil (instant conversion of any text), with all required fonts bundled (including Tibetan on iOS, which has no system font for it).

### Similar Apps

Dhamma.gift website, Simsapa Dhamma Reader, Sutta Central website, Tipiṭaka Pāḷi Reader, Tipitakapali.org, the Budun DྷV/Tipitaka apps with parallel readings (all use DPD in some form).

### What Sets It Apart?

- **Everything is one tap from a word, and everything is offline** — reader, DPD, translations, search index, audio and the AI's own source passages all live locally; no network needed between queries.
- **Sentence-level parallel reading in ~40+ languages** — plus Myanmar Nissaya shown simultaneously with Myanmar as a separate reading line.
- **Pāḷi in ~18 scripts**, instantly converted, centred on the Saṅgha scripts many other readers lack (Tai Tham, Lao Pāḷi, Brahmi, Chakma, Tamil conversion, Tibetan for iOS).
- **AI that works on your local copy of the Canon** — Vīmaṃsā finds its citations in your own libraries before answering; an "Orthodox" mode restricts answers to the passages it found. Answers carry clickable [book:para:line] citations into your reading view.
- **Gavesanā AI search** — describe what you are looking for in plain language and get multiple multi-step searches across the Tipiṭaka, with standard search and index build fully offline.
- **The Translation Builder** — no other reader app lets users create an entirely new translation database into their own language, with an editor UI, entirely within the app; ePitaka's website's translation packages are the same format the app itself makes.

### Other Features Worth Knowing

- **Vīmaṃsā (AI Q&A):** re-generate answers, edit questions, interrupt mid-answer, pinned/renamed chat history (UI polish for pinning/renaming in desktop view is still planned; see docs/Features.md).
- **Gavesanā:** up to 10 tool-call rounds / 60 passages per search.
- **MCP server:** settings tile with optional autostart; brings the app's search/section/dictionary/commentary tools to Claude Desktop, Cherry Studio, LibreChat etc. Local network access (server binds to LAN) should be trusted only on networks you know.
- **TTS read-aloud** with word sync; no special warning beyond the usual on-device voice availability.
- **AI warnings:** the "Orthodox" toggle states clearly that when it is on, answers are "strictly limited to passages found in the Tipiṭaka" but that the AI may still make mistakes — read it as a study aid, not a scripture; users with API keys should keep them private (the app scrubbing of keys from logs is built in).
- **DPD per-word audio** (male/female) streams from dpdict.net — that one feature is online-only.
- **Cloud sync of annotations** requires a Google sign-in; without signing in, annotations still work locally.

---

## How DPD Is Used

### Which Version of DPD?

The **full DPD mobile database** (`dpd-mobile.db`, the `dpd-mobile-db.zip` asset from the DPD repository's releases) — used *natively*, not via the web: the app opens the DPD SQLite database directly with the app's own local schema. It is also offered as an **optional slim `dpd-dictionary`** file for users who do not need the full text, and the DPD **deconstructor**, **grammar dictionary**, and **abbreviation/EPD** data ship as part of the same native database (parsed from the lookup table, not fetched separately).

### Which Parts of DPD?

- Meanings, literal meaning, grammar, construction, compound type and construction breakdown
- Roots (Dhatupatha/Dhatumanjusa/Dhatumala entries with a **root-matrix table**) and root "families"
- Full **inflection tables** (pre-built from DPD's templates, generated natively by the app)
- Word/compound/idiom/set **families** (derived natively by the app at export time)
- **Frequency** with a corpus legend
- **Sutta info** (DPD/CST/SuttaCentral/BJT/DPR references) and **sutta examples**
- Deconstructor, grammar-dictionary notes, abbreviations, external (EPD) entries
- Per-word **audio pronunciation** (male/female voices)
- The summary card shown in "Brief" mode with tap-to-lookup inside the summary itself

### Looking Up a Word

- **Tap a word in the reader** (desktop: side dictionary panel; phone: bottom sheet). Double-tap/tap behaviour is configurable (Settings → Reader). The panel shows the DPD entry with the DPD logo, meaning line, grammar/construction, and buttons at each level to expand inflection tables, examples, roots, frequency, families — plus a speaker button for audio and a feedback link.
- **Type into the dictionary panel's search box**: tiered suggestions, closest matches, and "partial"/"fuzzy" result sections you can enable.
- The dictionary icon row in the header lets you switch between DPD and any imported external dictionaries; back/forward history with saved chips shares history across panels (and Alt+R/other shortcuts on desktop).
- If DPD cannot split a word, the **deconstructor** output for that word is shown instead; unknown words fall through to short "MC-like" nearest headwords.

### Turning DPD On

DPD is **on by default**, and downloaded during the startup wizard (compulsory item step 3 of the wizard). If a user skipped it there, they can also pick it back up in Settings → Dictionaries → "DPD Pāḷi Dictionary" → Download. (Screenshots to be made by the developer — see Screenshots.)

1. Open ePitaka → the startup wizard runs on first start.
2. The wizard lists the compulsory downloads: Tipiṭaka DB, English, **DPD Pāḷi Dictionary**.
3. Tap **Download**; the size and SHA-256-verified file install and the app opens.

### Dictionary Settings and Modes

- **Three detail levels** — Saṅkhitta (Brief) / **Majjhima (Standard, default)** / Vitthāra (Full) — full DPD, partial or expanded.
- **Ordered dictionary list** (drag to reorder), external dictionaries grouped into their own tiers under "Other Dictionaries".
- **Search suggestions**: partial results on/off; fuzzy results on/off (each shows under its own heading).
- **Text size** and **panel reopen behaviour** (remember last search or always reset).
- **Audio**: male/female voice selection.
- **Validation options**: show summary, show construction in the summary line at Saṅkhitta level, click-through on summary lines, sandhi display in examples, one button open at a time vs many (setting names as implemented; exact menu labels differ slightly per language).

### Getting the Latest DPD

**Automatically, when DPD releases** — the app checks the DPD repository's own releases (`digitalpalidictionary/dpd-db`, `dpd-mobile-db.zip` asset, pre-releases included) **once every 24 hours at launch**, shows a notice with the new version and size, and offers the download. The DPD settings page has a "Check now" button for a manual check. The download is verified by SHA-256 from the release asset's digest and can resume after a break; a locally picked `.zip` file can also be imported instead of downloading. ePitaka rejects a DPD release whose schema it cannot read and asks the user to update the app first, so a DPD update can never land before the app can open it. There is no separate beta from the regular check (pre-releases are already included, same policy as the DPD app itself).

### DPD in Other Languages

Not at present — DPD is used in its original English only.

---

## Screenshots

(To be made by the developer. One screenshot already exists for the reader: `docs/epitaka-screenshot.png`. The pairs to produce: `main_light.png` / `main_dark.png`, `lookup_light.png` / `lookup_dark.png`, plus wizard/DPD-download steps and a "Check now" screen — crop to the dictionary panel and reader with a real word lookup, e.g. a sutta in Majjhima Nikāya.)

---

## Anything Else

### Work in Progress

The app is actively developed (1.1.11 at time of writing). Recent work is documented in the in-app "What's New" and the changelog in the repo. Known loose ends: the Vīmaṃsā question/pin/history UI polish listed in `docs/Features.md`; iOS/store distribution links in this doc need confirming; DPD works fully offline in this app, but the per-word pronunciation audio is the one element that needs any site/network.

### Coming Soon

- Vīmaṃsā improvements in `docs/Features.md`: re-generate an answer, edit the question before/while it runs, interrupt mid-answer, pin + rename chat history in a cleaner desktop layout.
- The semantic-search pipeline behind Gavesanā will keep improving as more languages are indexed.
- The Translation Builder keeps adding languages as translations complete, and the website shares them with every user.

### Anything We Missed

- The local MCP server turns ePitaka into a Tipiṭaka "tool source" for any MCP client, which most Pāḷi readers have no equivalent for.
- Deep-link/sutta-code integration: the site at epitaka.org and the app share URLs (`epitaka://` and `https://epitaka.org/app/...` links).
- ePitaka's website itself (epitaka.org) provides online reading of the same texts — this doc concerns the native app in this repo.
