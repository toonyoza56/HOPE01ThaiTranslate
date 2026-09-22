# HOPE 01 Thai translation mod

A separate project from the cheat plugin (`I:\HOPE01-CheatMod`). It doesn't touch the game folder
until you run `tools\install.ps1`.

## Translation rules
- **Not translated:** item names, room / place names, NPC names, upgrade names
- **Translated:** dialogue, dialogue choices, item / upgrade descriptions, signs, UI, tutorial
- Names mentioned inside translated text **stay in English** (the `keep_terms` column).
  A term with `?` is also an everyday word (e.g. `MAINTENANCE?`, `MILK?`): keep it in English
  only when it refers to the place / item in the game; otherwise translate it normally.

## Workflow

```powershell
powershell -ExecutionPolicy Bypass -File tools\serve.ps1     # dev server http://localhost:8787
```

1. **Extract** — `http://localhost:8787/tools/extract.html` → `work/strings.csv` (everything,
   with categories, translate yes/no, keep_terms, context), `work/glossary.csv`, `work/strings.json`
2. **Translate** — add rows to `translations/th.csv` (`id,category,english,thai,note`).
   Rows match on `category + english`, so they keep working even if ids shift after a game update.
   A newline in the text is written as `\n`.
3. **Build** — `http://localhost:8787/tools/build.html` → `build/www/` (data.json, scripts/c3main.js,
   images/thai-font-*.png). The build report is `work/build-report.txt`; it warns when a
   `keep_terms` word is missing from the Thai text.
4. **Test in a browser** — `http://localhost:8787/play/index.html` runs the real game with the
   patched build (separate save in the browser). `tools/preview.html` shows dialogue / item text at 1080p.
   `tools/capture.js` takes full-resolution screenshots from the WebGL buffer.
5. **Install into the game** — `powershell -ExecutionPolicy Bypass -File tools\install.ps1`
   (the first run backs up the originals to `backup/original/`) · undo with `tools\uninstall.ps1`.

## How Thai is displayed (technical)
- Almost all text in the game is **SpriteFont** (bitmap fonts, 47 types). There is no localization system.
- **Word breaks:** Construct wraps at whitespace, and `U+200B` counts as whitespace, so
  `Intl.Segmenter('th')` is used to insert `U+200B` between Thai words (0 width in the font).
- **Vowels / tone marks:** SpriteFont draws one cell per character, so each grapheme cluster that
  has marks (e.g. `ที่`, `น้ำ`) becomes one glyph mapped to a Private Use Area code point (`U+E000+`).
- **Font sheets:** the original English glyphs are copied at K× (K=3 for 7px fonts, 2 for 16px
  fonts) + Thai glyphs rendered from Tahoma at 1-bit, and the SpriteFont `scale` is divided by K
  → English looks the same as before; Thai gets K× the pixels (the same approach the developers
  used for their Japanese test font: 16px @ scale 0.5).
- The original `character spacing` is folded into the glyph widths (otherwise Thai glyphs overlap).
- SpriteFont boxes get taller (headroom 2.4×) because objects with effects (ScanLines) clip text inside the box.
  The main menu buttons are widened 1.8× (`WIDEN`).
- Tuning knobs: `build.html?size=1.6&line=1.35` (Thai size vs. English cap height, line spacing).

## Files
```
tools/serve.ps1       dev server (/game = original game, read-only · /play = build over the game · POST /work, /build)
tools/extract.html    extract text + glossary
tools/build.html      put translations in + build font sheets
tools/preview.html    SpriteFont text preview at 1080p
tools/capture.js      full-resolution screenshot from the game in /play
tools/install.ps1     install into the game (with backup) · tools/uninstall.ps1
translations/th.csv   Thai translations (source of truth)
work/                 generated files (strings.csv, glossary.csv, strings.json, report, screenshots)
build/www/            build output (scripts/main.js there is for browser testing only — never installed)
```

## Making a release (for GitHub)
1. Bump `VERSION.txt`.
2. `powershell -ExecutionPolicy Bypass -File tools\make-release.ps1` → `release/HOPE01-Thai-v<version>.zip`
   (translations, the bitsy font, the build pages and `installer/` - no game files).
3. Upload the zip to a new GitHub release.

The player installer (`installer/install.ps1`) builds on the player's PC: it backs up the original
files to `<game>\thai-mod-backup`, runs `tools/extract.html` and `tools/build.html` in headless
Microsoft Edge against a tiny local server (`installer/server.ps1`, TcpListener - no admin), refuses
to install if the save/load hooks can't be placed (unsupported game version), then copies the result.
Translations are the `translations/th-*.csv` files (merged in name order; a later file wins).