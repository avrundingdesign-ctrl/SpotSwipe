# SpotSwipe

Orte per Swipe entdecken: Suchbegriff und Umkreis eingeben, „Go“, dann bis zu 10 Orte nacheinander als Karten wischen. Rechts = merken (landet in der Bibliothek), links = weiter.

Herausgelöst aus der Swipe-Funktion von Meanwhile (`~/Downloads/Maps_Ki`, intern „ZwischenZeit“). Design: [SpotSwipe Design](https://claude.ai/artifact/4uajXUw5bcVU5xyKzQeCMU) (Variante A, Akzent Koralle `#FF5533`).

## Projekt öffnen

Das Xcode-Projekt wird aus `project.yml` erzeugt und ist nicht eingecheckt.

```sh
brew install xcodegen   # einmalig
xcodegen generate
open SpotSwipe.xcodeproj
```

Voraussetzungen: Xcode 26, iOS 26. Team (`8698DN5A64`) und Bundle-ID (`com.avrundingdesign.spotswipe`) stehen in `Config/App.xcconfig`; lokale Abweichungen gehören in `Config/Secrets.xcconfig` (Vorlage: `Secrets.example.xcconfig`).

## Woher die Daten kommen

Wie in Meanwhile, ohne einen einzigen API-Key in der App:

| Was | Quelle | Kosten |
| --- | --- | --- |
| Orte, Adresse, Telefon, Website | Apple Karten (`MKLocalSearch`) | kostenlos |
| Fotos, Bewertung, Öffnungszeiten, Preisniveau | Google Places über den Meanwhile-Proxy `POST /v1/place` | Google-Key und Monatsbudget liegen auf dem Server |
| Adresssuche, Karte, Route | Apple Karten | kostenlos |

Der Proxy (`Maps_Ki/server`, läuft auf `zwischenzeit-api.cleanyourstuff.nl`) prüft jede Anfrage per **App Attest**. SpotSwipe ist dort über `APPLE_EXTRA_BUNDLE_IDS=com.avrundingdesign.spotswipe` zugelassen und teilt sich Tageslimit und Monatsbudget mit Meanwhile.

App Attest gibt es nur auf echten Geräten. **Im Simulator** zeigt die App deshalb echte Orte von Apple Karten, aber ohne Fotos und Bewertungen. Für Screens mit Fotos: Beispieldaten per `-useMockPlaces`.

Beim Swipen erscheinen die Karten sofort mit den Apple-Daten; Fotos und Bewertung kommen Karte für Karte über den Proxy nach (oberste zuerst). Ist „Nur geöffnete Orte“ an, fliegen geschlossene Orte raus, bevor sie oben ankommen, und Orte aus der Reserve rücken nach.

## Sprachen

Deutsch (Quelle), Englisch, Spanisch, Französisch, Italienisch, Türkisch – in `SpotSwipe/Resources/Localizable.xcstrings` und `InfoPlist.xcstrings`. Die Sprache folgt dem iPhone; pro App lässt sie sich unter *Einstellungen › SpotSwipe › Sprache* ändern (in der App: Einstellungen › Sprache).

Neue Texte: in SwiftUI einfach als Literal schreiben (`Text("…")`), in normalem Code `String(localized: "…")`. Xcode trägt neue Schlüssel beim Bauen in den Katalog ein; danach die fünf Übersetzungen ergänzen. Öffnungszeiten kommen von Google in der App-Sprache (Proxy: `lang`).

## Intro

Beim ersten Start erklären vier Seiten Suchen, Wischen und Bibliothek und fragen am Ende nach dem Standort. Erneut ansehen: Einstellungen › Über › Intro noch einmal ansehen.

## iCloud

Die Bibliothek synchronisiert per CloudKit (`iCloud.com.avrundingdesign.spotswipe`, Schalter `SPOTSWIPE_CLOUDKIT`). Container und App-ID legt Xcode beim ersten Build auf ein Gerät an (automatisches Signieren). Klappt CloudKit nicht, bleibt die Bibliothek lokal.

## Aufbau

```
SpotSwipe/
  App/            Einstieg, AppModel, Konfiguration, Debug-Startargumente
  DesignSystem/   Farben (Theme), Buttons, Chips, Foto-Ansicht
  Models/         Place, SavedPlace (SwiftData), Geo-Rechnung, Formatierung
  Services/       Apple Karten + Proxy, App Attest, Beispieldaten, Standort, Foto-Cache, Bibliothek
  Features/       Home, Location, Swipe, Library, Settings
SpotSwipeTests/   Swift Testing: Geo, Formatierung, Proxy-Antworten, Swipe-Logik
```

Entscheidungen:

- **Eine Suche, eine Runde:** höchstens 5 oder 10 Karten (Einstellung), kein „Mehr laden“.
- **Fotos:** Wechsel per Tippen (links/rechts), weil horizontales Wischen Ja/Nein ist.
- **Gespeicherte Orte:** Google-Daten sind ein Schnappschuss, den die Detailansicht nach 24 h über den Proxy auffrischt. Vor dem Store-Release mit den Google-Bedingungen abgleichen.

## Tests

```sh
xcodebuild -project SpotSwipe.xcodeproj -scheme SpotSwipe \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

## Screens im Simulator prüfen (nur Debug)

```sh
xcrun simctl launch booted com.avrundingdesign.spotswipe -useMockPlaces -demoSearch Café
xcrun simctl launch booted com.avrundingdesign.spotswipe -useMockPlaces -demoSearch Café -demoScreen finished
xcrun simctl launch booted com.avrundingdesign.spotswipe -useMockPlaces -demoSeedLibrary YES -demoTab library
```

Weitere Werte für `-demoScreen`: `settings`, `location`, `map`, `detail`, `drag`. Intro: `-hasSeenIntro NO -demoIntroPage 2`. Sprache: `-AppleLanguages "(tr)"`.
