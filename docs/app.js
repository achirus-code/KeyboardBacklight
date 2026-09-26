// KeyboardBacklight – interaktive Vorschau der App.
// Die Logik folgt der App: 16 Stufen, mit ⌥⇧ 64, Einblendung 1,2 s, Tastenbelegung wie in AppState.swift.
(() => {
  'use strict';

  const $ = (sel, root = document) => root.querySelector(sel);
  const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];
  const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;

  // ——— Menüleisten-Symbol wie MenuBarIcon.swift: Balken mit fünf Punkten im Halbkreis ———
  function menuBarIconSVG(level) {
    const lit = level <= 0 ? 0 : Math.max(1, Math.ceil(level * 5));
    const cx = 11, cy = 12;
    let svg = `<rect x="${cx - 3.9}" y="${cy - 0.85}" width="7.8" height="1.7" rx="0.85" fill="currentColor"/>`;
    [180, 138, 90, 42, 0].forEach((deg, i) => {
      const rad = deg * Math.PI / 180;
      const on = i < lit;
      const x = (cx + Math.cos(rad) * 7.6).toFixed(2);
      const y = (cy - Math.sin(rad) * 7.6).toFixed(2);
      svg += `<circle cx="${x}" cy="${y}" r="${on ? 1.35 : 0.9}" fill="currentColor" opacity="${on ? 1 : 0.35}"/>`;
    });
    return svg;
  }
  $$('[data-menubar-icon]').forEach(el => { el.innerHTML = menuBarIconSVG(Number(el.dataset.menubarIcon)); });

  // ——— Tastatur (MacBook, deutsches Layout) ———
  const FN = [
    ['f1', 'i-sun-sm', 'Bildschirm dunkler'],
    ['f2', 'i-sun-lg', 'Bildschirm heller'],
    ['f3', 'i-mission', 'Mission Control'],
    ['f4', 'i-search', 'Spotlight 🔍'],
    ['f5', 'i-mic', 'Diktat 🎙'],
    ['f6', 'i-moon', 'Nicht stören 🌙'],
    ['f7', 'i-rewind', 'Zurück ◀◀'],
    ['f8', 'i-playpause', 'Wiedergabe ▶︎⏸'],
    ['f9', 'i-forward', 'Weiter ▶▶'],
    ['f10', 'i-speaker', 'Ton aus'],
    ['f11', 'i-vol-down', 'Leiser'],
    ['f12', 'i-vol-up', 'Lauter'],
  ];
  // Physische Position → KeyboardEvent.code (deutsches Layout auf US-Codes)
  const LETTER_CODES = { Z: 'KeyY', Ü: 'BracketLeft', Ö: 'Semicolon', Ä: 'Quote' };

  const legend = (text, cls = '') => `<span class="lg ${cls}">${text}</span>`;
  const twoLevel = (top, bottom) => `<span class="lg lg2"><span>${top}</span><span>${bottom}</span></span>`;
  const letter = ch => ({ id: 'k' + ch, code: LETTER_CODES[ch] || 'Key' + ch, html: legend(ch, 'lg-big'), name: ch });

  const ROWS = [
    [
      { id: 'esc', w: 1.5, code: 'Escape', html: legend('esc', 'lg-l'), name: 'esc' },
      ...FN.map(([id, icon, name]) => ({
        id, cls: 'fn', code: id.toUpperCase(), name, fnLabel: id.toUpperCase(),
        html: `<span class="lg"><svg aria-hidden="true"><use href="#${icon}"/></svg><small>${id.toUpperCase()}</small></span>`,
      })),
      { id: 'touchid', cls: 'touchid', html: '', name: 'Touch ID' },
    ],
    [
      ...[['°', '^', 'Backquote'], ['!', '1'], ['"', '2'], ['§', '3'], ['$', '4'], ['%', '5'], ['&amp;', '6'],
        ['/', '7'], ['(', '8'], [')', '9'], ['=', '0'], ['?', 'ß', 'Minus'], ['`', '´', 'Equal']]
        .map(([top, bottom, code]) => ({ id: 'n' + bottom, code: code || 'Digit' + bottom, html: twoLevel(top, bottom), name: bottom })),
      { id: 'bksp', w: 1.5, code: 'Backspace', html: legend('⌫', 'lg-r'), name: '⌫' },
    ],
    [
      { id: 'tab', w: 1.5, code: 'Tab', html: legend('⇥', 'lg-l'), name: '⇥' },
      ...[...'QWERTZUIOPÜ'].map(letter),
      { id: 'plus', code: 'BracketRight', html: twoLevel('*', '+'), name: '+' },
      { id: 'enter', cls: 'enter-top', code: 'Enter', html: legend('↩', 'lg-r'), name: '↩' },
    ],
    [
      { id: 'caps', w: 1.75, code: 'CapsLock', html: legend('⇪', 'lg-l'), name: '⇪' },
      ...[...'ASDFGHJKLÖÄ'].map(letter),
      { id: 'hash', code: 'Backslash', html: twoLevel("'", '#'), name: '#' },
      { id: 'enter', w: 0.75, cls: 'enter-bottom', html: '', name: '↩' },
    ],
  ];

  const KEYS = {};        // id → Taste
  const CODE_TO_ID = {};  // KeyboardEvent.code → id
  ROWS.flat().forEach(k => {
    KEYS[k.id] = KEYS[k.id] || k;
    if (k.code) CODE_TO_ID[k.code] = k.id;
  });

  const kb = $('#kb');
  const kbInner = document.createElement('div');
  kbInner.className = 'kb-inner';
  ROWS.forEach((row, i) => {
    const rowEl = document.createElement('div');
    rowEl.className = i === 0 ? 'row row-fn' : 'row';
    row.forEach(k => {
      const b = document.createElement('button');
      b.type = 'button';
      b.className = 'key' + (k.cls ? ' ' + k.cls : '');
      b.dataset.id = k.id;
      if (k.w) b.style.setProperty('--w', k.w);
      b.innerHTML = k.html + '<span class="tag"></span>';
      b.tabIndex = -1;
      if (k.id === 'touchid' || k.cls === 'enter-bottom') b.setAttribute('aria-hidden', 'true');
      else b.setAttribute('aria-label', k.fnLabel ? `${k.fnLabel} – ${k.name}` : `Taste ${k.name}`);
      rowEl.append(b);
    });
    kbInner.append(rowEl);
  });
  kb.append(kbInner);
  kb.classList.add('hint');

  // ——— Zustand ———
  const DEFAULTS = {
    darker: [{ id: 'f6', label: 'Nicht stören 🌙' }, { id: 'f6', label: 'F6' }],
    brighter: [{ id: 'f7', label: 'Zurück ◀◀' }, { id: 'f7', label: 'Zurückspulen ◀◀' }, { id: 'f7', label: 'F7' }],
  };
  const state = {
    brightness: 6 / 16,
    enabled: true,
    auto: false,
    showHUD: true,
    hideIcon: false,
    login: false,
    darker: DEFAULTS.darker,
    brighter: DEFAULTS.brighter,
    learning: null,
  };
  let lastChange = 0;
  let hudTimer = 0;

  const el = {
    device: $('#device'),
    status: $('#demo-status'),
    mbApp: $('#mb-app'),
    mbIcon: $('#mb-icon'),
    hud: $('#hud'),
    hudUse: $('#hud-use'),
    hudBar: $('#hud-bar'),
    popover: $('#popover'),
    enabled: $('#opt-enabled'),
    range: $('#opt-brightness'),
    pct: $('#opt-pct'),
    auto: $('#opt-auto'),
    hud2: $('#opt-hud'),
    hide: $('#opt-hide'),
    login: $('#opt-login'),
    labels: { darker: $('#label-darker'), brighter: $('#label-brighter') },
    learnButtons: $$('[data-learn]'),
  };
  el.hudBar.innerHTML = '<i></i>'.repeat(16);

  const actionFor = id =>
    state.darker.some(t => t.id === id) ? 'darker' : state.brighter.some(t => t.id === id) ? 'brighter' : null;
  const nameOf = id => (KEYS[id].fnLabel ? KEYS[id].name : `Taste ${KEYS[id].name}`);
  const labelFor = action => (state[action].length ? state[action].map(t => t.label).join(', ') : '–');
  const status = html => { el.status.innerHTML = html; };

  // ——— Helligkeit ———
  function setBrightness(value, overlay) {
    // Wie in der App: Die Automatik würde die Beleuchtung bei hellem Licht aushalten → abschalten
    state.auto = false;
    state.brightness = Math.min(1, Math.max(0, value));
    lastChange = performance.now();
    if (overlay && state.showHUD) showHUD();
    render();
  }

  function step(action, fine) {
    const n = fine ? 64 : 16;
    const next = Math.round(state.brightness * n) + (action === 'brighter' ? 1 : -1);
    setBrightness(next / n, true);
    const pct = Math.round(state.brightness * 100);
    status(`<b>${action === 'brighter' ? 'Heller' : 'Dunkler'}</b> · ${pct} %${fine ? ' · feiner Schritt' : ''}`);
  }

  function perform(action, fine, isRepeat) {
    kb.classList.remove('hint');
    if (!state.enabled) {
      status('Das Abfangen ist ausgeschaltet – macOS bekommt die Taste.');
      return;
    }
    // Gedrückt halten: auf ein angenehmes Tempo bremsen
    if (isRepeat && performance.now() - lastChange < 90) return;
    step(action, fine);
  }

  function showHUD() {
    el.hud.classList.add('is-visible');
    clearTimeout(hudTimer);
    hudTimer = setTimeout(() => el.hud.classList.remove('is-visible'), 1200);
  }

  // ——— Tasten ———
  function flashKey(id) {
    $$(`.key[data-id="${id}"]`, kb).forEach(k => {
      k.classList.add('is-pressed');
      clearTimeout(k._t);
      k._t = setTimeout(() => k.classList.remove('is-pressed'), 130);
    });
  }

  function pressKey(id, fine, isRepeat) {
    if (!KEYS[id] || id === 'touchid') return;
    flashKey(id);
    if (state.learning) {
      if (id === 'esc') cancelLearning();
      else assign(id);
      return;
    }
    const action = actionFor(id);
    if (action) {
      perform(action, fine, isRepeat);
    } else if (!isRepeat) {
      status(`<b>${nameOf(id)}</b> ist nicht belegt – die Taste geht wie gewohnt an macOS.`);
    }
  }

  function assign(id) {
    const action = state.learning;
    const trigger = { id, label: KEYS[id].fnLabel ? KEYS[id].name : `Taste ${KEYS[id].name}` };
    state.darker = state.darker.filter(t => t.id !== id);
    state.brighter = state.brighter.filter(t => t.id !== id);
    state[action] = [trigger];
    state.learning = null;
    kb.classList.remove('hint');
    status(`<b>${action === 'darker' ? 'Dunkler' : 'Heller'}</b> liegt jetzt auf ${trigger.label}.`);
    render();
  }

  function cancelLearning() {
    state.learning = null;
    status('Abgebrochen.');
    render();
  }

  // Maus und Touch: Drücken löst aus, Halten wiederholt
  let holdDelay = 0;
  let holdRepeat = 0;
  const stopHold = () => { clearTimeout(holdDelay); clearInterval(holdRepeat); };
  kb.addEventListener('pointerdown', e => {
    const key = e.target.closest('.key');
    if (!key || e.button > 0) return;
    e.preventDefault();
    const id = key.dataset.id;
    const fine = e.altKey && e.shiftKey;
    const learning = !!state.learning;
    pressKey(id, fine, false);
    stopHold();
    if (!learning && actionFor(id)) {
      holdDelay = setTimeout(() => { holdRepeat = setInterval(() => pressKey(id, fine, true), 90); }, 400);
    }
  });
  ['pointerup', 'pointercancel', 'blur'].forEach(type => window.addEventListener(type, stopHold));
  kb.addEventListener('pointerleave', stopHold);
  kb.addEventListener('contextmenu', e => e.preventDefault());
  // Tastatur-Bedienung einer fokussierten Taste (Enter/Leertaste)
  kb.addEventListener('click', e => {
    const key = e.target.closest('.key');
    if (key && e.detail === 0) pressKey(key.dataset.id, false, false);
  });

  // Echte Tastatur: ← / → als Abkürzung, belegte Tasten, im Lernmodus jede Taste
  let demoVisible = false;
  if ('IntersectionObserver' in window) {
    new IntersectionObserver(entries => { demoVisible = entries[0].isIntersecting; }, { threshold: 0.15 }).observe(el.device);
  }

  document.addEventListener('keydown', e => {
    if (e.metaKey || e.ctrlKey) return;
    const target = e.target;
    if (state.learning) {
      if (e.code === 'Escape') {
        e.preventDefault();
        flashKey('esc');
        cancelLearning();
        return;
      }
      const id = CODE_TO_ID[e.code];
      if (id) {
        e.preventDefault();
        pressKey(id, false, false);
      }
      return;
    }
    if (!demoVisible) return;

    if (e.key === 'ArrowLeft' || e.key === 'ArrowRight') {
      if (target.matches && target.matches('input[type="range"], textarea, select, input[type="text"]')) return;
      e.preventDefault();
      const action = e.key === 'ArrowLeft' ? 'darker' : 'brighter';
      if (state[action][0]) flashKey(state[action][0].id);
      perform(action, e.altKey && e.shiftKey, e.repeat);
      return;
    }
    if (target.matches && target.matches('input, textarea, select')) return;
    const id = CODE_TO_ID[e.code];
    if (id && actionFor(id)) {
      if (e.key === 'Enter' && target.closest && target.closest('button, a, summary')) return;
      e.preventDefault();
      pressKey(id, e.altKey && e.shiftKey, e.repeat);
    }
  });

  // ——— Einstellungsfenster ———
  el.enabled.addEventListener('change', () => {
    state.enabled = el.enabled.checked;
    status(state.enabled ? 'Tasten werden wieder abgefangen.' : 'Abfangen aus – „Nicht stören“ und „Zurück“ gehen wieder an macOS.');
    render();
  });
  el.range.addEventListener('input', () => {
    setBrightness(Number(el.range.value), false);
    status(`Helligkeit ${Math.round(state.brightness * 100)} %`);
  });
  el.auto.addEventListener('change', () => {
    state.auto = el.auto.checked;
    status(state.auto ? 'Automatik an – der nächste Tastendruck schaltet sie wieder ab.' : 'Automatik aus.');
  });
  el.hud2.addEventListener('change', () => { state.showHUD = el.hud2.checked; });
  el.hide.addEventListener('change', () => {
    state.hideIcon = el.hide.checked;
    status(state.hideIcon
      ? 'Icon ausgeblendet – die Tasten funktionieren weiter. Zurückholen: App erneut öffnen.'
      : 'Icon wieder in der Menüleiste.');
    render();
  });
  el.login.addEventListener('change', () => { state.login = el.login.checked; });
  el.learnButtons.forEach(btn => btn.addEventListener('click', () => {
    const action = btn.dataset.learn;
    state.learning = state.learning === action ? null : action;
    status(state.learning ? 'Jetzt eine Taste drücken – auf der Tastatur oben oder auf deiner eigenen. <b>esc</b> bricht ab.' : 'Abgebrochen.');
    render();
  }));
  $('#btn-swap').addEventListener('click', () => {
    [state.darker, state.brighter] = [state.brighter, state.darker];
    status('Tasten getauscht.');
    render();
  });
  $('#btn-reset').addEventListener('click', () => {
    state.darker = DEFAULTS.darker;
    state.brighter = DEFAULTS.brighter;
    status('Standardbelegung: Mond-Taste dunkler, Zurück-Taste heller.');
    render();
  });
  $('#btn-quit').addEventListener('click', () => status('In der App beendet <b>Beenden</b> (⌘Q) KeyboardBacklight.'));
  $('#btn-close').addEventListener('click', () => status('In der App schließt <b>Schließen</b> das Fenster wieder.'));

  el.mbApp.addEventListener('click', () => {
    el.popover.classList.add('is-flash');
    el.mbApp.classList.add('is-active');
    setTimeout(() => {
      el.popover.classList.remove('is-flash');
      el.mbApp.classList.remove('is-active');
    }, 900);
    const r = el.popover.getBoundingClientRect();
    if (r.top < 64 || r.bottom > innerHeight) {
      el.popover.scrollIntoView({ behavior: reduceMotion ? 'auto' : 'smooth', block: 'center' });
    }
  });

  // ——— Darstellung ———
  function render() {
    const b = state.brightness;
    kb.style.setProperty('--b', b.toFixed(4));
    kb.classList.toggle('is-disabled', !state.enabled);
    kb.classList.toggle('is-learning', !!state.learning);

    $$('.key', kb).forEach(k => {
      const action = actionFor(k.dataset.id);
      k.classList.toggle('is-bound', !!action);
      // Liegen zwei belegte Tasten nebeneinander, zeigen ihre Schilder nach außen
      const prev = k.previousElementSibling, next = k.nextElementSibling;
      k.classList.toggle('tag-left', !!action && !!next && !!actionFor(next.dataset.id));
      k.classList.toggle('tag-right', !!action && !!prev && !!actionFor(prev.dataset.id));
      k.querySelector('.tag').textContent = action === 'darker' ? '− dunkler' : action === 'brighter' ? '+ heller' : '';
      if (!k.hasAttribute('aria-hidden')) k.tabIndex = action ? 0 : -1;
    });

    el.mbIcon.innerHTML = menuBarIconSVG(b);
    el.mbApp.hidden = state.hideIcon;

    el.range.value = b;
    el.range.style.setProperty('--pct', (b * 100).toFixed(2) + '%');
    el.pct.textContent = Math.round(b * 100) + ' %';
    el.enabled.checked = state.enabled;
    el.auto.checked = state.auto;
    el.hud2.checked = state.showHUD;
    el.hide.checked = state.hideIcon;
    el.login.checked = state.login;

    ['darker', 'brighter'].forEach(action => {
      const learning = state.learning === action;
      el.labels[action].textContent = learning ? 'Taste drücken … (Esc)' : labelFor(action);
      el.labels[action].classList.toggle('is-learning', learning);
    });
    el.learnButtons.forEach(btn => { btn.textContent = state.learning === btn.dataset.learn ? 'Abbrechen' : 'Ändern'; });

    el.hudUse.setAttribute('href', b > 0 ? '#i-light-max' : '#i-light-min');
    const lit = Math.round(b * 16);
    [...el.hudBar.children].forEach((seg, i) => seg.classList.toggle('on', i < lit));
  }
  render();

  // ——— Uhrzeit in der Menüleiste (wie macOS: „Sa. 26. Sept. 9:41“) ———
  const WEEKDAYS = ['So.', 'Mo.', 'Di.', 'Mi.', 'Do.', 'Fr.', 'Sa.'];
  const MONTHS = ['Jan.', 'Feb.', 'März', 'Apr.', 'Mai', 'Juni', 'Juli', 'Aug.', 'Sept.', 'Okt.', 'Nov.', 'Dez.'];
  function tick() {
    const d = new Date();
    $('#mb-date').textContent = `${WEEKDAYS[d.getDay()]} ${d.getDate()}. ${MONTHS[d.getMonth()]}`;
    $('#mb-time').textContent = `${d.getHours()}:${String(d.getMinutes()).padStart(2, '0')}`;
  }
  tick();
  setInterval(tick, 15000);

  // ——— Befehle kopieren ———
  $$('.copy').forEach(btn => btn.addEventListener('click', async () => {
    const text = btn.parentElement.querySelector('code').textContent;
    try {
      await navigator.clipboard.writeText(text);
    } catch {
      const range = document.createRange();
      range.selectNodeContents(btn.parentElement.querySelector('code'));
      getSelection().removeAllRanges();
      getSelection().addRange(range);
      return;
    }
    const use = btn.querySelector('use');
    btn.classList.add('is-done');
    use.setAttribute('href', '#i-check');
    setTimeout(() => {
      btn.classList.remove('is-done');
      use.setAttribute('href', '#i-copy');
    }, 1600);
  }));

  // ——— Sanftes Einblenden beim Scrollen ———
  if (!reduceMotion && 'IntersectionObserver' in window) {
    const targets = $$('.section-head, .card, .spec > div, .faq details');
    const io = new IntersectionObserver(entries => entries.forEach(entry => {
      if (!entry.isIntersecting) return;
      entry.target.classList.add('is-in');
      io.unobserve(entry.target);
    }), { rootMargin: '0px 0px -8% 0px' });
    targets.forEach(t => { t.classList.add('reveal'); io.observe(t); });
  }
})();
