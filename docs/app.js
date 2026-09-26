// KeyboardBacklight – interaktive Vorschau der App.
// Die Logik folgt der App: 16 Stufen, mit ⌥⇧ 64, Einblendung 1,2 s, Tastenbelegung wie in AppState.swift.
(() => {
  'use strict';

  const $ = (sel, root = document) => root.querySelector(sel);
  const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];
  const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;

  // ——— Texte: Die Seite gibt es auf Deutsch (/) und Englisch (/en/), <html lang> wählt die Sprache ———
  const LANG = document.documentElement.lang === 'en' ? 'en' : 'de';
  const TEXT = {
    de: {
      fn: ['Bildschirm dunkler', 'Bildschirm heller', 'Mission Control', 'Spotlight 🔍', 'Diktat 🎙', 'Nicht stören 🌙',
        'Zurück ◀◀', 'Wiedergabe/Pause ▶︎⏸', 'Weiter ▶▶', 'Ton aus', 'Leiser', 'Lauter'],
      key: name => `Taste ${name}`,
      darker: 'Dunkler', brighter: 'Heller',
      tagDarker: '− dunkler', tagBrighter: '+ heller',
      fineStep: 'feiner Schritt',
      captureOff: 'Das Abfangen ist ausgeschaltet – macOS bekommt die Taste.',
      notBound: name => `<b>${name}</b> ist nicht belegt – die Taste geht wie gewohnt an macOS.`,
      assigned: (action, label) => `<b>${action}</b> liegt jetzt auf ${label}.`,
      cancelled: 'Abgebrochen.',
      captureOnAgain: 'Tasten werden wieder abgefangen.',
      captureOffNow: 'Abfangen aus – die Tasten gehen wieder an macOS.',
      brightness: pct => `Helligkeit ${pct} %`,
      autoOn: 'Automatik an – der nächste Tastendruck schaltet sie wieder ab.',
      autoOff: 'Automatik aus.',
      iconHidden: 'Icon ausgeblendet – die Tasten funktionieren weiter. Zurückholen: App erneut öffnen.',
      iconShown: 'Icon wieder in der Menüleiste.',
      learn: 'Jetzt eine Taste drücken – auf der Tastatur oben oder auf deiner eigenen. <b>esc</b> bricht ab.',
      swapped: 'Tasten getauscht.',
      reset: 'Standardbelegung: F5 dunkler, F6 heller.',
      quit: 'In der App beendet <b>Beenden</b> (⌘Q) KeyboardBacklight. Ein Klick neben das Fenster schließt es.',
      pressKey: 'Taste drücken … (Esc)', cancel: 'Abbrechen', change: 'Ändern',
    },
    en: {
      fn: ['Display Darker', 'Display Brighter', 'Mission Control', 'Spotlight 🔍', 'Dictation 🎙', 'Do Not Disturb 🌙',
        'Previous ◀◀', 'Play/Pause ▶︎⏸', 'Next ▶▶', 'Mute', 'Volume Down', 'Volume Up'],
      key: name => `Key ${name}`,
      darker: 'Darker', brighter: 'Brighter',
      tagDarker: '− darker', tagBrighter: '+ brighter',
      fineStep: 'fine step',
      captureOff: 'Capturing is off – macOS gets the key.',
      notBound: name => `<b>${name}</b> isn't assigned – the key goes to macOS as usual.`,
      assigned: (action, label) => `<b>${action}</b> is now on ${label}.`,
      cancelled: 'Cancelled.',
      captureOnAgain: 'Keys are captured again.',
      captureOffNow: 'Capturing off – the keys go to macOS again.',
      brightness: pct => `Brightness ${pct} %`,
      autoOn: 'Automatic adjustment on – the next key press turns it off again.',
      autoOff: 'Automatic adjustment off.',
      iconHidden: 'Icon hidden – the keys keep working. To bring it back, open the app again.',
      iconShown: 'Icon is back in the menu bar.',
      learn: 'Now press a key – on the keyboard above or on your own. <b>esc</b> cancels.',
      swapped: 'Keys swapped.',
      reset: 'Default: F5 darker, F6 brighter.',
      quit: 'In the app, <b>Quit</b> (⌘Q) quits KeyboardBacklight. Clicking outside the window closes it.',
      pressKey: 'Press a key … (Esc)', cancel: 'Cancel', change: 'Change',
    },
  }[LANG];

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

  // ——— Tastatur (MacBook, deutsches bzw. US-Layout je nach Seitensprache) ———
  const FN = ['i-sun-sm', 'i-sun-lg', 'i-mission', 'i-search', 'i-mic', 'i-moon',
    'i-rewind', 'i-playpause', 'i-forward', 'i-speaker', 'i-vol-down', 'i-vol-up']
    .map((icon, i) => [`f${i + 1}`, icon, TEXT.fn[i]]);
  // Physische Position → KeyboardEvent.code (deutsches Layout auf US-Codes)
  const LETTER_CODES = LANG === 'de' ? { Z: 'KeyY', Ü: 'BracketLeft', Ö: 'Semicolon', Ä: 'Quote' } : {};

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
      ...(LANG === 'de'
        ? [['°', '^', 'Backquote'], ['!', '1'], ['"', '2'], ['§', '3'], ['$', '4'], ['%', '5'], ['&amp;', '6'],
          ['/', '7'], ['(', '8'], [')', '9'], ['=', '0'], ['?', 'ß', 'Minus'], ['`', '´', 'Equal']]
        : [['~', '`', 'Backquote'], ['!', '1'], ['@', '2'], ['#', '3'], ['$', '4'], ['%', '5'], ['^', '6'],
          ['&amp;', '7'], ['*', '8'], ['(', '9'], [')', '0'], ['_', '-', 'Minus'], ['+', '=', 'Equal']])
        .map(([top, bottom, code]) => ({ id: 'n' + bottom, code: code || 'Digit' + bottom, html: twoLevel(top, bottom), name: bottom })),
      { id: 'bksp', w: 1.5, code: 'Backspace', html: legend('⌫', 'lg-r'), name: '⌫' },
    ],
    [
      { id: 'tab', w: 1.5, code: 'Tab', html: legend('⇥', 'lg-l'), name: '⇥' },
      ...(LANG === 'de'
        ? [...[...'QWERTZUIOPÜ'].map(letter), { id: 'plus', code: 'BracketRight', html: twoLevel('*', '+'), name: '+' }]
        : [...[...'QWERTYUIOP'].map(letter),
          { id: 'lbr', code: 'BracketLeft', html: twoLevel('{', '['), name: '[' },
          { id: 'rbr', code: 'BracketRight', html: twoLevel('}', ']'), name: ']' }]),
      { id: 'enter', cls: 'enter-top', code: 'Enter', html: legend('↩', 'lg-r'), name: '↩' },
    ],
    [
      { id: 'caps', w: 1.75, code: 'CapsLock', html: legend('⇪', 'lg-l'), name: '⇪' },
      ...(LANG === 'de'
        ? [...[...'ASDFGHJKLÖÄ'].map(letter), { id: 'hash', code: 'Backslash', html: twoLevel("'", '#'), name: '#' }]
        : [...[...'ASDFGHJKL'].map(letter),
          { id: 'semi', code: 'Semicolon', html: twoLevel(':', ';'), name: ';' },
          { id: 'quote', code: 'Quote', html: twoLevel('"', "'"), name: "'" },
          { id: 'bsl', code: 'Backslash', html: twoLevel('|', '\\'), name: '\\' }]),
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
      else b.setAttribute('aria-label', k.fnLabel ? `${k.fnLabel} – ${k.name}` : TEXT.key(k.name));
      rowEl.append(b);
    });
    kbInner.append(rowEl);
  });
  kb.append(kbInner);
  kb.classList.add('hint');

  // ——— Zustand ———
  const DEFAULTS = {
    darker: [{ id: 'f5', label: TEXT.fn[4] }, { id: 'f5', label: 'F5' }],
    brighter: [{ id: 'f6', label: TEXT.fn[5] }, { id: 'f6', label: 'F6' }],
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
  const nameOf = id => KEYS[id].fnLabel || TEXT.key(KEYS[id].name);
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
    status(`<b>${action === 'brighter' ? TEXT.brighter : TEXT.darker}</b> · ${pct} %${fine ? ` · ${TEXT.fineStep}` : ''}`);
  }

  function perform(action, fine, isRepeat) {
    kb.classList.remove('hint');
    if (!state.enabled) {
      status(TEXT.captureOff);
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
      status(TEXT.notBound(nameOf(id)));
    }
  }

  function assign(id) {
    const action = state.learning;
    const trigger = { id, label: KEYS[id].fnLabel ? KEYS[id].name : TEXT.key(KEYS[id].name) };
    state.darker = state.darker.filter(t => t.id !== id);
    state.brighter = state.brighter.filter(t => t.id !== id);
    state[action] = [trigger];
    state.learning = null;
    kb.classList.remove('hint');
    status(TEXT.assigned(action === 'darker' ? TEXT.darker : TEXT.brighter, trigger.label));
    render();
  }

  function cancelLearning() {
    state.learning = null;
    status(TEXT.cancelled);
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
    status(state.enabled ? TEXT.captureOnAgain : TEXT.captureOffNow);
    render();
  });
  el.range.addEventListener('input', () => {
    setBrightness(Number(el.range.value), false);
    status(TEXT.brightness(Math.round(state.brightness * 100)));
  });
  el.auto.addEventListener('change', () => {
    state.auto = el.auto.checked;
    status(state.auto ? TEXT.autoOn : TEXT.autoOff);
  });
  el.hud2.addEventListener('change', () => { state.showHUD = el.hud2.checked; });
  el.hide.addEventListener('change', () => {
    state.hideIcon = el.hide.checked;
    status(state.hideIcon ? TEXT.iconHidden : TEXT.iconShown);
    render();
  });
  el.login.addEventListener('change', () => { state.login = el.login.checked; });
  el.learnButtons.forEach(btn => btn.addEventListener('click', () => {
    const action = btn.dataset.learn;
    state.learning = state.learning === action ? null : action;
    status(state.learning ? TEXT.learn : TEXT.cancelled);
    render();
  }));
  $('#btn-swap').addEventListener('click', () => {
    [state.darker, state.brighter] = [state.brighter, state.darker];
    status(TEXT.swapped);
    render();
  });
  $('#btn-reset').addEventListener('click', () => {
    state.darker = DEFAULTS.darker;
    state.brighter = DEFAULTS.brighter;
    status(TEXT.reset);
    render();
  });
  $('#btn-quit').addEventListener('click', () => status(TEXT.quit));

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
      k.querySelector('.tag').textContent = action === 'darker' ? TEXT.tagDarker : action === 'brighter' ? TEXT.tagBrighter : '';
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
      el.labels[action].textContent = learning ? TEXT.pressKey : labelFor(action);
      el.labels[action].classList.toggle('is-learning', learning);
    });
    el.learnButtons.forEach(btn => { btn.textContent = state.learning === btn.dataset.learn ? TEXT.cancel : TEXT.change; });

    el.hudUse.setAttribute('href', b > 0 ? '#i-light-max' : '#i-light-min');
    const lit = Math.round(b * 16);
    [...el.hudBar.children].forEach((seg, i) => seg.classList.toggle('on', i < lit));
  }
  render();

  // ——— Uhrzeit in der Menüleiste (wie macOS: „Sa. 26. Sept. 9:41“ bzw. „Sat Sep 26 9:41 AM“) ———
  const WEEKDAYS = LANG === 'de' ? ['So.', 'Mo.', 'Di.', 'Mi.', 'Do.', 'Fr.', 'Sa.'] : ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  const MONTHS = LANG === 'de'
    ? ['Jan.', 'Feb.', 'März', 'Apr.', 'Mai', 'Juni', 'Juli', 'Aug.', 'Sept.', 'Okt.', 'Nov.', 'Dez.']
    : ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  function tick() {
    const d = new Date();
    const min = String(d.getMinutes()).padStart(2, '0');
    if (LANG === 'de') {
      $('#mb-date').textContent = `${WEEKDAYS[d.getDay()]} ${d.getDate()}. ${MONTHS[d.getMonth()]}`;
      $('#mb-time').textContent = `${d.getHours()}:${min}`;
    } else {
      $('#mb-date').textContent = `${WEEKDAYS[d.getDay()]} ${MONTHS[d.getMonth()]} ${d.getDate()}`;
      $('#mb-time').textContent = `${d.getHours() % 12 || 12}:${min} ${d.getHours() < 12 ? 'AM' : 'PM'}`;
    }
  }
  tick();
  setInterval(tick, 15000);

  // ——— Sprachwahl merken (steuert die automatische Weiterleitung auf der deutschen Seite) ———
  $$('.lang-switch a').forEach(a => a.addEventListener('click', () => {
    try { localStorage.setItem('kb-lang', a.dataset.lang); } catch (e) {}
    a.href = a.getAttribute('href').split('#')[0] + location.hash;
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
