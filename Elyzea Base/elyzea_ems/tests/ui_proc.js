// Test de l'interface des actes médicaux (navigateur Chromium, hors jeu, paquet npm « playwright ») :
//   node tests/ui_proc.js   (depuis elyzea_ems/)   ·   UI_PROC_SHOTS=dossier pour garder les captures
// Chaque mini-jeu est joué jusqu'au bout par un « joueur » automatique qui n'utilise que la souris
// et le clavier (événements envoyés au canevas) ; il lit l'état affiché de l'étape pour viser.
const { chromium } = require('playwright');
const path = require('path');
const os = require('os');
const fs = require('fs');
const SHOTS = process.env.UI_PROC_SHOTS || fs.mkdtempSync(path.join(os.tmpdir(), 'ui-proc-'));

// Joueur automatique, injecté dans la page. mode : 'good' (réussir) ou 'wrong' (se tromper au premier choix)
function installBot() {
  const B = { mode: 'good', last: 0, held: {}, angle: 0, pressed: new Set(), drop: 0 };
  window.BOT = B;
  const W = 760, H = 440;
  const cv = () => document.querySelector('#pg canvas');
  const toClient = (x, y) => { const r = cv().getBoundingClientRect(); return { clientX: r.left + (x / W) * r.width, clientY: r.top + (y / H) * r.height }; };
  const ptr = (type, x, y, buttons) => {
    const c = toClient(x, y);
    const ev = new PointerEvent(type, { bubbles: true, cancelable: true, pointerId: 1, button: 0, buttons, ...c });
    (type === 'pointerup' ? window : cv()).dispatchEvent(ev);
  };
  const down = (x, y) => { ptr('pointerdown', x, y, 1); B.isDown = true; };
  const move = (x, y) => ptr('pointermove', x, y, B.isDown ? 1 : 0);
  const up = (x, y) => { ptr('pointerup', x, y, 0); B.isDown = false; };
  const click = (x, y) => { move(x, y); down(x, y); up(x, y); };
  const key = (code, on) => { if (!!B.held[code] === on) return; B.held[code] = on; window.dispatchEvent(new KeyboardEvent(on ? 'keydown' : 'keyup', { code, key: code === 'Space' ? ' ' : code.replace('Key', '').toLowerCase(), bubbles: true })); };
  const tap = (code) => { key(code, true); key(code, false); };
  const releaseKeys = () => Object.keys(B.held).forEach((k) => key(k, false));
  const pathAt = (pts, u) => {
    const segs = []; let total = 0;
    for (let k = 0; k < pts.length - 1; k++) { const a = pts[k], b = pts[k + 1], l = Math.hypot(b.x - a.x, b.y - a.y); segs.push({ a, b, l, s: total }); total += l; }
    const s = u * total;
    for (const sg of segs) if (s <= sg.s + sg.l) { const t = (s - sg.s) / sg.l; return { x: sg.a.x + (sg.b.x - sg.a.x) * t, y: sg.a.y + (sg.b.y - sg.a.y) * t }; }
    return pts[pts.length - 1];
  };
  let prevType = null;
  B.tick = () => {
    const S = window.ProcMG.cur;
    if (!S || S.ended) { if (B.isDown) up(380, 200); releaseKeys(); prevType = null; return; }
    let ph = S.phases[S.pi];
    const now = performance.now();
    if (ph.type === 'steps') {
      const st = ph.state;
      if (st.child) ph = st.child;
      else {
        if (B.isDown) up(S.m.x, S.m.y);
        if (now - B.last > 250) { B.last = now; const c = st.cards.find((x) => x.k === st.next); if (c) click(c.x + c.w / 2, c.y + c.h / 2); }
        return;
      }
    }
    if (ph.type !== prevType) { if (B.isDown) up(S.m.x, S.m.y); releaseKeys(); prevType = ph.type; B.drop = 0; }
    const o = ph.spec || {};
    switch (ph.type) {
      case 'choose': {
        if (now - B.last < 400) return; B.last = now;
        let it = o.items.find((i) => i.id === o.expect) || o.items[0];
        if (B.mode === 'wrong') it = o.items.find((i) => i.id !== o.expect) || it;
        click(it.x + it.w / 2, it.y + it.h / 2); return;
      }
      case 'rub': { B.angle += 0.45; const rr = (o.r * 0.9) * ((Math.sin(B.angle * 0.13) + 1) / 2); const x = o.cx + Math.cos(B.angle) * rr, y = o.cy + Math.sin(B.angle) * rr; if (!B.isDown) down(x, y); move(x, y); return; }
      case 'timing': { const c = o.center ?? 0.5, w = (o.width || 0.16) * S.k; if (Math.abs(ph.val() - c) < w * 0.25 && now - B.last > 450) { B.last = now; tap('Space'); } return; }
      case 'dial': { const v = ph.state.value; if (v < o.target - 0.012) { key('KeyA', false); key('KeyD', true); } else if (v > o.target + 0.012) { key('KeyD', false); key('KeyA', true); } else releaseKeys(); return; }
      case 'track': { const c = ph.center(S); const y = 60 + 300 * (1 - c); if (!B.isDown) down(200, y); move(200, y); return; }
      case 'points': { if (now - B.last < 250) return; B.last = now; const pt = o.pts[ph.state.next]; if (pt) click(pt.x, pt.y); return; }
      case 'path': {
        const st = ph.state;
        const head = pathAt(o.pts, st.p);
        if (!st.active) { if (B.isDown) up(head.x, head.y); move(head.x, head.y); down(head.x, head.y); return; }
        const ahead = pathAt(o.pts, Math.min(1, st.p + 0.02)); move(ahead.x, ahead.y); return;
      }
      case 'drop': {
        if (B.drop === 0) { move(o.from.x, o.from.y); down(o.from.x, o.from.y); B.drop = 1; return; }
        if (B.drop < 12) { const t = B.drop / 11; move(o.from.x + (o.to.x - o.from.x) * t, o.from.y + (o.to.y - o.from.y) * t); B.drop++; return; }
        up(o.to.x, o.to.y); B.drop = 0; return;
      }
      case 'circle': { B.angle += 0.2; const x = o.cx + Math.cos(B.angle) * o.r * 1.2, y = o.cy + Math.sin(B.angle) * o.r * 1.2; if (!B.isDown) down(x, y); move(x, y); return; }
      case 'find': { const st = ph.state; if (!B.isDown) down(st.x, st.y); move(st.x, st.y); if (st.ready && o.freeze && now - B.last > 300) { B.last = now; tap('Space'); } return; }
      case 'alerts': { if (ph.state.alert > 0 && now - B.last > 200) { B.last = now; tap('KeyE'); } return; }
      case 'vein': { if (now - B.last < 500) return; B.last = now; const x = 420; click(x, 230 + 16 * Math.sin(x * 0.018 + S.seedA)); return; }
      case 'align': {
        const st = ph.state; move(st.x, st.y);
        if (st.ang < st.a0 - 0.02) { key('KeyA', false); key('KeyD', true); } else if (st.ang > st.a0 + 0.02) { key('KeyD', false); key('KeyA', true); } else releaseKeys();
        return;
      }
      case 'pressure': { const st = ph.state; if (st.pressure < 0.53) { if (!B.isDown) down(380, 200); } else if (B.isDown) up(380, 200); move(380, 200); return; }
      case 'rhythm': {
        const st = ph.state; if (st.t < 0) return;
        const b = Math.round(st.t / st.beat);
        if (Math.abs(st.t - b * st.beat) < 0.035 && !B.pressed.has(b)) { B.pressed.add(b); tap('Space'); }
        return;
      }
      default: return;
    }
  };
  setInterval(B.tick, 15);
}

(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1600, height: 900 } });
  const errs = [];
  p.on('pageerror', (e) => errs.push(e.message));
  p.on('console', (m) => { if (m.type() === 'error' && !m.text().includes('ERR_')) errs.push(m.text()); });
  await p.route('**/*', (r) => (r.request().url().startsWith('file:') ? r.continue() : r.abort()));
  await p.goto('file://' + path.join(__dirname, '..', 'html', 'index.html'));
  await p.evaluate(() => { window.OUT = []; window.ProcOut = (n, d) => window.OUT.push({ n, d }); });
  await p.evaluate(installBot);
  let fails = 0, total = 0;
  const check = (label, ok, detail) => { total++; if (!ok) fails++; console.log(`${ok ? 'OK  ' : 'FAIL'} ${label}${ok || detail === undefined ? '' : ' -> ' + JSON.stringify(detail)}`); };

  const tubes = [{ id: 'gris', label: 'Tube gris (fluorure)', color: '#9ca3af' }, { id: 'violet', label: 'Tube violet (EDTA)', color: '#a855f7' }, { id: 'rouge', label: 'Tube rouge (sec)', color: '#ef4444' }];
  const zones = [{ id: 'deltoide', label: 'Deltoïde (épaule)' }, { id: 'cuisse', label: 'Face externe de la cuisse' }, { id: 'fesse', label: 'Quadrant supérieur externe de la fesse' }];
  const GAMES = [
    { act: 'blood', duration: 12, extra: { tubes, expect: 'gris', analysis: 'Alcool et substances' }, choice: 'gris' },
    { act: 'xray', duration: 12, extra: { zone: 'jambe_d', zoneLabel: 'Jambe droite', region: 'leg' } },
    { act: 'cast', duration: 14, extra: { zoneLabel: 'Bras gauche', material: 'attelle', materialLabel: 'Attelle', region: 'arm' } },
    { act: 'cast', duration: 14, extra: { zoneLabel: 'Jambe droite', material: 'platre', materialLabel: 'Plâtre', region: 'leg' }, name: 'cast (plâtre)' },
    { act: 'hemostasis', duration: 12, extra: { zoneLabel: 'Bras droit', severity: 2, seconds: 12, region: 'arm', assistBonus: 0.06 } },
    { act: 'hemostasis', duration: 14, difficulty: 3, extra: { zoneLabel: 'Thorax', severity: 3, seconds: 14, region: 'torso', assistBonus: 0.06 }, name: 'hemostasis (critique, difficile)' },
    { act: 'dressing', duration: 10, extra: { zoneLabel: 'Bras droit', severity: 2, region: 'arm' } },
    { act: 'cpr', duration: 20, extra: { compressions: 30, bpm: 110, defib: true, pass: 0.6 } },
    { act: 'echo', duration: 12, extra: { type: 'pregnancy', typeLabel: 'Suivi de grossesse' } },
    { act: 'echo', duration: 12, extra: { type: 'abdomen', typeLabel: 'Échographie abdominale' }, name: 'echo (abdomen)' },
    { act: 'scan', duration: 14, extra: { type: 'head', typeLabel: 'Scanner cérébral' } },
    { act: 'vaccine', duration: 12, extra: { zones, expect: 'deltoide', vaccine: 'Vaccin anti-grippal' }, choice: 'deltoide' },
    { act: 'implant', duration: 14, extra: {} },
    { act: 'implant_remove', duration: 12, extra: {} },
  ];
  let id = 1000;
  const run = async (g, mode = 'good', timeout = 120000) => {
    id++;
    await p.evaluate(() => { window.OUT = []; });
    await p.evaluate((m) => { window.BOT.mode = m; window.BOT.pressed = new Set(); }, mode);
    const game = { id, act: g.act, title: g.name || g.act, icon: '🩺', seed: 12345 + id, duration: g.duration, difficulty: g.difficulty || 2, maxMistakes: g.max ?? 3, extra: g.extra };
    const t0 = Date.now();
    await p.evaluate((game) => window.postMessage({ action: 'proc:start', game }, '*'), game);
    let shot = false;
    for (;;) {
      await p.waitForTimeout(100);
      if (!shot && Date.now() - t0 > 2500) { shot = true; await p.screenshot({ path: path.join(SHOTS, `${(g.name || g.act).replace(/[^\w]+/g, '_')}.png`) }); }
      const out = await p.evaluate(() => window.OUT.find((o) => o.n === 'procResult'));
      if (out) return { res: out.d, secs: (Date.now() - t0) / 1000 };
      if (Date.now() - t0 > timeout) return { res: null, secs: timeout / 1000 };
    }
  };

  console.log('[Chaque acte joué jusqu\'au bout]');
  for (const g of GAMES) {
    const { res, secs } = await run(g);
    const ok = res && res.ok === true && res.id === id && !res.cancelled && (g.choice === undefined || res.choice === g.choice);
    check(`${g.name || g.act} : réussi en ${secs.toFixed(1)} s (${res ? res.mistakes : '?'} erreur(s), score ${res ? res.score : '?'})`, ok, res);
    check(`${g.name || g.act} : pas plus court que 42 % de la durée prévue (contrôle serveur)`, secs >= g.duration * 0.42, secs);
  }
  const cpr = (await p.evaluate(() => 0)) || null;

  console.log('[Échec, annulation]');
  let r = await run({ act: 'blood', duration: 12, extra: { tubes, expect: 'gris', analysis: 'Alcool et substances' }, max: 2 }, 'wrong', 20000);
  check('mauvais tube répété : échec « trop d\'erreurs »', r.res && r.res.ok === false && r.res.reason === 'mistakes' && r.res.mistakes === 3, r.res);
  r = await run({ act: 'vaccine', duration: 12, extra: { zones, expect: 'deltoide', vaccine: 'Test' }, max: 0 }, 'wrong', 20000);
  check('mauvaise zone d\'injection, aucune erreur tolérée : échec immédiat', r.res && r.res.ok === false && r.res.mistakes === 1, r.res);
  id++;
  await p.evaluate(() => { window.OUT = []; window.BOT.mode = 'idle'; });
  await p.evaluate((id) => window.postMessage({ action: 'proc:start', game: { id, act: 'scan', title: 'Scanner', duration: 14, difficulty: 2, maxMistakes: 3, seed: 7, extra: { type: 'head' } } }, '*'), id);
  await p.waitForTimeout(600);
  await p.keyboard.press('Escape');
  await p.waitForTimeout(1300);
  r = await p.evaluate(() => window.OUT.find((o) => o.n === 'procResult'));
  check('Échap : acte annulé (résultat « annulé » envoyé)', r && r.d.cancelled === true && r.d.ok === false, r);
  check('Échap n\'a pas fermé autre chose (pas de « close » envoyé)', !(await p.evaluate(() => window.OUT.some((o) => o.n === 'close'))));
  check('mini-jeu fermé après l\'annulation', !(await p.evaluate(() => document.querySelector('#pg').classList.contains('on'))));
  id++;
  await p.evaluate((id) => window.postMessage({ action: 'proc:start', game: { id, act: 'inconnu', duration: 10, extra: {} } }, '*'), id);
  await p.waitForTimeout(200);
  r = await p.evaluate(() => window.OUT.filter((o) => o.n === 'procResult').pop());
  check('acte inconnu : annulé proprement', r && r.d.cancelled === true && r.d.reason === 'type', r);
  await p.evaluate(() => { window.BOT.mode = 'good'; });

  console.log('[Fenêtres : choix, consentement, question]');
  const pick = { patient: { id: 7, name: 'Élodie Durand', down: false }, acts: [
    { id: 'blood', label: 'Prise de sang', icon: '🩸', consent: true, choices: [{ key: 'analysis', value: 'tox', label: 'Alcool et substances' }] },
    { id: 'cast', label: 'Attelle / plâtre', icon: '🩼', consent: true, choices: [{ key: 'injury', value: 4, material: 'platre', label: 'Plâtre · Jambe droite', sub: 'Fracture' }] },
    { id: 'cpr', label: 'Massage cardiaque', icon: '❤️', disabled: true, reason: 'Le patient n\'est pas inconscient.' },
    { id: 'hemostasis', label: 'Contrôle d\'hémorragie', icon: '🩸', choices: [], assist: true },
  ] };
  await p.evaluate((data) => { window.OUT = []; window.postMessage({ action: 'proc:pick', show: true, data }, '*'); }, pick);
  await p.waitForTimeout(250);
  await p.screenshot({ path: path.join(SHOTS, 'choix_actes.png') });
  check('fenêtre des actes : 4 actes, acte impossible grisé avec sa raison', await p.evaluate(() => document.querySelectorAll('#procPick .pk-act').length === 4
    && document.querySelector('#procPick .pk-act.off small').textContent.includes('pas inconscient')));
  await p.click('#procPick [data-pk="cast"]');
  r = await p.evaluate(() => window.OUT.find((o) => o.n === 'procChoose'));
  check('choix envoyé : acte, patient, blessure et matériel', r && r.d.act === 'cast' && r.d.target === 7 && r.d.choice.injury === 4 && r.d.choice.material === 'platre', r);
  await p.click('#procPick [data-assist]');
  r = await p.evaluate(() => window.OUT.filter((o) => o.n === 'procChoose').pop());
  check('aide à la compression proposée', r && r.d.assist === true, r);
  await p.keyboard.press('Escape');
  r = await p.evaluate(() => window.OUT.filter((o) => o.n === 'close').pop());
  check('Échap ferme la fenêtre des actes (côté jeu)', r && r.d.ui === 'proc', r);
  await p.evaluate(() => { window.OUT = []; window.postMessage({ action: 'proc:pick', show: false }, '*'); window.postMessage({ action: 'proc:consent', show: true, token: 'T1', title: 'Vaccination', text: 'Lucas Martin propose de vous vacciner.', timeout: 20 }, '*'); });
  await p.waitForTimeout(250);
  await p.screenshot({ path: path.join(SHOTS, 'consentement.png') });
  check('consentement affiché au patient', await p.evaluate(() => !document.querySelector('#procConsent').classList.contains('hidden') && document.querySelector('#procConsent').textContent.includes('vacciner')));
  await p.keyboard.press('Enter');
  r = await p.evaluate(() => window.OUT.find((o) => o.n === 'procConsent'));
  check('Entrée : consentement accepté (jeton renvoyé)', r && r.d.token === 'T1' && r.d.yes === true, r);
  await p.evaluate(() => { window.OUT = []; window.postMessage({ action: 'proc:consent', show: true, token: 'T2', title: 'Implant', text: 'x', timeout: 20 }, '*'); });
  await p.waitForTimeout(150);
  await p.click('#procConsent [data-cs="0"]');
  r = await p.evaluate(() => window.OUT.find((o) => o.n === 'procConsent'));
  check('bouton Refuser : refus envoyé', r && r.d.token === 'T2' && r.d.yes === false, r);
  await p.evaluate(() => { window.OUT = []; window.postMessage({ action: 'proc:ask', show: true, title: 'Échec', text: 'Veine manquée.', yes: 'Recommencer', no: 'Arrêter' }, '*'); });
  await p.waitForTimeout(150);
  await p.keyboard.press('Escape');
  r = await p.evaluate(() => window.OUT.find((o) => o.n === 'procAsk'));
  check('question « recommencer ? » : Échap = non', r && r.d.yes === false, r);
  await p.evaluate(() => window.postMessage({ action: 'proc:report', title: 'Radiographie · Jambe droite', text: 'Radiographie jambe droite : fracture nécessitant une prise en charge par plâtre.' }, '*'));
  await p.waitForTimeout(150);
  check('compte rendu affiché à l\'EMS', await p.evaluate(() => !document.querySelector('#procReport').classList.contains('hidden')));
  await p.evaluate(() => window.postMessage({ action: 'proc:wait', show: true, text: 'Demande de consentement envoyée au patient…' }, '*'));
  await p.waitForTimeout(100);
  await p.screenshot({ path: path.join(SHOTS, 'attente_et_compte_rendu.png') });

  console.log('[Examen et F6]');
  await p.evaluate(() => {
    window.postMessage({ action: 'procs', procs: { blood: true, cpr: true, hemostasis: true, cast: true } }, '*');
    window.postMessage({ action: 'exam', show: true, perms: { medical: true, heal: true, stabilize: true, revive: true, billing: true },
      exam: { id: 7, name: 'Élodie Durand', hp: 54, armor: 0, state: 'Conscient · blessé', down: false, conditions: [], procs: true, cprProc: true, castProc: true,
        injuries: [{ id: 1, type: 'hemorrhage', zoneLabel: 'Bras droit', label: 'Hémorragie importante', status: 'active' }, { id: 2, type: 'fracture', zoneLabel: 'Jambe gauche', label: 'Douleur, membre à radiographier', status: 'active' }] } }, '*');
  });
  await p.waitForTimeout(250);
  await p.screenshot({ path: path.join(SHOTS, 'examen.png') });
  check('examen : blessures et boutons Compression / Actes et examens', await p.evaluate(() => {
    const m = document.querySelector('#exam .modal');
    return m.textContent.includes('Hémorragie importante') && !!m.querySelector('[data-ex="hemostasis"]') && !!m.querySelector('[data-ex="procs"]') && !m.querySelector('[data-ex="splint"]');
  }));

  check('aucune erreur JavaScript', errs.length === 0, errs);
  console.log(`\n${total - fails}/${total} · captures : ${SHOTS}`);
  await b.close();
  process.exit(fails ? 1 : 0);
})();
