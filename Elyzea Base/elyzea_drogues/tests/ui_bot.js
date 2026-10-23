// Usage : node tests/ui_bot.js <dossier_captures> html/index.html   (MISTAKE=1 : une erreur volontaire au début de chaque partie, puis on finit)
// Joueur automatique : fait chaque mini-jeu de bout en bout dans Chromium (page de l'interface réelle)
const { chromium } = require('/opt/node-tools/node_modules/playwright');
const path = require('path');
const OUT = process.argv[2];
const PAGE = 'file://' + path.resolve(process.argv[3]) + '?mg';
const CASES = [
  { type: 'trim', drug: 'weed', count: 12, extra: { per: 6 }, title: 'Effeuiller les têtes' },
  { type: 'trim', drug: 'weed', count: 6, extra: { per: 6, tint: 'purple' }, title: 'Effeuiller (Purple Haze)' },
  { type: 'hang', drug: 'weed', skin: 'weed', count: 5, title: 'Suspendre les têtes au séchoir' },
  { type: 'hang', drug: 'crack', skin: 'crack', count: 3, title: 'Étaler la pâte' },
  { type: 'grind', drug: 'weed', skin: 'grinder', count: 4, title: 'Effriter au moulin' },
  { type: 'grind', drug: 'cocaine', skin: 'crank', count: 4, title: 'Broyer les feuilles' },
  { type: 'grind', drug: 'opiates', skin: 'mortar', count: 3, title: 'Réduire en poudre' },
  { type: 'roll', drug: 'weed', count: 3, title: 'Rouler un joint' },
  { type: 'scale', drug: 'cocaine', skin: 'powder', count: 2, extra: { grams: 1.0 }, title: 'Peser et ensacher' },
  { type: 'scale', drug: 'weed', skin: 'bud', count: 1, extra: { grams: 3.5 }, title: 'Peser le pochon' },
  { type: 'count', drug: 'ecstasy', skin: 'pills', count: 4, extra: { color: 'pink' }, title: 'Mettre en blister' },
  { type: 'count', drug: 'crack', skin: 'rocks', count: 2, title: 'Ensacher les cailloux' },
  { type: 'pour', drug: 'meth', count: 2, extra: { reagents: [{ label: 'Produits chimiques', color: 'base' }, { label: 'Acide', color: 'acid' }] }, title: 'Préparer le mélange' },
  { type: 'heat', drug: 'meth', skin: 'reactor', count: 6, title: 'Cuire le mélange' },
  { type: 'heat', drug: 'crack', skin: 'stove', count: 5, title: 'Chauffer' },
  { type: 'heat', drug: 'meth', skin: 'pump', count: 4, title: 'Siphonner le fût' },
  { type: 'shake', drug: 'opiates', skin: 'filter', count: 8, title: 'Filtrer la solution' },
  { type: 'cut', drug: 'crack', skin: 'crack', count: 3, extra: { per: 3 }, title: 'Découper en cailloux' },
  { type: 'cut', drug: 'cocaine', skin: 'coke', count: 4, extra: { per: 2 }, title: 'Couper les lignes' },
  { type: 'smash', drug: 'meth', count: 6, maxMistakes: 4, title: 'Casser les cristaux' },
  { type: 'press', drug: 'ecstasy', count: 5, extra: { color: 'blue' }, title: 'Presser les comprimés' },
  { type: 'sort', drug: 'mushrooms', count: 4, title: 'Trier les champignons' },
  { type: 'syringe', drug: 'opiates', count: 2, title: 'Préparer les seringues' },
];
const BOT = String.raw`
window.__bot = (cfg, mistakeFirst) => new Promise((resolve) => {
  const MG = window.ElyMG, cv = document.querySelector('#mg canvas');
  let res = null; MG.onResult = (r) => { res = r; };
  MG.start(Object.assign({ id: 1, seed: 12345, maxMistakes: 3, limit: 90 }, cfg));
  const S = MG.cur, G = MG.games[cfg.type];
  const ev = (type, x, y) => { const r = cv.getBoundingClientRect(); cv.dispatchEvent(new PointerEvent(type, { clientX: r.left + x * r.width / 760, clientY: r.top + y * r.height / 440, pointerId: 1, bubbles: true })); };
  const queue = []; // actions programmées
  let busy = false, t = 0;
  const steps = (pts, done) => { busy = true; const go = () => { const p = pts.shift(); if (!p) { busy = false; if (done) done(); return; } ev(p[0], p[1], p[2]); setTimeout(go, p[3] || 16); }; go(); };
  const line = (x0, y0, x1, y1, n, ms) => { const a = []; for (let i = 1; i <= n; i++) a.push(['pointermove', x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * i / n, ms]); return a; };
  let hold = false, ang = 0, pre = !!mistakeFirst, preT = 0, preSentAt = 0;
  const tick = () => {
    if (res) { resolve(Object.assign({ mistakes: S.mistakes }, res)); return; }
    t += 16;
    const st = S.g;
    if (pre && S.mistakes >= 1) { pre = false; if (hold) { ev('pointerup', 380, 230); hold = false; } }
    const ONESHOT = { trim: 1, roll: 1, count: 1, cut: 1, press: 1, sort: 1, syringe: 1 };
    if (pre && !busy) { preT += 16;
      if (preT > 15000) { pre = false; }
      else if (ONESHOT[cfg.type] && preSentAt && t - preSentAt < 1500) { setTimeout(tick, 16); return; }   // une seule erreur, on attend qu'elle compte
      else { const before = busy; doMistake(st); if (busy && !before) preSentAt = t; setTimeout(tick, 16); return; } }
    if (!busy) switch (cfg.type) {
      case 'trim': {
        if (!st.bud || st.slide !== 0) break;
        const l = st.bud.leaves.find((k) => !k.gone); if (!l) break;
        const [gx, gy] = G.grip(l), dx = Math.cos(l.a), dy = Math.sin(l.a);
        steps([['pointermove', gx, gy], ['pointerdown', gx, gy, 120], ...line(gx, gy, gx + dx * 75, gy + dy * 75, 10, 24), ['pointerup', gx + dx * 75, gy + dy * 75, 200]]);
        break; }
      case 'hang': {
        if (st.phase === 'hang') { const it = st.items.find((k) => !k.at); const sp = st.spots.find((s) => !s.used); const ty = sp.y + (st.grid ? 0 : 40);
          steps([['pointerdown', it.x, it.y], ...line(it.x, it.y, sp.x, ty, 8, 16), ['pointerup', sp.x, ty]]); }
        else if (st.phase === 'tune') { const c = (st.band[0] + st.band[1]) / 2; const x = 270 + D_clamp(c, 0, 1) * 360; if (!hold) { ev('pointerdown', x, 358); hold = true; } else ev('pointermove', x, 358); }
        break; }
      case 'grind': { const cx = 760 / 2 - 60, cy = 440 / 2 + 10; ang += Math.PI * 2 * 1.1 * 0.016; const x = cx + Math.cos(ang) * 90, y = cy + Math.sin(ang) * 90; if (!hold) { ev('pointermove', x, y); ev('pointerdown', x, y); hold = true; } else ev('pointermove', x, y); break; }
      case 'roll': {
        if (st.phase === 0) { const s = st.spots.find((p) => !p.ok); steps([['pointerdown', 180 + s.f * 400, 230], ['pointerup', 180 + s.f * 400, 230, 60]]); }
        else if (st.phase === 1) { const want = st.m < st.zone; if (want && !hold) { ev('pointerdown', 380, 300); hold = true; } else if (!want && hold) { ev('pointerup', 380, 300); hold = false; } }
        else { if (hold) { ev('pointerup', 380, 300); hold = false; } if (Math.abs(st.needle - 0.5) < 0.03) steps([['pointerdown', 380, 300], ['pointerup', 380, 300, 30]]); }
        break; }
      case 'scale': { const est = st.w + st.flow * 0.22 * 1.05; if (!st.pour && st.stable === 0 && est < st.t - st.tol * 0.3 && st.lag <= 0.0001) { ev('pointerdown', 560, 150); } else if (st.pour && est >= st.t - st.tol * 0.3) ev('pointerup', 560, 150); break; }
      case 'count': {
        const bad = st.items.find((k) => !k.good && !k.placed); const good = st.items.find((k) => k.good && !k.placed); const sl = st.slots.find((s) => !s.it);
        const it = good || bad; if (!it) break; const to = it.good ? [sl.x, sl.y] : [670, 350];
        steps([['pointerdown', it.x, it.y], ...line(it.x, it.y, to[0], to[1], 6, 16), ['pointerup', to[0], to[1]]]); break; }
      case 'pour': { const tg = st.targets[st.idx]; if (tg === undefined) break; const est = st.level + st.flow * 0.18 * 1.05; const bx = 470 + st.idx * 95;
        if (!st.pour && est < tg - 0.012 && st.lag <= 0.0001) ev('pointerdown', bx, 120); else if (st.pour && est >= tg - 0.012) ev('pointerup', bx, 120); break; }
      case 'heat': { const c = (st.band[0] + st.band[1]) / 2; const want = st.T < c; if (want && !hold) { ev('pointerdown', 300, 250); hold = true; } else if (!want && hold) { ev('pointerup', 300, 250); hold = false; } break; }
      case 'shake': { if (!hold) { ev('pointerdown', 380, 200); hold = true; ang = 0; } ang += 1; const x = 380 + Math.sin(ang * 0.18) * 120; ev('pointermove', x, 200); break; }
      case 'cut': { const l = st.lines.find((k) => !k.done); if (!l) break; steps([['pointerdown', l.ax, l.ay], ...line(l.ax, l.ay, l.bx, l.by, 12, 16), ['pointerup', l.bx, l.by]]); break; }
      case 'smash': { const s = st.spots.find((k) => k.t > 0.15); if (s) steps([['pointerdown', s.x, s.y], ['pointerup', s.x, s.y, 30]]); break; }
      case 'press': { if (Math.abs(st.r - 36) < 4) steps([['pointerdown', 300, 230], ['pointerup', 300, 230, 30]]); break; }
      case 'sort': { const it = st.items.find((k) => k.x > 60 && k.x < 600); if (!it) break; const to = it.good ? [110, 360] : [645, 360];
        steps([['pointerdown', it.x, it.y], ...line(it.x, it.y, to[0], to[1], 6, 16), ['pointerup', to[0], to[1]]]); break; }
      case 'syringe': { if (st.bubbles.length) { const b = st.bubbles[0]; steps([['pointerdown', b.x, b.y], ['pointerup', b.x, b.y, 40]]); }
        else { const x0 = 170 + st.v * 436, x1 = 170 + st.target * 436; steps([['pointerdown', x0, 220], ...line(x0, 220, x1, 220, 10, 16), ['pointerup', x1, 220, 60]]); } break; }
    }
    setTimeout(tick, 16);
  };
  const D_clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  function doMistake(st) {
    switch (cfg.type) {
      case 'trim': if (st.bud && st.slide === 0) steps([['pointerdown', st.bud.cx, st.bud.cy], ['pointerup', st.bud.cx, st.bud.cy, 60]]); break;
      case 'hang': {
        if (st.phase === 'hang') { const it = st.items.find((k) => !k.at); const sp = st.spots.find((s) => !s.used); const ty = sp.y + (st.grid ? 0 : 40);
          steps([['pointerdown', it.x, it.y], ...line(it.x, it.y, sp.x, ty, 8, 16), ['pointerup', sp.x, ty]]); }
        else { const band = st.band; const x = 270 + (band[0] > 0.5 ? 0 : 1) * 360; if (!hold) { ev('pointerdown', x, 358); hold = true; } else ev('pointermove', x, 358); }
        break; }
      case 'grind': { const cx = 320, cy = 230; ang += 0.9; const x = cx + Math.cos(ang) * 90, y = cy + Math.sin(ang) * 90; if (!hold) { ev('pointermove', x, y); ev('pointerdown', x, y); hold = true; } else ev('pointermove', x, y); break; }
      case 'roll': if (st.phase === 0) steps([['pointerdown', 560, 230], ['pointerup', 560, 230, 60]]); else if (st.phase === 2) steps([['pointerdown', 380, 300], ['pointerup', 380, 300, 30]]); break;
      case 'scale': case 'pour': { const x = cfg.type === 'scale' ? 560 : 470 + st.idx * 95, y = cfg.type === 'scale' ? 150 : 120; if (!hold) { ev('pointerdown', x, y); hold = true; } break; }
      case 'count': { const it = st.items.find((k) => !k.good && !k.placed); const sl = st.slots.find((q) => !q.it); if (it && sl) steps([['pointerdown', it.x, it.y], ...line(it.x, it.y, sl.x, sl.y, 6, 16), ['pointerup', sl.x, sl.y]]); break; }
      case 'heat': if (!hold) { ev('pointerdown', 300, 250); hold = true; } break;
      case 'shake': { if (!hold) { ev('pointerdown', 380, 200); hold = true; } ang += 1; ev('pointermove', 380 + (ang % 2 ? 170 : -170), 200); break; }
      case 'cut': { const l = st.lines.find((k) => !k.done); if (!l) break;
        const dx = l.bx - l.ax, dy = l.by - l.ay, n = Math.hypot(dx, dy), px = -dy / n * 40, py = dx / n * 40;   // on s'écarte du trait
        steps([['pointerdown', l.ax, l.ay], ...line(l.ax, l.ay, l.ax + px, l.ay + py, 5, 16), ['pointerup', l.ax + px, l.ay + py]]); break; }
      case 'smash': break;
      case 'press': if (Math.abs(st.r - 36) > 40) steps([['pointerdown', 300, 230], ['pointerup', 300, 230, 30]]); break;
      case 'sort': { const it = st.items.find((k) => k.good && k.x > 60 && k.x < 500); if (it) steps([['pointerdown', it.x, it.y], ...line(it.x, it.y, 645, 360, 6, 16), ['pointerup', 645, 360]]); break; }
      case 'syringe': { const x0 = 170 + st.v * 436; steps([['pointerdown', x0, 220], ...line(x0, 220, 610, 220, 10, 16), ['pointerup', 610, 220, 60]]); break; }
    }
  }
  setTimeout(tick, 50);
});
window.__fail = (cfg) => new Promise((resolve) => {
  const MG = window.ElyMG, cv = document.querySelector('#mg canvas');
  MG.onResult = (r) => resolve(r);
  MG.start(Object.assign({ id: 2, seed: 7, maxMistakes: 2, limit: 30 }, cfg));
  const r = cv.getBoundingClientRect();
  let n = 0; const go = () => { n++; const x = r.left + r.width * 0.42, y = r.top + r.height * 0.52;
    cv.dispatchEvent(new PointerEvent('pointerdown', { clientX: x, clientY: y, pointerId: 1, bubbles: true }));
    cv.dispatchEvent(new PointerEvent('pointermove', { clientX: x + 3, clientY: y + 2, pointerId: 1, bubbles: true }));
    cv.dispatchEvent(new PointerEvent('pointerup', { clientX: x + 3, clientY: y + 2, pointerId: 1, bubbles: true }));
    if (n < 40) setTimeout(go, 500); };
  go();
});`;
(async () => {
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' }).catch(() => chromium.launch());
  const p = await b.newPage({ viewport: { width: 1280, height: 760 } });
  const errs = []; p.on('pageerror', (e) => errs.push(String(e))); p.on('console', (m) => { if (m.type() === 'error') errs.push(m.text()); });
  await p.goto(PAGE); await p.addScriptTag({ content: BOT });
  let ok = 0, ko = 0;
  for (const [i, c] of CASES.entries()) {
    const shot = p.waitForTimeout(2200).then(() => p.screenshot({ path: `${OUT}/${String(i + 1).padStart(2, '0')}_${c.type}${c.skin ? '_' + c.skin : ''}.png` }));
    const r = await Promise.race([p.evaluate(([cfg, mf]) => window.__bot(cfg, mf), [c, !!process.env.MISTAKE]), p.waitForTimeout(80000).then(() => ({ ok: false, reason: 'bot-timeout' }))]);
    await shot.catch(() => {});
    const good = r.ok && r.done === c.count && (!process.env.MISTAKE || r.mistakes >= 1);
    good ? ok++ : ko++;
    console.log(`${good ? 'ok  ' : 'ÉCHEC'} ${c.type}${c.skin ? '/' + c.skin : ''} : réussi=${r.ok} objectifs=${r.done}/${c.count} erreurs=${r.mistakes} durée=${(r.ms / 1000).toFixed(1)}s ${r.reason || ''}`);
    await p.waitForTimeout(1000);
  }
  // chemins d'échec et d'annulation
  const f = await p.evaluate(() => window.__fail({ type: 'trim', drug: 'weed', count: 6, title: 'test échec' }));
  console.log(`${!f.ok && f.reason === 'mistakes' ? 'ok  ' : 'ÉCHEC'} échec par erreurs (trim) : ok=${f.ok} raison=${f.reason} erreurs=${f.mistakes}`);
  await p.waitForTimeout(1000);
  const cancel = p.evaluate(() => new Promise((res) => { window.ElyMG.onResult = res; window.ElyMG.start({ id: 3, type: 'heat', drug: 'meth', count: 5, seed: 1, limit: 30, maxMistakes: 2 }); }));
  await p.waitForTimeout(600); await p.keyboard.press('Escape');
  const c = await cancel;
  console.log(`${c.cancelled && !c.ok ? 'ok  ' : 'ÉCHEC'} annulation par Échap : cancelled=${c.cancelled}`);
  await p.waitForTimeout(1000);
  const tm = await p.evaluate(() => new Promise((res) => { window.ElyMG.onResult = res; window.ElyMG.start({ id: 4, type: 'press', drug: 'ecstasy', count: 5, seed: 1, limit: 10, maxMistakes: 99 }); }));
  console.log(`${!tm.ok && tm.reason === 'time' ? 'ok  ' : 'ÉCHEC'} temps écoulé : raison=${tm.reason}`);
  const unk = await p.evaluate(() => new Promise((res) => { window.ElyMG.onResult = res; window.ElyMG.start({ id: 5, type: 'inconnu' }); setTimeout(() => res({ visible: document.querySelector('#mg').classList.contains('on') }), 300); }));
  console.log(`${!unk.visible ? 'ok  ' : 'ÉCHEC'} type inconnu : interface non ouverte`);
  console.log(`Erreurs JS : ${errs.length ? errs.join(' | ') : 'aucune'}`);
  console.log(`Résultat : ${ok}/${CASES.length} mini-jeux terminés par le joueur automatique`);
  await b.close();
})();
