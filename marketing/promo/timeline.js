// Rechenhelfer und der Vorschau-Player. Das Video selbst ist eine reine Funktion der Zeit:
// Promo.seek(t) stellt den Zustand zur Sekunde t her – render.mjs ruft das Bild für Bild auf.
(function () {
  const P = (window.Promo = window.Promo || {});

  const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
  const prog = (t, a, b) => clamp((t - a) / (b - a));
  const lerp = (a, b, p) => a + (b - a) * p;
  const E = {
    out3: (p) => 1 - Math.pow(1 - p, 3),
    in2: (p) => p * p,
    in3: (p) => p * p * p,
    inOut: (p) => (p < 0.5 ? 4 * p * p * p : 1 - Math.pow(-2 * p + 2, 3) / 2),
    outBack: (p) => 1 + 2.4 * Math.pow(p - 1, 3) + 1.4 * Math.pow(p - 1, 2)
  };
  /** Gedämpfte Feder: 0 bei s ≤ 0, schwingt leicht über und landet bei 1. `s` in Sekunden seit Start. */
  const spring = (s, damp = 7, freq = 9) => (s <= 0 ? 0 : 1 - Math.exp(-damp * s) * Math.cos(freq * s));
  /** 0 → 1 → 0 über p = 0…1. */
  const bump = (p) => Math.sin(Math.PI * clamp(p));

  P.math = { clamp, prog, lerp, E, spring, bump };
  P.duration = 22;
  P.fps = 30;

  P.start = function () {
    const params = new URLSearchParams(location.search);
    const lang = params.get('lang') === 'en' ? 'en' : 'de';
    const isRender = params.has('render');
    document.documentElement.lang = lang;
    P.build(lang);

    let time = Number(params.get('t')) || 0;
    P.seek = function (t) {
      time = clamp(t, 0, P.duration);
      P.update(time);
    };
    P.seek(time);
    if (isRender) return;

    // Vorschau: Bühne in das Fenster einpassen, Regler und Abspielen.
    document.body.classList.add('preview');
    const stage = document.getElementById('stage');
    const fit = () => {
      const k = Math.min(innerWidth / 1080, (innerHeight - 64) / 1920);
      stage.style.transform = `scale(${k})`;
      stage.style.marginLeft = `${(innerWidth - 1080 * k) / 2}px`;
    };
    addEventListener('resize', fit);
    fit();

    const bar = document.createElement('div');
    bar.className = 'controls';
    bar.innerHTML = `<button id="play">▶︎</button><input id="scrub" type="range" min="0" max="${P.duration}" step="0.01" value="${time}"><span id="clock"></span>
      <a href="?lang=${lang === 'de' ? 'en' : 'de'}">${lang === 'de' ? 'EN' : 'DE'}</a>`;
    document.body.appendChild(bar);
    const scrub = bar.querySelector('#scrub');
    const clock = bar.querySelector('#clock');
    const play = bar.querySelector('#play');
    let playing = false;
    let last = 0;
    const show = () => {
      scrub.value = time;
      clock.textContent = time.toFixed(2) + ' s';
    };
    const tick = (now) => {
      if (!playing) return;
      time += (now - last) / 1000;
      last = now;
      if (time >= P.duration) time = 0;
      P.update(time);
      show();
      requestAnimationFrame(tick);
    };
    const toggle = () => {
      playing = !playing;
      play.textContent = playing ? '❚❚' : '▶︎';
      if (playing) {
        last = performance.now();
        requestAnimationFrame(tick);
      }
    };
    play.onclick = toggle;
    scrub.oninput = () => {
      P.seek(Number(scrub.value));
      show();
    };
    addEventListener('keydown', (e) => {
      if (e.code === 'Space') {
        e.preventDefault();
        toggle();
      }
    });
    show();
  };
})();
