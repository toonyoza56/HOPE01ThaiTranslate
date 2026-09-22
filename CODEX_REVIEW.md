# HOPE 01 Thai mod: work summary and review brief (for Codex)

**Written:** 2026-09-22.
**Purpose:** a handoff so you can review, fix and extend this project without the chat history.
README.md covers the basics and KNOWN_ISSUES.md the bug history. This file is the full current state,
the decisions behind it, and what is fragile or unverified.

---

## 0. UPDATE 2026-09-22 (evening), read this first: fonts reworked after the Codex pass

The Codex pass produced `fonts/Thai_7x7.bitsyfont` and `fonts/Thai_4x5.bitsyfont`
(`tools/make-thai-*-font.mjs`) by **resizing** the bitsy glyphs, and used line 12 for item/hint text.
In the real game both were unreadable. **They are no longer used; please don't go back to them.** Why:

1. **Pixel fonts can't be scaled by a ratio.** Nearest-neighbour resizing merges strokes and closes counters.
   - To make glyphs taller, `loadBitsy(url, grow)` now **duplicates one row in a straight stem**:
     a row equal to its neighbour, else a row made only of vertical strokes.
   - Shapes stay intact. ก goes from 6 to 7 rows, still a ก.
2. **Line advance must be ≥ glyph cell height. This is an engine limit, not a tuning choice.**
   - Measured in game:
     - The SpriteFont renderer draws lines bottom-to-top.
     - Each glyph quad (including its transparent part) hides whatever was drawn earlier under it.
   - Result: with line < cell, the upper line hides the next line's tone marks.
     - Controlled test: line-1 `กุ`s survive, line-2 `ก่` marks vanish except under line-1 spaces.
     - Effects/blend mode are not the cause.
   - So "compact line 12" = missing tone marks.
3. **Current setup** (`FONT_TUNING` in build.html; all fonts are `Thai_nuttatulipa`, 1 font px = 1 game px):

| Box | Body | Marks | Cell / line | Box | Result |
|---|---|---|---|---|---|
| dialogue `ui_dialogue_textframe_text` | 7 (grow 1) | normal | 17 / 17 | 236×62, moveDown 3 | ≤3 lines, all fit |
| choices 1-4 | 6 | normal | 16 / 16 | 16 tall (HEIGHT_CAP) | 1 line each, all fit |
| item title / description, hint, ending | 6 | **tight** (tone on the vowel, lower vowel under the body) | 14 / 14 | description fixed 232 tall (`HEIGHT_FIXED`, down to the screen bottom) | ≤16 lines, all fit |

4. **Item descriptions** use English lines 7 px apart; Thai needs 14. What makes them fit:
   - blank lines are dropped (Thai `item_desc` only; the `---` lines stay);
   - the box grows down to the screen bottom (a small overflow of the panel, which the user accepts);
   - 13 long texts are shortened in `translations/th-016.csv`.
   - The build writes `work/too-long.csv` (id, box, lines, max_lines) whenever something doesn't fit.
5. **Other fixes in this pass:**
   - **Wrap check** now ignores `[color=…]` tags (the old count overstated item descriptions a lot).
   - **Space width:** fonts without a space in their spacing data get the original default advance.
     Before, a space was a full 16 px cell and English words in item descriptions were spread apart.
   - **Save hook for instance variables** (`patchInstanceVars`):
     - Items saved before the mod came back with English descriptions, because instance variables
       are stored in the save.
     - Load maps English→Thai (exact match; 1,024 strings, not dialogue/options). Save maps it back,
       so saves stay valid without the mod.
   - **extract.html bug:** its all-caps test counted the lowercase `[color=rgb(...)]` letters, so every
     short text with a colour tag was skipped. That was 47 magazines, the tutorial prompts with key
     names, and more.
     - Fixed; the 169 newly found strings are translated in `translations/th-017.csv` (magazines
       generated from one template).
   - **extract.html** now refuses to run when the Thai build is installed (same guard as build.html).
     Running it against the Thai data had silently produced a wrong strings.json.
   - **import-batch.ps1** keeps the English leading/trailing spaces. Script fragments like
     `" OR TAB[/color]"` are concatenated with key names at runtime.
6. **Item description scrolls (user request)** instead of spilling over the weapon slots:
   - The box is the panel's inner area again: `HEIGHT_FIXED` 176 = 12 lines. The engine doesn't draw
     lines below the box, which acts as the mask.
   - `scrollRuntime()` appends code to c3main.js (`runOnStartup` + `tick`):
     - When the game sets a new text, it word-wraps it with the font's glyph widths and shows 12 lines
       from the scroll position.
     - `[color]` tags spanning a cut are closed/reopened.
     - Keys: ArrowUp/Down, PageUp/Down, or the mouse wheel over the box (captured only while the box
       is visible and overflowing).
     - A 2px scrollbar is drawn in a DOM overlay over the canvas.
   - Verified in game: `tools/ingame/scroll-test.ps1`, or the manual long-text test (see chat log).
   - The game doesn't reset the text every tick, so scrolling holds.
   - **Gamepad:** right stick up/down (standard mapping axis 3, dead zone 0.5; one line per 150 ms,
     80 ms when fully pushed). Tested in game with a faked `navigator.getGamepads`, not with a real pad.
   - Minified names used: `runtime.QH`, `cls.BV()`.
7. **Verified in the real game** (`tools/ingame/dialogue-test.ps1`, `choice-test.ps1`, new
   `item-test.ps1`; the last one opens the inventory with B and hovers 4 slots):
   - dialogue, choices and item descriptions display correctly with the user's save.
   - **Not checked in game:** `hint_text` and `ending_text`.

---

## 1. What this project is

- **Game:** HOPE 01 (Steam app 4562940). It is a Construct 3 export in DOM mode running inside a
  WebView2 wrapper (`Hope 01.exe`).
- **Game files:** `I:\SteamLibrary\steamapps\common\HOPE 01\www\`:
  - `data.json`: project data, 13 MB
  - `scripts/c3main.js`: engine + expression table, minified
  - `images/`
- **The mod:** Thai translation. The project lives outside the game in `I:\HOPE01-ThaiMod\`, so Steam
  "Verify integrity" cannot delete it.
- **What gets installed:** a patched `data.json`, a patched `c3main.js` and `images/thai-font-*.png`.
- **Separate project:** a cheat plugin in `I:\HOPE01-CheatMod\` adds `scripts/hope_cheat.js` to
  `index.html`. The in-game tests use it (`HopeCheat.runtime`).

### Translation rules (from the user)

- **Keep in English:** item names, room/place names, NPC names, upgrade names. This includes when they
  appear inside a Thai sentence (the `keep_terms` column).
- **Translate:** dialogue, choices, descriptions, signs, tutorial/script text.
  - UI words are skipped for now, by the user's choice.
- **Speaker gender:** known gender uses the matching pronouns; unknown uses neutral wording. No
  ครับ/ค่ะ particles. See `translations/STYLE.md` for the speaker table.

### Translation status

| Category | Status |
|---|---|
| dialogue (1,442) + option (346) | translated (th-002..010) |
| sign (34), upgrade_desc (34) | translated (th-011) |
| item_desc (246) | **not translated** |
| script (546) | **not translated** (tutorial texts, c3main literals) |
| ui (52) | skipped for now |

- `translations/th-012.csv` overrides earlier files. It holds shortened versions of 2 dialogue lines
  and 3 choices, so they fit the pixel-font boxes.
- **Update needed:** the translation files are `translations/th-001..012.csv`, merged in name order.
  A later file wins, matched on `category|english`. README still says `th.csv`.

---

## 2. Pipeline

```powershell
powershell -ExecutionPolicy Bypass -File tools\serve.ps1          # http://localhost:8787 (the only port the Claude in-app browser may use)
powershell -ExecutionPolicy Bypass -File tools\uninstall.ps1      # REQUIRED before building: build reads /game/ = the live game folder
# open http://localhost:8787/tools/extract.html#auto   -> work/strings.csv, strings.json, glossary.csv
# open http://localhost:8787/tools/build.html#auto     -> build/www/*, work/build-report.txt (log on the page)
powershell -ExecutionPolicy Bypass -File tools\install.ps1        # copies build/www into the game (backs up originals first)
```

- **Build safety check:** `build.html` refuses to run if the game folder already has the Thai build
  installed. It detects `thai-font-` in the type image paths.
- **Backups:**
  - `backup/original/` holds the originals of the **current** game version.
  - `backup/original-2026-09-22-old/` holds the version before the Steam update that happened mid-session.
  - `install.ps1` refuses if the game file hash differs from the backup, which means the game was updated.
    In that case: re-extract, re-build, and replace the backup.
- **Browser test:** `/play/` runs the game in the browser. It only reproduces a **new game**. Anything
  involving the player's save needs the real game (section 6).

### Files

```
tools/build.html          ~700 lines, all build logic (fonts, patches, save/load hook, checks)
tools/extract.html        text extraction + categories + glossary
tools/lib.js              HM.save / HM.saveBuild / CSV helpers
tools/serve.ps1           dev server (/game read-only, /play = build over game, POST /work /build)
tools/import-batch.ps1    translations/src/th-XXX.txt (id|thai) -> CSV with checks
tools/install.ps1, uninstall.ps1
tools/ingame/             real-game test harness (CDP), see section 6
fonts/Thai_nuttatulipa.bitsyfont   Thai pixel font supplied by the user (bitsy format)
translations/th-0XX.csv, translations/src/*.txt, translations/STYLE.md
KNOWN_ISSUES.md           bug history + fixes
```

---

## 3. How Thai is rendered (build.html)

All game text is Construct **SpriteFont** (bitmap font). There is no localization system.

1. **Word breaks.** `Intl.Segmenter('th', word)` inserts U+200B between Thai words. Construct wraps at
   whitespace, and U+200B counts as whitespace. It is drawn with width 0.
2. **Grapheme clusters.** A Thai cluster with marks (e.g. `ที่`) becomes one glyph at a PUA code point
   (U+E000+). Single Thai characters keep their own code point.
3. **Font sheets.** There is one new sheet per distinct original font (38 sheets):
   - The original English glyphs are upscaled K× (K=3 when the cell is ≤8px, else 2), and the instance
     `scale` is divided by K, so English looks unchanged.
   - Original `characterSpacing` is folded into the widths and set to 0.
   - Fill and outline colours are sampled from the original font.
4. **Thai glyph sources:**
   - **Default: Tahoma, 1-bit**, at `THAI_SIZE` (1.6 × English cap height).
   - **Dialogue box + the 4 dialogue choices: the bitsy pixel font** (`FONT_TUNING`).
     - 1 font px = 1 game px (px=3 sheet px, final scale 1/3).
     - Marks are placed tighter than the font file does (`bitsyRowShift`):
       - upper vowels/tones move 2 rows down;
       - a tone with no upper vowel moves 4 rows down;
       - ์ is placed like a tone;
       - lower vowels move 2 rows up;
       - the circle of ำ moves 2 rows down;
       - over ป ฝ ฟ ฬ, marks move 2 px left.
     - Cell height 16 px, line 16 px.
     - `?dfont=tahoma` switches back to the anti-aliased Tahoma dialogue font (size 2.0).
   - **bitsy format:**
     - `CHAR <cp>` starts a glyph;
     - `CHAR_SIZE w h` gives the advance `w`;
     - `CHAR_OFFSET x y` is in **half pixels** (bitsy draws at 2×), so it is divided by 2;
     - `CHAR_SPACING n` is an advance that overrides `w`;
     - after these come the 0/1 pixel rows.
5. **Instance patches**, per instance of each patched type:
   - cell size, charset and spacing data;
   - `scale/K`;
   - line height;
   - the box grows by `(lineH − ch)·scale + 2`, where `lineH = max(cell/K, ch·1.35)·2.4`. The box is
     then moved by its valign so the text stays in place.
   - `HEIGHT_CAP` limits the box height for:
     - menu buttons: 24;
     - dialogue choices: 16;
     - dialogue text: 62.
   - `WIDEN` makes the menu buttons 1.8× wider.
   - `moveDown`: dialogue text 3 px.
6. **Event patch (`patchScaleActions`).** Event actions `Set scale` (ACE index **62**) on patched
   SpriteFonts get their constant divided by K:
   - This covers the title menu hover (1.1 → 0.55 and 1 → 0.5).
   - The new constants are appended to the expression table `self.rwt=[...]` in c3main.js
     (`parseExprTable` bracket-matches it; 4158 entries in the current game version).
7. **Savegame hook (`patchSaveLoad`)**, the most important runtime patch:
   - **Why it's needed:** the save stores SpriteFont state `{cw, ch, cs, sd, csc, lh, …}` and the box
     (x/y/w/h). Loading a save made before the mod put the English settings onto the new sheet, so no
     Thai showed.
   - **How it's wired:** the build replaces the exact string `SAVE_HOOK_FIND` in c3main.js. SpriteFont
     `xI` (save) and `yI` (load) then call `self.__thaiSave` and `self.__thaiLoad`, which are appended
     at the end of c3main.js.
   - **Load:**
     - A patched font keeps the new sheet settings.
     - `csc /= K` and `lh += lhx`.
     - The box is regrown with the current build's rules:
       - An original save has no `thai` mark.
       - A mod save has `thai:1` + `gd` (box growth), which is undone first.
       - An older mod save has `thai` without `gd`. Its box is reset to the type's original height
         around the same centre.
   - **Save:** patched fonts are written in the **original** font's units + `thai:1` + `gd`. That way
     the save still loads after uninstalling the mod. Only the box stays a bit taller, which is cosmetic.
   - **Font lookup:** by object type name, `sdk.pZ().iq().Bf()`. Several types share identical new
     settings but have different originals.
   - **Debug:** `self.__thaiConverted` counts fonts converted on load. The user's save gives 176.
8. **Checks.** `checkWrap` simulates word wrap for all dialogue (dialogue box: 3 lines max) and all
   options (1 line). It warns about text that would be cut off. Current result: 0 too long.

### Minified engine names used (c3main.js of this build, checked 2026-09-22 after the Steam update)

| Name | Meaning |
|---|---|
| `inst.RLt.b8t()` | SpriteFont font settings: `X8t` cw, `Z8t` ch, `Q8t` charset, `t6t` spacing data |
| `inst.uW()` | world info: `cI` y, `pI(y)`, `dT` height, `Qg(h)`, `Jj` originY, `Cj` bbox changed |
| `inst.pZ().iq().Bf()` | instance → object class → name |
| `SAVE_HOOK_FIND` | exact text of the SpriteFont save→load boundary |
| ACE 62 | SpriteFont Set scale (61 = set effect param, 247 = set color, 246 = typewriter, 234 = set text) |
| `self.rwt` | expression table (index = `[0,[i]]` params in data.json) |
| `runtime.AU(name, ...args)` | call a Construct function (used by the tests) |
| `runtime.QH` | `runtime.objects` (keys mangled; index by `cls.name`) · `cls.BV()` = getAllInstances |

**If the game updates its engine, all of these can change.** The build warns if `SAVE_HOOK_FIND` or
`self.rwt` are not found. The runtime hooks catch exceptions and fall back to the unmodified data.

---

## 4. In-game findings (verified in the real game, not just the browser)

These are empirical rules. Please don't "simplify" them away.

1. **Box overlap hides text.** If a glyph cell is taller than the line advance, the next line's pixels
   that fall inside the previous line's glyph quads are **not drawn**. That is how marks disappeared.
   - The engine's draw loop (`#e` in the text renderer) does not clip per line, so the root cause is
     **not understood**.
   - **Rule: cell height ≤ line advance.**
2. **Pixel fonts need whole game pixels.** Drawing at 2/3 game px (px=2) was garbled. The game renders
   the UI at low resolution.
3. **Stacked mouse targets must not overlap.** Menu buttons are 32 apart and choices 16 apart. With
   overlapping boxes, two items highlighted at once and a click could hit the wrong one. Hence `HEIGHT_CAP`.
4. **Menu hover.** The original game scales the menu text to 1.1× on hover. That is intended. The user
   asked "only colour"; the current build keeps the original 10% growth. **Open question for the user.**
5. **Old saves.** Only the real game shows old-save problems. `/play/` always starts a new game.
6. **The dialogue text box** is `ui_dialogue_textframe_text` (236×62 after patch). The frame is the Sprite
   `ui_dialogue_textframe` (315×60, at y 50..110). Text is set with the SpriteFont typewriter
   (ACE 246), inside the function `DialogueShow(text, profile)`. Choices come from `DialogueBoxChoices(o1..o4)`.

---

## 5. Review checklist: known weak spots, please check or fix

- [ ] **Wrap simulation vs engine.** `checkWrap` approximates Construct's word wrap (greedy, whitespace +
      U+200B). It has only been spot-checked in game (longest lines).
      - Consider verifying against the engine directly: set the text on the instance in `/play/` and read
        its line count or text height (getter `b1` looked like text height).
- [ ] **Capacity formula.** `floor((boxH − cell·scale)/advance)+1` has been right so far. With the old
      56 px box it predicted 3 lines where the game showed 2.
- [ ] **`extraLineHeight` units.**
      - Tuned fonts: `lh = target − cell/K − lh0`, where `lh0` comes from the **first instance only**.
      - Non-tuned fonts add `ch·1.35 − cell/K` to each instance's own lh.
      - Check that no type has instances with different `lh0` (the build checks cw/ch/charset/spacing/scale
        uniformity, but not lh).
- [ ] **`noGd` branch** in `__thaiLoad`: it resets to the type's original height around the old centre.
      That is an approximation for moving objects. It only affects saves written by builds from before
      `gd` existed (the user's test save).
- [ ] **Uninstalled game + mod save.** Box heights stay grown. `gd` could also be used to shrink them back
      if saving could write world state. It can't from the SpriteFont hook.
- [ ] **ItemInfo family** has mixed font patches, so its Set-scale actions are skipped. There are none
      today (warning only).
- [ ] **REGENERATION** keep-term missing in upgrade_desc.1911/1913 (build warning). Check the Thai text.
- [ ] **`self.BUILD_DEBUG`** in build.html is debug-only (harmless, build page only).
- [ ] **README** is outdated: `th.csv` → `th-0XX.csv`, and it doesn't mention bitsy / FONT_TUNING /
      the save hook / HEIGHT_CAP. Update it from this file.
- [ ] **Font licence.** `Thai_nuttatulipa` came from the user. If the mod is published, confirm the
      author's terms and credit them.
- [ ] **"White screen" bug** reported once by the user. Not reproduced after the save-hook fix, and
      probably the same cause. Keep an eye on it.

## 6. Testing in the real game (tools/ingame)

- **Requirements:** Windows PowerShell 5.1, and the game installed with the cheat plugin (for
  `HopeCheat.runtime`).
- **The scripts:**
  - start the game with a temporary `steam_appid.txt`, so the exe doesn't relaunch through Steam;
  - use `WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS=--remote-debugging-port=9222`;
  - talk CDP over a websocket (`cdp.ps1`: `-Expr` / `-File` Runtime.evaluate, `-Shot` screenshot,
    `-Method` any CDP call).
- **Commands:**
  ```powershell
  tools\ingame\dialogue-test.ps1 -Name x   # install build, load save (clicks Load at 330,665 @1920x1080), 5 dialogues -> work\ingame\x.png
  tools\ingame\choice-test.ps1 -Name x     # longest 4 options, no-hover + hover on choice 2
  ```
- **`dialogue.js`:** picks a dialogue by substring via `self.PICK` (`"longest"` is allowed).
- **`marktest.js`:** maps Thai graphemes to encoded glyphs, using one known line, then shows `self.TEST`.
  It needs `THS3`, so run `dialogue.js` first.
- **Caution:**
  - These scripts load the user's real save. The game may autosave while it's open, which is why the
    save hook matters.
  - Always `Stop-Process` the game and delete `steam_appid.txt` afterwards (the scripts do this).
  - The click coordinate assumes a 1920×1080 window.

## 7. Suggested next work

1. **Translate item_desc (246) and script (546).** Script covers the tutorial boxes, which use the same
   dialogue box, so the wrap check should include `script` categories that go to it. Use
   `tools/import-batch.ps1` and STYLE.md.
2. **Decide whether the bitsy font should cover more boxes.** Candidates: item descriptions, signs, tutorial
   hints (`hint_text`). Each needs a `FONT_TUNING` entry, a wrap check and an in-game look.
3. **Consider using the bitsy font's own Latin glyphs** in the dialogue box, so English words match the
   Thai style. The game's English font is currently kept.
4. **Refactor build.html into modules** (fonts / patches / save hook / checks) with small unit tests for:
   `parseExprTable`, the bitsy parser + `bitsyRowShift`, `checkWrap` and the save hook conversions. The
   save-hook maths is pure given a fake inst; `save2.js`-style fakes were used during development.
5. **Automate the in-game regression** (dialogue + choices strips) and compare against reference PNGs.
