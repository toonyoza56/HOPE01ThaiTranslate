# Known issues

## Fixed 2026-09-22 (tested in the real game with the user's pre-mod save)

### 1. NPC dialogue showed no text — FIXED
- **Cause:** the savegame stores each SpriteFont's font settings (`cw/ch` cell, `cs` charset, `sd` spacing,
  `csc` scale, `lh` line height; Spritefont2 SaveToJson/LoadFromJson in c3main.js) and its box (x/y/w/h).
  Loading a save made before the mod put the original 10px English settings back onto the new sheet:
  Thai characters weren't in the charset, so nothing was drawn. A new game worked, which is why the
  browser test (/play/, new game) never showed it.
- **Fix (build.html `patchSaveLoad`):** hooks in the SpriteFont load/save code (`self.__thaiLoad` / `self.__thaiSave`,
  appended to c3main.js):
  - load: a patched font keeps the new sheet settings, and scale/line height are converted. A save without the
    `thai` mark also gets its box grown/shifted like the layout instances. Saves from the earlier build
    (already in the new units, unmarked) are detected by `cw`.
  - save: patched fonts are written in the **original** font's units + `thai: 1` → the save still works
    after uninstalling the mod (the box stays slightly taller, cosmetic).
  - fonts are found by object type name (`sdk.pZ().iq().Bf()`), because several types share identical new settings.
  - debug: `self.__thaiConverted` = number of fonts converted on load (176 with the user's save).

### 2. White screen — not reproduced
- Not seen again after fix #1. Probably the same cause (old-save font settings reading the wrong parts of the new
  sheets). **If it happens again: note when (which room/menu/action).**

### 3. Title menu hover: text grew and stayed big — FIXED
- **Cause:** hover sets Set scale 1.1, leaving sets 1 (ACE 62 on family MainMenuButtons); the patch had changed the
  base scale to 1/K = 0.5, so 1 = twice as big. (The original game does grow 10% on hover.)
- **Fix (build.html `patchScaleActions`):** Set scale actions on patched SpriteFonts get their constant divided by K
  (new expressions appended to `self.rwt` in c3main.js: 0.55 / 0.5).

### 4. Menu/choice boxes overlapped → two items highlighted, clicks could hit the wrong one — FIXED
- Found while testing #3: boxes grown ×2.4 overlapped (menu 59px tall, 32px apart; dialogue choices 48px, 16px apart),
  and the game hit-tests them with "mouse is over".
- **Fix:** `HEIGHT_CAP` in build.html (menu 24, choices 16 — Thai not clipped in the real game), also used by the load hook.

### 5. Dialogue font too small to read — FIXED
- `FONT_TUNING` in build.html: the dialogue box font gets Thai at size 2.0 (was 1.6), line 1.12 x font size,
  anti-aliased instead of 1-bit. URL params `dsize`, `dline`, `dsmooth=0` for experiments.
- `checkWrap` simulates word wrap for every translated dialogue: at 2.0 max 3 lines, box fits 4 → none cut off
  (2.2 → 5 lines too long). 3-line texts (115 of 1,441) fill the frame edge to edge.
- Saves now record the box growth (`gd`); loading undoes it and grows again with the current build's rules, so
  size changes in later builds apply to existing saves. Saves from before `gd` keep their box (the user's save:
  dialogue box 56 instead of 62 — text still fits).

### 6. Pixel font for dialogue + choices (user request) — DONE
- Dialogue box and the 4 choices now use `fonts/Thai_nuttatulipa.bitsyfont` (1 font px = 1 game px),
  marks placed tighter than the font file (16px cell, line 16). Rule found in game: glyph cell must not be
  taller than the line advance (else the next line's marks vanish). 2 dialogues + 3 choices shortened in
  `translations/th-012.csv` to fit. Full details / review list: `CODEX_REVIEW.md`.

## Game update 2026-09-22 (~14:54)
Steam updated data.json + c3main.js (content only; engine/minified names unchanged).
`backup/original` = the new originals; the old ones are in `backup/original-2026-09-22-old`.
Extract + build were re-run: dialogue/options unchanged (1,788), item_desc 244→246, script 544→546,
1 string changed (now untranslated).

## How to debug in the real game (WebView2)
1. Put `steam_appid.txt` (4562940) in the game folder so the exe doesn't relaunch through Steam (**delete it afterwards**).
2. `$env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS="--remote-debugging-port=9222"` then start `Hope 01.exe`.
3. `http://127.0.0.1:9222/json` → CDP websocket (Runtime.evaluate / Page.captureScreenshot / Input.dispatchMouseEvent)
   from PowerShell (ClientWebSocket). Runtime: `HopeCheat.runtime` (cheat mod), `runtime.AU(name, ...args)` = call function
   (e.g. `AU("DialogueShow", text, "hermes")`, `AU("DialogueBoxChoices", o1, o2, o3, o4)`).

## Build note
build.html reads `/game/` = the game folder: **run tools/uninstall.ps1 before building** (it now refuses if the Thai
build is installed).

## Uninstall
```
powershell -ExecutionPolicy Bypass -File I:\HOPE01-ThaiMod\tools\uninstall.ps1
```
