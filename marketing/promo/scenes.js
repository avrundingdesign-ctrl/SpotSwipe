// Aufbau der Bühne (build) und Zustand zur Sekunde t (update).
// Die App-Oberfläche ist nach HomeView, SwipeDeckView, PlaceCardView und LibraryView nachgebaut;
// Maße im iPhone sind Punkte (393×852), das Gerät wird als Ganzes skaliert.
(function () {
  const P = window.Promo;
  const { clamp, prog, lerp, E, spring, bump } = P.math;

  // ---------- Zeitplan (Sekunden) ----------
  const T = {
    hookOut: 2.1,
    phoneIn: 2.4,
    captions: [[3.0, 5.75], [6.0, 11.75], [12.0, 15.8], [16.0, 18.45]],
    type1: [3.3, 4.1],
    slider: [4.4, 4.85],
    go1: 5.25,
    deckUp1: [5.4, 5.85],
    cardsIn1: 6.15,
    deckDown1: [11.5, 11.9],
    aiOn: 12.3,
    type2: [12.5, 13.5],
    go2: 13.75,
    deckUp2: [13.85, 14.25],
    cardsIn2: 14.55,
    deckDown2: [16.0, 16.4],
    tilesIn: 16.38,
    tileTap: 17.3,
    sheetUp: [17.35, 17.8],
    phoneOut: [18.5, 18.95],
    endIn: 18.85
  };
  const swipe = (t0, dir, drag, hold, fly) => ({ t0, dir, d1: t0 + drag, h1: t0 + drag + hold, f1: t0 + drag + hold + fly });
  const SWIPES1 = [swipe(6.9, 1, 0.6, 0.25, 0.28), swipe(8.3, -1, 0.45, 0.15, 0.28), swipe(9.5, 1, 0.3, 0.08, 0.26), swipe(10.5, 1, 0.3, 0.08, 0.26)];
  const SWIPES2 = [swipe(15.3, 1, 0.32, 0.1, 0.26)];

  // ---------- Symbole (eigene, an SF Symbols angelehnt) ----------
  const line = (d, w = 2.2) => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round">${d}</svg>`;
  const solid = (d) => `<svg viewBox="0 0 24 24" fill="currentColor">${d}</svg>`;
  const I = {
    search: line('<circle cx="10.5" cy="10.5" r="6.5"/><path d="M15.5 15.5 21 21"/>', 2.6),
    sparkles: solid('<path d="M10 3.5 11.9 9.1 17.5 11 11.9 12.9 10 18.5 8.1 12.9 2.5 11 8.1 9.1Z"/><path d="M18.5 2 19.4 4.6 22 5.5 19.4 6.4 18.5 9 17.6 6.4 15 5.5 17.6 4.6Z"/><path d="M18 15 18.8 17.2 21 18 18.8 18.8 18 21 17.2 18.8 15 18 17.2 17.2Z"/>'),
    gear: line('<circle cx="12" cy="12" r="3"/><circle cx="12" cy="12" r="6.4"/><circle cx="12" cy="12" r="8.6" stroke-width="3" stroke-dasharray="3.2 3.55" stroke-linecap="butt"/>', 1.9),
    location: solid('<path d="M21 3 3 10.4l7.4 2.6 2.6 7.4z"/>'),
    chevDown: line('<path d="m5 9 7 7 7-7"/>', 3),
    chevLeft: line('<path d="m15 4-8 8 8 8"/>', 2.8),
    arrowRight: line('<path d="M4 12h16M13 5l7 7-7 7"/>', 3),
    xmark: line('<path d="M5 5l14 14M19 5 5 19"/>', 3),
    undo: line('<path d="M9 14 4 9l5-5"/><path d="M4 9h10.5a5.5 5.5 0 0 1 0 11H11"/>', 2.8),
    heart: solid('<path d="M12 21s-7.5-4.6-9.6-9.3C.9 8.3 2.9 4.5 6.6 4.5c2.1 0 3.9 1.1 5.4 3 1.5-1.9 3.3-3 5.4-3 3.7 0 5.7 3.8 4.2 7.2C19.5 16.4 12 21 12 21z"/>'),
    star: solid('<path d="m12 2.5 2.9 6.1 6.6.9-4.8 4.6 1.2 6.6L12 17.5l-5.9 3.2 1.2-6.6L2.5 9.5l6.6-.9z"/>'),
    share: line('<path d="M12 15V3M7.5 7 12 2.5 16.5 7"/><path d="M5 11v8.5a1.5 1.5 0 0 0 1.5 1.5h11a1.5 1.5 0 0 0 1.5-1.5V11"/>'),
    globe: line('<circle cx="12" cy="12" r="9"/><ellipse cx="12" cy="12" rx="4" ry="9"/><path d="M3 12h18"/>', 2),
    phone: line('<path d="M22 16.9v3a2 2 0 0 1-2.2 2 19.8 19.8 0 0 1-8.6-3.1 19.5 19.5 0 0 1-6-6A19.8 19.8 0 0 1 2.1 4.2 2 2 0 0 1 4.1 2h3a2 2 0 0 1 2 1.7c.1 1 .4 1.9.7 2.8a2 2 0 0 1-.5 2.1L8.1 9.9a16 16 0 0 0 6 6l1.3-1.3a2 2 0 0 1 2.1-.4c.9.3 1.8.6 2.8.7a2 2 0 0 1 1.7 2z"/>', 2),
    route: line('<path d="M12 2.6 21.4 12 12 21.4 2.6 12Z"/><path d="M9.2 14.6v-2.4a1.4 1.4 0 0 1 1.4-1.4h4"/><path d="m12.9 8.9 1.9 1.9-1.9 1.9"/>', 2),
    compass: line('<circle cx="12" cy="12" r="9"/><path d="m15.8 8.2-2.2 5.4-5.4 2.2 2.2-5.4z"/>', 2),
    bookmark: line('<path d="M6.5 3h11v18L12 16.8 6.5 21z"/>', 2),
    cloud: line('<path d="M7 18.5a4.5 4.5 0 0 1-.5-9A6 6 0 0 1 18 10.6a4 4 0 0 1-.6 7.9z"/>', 2),
    sort: line('<path d="M7 20V4M3.5 7.5 7 4l3.5 3.5M17 4v16M13.500 16.500 17 20l3.5-3.5"/>', 2.4),
    signal: '<svg viewBox="0 0 19 13" fill="currentColor"><rect x="0" y="8.5" width="3.2" height="4.5" rx="1"/><rect x="5.2" y="6" width="3.2" height="7" rx="1"/><rect x="10.4" y="3" width="3.2" height="10" rx="1"/><rect x="15.6" y="0" width="3.2" height="13" rx="1"/></svg>',
    wifi: '<svg viewBox="0 0 18 13" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M1.5 4.8a11 11 0 0 1 15 0"/><path d="M4.4 7.9a6.8 6.8 0 0 1 9.200 0"/><circle cx="9" cy="11" r="1.300" fill="currentColor" stroke="none"/></svg>',
    battery: '<svg viewBox="0 0 28 13" fill="none"><rect x=".6" y=".6" width="23.800" height="11.800" rx="3.800" stroke="currentColor" opacity=".4" stroke-width="1.200"/><rect x="2.200" y="2.200" width="20.600" height="8.600" rx="2.400" fill="currentColor"/><path d="M26 4.300v4.400c.9-.3 1.500-1.200 1.500-2.200S26.900 4.600 26 4.300z" fill="currentColor" opacity=".45"/></svg>'
  };

  // ---------- Bausteine ----------
  let S;
  const R = {};
  const num = (v) => v.toFixed(1).replace('.', S.decimal);
  const dist = (d) => d.replace(',', S.decimal);

  const photo = (pl) =>
    `<div class="photo" style="background:linear-gradient(160deg,${pl.pal[0]},${pl.pal[1]})"><span class="emoji">${pl.emoji}</span><img data-photo="${pl.photo}" alt=""></div>`;

  const tags = () => `<div class="tags"><span class="tag">${S.category}</span><span class="tag"><i class="dot"></i>${S.open}</span></div>`;
  const meta = (pl) =>
    `<div class="meta">${I.star}<span>${num(pl.rating)}</span><span class="dim">(${pl.count})</span><span class="sep">·</span><span>${dist(pl.dist)}</span><span class="sep">·</span><span>${pl.price}</span></div>`;
  const actions = (dimIndex) =>
    `<div class="actions">${[I.share, I.globe, I.phone, I.route]
      .map((icon, i) => `<div class="act${i === dimIndex ? ' dim' : ''}">${icon}<span>${S.actions[i]}</span></div>`)
      .join('')}</div>`;

  const card = (pl, opts = {}) => `
    <div class="card">
      ${photo(pl)}
      <div class="pager"><i class="on"></i><i></i><i></i></div>
      <div class="stamp save">${S.save}</div>
      <div class="stamp skip">${S.skip}</div>
      <div class="info">
        ${tags()}
        <div class="name">${pl.name}</div>
        ${meta(pl)}
        ${opts.reason ? `<div class="reason">${I.sparkles}<span>${opts.reason}</span></div>` : ''}
        ${actions(opts.dim)}
      </div>
    </div>`;

  const tabbar = (selected) => `
    <div class="tabbar">
      <div class="tab${selected === 0 ? ' on' : ''}">${I.compass}<span>${S.tabDiscover}</span></div>
      <div class="tab${selected === 1 ? ' on' : ''}">${I.bookmark}<span>${S.tabLibrary}</span></div>
    </div>`;

  const tile = (pl, sub) => `
    <div class="tile">
      <div class="ph">${photo(pl)}<span class="dist">${dist(pl.dist)}</span></div>
      <div class="tn">${pl.name}</div>
      <div class="ts">${sub}</div>
    </div>`;

  P.build = function (lang) {
    S = P.strings[lang];
    const pl = P.places;
    const stage = document.getElementById('stage');
    const libraryOrder = [pl.arbeitscafe, pl.roestbar, pl.pizza, pl.bar, pl.cafe, pl.backstube];

    stage.innerHTML = `
      <div class="glow g1"></div><div class="glow g2"></div>

      <div id="hook">
        <div class="fan">
          <div class="fc blue"></div>
          <div class="fc violet"></div>
          <div class="fc white"><div class="lens">${I.search}</div><div class="word"></div></div>
        </div>
        <div class="hook-title"><span>${S.hook[0]}</span><span>${S.hook[1]}</span></div>
      </div>

      ${S.captions.map((lines) => `<div class="caption">${lines.map((l) => `<span class="cl">${l}</span>`).join('')}</div>`).join('')}

      <div id="phone"><div class="device">
        <div class="screen">
          <div class="statusbar"><span>9:41</span><span class="right">${I.signal}${I.wifi}${I.battery}</span></div>
          <div class="island"></div>

          <div class="view" id="home">
            <div class="topbar">
              <div class="glassbtn">${I.gear}</div>
              <div class="locpill"><span class="loc">${I.location}</span><span>${S.location}</span><span class="chev">${I.chevDown}</span></div>
            </div>
            <div class="headline">${S.headline[0]}<br>${S.headline[1]}</div>
            <div class="search">
              ${I.search}
              <div class="qbox"><span class="qph"></span><span class="qinner"><span class="qtext"></span><i class="caret"></i></span></div>
              <div class="clear">${I.xmark}</div>
              <div class="spark">${I.sparkles}</div>
            </div>
            <div class="chips">${S.chips.map((c) => `<div class="chip">${c}</div>`).join('')}</div>
            <div class="radius">
              <div class="row"><span class="label">${S.radius}</span><span class="value"><span class="rv">2</span><small>km</small></span></div>
              <div class="track"><div class="rail"></div><div class="fillbar"></div><div class="thumb"></div></div>
              <div class="ticks">${S.ticks.map((t) => `<span>${t}</span>`).join('')}</div>
            </div>
            <div class="go"><span>Go</span>${I.arrowRight}</div>
            ${tabbar(0)}
          </div>

          <div class="view" id="library">
            <div class="libhead"><h1>${S.library}</h1><div class="sortpill">${I.sort}<span>${S.newest}</span></div></div>
            <div class="syncline">${I.cloud}<span>${S.synced}</span></div>
            <div class="libsearch">${I.search}<span>${S.searchLibrary}</span></div>
            <div class="grid">${libraryOrder.map((p, i) => tile(p, S.tiles[i])).join('')}</div>
            ${tabbar(1)}
            <div class="dim-layer"></div>
            <div class="sheet">
              <div class="hero">${photo(pl.arbeitscafe)}<div class="glassbtn">${I.xmark}</div></div>
              <div class="body">
                ${tags()}
                <div class="name">${pl.arbeitscafe.name}</div>
                ${meta(pl.arbeitscafe)}
                ${actions()}
                <div class="note">${S.savedFor}</div>
                <div class="hours"><h3>${S.hoursTitle}</h3>${S.hours.map(([day, time]) => `<div class="hr"><span>${day}</span><span>${time}</span></div>`).join('')}</div>
              </div>
            </div>
          </div>

          <div class="view" id="deck">
            <div class="decktop">
              <div class="glassbtn">${I.chevLeft}</div>
              <div class="mid"><div class="q"></div><div class="sub">${S.around}</div></div>
              <div class="counter"></div>
            </div>
            <div class="cards">
              <div class="loader"><div class="ring"></div><div class="ai">${I.sparkles}</div><span class="lt"></span></div>
              <div class="round r1">${[pl.kontor, pl.backstube, pl.roestbar, pl.terrasse, pl.cafe].map((p, i) => card(p, { dim: i === 1 ? 1 : -1 })).join('')}</div>
              <div class="round r2">${card(pl.kontor)}${card(pl.arbeitscafe, { reason: S.reason })}</div>
            </div>
            <div class="controlsrow">
              <div class="ctl big skipbtn">${I.xmark}</div>
              <div class="ctl small">${I.undo}</div>
              <div class="ctl big like">${I.heart}</div>
            </div>
          </div>

          <div class="homebar"></div>
        </div>
        <div class="overlay"><div id="finger"></div></div>
      </div></div>

      <div id="end">
        <div class="endstack"><div class="ec blue"></div><div class="ec violet"></div><div class="icon"></div></div>
        <div class="endname">Swipez</div>
        <div class="endclaim">${'Swipe to discover the world'.split(' ').map((w) => `<span>${w}</span>`).join('')}</div>
        <div class="endcta">${I.arrowRight}<span>${S.cta}</span></div>
      </div>`;

    const $ = (sel, root = stage) => root.querySelector(sel);
    const $$ = (sel, root = stage) => Array.from(root.querySelectorAll(sel));
    Object.assign(R, {
      g1: $('.g1'), g2: $('.g2'),
      hook: $('#hook'), hookWords: $$('.hook-title span'), fan: $$('.fan .fc'), word: $('.fan .word'),
      captions: $$('.caption').map((c) => $$('.cl', c)),
      phone: $('#phone'), screen: $('.screen'), finger: $('#finger'),
      qbox: $('.qbox'), qinner: $('.qinner'), qtext: $('.qtext'), qph: $('.qph'), caret: $('.caret'),
      clear: $('.clear'), spark: $('.spark'), search: $('.search'), chips: $$('.chip'),
      rv: $('.rv'), fillbar: $('.fillbar'), thumb: $('.thumb'), track: $('.track'), ticks: $$('.ticks span'), go: $('.go'),
      deck: $('#deck'), deckQ: $('.decktop .q'), counter: $('.counter'),
      loader: $('.loader'), ring: $('.loader .ring'), loaderAI: $('.loader .ai'), loaderText: $('.loader .lt'),
      r1: $('.r1'), r2: $('.r2'), skipbtn: $('.skipbtn'), likebtn: $('.ctl.like'),
      library: $('#library'), tiles: $$('.tile'), sheet: $('.sheet'), dimLayer: $('.dim-layer'),
      routeAct: $$('.sheet .act')[3], reason: $('.r2 .reason'),
      end: $('#end'), endCards: $$('.endstack .ec'), icon: $('.endstack .icon'), endName: $('.endname'),
      claim: $$('.endclaim span'), cta: $('.endcta')
    });
    // Im DOM liegt die oberste Karte zuletzt (Reihenfolge = Stapel von unten nach oben).
    R.cards1 = $$('.card', R.r1).reverse();
    R.cards2 = $$('.card', R.r2).reverse();
    for (const list of [R.cards1, R.cards2]) {
      for (const el of list) {
        el._save = $('.stamp.save', el);
        el._skip = $('.stamp.skip', el);
      }
    }

    // Mittelpunkte für den Finger, in Punkten relativ zum Bildschirm (unabhängig von Transformationen).
    const center = (el) => {
      let x = el.offsetWidth / 2;
      let y = el.offsetHeight / 2;
      for (let n = el; n && n !== R.screen; n = n.offsetParent) {
        x += n.offsetLeft;
        y += n.offsetTop;
      }
      return [x, y];
    };
    const [trackX, trackY] = center(R.track);
    R.trackW = R.track.offsetWidth;
    R.pt = {
      trackLeft: trackX - R.trackW / 2,
      trackY,
      go: center(R.go),
      spark: center(R.spark),
      card: center($('.cards')),
      tile: center(R.tiles[0])
    };

    // Fotos: photos/<name>.jpg|jpeg|png|webp – was fehlt, bleibt Farbverlauf.
    const exts = ['jpg', 'jpeg', 'png', 'webp'];
    P.ready = Promise.all(
      $$('img[data-photo]').map(
        (img) =>
          new Promise((resolve) => {
            let i = 0;
            const next = () => {
              if (i >= exts.length) return resolve(false);
              img.src = `photos/${img.dataset.photo}.${exts[i++]}`;
            };
            img.onload = () => {
              img.classList.add('ok');
              (img.decode ? img.decode().catch(() => {}) : Promise.resolve()).then(() => resolve(true));
            };
            img.onerror = next;
            next();
          })
      )
    ).then((found) => {
      P.photosFound = found.filter(Boolean).length;
      P.photosTotal = found.length;
      return document.fonts.ready;
    });
  };

  // ---------- Zustand zur Sekunde t ----------
  let lastQuery = null;
  function setQuery(text, placeholder) {
    const key = text + '|' + placeholder;
    if (key === lastQuery) return;
    lastQuery = key;
    R.qtext.textContent = text;
    R.qph.textContent = text ? '' : placeholder;
    R.clear.style.visibility = text ? 'visible' : 'hidden';
    const over = R.qinner.offsetWidth - R.qbox.clientWidth;
    R.qinner.style.transform = `translateX(${-Math.max(0, over)}px)`;
  }
  const typed = (text, t, [a, b]) => text.slice(0, Math.floor(prog(t, a, b) * text.length + 1e-6));

  function swipeX(sw, t) {
    if (t < sw.d1) return 118 * E.inOut(prog(t, sw.t0, sw.d1));
    if (t < sw.h1) return 118 + 10 * prog(t, sw.d1, sw.h1);
    return 128 + 560 * E.in2(prog(t, sw.h1, sw.f1));
  }

  /** Stapel einer Runde: Karte i wird von Wisch i bewegt, die Karten dahinter rücken nach. */
  function layoutDeck(cards, swipes, t) {
    const advance = swipes.reduce((sum, sw) => sum + E.out3(prog(t, sw.h1, sw.h1 + 0.38)), 0);
    cards.forEach((el, i) => {
      const sw = swipes[i];
      el.style.zIndex = cards.length - i;
      if (sw && t >= sw.t0) {
        const x = swipeX(sw, t) * sw.dir;
        const shown = clamp(Math.abs(x) / 96);
        el.style.visibility = t >= sw.f1 ? 'hidden' : 'visible';
        el.style.transform = `translate(${x}px, ${-Math.abs(x) * 0.07}px) rotate(${x / 18}deg)`;
        el._save.style.opacity = sw.dir > 0 ? shown : 0;
        el._skip.style.opacity = sw.dir < 0 ? shown : 0;
      } else {
        const depth = i - advance;
        const d = clamp(depth);
        el.style.visibility = depth > 1.98 ? 'hidden' : 'visible';
        el.style.transform = `translateY(${16 * d}px) scale(${1 - 0.05 * d})`;
        el._save.style.opacity = 0;
        el._skip.style.opacity = 0;
      }
    });
    return swipes.filter((sw) => t >= sw.h1).length;
  }

  /** Finger: Tipp an einer Stelle. Liefert null außerhalb des Zeitfensters. */
  function tap(t, at, [x, y]) {
    if (t < at - 0.3 || t > at + 0.28) return null;
    const press = bump(prog(t, at - 0.1, at + 0.14));
    return { x, y, o: Math.min(prog(t, at - 0.3, at - 0.16), 1 - prog(t, at + 0.12, at + 0.28)), s: 1.25 - 0.25 * prog(t, at - 0.3, at - 0.12) - 0.2 * press };
  }

  P.update = function (t) {
    // Hintergrund
    R.g1.style.transform = `translate(${-380 + 160 * Math.sin(t * 0.35)}px, ${-250 + 220 * Math.cos(t * 0.27)}px)`;
    R.g2.style.transform = `translate(${180 + 140 * Math.cos(t * 0.31 + 1)}px, ${760 + 200 * Math.sin(t * 0.24 + 2)}px)`;

    // ----- Hook -----
    const hookOn = t < T.hookOut + 0.9;
    R.hook.style.display = hookOn ? '' : 'none';
    if (hookOn) {
      const rot = [-15, -5, 6];
      const dx = [-130, -45, 55];
      const dy = [26, 4, 14];
      R.fan.forEach((el, k) => {
        const inP = spring(t - 0.08 - k * 0.09, 6, 8);
        const outP = E.in3(prog(t, T.hookOut + k * 0.07, T.hookOut + 0.55 + k * 0.07));
        const float = Math.sin(t * 1.6 + k) * 6;
        const x = dx[k] * inP + (k - 1) * 260 * outP;
        const y = lerp(1500, dy[k], inP) + float - 2100 * outP;
        el.style.transform = `translate(${x}px, ${y}px) rotate(${rot[k] * inP + (k - 1) * 24 * outP}deg)`;
      });
      const wi = clamp(Math.floor((t - 0.75) / 0.36), 0, S.hookWords.length - 1);
      const wLocal = t - 0.75 - wi * 0.36;
      R.word.textContent = S.hookWords[wi];
      R.word.style.transform = `scale(${0.82 + 0.18 * E.outBack(prog(wLocal, 0, 0.16))})`;
      R.word.style.opacity = t < 0.75 ? prog(t, 0.5, 0.75) : 0.3 + 0.7 * prog(wLocal, 0, 0.08);
      R.hookWords.forEach((el, i) => {
        const inP = spring(t - 0.22 - i * 0.2, 8, 9);
        const outP = prog(t, T.hookOut, T.hookOut + 0.32);
        el.style.opacity = clamp(inP * 1.4) * (1 - outP);
        el.style.transform = `translateY(${70 * (1 - inP) - 80 * E.in2(outP)}px)`;
      });
    }

    // ----- Werbezeilen -----
    R.captions.forEach((lines, c) => {
      const [a, b] = T.captions[c];
      lines.forEach((el, i) => {
        const inP = E.out3(prog(t, a + i * 0.1, a + 0.42 + i * 0.1));
        const outP = prog(t, b, b + 0.25);
        el.style.opacity = t < a || t > b + 0.25 ? 0 : inP * (1 - outP);
        el.style.transform = `translateY(${46 * (1 - inP) - 34 * E.in2(outP)}px)`;
      });
    });

    // ----- iPhone -----
    const phoneOn = t >= T.phoneIn && t < T.phoneOut[1];
    R.phone.style.display = phoneOn ? '' : 'none';
    if (phoneOn) {
      const inP = spring(t - T.phoneIn, 6.5, 7);
      const outP = E.in3(prog(t, T.phoneOut[0], T.phoneOut[1]));
      const y = 1700 * (1 - inP) + 5 * Math.sin(t * 1.1) + 1750 * outP;
      R.phone.style.transform = `translateY(${y}px) rotate(${5 * (1 - inP) - 4 * outP}deg)`;
      updateHome(t);
      updateDeck(t);
      updateLibrary(t);
      updateFinger(t);
    }

    // ----- Schluss -----
    const endOn = t >= T.endIn - 0.05;
    R.end.style.display = endOn ? '' : 'none';
    if (endOn) {
      const s = t - T.endIn;
      const iconP = spring(s, 6, 8.5);
      R.icon.style.opacity = clamp(s / 0.12);
      R.icon.style.transform = `scale(${0.35 + 0.65 * iconP}) rotate(${-14 * (1 - iconP)}deg)`;
      R.endCards.forEach((el, k) => {
        const p = spring(s - 0.18 - (1 - k) * 0.08, 6, 8);
        const rot = [-17, -8][k];
        const dx = [-54, -24][k];
        el.style.opacity = clamp((s - 0.1) / 0.12);
        el.style.transform = `translate(${dx * p}px, ${6 * p}px) rotate(${rot * p}deg) scale(${0.35 + 0.65 * clamp(iconP)})`;
      });
      const nameP = spring(s - 0.4, 7, 8);
      R.endName.style.opacity = clamp((s - 0.4) / 0.2);
      R.endName.style.transform = `translateY(${60 * (1 - nameP)}px)`;
      R.claim.forEach((el, i) => {
        const p = E.out3(prog(s, 0.72 + i * 0.07, 1.05 + i * 0.07));
        el.style.opacity = p;
        el.style.transform = `translateY(${26 * (1 - p)}px)`;
      });
      const ctaP = spring(s - 1.3, 6.5, 9);
      const breathe = 1 + 0.018 * Math.sin((s - 1.9) * 3.2) * prog(s, 1.9, 2.3);
      R.cta.style.opacity = clamp((s - 1.3) / 0.15);
      R.cta.style.transform = `translateX(-50%) scale(${(0.6 + 0.4 * ctaP) * breathe})`;
    }
  };

  function updateHome(t) {
    const second = t >= 8;
    const aiOn = second && t >= T.aiOn;
    const text = second ? typed(S.queryAI, t, T.type2) : typed(S.query, t, T.type1);
    setQuery(text, aiOn ? S.placeholderAI : S.placeholder);

    const [a, b] = second ? T.type2 : T.type1;
    const focused = t > a - 0.25 && t < b + 0.6;
    const typing = t >= a && t <= b;
    R.caret.style.opacity = focused && (typing || Math.floor(t * 2.2) % 2 === 0) ? 1 : 0;

    R.spark.style.background = aiOn ? 'var(--accent)' : 'var(--fill)';
    R.spark.style.color = aiOn ? '#fff' : 'var(--ink2)';
    R.spark.style.transform = `scale(${1 + 0.32 * bump(prog(t, T.aiOn, T.aiOn + 0.38))})`;
    R.search.style.boxShadow = aiOn
      ? '0 10px 15px rgba(0,0,0,.06), inset 0 0 0 1.5px var(--accent)'
      : '0 10px 15px rgba(0,0,0,.06), inset 0 0 0 1px var(--hairline)';

    const full = !second && text === S.query;
    R.chips.forEach((el, i) => el.classList.toggle('on', full && i === 0));

    const idx = second ? 2 : lerp(1, 2, E.inOut(prog(t, T.slider[0], T.slider[1])));
    const x = (idx / 5) * (R.trackW - 38);
    R.thumb.style.transform = `translateX(${x}px)`;
    R.fillbar.style.width = `${x + 19}px`;
    R.rv.textContent = idx < 1.5 ? '1' : '2';
    R.ticks.forEach((el, i) => el.classList.toggle('on', i === Math.round(idx)));

    const press = bump(prog(t, T.go1 - 0.08, T.go1 + 0.16)) + bump(prog(t, T.go2 - 0.08, T.go2 + 0.16));
    R.go.style.opacity = text ? 1 : 0.45;
    R.go.style.transform = `scale(${1 - 0.045 * press})`;
  }

  function updateDeck(t) {
    const first = t < 12.5;
    let y;
    if (t < 8) y = 1 - E.out3(prog(t, T.deckUp1[0], T.deckUp1[1]));
    else if (first) y = E.inOut(prog(t, T.deckDown1[0], T.deckDown1[1]));
    else if (t < 15.5) y = 1 - E.out3(prog(t, T.deckUp2[0], T.deckUp2[1]));
    else y = E.inOut(prog(t, T.deckDown2[0], T.deckDown2[1]));
    R.deck.style.visibility = y >= 1 ? 'hidden' : 'visible';
    R.deck.style.transform = `translateY(${y * 100}%)`;
    if (y >= 1) return;

    const cardsAt = first ? T.cardsIn1 : T.cardsIn2;
    const cardsP = E.out3(prog(t, cardsAt, cardsAt + 0.35));
    const round = first ? R.r1 : R.r2;
    // display statt visibility: Die Karten setzen ihre eigene Sichtbarkeit und würden die der Runde übersteuern.
    R.r1.style.display = first ? '' : 'none';
    R.r2.style.display = first ? 'none' : '';
    round.style.opacity = cardsP;
    round.style.transform = `scale(${0.93 + 0.07 * cardsP})`;

    R.loader.style.opacity = 1 - prog(t, cardsAt - 0.12, cardsAt + 0.05);
    R.ring.style.display = first ? '' : 'none';
    R.ring.style.transform = `rotate(${t * 420}deg)`;
    R.loaderAI.style.display = first ? 'none' : '';
    R.loaderAI.style.transform = `scale(${1 + 0.12 * Math.sin(t * 9)})`;
    R.loaderText.textContent = first ? S.loading : S.loadingAI;

    const swipes = first ? SWIPES1 : SWIPES2;
    const done = layoutDeck(first ? R.cards1 : R.cards2, swipes, t);
    R.deckQ.textContent = first ? S.query : S.queryAI;
    R.counter.textContent = t < cardsAt ? '–' : `${done + 1}/${first ? 10 : 6}`;

    let like = 0;
    let skip = 0;
    for (const sw of swipes) {
      const p = bump(prog(t, sw.h1, sw.h1 + 0.36));
      if (sw.dir > 0) like += p;
      else skip += p;
    }
    R.likebtn.style.transform = `scale(${1 + 0.24 * like})`;
    R.skipbtn.style.transform = `scale(${1 + 0.24 * skip})`;

    if (!first) {
      const glow = bump(prog(t, cardsAt + 0.35, cardsAt + 0.8));
      R.reason.style.background = `rgba(47, 75, 255, ${0.75 * glow})`;
    }
  }

  function updateLibrary(t) {
    const on = t >= 14.6;
    R.library.style.visibility = on ? 'visible' : 'hidden';
    if (!on) return;
    R.tiles.forEach((el, i) => {
      const s = t - T.tilesIn - i * 0.08;
      const p = spring(s, 8, 9);
      const press = i === 0 ? bump(prog(t, T.tileTap - 0.08, T.tileTap + 0.14)) : 0;
      el.style.opacity = clamp(s / 0.14);
      el.style.transform = `translateY(${30 * (1 - p)}px) scale(${0.86 + 0.14 * p - 0.045 * press})`;
    });
    const up = E.out3(prog(t, T.sheetUp[0], T.sheetUp[1]));
    R.sheet.style.transform = `translateY(${(1 - up) * 105}%)`;
    R.dimLayer.style.opacity = 0.38 * up;
    const a = T.sheetUp[1] + 0.12;
    const mix = prog(t, a, a + 0.12);
    const pulse = bump(prog(t, a, a + 0.26)) + bump(prog(t, a + 0.26, a + 0.52));
    R.routeAct.style.background = mix > 0.5 ? 'var(--accent)' : 'var(--surface)';
    R.routeAct.style.color = mix > 0.5 ? '#fff' : 'var(--ink)';
    R.routeAct.style.boxShadow = mix > 0.5 ? '0 8px 18px rgba(47,75,255,.35)' : 'inset 0 0 0 1px var(--hairline)';
    R.routeAct.style.transform = `scale(${1 + 0.09 * pulse})`;
  }

  function updateFinger(t) {
    const pt = R.pt;
    let f = null;

    // Umkreis ziehen
    if (t > T.slider[0] - 0.28 && t < T.slider[1] + 0.25) {
      const idx = lerp(1, 2, E.inOut(prog(t, T.slider[0], T.slider[1])));
      f = {
        x: pt.trackLeft + (idx / 5) * (R.trackW - 38) + 19,
        y: pt.trackY + 6,
        o: Math.min(prog(t, T.slider[0] - 0.28, T.slider[0] - 0.12), 1 - prog(t, T.slider[1] + 0.08, T.slider[1] + 0.25)),
        s: 0.9
      };
    }
    f = f || tap(t, T.go1, pt.go) || tap(t, T.aiOn, pt.spark) || tap(t, T.go2, pt.go) || tap(t, T.tileTap, pt.tile);

    // Wischen
    for (const sw of [...SWIPES1, ...SWIPES2]) {
      if (t > sw.t0 - 0.22 && t < sw.h1 + 0.16) {
        const x = t < sw.t0 ? 0 : swipeX(sw, Math.min(t, sw.h1)) * sw.dir;
        f = {
          x: pt.card[0] + x * 0.92 + sw.dir * 10,
          y: pt.card[1] + 70 - Math.abs(x) * 0.07,
          o: Math.min(prog(t, sw.t0 - 0.22, sw.t0 - 0.08), 1 - prog(t, sw.h1, sw.h1 + 0.16)),
          s: 0.92
        };
      }
    }

    if (!f) {
      R.finger.style.opacity = 0;
      return;
    }
    R.finger.style.opacity = f.o;
    R.finger.style.transform = `translate(${f.x}px, ${f.y}px) scale(${f.s})`;
  }
})();
