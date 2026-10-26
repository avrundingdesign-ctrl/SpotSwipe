# SpotSwipe

Orte per Swipe entdecken: Suchbegriff und Umkreis eingeben, „Go“, dann bis zu 10 Orte nacheinander als Karten wischen. Rechts = merken (landet in der Bibliothek), links = weiter.

Herausgelöst aus der Swipe-Funktion von Meanwhile. Design: [SpotSwipe Design](https://claude.ai/artifact/4uajXUw5bcVU5xyKzQeCMU) (Variante A, Akzent Koralle `#FF5533`).

## Projekt öffnen

Das Xcode-Projekt wird aus `project.yml` erzeugt und ist nicht eingecheckt.

```sh
brew install xcodegen   # einmalig
xcodegen generate
open SpotSwipe.xcodeproj
```

Voraussetzungen: Xcode 26, iOS 26.

## Schlüssel und Konten

Alles Persönliche steht in `Config/Secrets.xcconfig` (in `.gitignore`). Vorlage: `Config/Secrets.example.xcconfig`.

| Wert | Wofür | Ohne den Wert |
| --- | --- | --- |
| `GOOGLE_PLACES_API_KEY` | Orte, Fotos, Bewertungen über die Google Places API (New) | App läuft mit Beispieldaten |
| `SPOTSWIPE_BUNDLE_ID`, `SPOTSWIPE_TEAM_ID` | Signieren für echte Geräte und iCloud | Simulator funktioniert trotzdem |
| `SPOTSWIPE_CLOUDKIT = YES` + `SPOTSWIPE_ENTITLEMENTS = SpotSwipe/SpotSwipe.entitlements` | Bibliothek per iCloud synchronisieren | Bibliothek bleibt lokal |

Google-Key einrichten:

1. In der Google Cloud Console ein Projekt mit Abrechnung anlegen und **Places API (New)** aktivieren.
2. API-Key erstellen und beschränken: Anwendung = iOS-App mit der Bundle-ID oben, API = nur Places API (New).
3. Budget-Alarm setzen. Pro Suche fallen 1 Text-Search-Anfrage (Enterprise-Felder wegen Telefon/Website/Bewertung) plus Foto-Abrufe an.

Nach Änderungen an den xcconfig-Dateien: `xcodegen generate`.

## Aufbau

```
SpotSwipe/
  App/            Einstieg, AppModel, Konfiguration, Debug-Startargumente
  DesignSystem/   Farben (Theme), Buttons, Chips, Foto-Ansicht
  Models/         Place, SavedPlace (SwiftData), Geo-Rechnung, Formatierung
  Services/       Google Places, Beispieldaten, Standort, Foto-Cache, Bibliothek
  Features/       Home, Location, Swipe, Library, Settings
SpotSwipeTests/   Swift Testing: Geo, Formatierung, Google-Antworten, Swipe-Logik
```

Wichtige Entscheidungen:

- **Eine Suche, eine Runde:** höchstens 5 oder 10 Karten (Einstellung), kein „Mehr laden“.
- **Umkreis:** Google erlaubt bei der Text Search nur ein Rechteck. Wir fragen das umschließende Rechteck ab und filtern danach auf den echten Kreis.
- **Fotos:** Wechsel per Tippen (links/rechts), weil horizontales Wischen Ja/Nein ist. Folgefotos lädt nur die oberste Karte vor.
- **Gespeicherte Orte:** Google erlaubt dauerhaftes Speichern nur der Place-ID. Der Rest ist ein Schnappschuss, den die Detailansicht nach 24 h auffrischt. Vor dem Store-Release mit den Google-Bedingungen abgleichen.

## Tests

```sh
xcodebuild -project SpotSwipe.xcodeproj -scheme SpotSwipe \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

## Screens im Simulator prüfen (nur Debug)

Startargumente springen direkt in einen Zustand:

```sh
xcrun simctl launch booted de.example.spotswipe -useMockPlaces -demoSearch Café
xcrun simctl launch booted de.example.spotswipe -demoSearch Café -demoScreen finished
xcrun simctl launch booted de.example.spotswipe -demoSeedLibrary YES -demoTab library
```

Weitere Werte für `-demoScreen`: `settings`, `location`, `map`, `detail`, `drag`.
