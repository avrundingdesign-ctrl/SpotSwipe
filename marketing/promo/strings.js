// Alle Texte des Videos. App-Texte stammen aus SpotSwipe/Resources/Localizable.xcstrings,
// die Werbezeilen (hook, captions, cta) gibt es nur hier. <b>…</b> = Akzentfarbe.
(function () {
  const P = (window.Promo = window.Promo || {});

  P.strings = {
    de: {
      hook: ['Wohin', 'heute?'],
      hookWords: ['Café', 'Pizza', 'Bar', 'Park'],
      captions: [
        ['Tipp ein,', 'was du <b>suchst.</b>'],
        ['Rechts <b>merken.</b>', 'Links weiter.'],
        ['Oder <b>beschreib</b>', 'es einfach.'],
        ['Alles in deiner', '<b>Bibliothek.</b>']
      ],
      cta: 'Jetzt im App Store',

      location: 'Köln',
      headline: ['Wonach', 'suchst du?'],
      placeholder: 'Café, Pizza, Buchladen …',
      placeholderAI: 'z. B. ruhiges Café zum Arbeiten',
      chips: ['Café', 'Brunch', 'Pizza', 'Bar', 'Park', 'Sushi'],
      radius: 'Umkreis',
      ticks: ['0,5', '1', '2', '5', '10', '25 km'],
      tabDiscover: 'Entdecken',
      tabLibrary: 'Bibliothek',

      query: 'Café',
      queryAI: 'ruhiges Café zum Arbeiten',
      around: '2 km um dich herum',
      loading: 'Suche „Café“ in der Nähe …',
      loadingAI: 'KI versteht deinen Wunsch …',
      save: 'MERKEN',
      skip: 'WEITER',
      category: 'Café',
      open: 'Geöffnet · bis 18:00',
      actions: ['Teilen', 'Website', 'Anrufen', 'Route'],
      reason: 'Ruhig, viele Steckdosen, gutes WLAN.',
      decimal: ',',

      library: 'Bibliothek',
      newest: 'Neueste',
      synced: 'Gemerkte Orte auf all deinen Geräten',
      searchLibrary: 'In Bibliothek suchen',
      savedFor: 'Gemerkt bei der Suche „ruhiges Café zum Arbeiten“.',
      hoursTitle: 'Öffnungszeiten',
      hours: [['Montag', '08:00–18:00'], ['Dienstag', '08:00–18:00'], ['Mittwoch', '08:00–18:00'], ['Donnerstag', '08:00–18:00']],
      tiles: ['Café · Venloer Str. 97', 'Café · Venloer Str. 46', 'Pizza · Körnerstr. 12', 'Bar · Subbelrather Str. 8', 'Café · Venloer Str. 12', 'Café · Venloer Str. 63']
    },
    en: {
      hook: ['Where to', 'today?'],
      hookWords: ['Coffee', 'Pizza', 'Bars', 'Parks'],
      captions: [
        ['Type what', 'you’re <b>after.</b>'],
        ['Right to <b>save.</b>', 'Left to skip.'],
        ['Or just', '<b>describe</b> it.'],
        ['All in your', '<b>library.</b>']
      ],
      cta: 'Now on the App Store',

      location: 'Cologne',
      headline: ['What are you', 'looking for?'],
      placeholder: 'Café, pizza, bookshop…',
      placeholderAI: 'e.g. quiet café to work in',
      chips: ['Café', 'Brunch', 'Pizza', 'Bar', 'Park', 'Sushi'],
      radius: 'Radius',
      ticks: ['0.5', '1', '2', '5', '10', '25 km'],
      tabDiscover: 'Discover',
      tabLibrary: 'Library',

      query: 'Café',
      queryAI: 'quiet café to work in',
      around: '2 km around you',
      loading: 'Searching for “Café” nearby…',
      loadingAI: 'AI is understanding your wish…',
      save: 'SAVE',
      skip: 'NEXT',
      category: 'Café',
      open: 'Open · until 6 PM',
      actions: ['Share', 'Website', 'Call', 'Directions'],
      reason: 'Quiet, plenty of outlets, good Wi‑Fi.',
      decimal: '.',

      library: 'Library',
      newest: 'Newest',
      synced: 'Saved places on all your devices',
      searchLibrary: 'Search library',
      savedFor: 'Saved while searching for “quiet café to work in”.',
      hoursTitle: 'Opening hours',
      hours: [['Monday', '8 AM–6 PM'], ['Tuesday', '8 AM–6 PM'], ['Wednesday', '8 AM–6 PM'], ['Thursday', '8 AM–6 PM']],
      tiles: ['Café · Venloer Str. 97', 'Café · Venloer Str. 46', 'Pizza · Körnerstr. 12', 'Bar · Subbelrather Str. 8', 'Café · Venloer Str. 12', 'Café · Venloer Str. 63']
    }
  };

  // Orte: Namen wie in MockPlacesService. `photo` = Dateiname in photos/ ohne Endung.
  // Fehlt die Datei, zeigt die Karte den Farbverlauf (Theme.photoPalettes) mit dem Emoji.
  P.places = {
    cafe: { photo: '01-cafe', emoji: '☕', pal: ['#DCC7A9', '#6B5440'], name: 'Café Liebling', rating: 4.6, count: 412, dist: '350 m', price: '€€' },
    terrasse: { photo: '02-terrasse', emoji: '🪑', pal: ['#C9D6CF', '#4F6458'], name: 'Morgenrot', rating: 4.1, count: 186, dist: '600 m', price: '€' },
    roestbar: { photo: '03-roestbar', emoji: '🫘', pal: ['#E7C9B8', '#9A5B45'], name: 'Röstwerk 7', rating: 4.8, count: 731, dist: '850 m', price: '€€' },
    backstube: { photo: '04-backstube', emoji: '🥐', pal: ['#E5D5BC', '#8C7350'], name: 'Zuckerstück', rating: 4.7, count: 298, dist: '1,2 km', price: '€€' },
    arbeitscafe: { photo: '05-arbeitscafe', emoji: '💻', pal: ['#CDD3E0', '#55607A'], name: 'Kleine Pause', rating: 4.5, count: 257, dist: '700 m', price: '€€' },
    pizza: { photo: '06-pizza', emoji: '🍕', pal: ['#E7C9B8', '#9A5B45'], name: 'Da Enzo', rating: 4.7, count: 903, dist: '1,1 km', price: '€€' },
    bar: { photo: '07-bar', emoji: '🍸', pal: ['#B9B3CF', '#3F3A5A'], name: 'Feierabend', rating: 4.4, count: 521, dist: '1,6 km', price: '€€' },
    // Nur als nächste Karte im Stapel zu sehen, über die nicht mehr entschieden wird.
    kontor: { photo: '08-kaffeekontor', emoji: '🍰', pal: ['#C9D6CF', '#4F6458'], name: 'Kaffeekontor', rating: 4.3, count: 164, dist: '1,4 km', price: '€' }
  };
})();
