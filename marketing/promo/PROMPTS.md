# Fotos für das Werbevideo

Das Video braucht acht Fotos. Solange eine Datei fehlt, zeigt die Karte einen Farbverlauf mit Emoji – das Video rendert trotzdem.

## So geht's

1. Bilder mit den Prompts unten erzeugen: **Hochformat 2:3 oder 3:4**, mindestens 1080 px breit.
2. Unter genau diesen Namen in `marketing/promo/photos/` legen (`.jpg`, `.jpeg`, `.png` oder `.webp`).
3. `cd marketing/promo && npm install && npm run render` → `out/swipez-promo-de.mp4` und `out/swipez-promo-en.mp4`.
   Beim ersten Mal zusätzlich: `npx playwright install chromium-headless-shell`.

Worauf es bei allen Bildern ankommt:

- **Motiv in der oberen Bildhälfte.** Das untere Drittel liegt auf der Karte unter einem dunklen Verlauf mit Name und Tasten.
- **Kein Text, keine Logos, keine Schilder, kein Wasserzeichen** – erfundene Schrift fällt im Video sofort auf.
- **Keine erkennbaren Gesichter**; Menschen höchstens unscharf im Hintergrund.
- Wirken soll es wie ein gutes Handyfoto aus Google Maps, nicht wie ein Werbeplakat: natürliches Licht, leicht warm.

An jeden Prompt anhängen:

> vertical 2:3, natural light, realistic smartphone photo, shallow depth of field, no text, no logos, no signs, no watermark, no recognizable faces

## Die acht Bilder

| Datei | Wo im Video | Prompt |
| --- | --- | --- |
| `01-cafe` | 1. Swipe-Karte „Café Liebling“ (wird gemerkt) | Cozy European neighborhood café interior, wooden tables, a cappuccino with latte art on the table in the upper half of the frame, warm morning light through a large window, plants, vintage chairs |
| `02-terrasse` | 2. Karte „Morgenrot“ (wird weitergewischt) | Small street café terrace on a cobblestone sidewalk in a German city, bistro tables and rattan chairs under a striped awning, overcast daylight, slightly plain and ordinary |
| `03-roestbar` | 3. Karte „Röstwerk 7“ und Bibliothek | Modern specialty coffee roastery bar, barista counter with a chrome espresso machine and pour-over equipment, concrete and light oak, bright minimal interior, hands of a barista only |
| `04-backstube` | 4. Karte „Zuckerstück“ | Bakery café counter with a glass display full of croissants, cinnamon buns and cakes, a cup of coffee on the marble counter, soft warm light |
| `05-arbeitscafe` | KI-Karte „Kleine Pause“, Bibliothek und Detailansicht | Quiet café corner for working, a laptop and a flat white on a wooden table by the window in the upper half of the frame, power outlet on the wall, bookshelves, calm empty seats, soft daylight |
| `06-pizza` | Bibliothek „Da Enzo“ | Neapolitan pizza margherita fresh from a wood-fired oven on a rustic table in a small Italian restaurant, oven glow in the blurred background, seen from a 45 degree angle |
| `07-bar` | Bibliothek „Feierabend“ | Intimate cocktail bar at night, a negroni with an orange peel on a dark wooden bar, warm amber back-bar lighting, bottles blurred in the background |
| `08-kaffeekontor` | Nächste Karte im Stapel, nur angeschnitten und kurz zu sehen | Classic old-town coffee house interior, dark wood paneling, a slice of cake and a filter coffee on a small round marble table, brass lamps, calm afternoon light |

`05-arbeitscafe` ist am wichtigsten: Es ist dreimal groß zu sehen. `06` und `07` erscheinen nur als kleine Kacheln, `08` nur kurz hinter einer anderen Karte.
