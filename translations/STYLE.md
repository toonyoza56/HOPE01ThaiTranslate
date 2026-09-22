# Thai translation style guide — HOPE 01

## Do not translate
- Item names, room / place names, NPC names, upgrade names → keep English as in the game
- When translated text mentions a name (`keep_terms` column) → **keep the English word**
  - A term marked `?` (e.g. `MAINTENANCE?`, `MILK?`) → keep it only when it means the place / item in the game

## Speaker and gender
Use pronouns that fit the speaker's gender. If the gender is unknown → neutral wording.
**Do not add** polite particles (ครับ / ค่ะ / คะ / นะคะ).

| speaker | who | first person | calls the player |
|---|---|---|---|
| player | protagonist (female, red hair — called "RED") | ฉัน | – |
| kio | KIO, shy young woman, afraid of going outside | ฉัน | เธอ |
| myst | MYST, woman, mysterious, formal, knows a lot | ฉัน | เธอ |
| cayd | CAYD, weird man, loud, invents slang (DEK, BRICK, UPPING) → make up matching Thai slang | ผม (casual) | เธอ / RED |
| shasta | MR. SHASTA, flamboyant man, calls people HUN | ผม (theatrical, bouncy) | ที่รัก / เธอ |
| hermes | HERMES, man in a dog's body, well-off and fairly polite, often barks WOOF | ผม (with barking sounds) | คุณ |
| one | THE ONE, AI / collective entity, calls itself WE | เรา | เธอ / เจ้า |
| (desmond) | DR. DESMOND, zealot scientist of THE CONGREGATE, gender not stated → neutral | ฉัน | เธอ (in their lines "SHE/HER" = the giant organism → "เธอ" in quotes) |
| (shasta crew) | MR. SHASTA's entourage (e.g. CLOVE), talk about him in the third person | – | เธอ / ที่รัก |
| info / tutorial | narration, system, quest log | no first person | เธอ / you (neutral) |

> The `speaker` column is the speaker carried forward from the dialogue flow — it can be off
> (especially `info`). Check against the surrounding lines.

## Terms
| English | Thai |
|---|---|
| EXTRACT / EXTRACTION | EXTRACT (keep English — a game-system term) |
| RAID | RAID (keep English) |
| HAB (residential building) | ฮับ / HAB (keep English when followed by a number, e.g. HAB 01) |
| STUG (gun) | STUG (keep English), STUGFIRE = เสียงปืน |
| FABRICK(S) (currency / printing material) | FABRICKS (keep English) |
| PRINT / PRINTING (3D printing) | พิมพ์ |
| CYCLER / CYCLERFORM | CYCLER / CYCLERFORM (keep English) |

## Format
- Keep `\n` (line breaks), `...` / `..`, `[color=...]...[/color]` tags, numbers, `(` `)` exactly as in the original
- Game text is ALL CAPS: Thai has no case, so just keep English names in capitals as they are
- Keep lines short enough to fit the box (dialogue box ~236px ≈ 35–40 Thai characters per line)
