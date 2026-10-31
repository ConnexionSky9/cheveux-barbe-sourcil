// Test de l'interface mécano dans Chromium (page réelle html/index.html, jeu imité) :
// atelier (Esthétique / Performance), devis, 4 pneus, DRIFT, envoi, étapes du devis, installation,
// liste des interventions, chaque mini-jeu joué par un robot, peinture progressive, délai, Échap,
// suivi du client, remise des clés.
// Usage : node tests/ui_workshop.js <dossier_captures>   (NODE_PATH=$(npm root -g))
const { chromium } = require('playwright');
const path = require('path');
const OUT = process.argv[2] || '.';
const PAGE = 'file://' + path.resolve(__dirname, '..', 'html', 'index.html');
let fails = 0, passes = 0;
const check = (c, m) => { if (c) { passes++; console.log('  ok   ' + m); } else { fails++; console.log('  ÉCHEC ' + m); } };

const DATA = {
  ws: { id: 'WS1', label: 'Pont 1', categories: ['perf', 'cosmetic', 'paint', 'wheels', 'lights', 'interior', 'service'] },
  plate: 'ABC123', owned: true, owner: 'Jean Dupont', savedPerf: { engine: 1, brakes: 0, transmission: 0, suspension: 0, armor: 0, turbo: 0 }, drift: false,
  categories: { service: 'Prestations', perf: 'Performances', cosmetic: 'Carrosserie', paint: 'Peinture et vitres', wheels: 'Roues', lights: 'Éclairage', interior: 'Intérieur', carplay: 'CarPlay' },
  customers: [{ id: 7, owner: true, name: 'Jean Dupont' }, { id: 1, self: true }],
  items: [
    { code: 'engine_1', name: 'Moteur niveau 1', category: 'perf', kind: 'perf', mod: 'engine', level: 1, price: 2500 },
    { code: 'engine_2', name: 'Moteur niveau 2', category: 'perf', kind: 'perf', mod: 'engine', level: 2, price: 4500 },
    { code: 'engine_3', name: 'Moteur niveau 3', category: 'perf', kind: 'perf', mod: 'engine', level: 3, price: 7500 },
    { code: 'brakes_1', name: 'Freins niveau 1', category: 'perf', kind: 'perf', mod: 'brakes', level: 1, price: 1500 },
    { code: 'brakes_2', name: 'Freins niveau 2', category: 'perf', kind: 'perf', mod: 'brakes', level: 2, price: 2800 },
    { code: 'turbo', name: 'Turbo', category: 'perf', kind: 'perf', mod: 'turbo', level: 1, price: 6000 },
    { code: 'cosmetic_body', name: 'Pièce de carrosserie', category: 'cosmetic', kind: 'cosmetic', mod: 'body', price: 750 },
    { code: 'cosmetic_paint', name: 'Peinture', category: 'paint', kind: 'cosmetic', mod: 'paint', price: 900 },
    { code: 'cosmetic_newtyres', name: 'Pneus neufs', category: 'wheels', kind: 'cosmetic', mod: 'newtyres', price: 350, description: 'Prix par pneu.' },
    { code: 'cosmetic_drift', name: 'Pneus DRIFT', category: 'wheels', kind: 'cosmetic', mod: 'drift', price: 6500 },
    { code: 'cosmetic_wheels', name: 'Jantes', category: 'wheels', kind: 'cosmetic', mod: 'wheels', price: 1500 },
    { code: 'repair_full', name: 'Réparation complète', category: 'service', kind: 'service', price: 1200 },
  ],
  quote: null, canInstall: true, lift: false,
};
const OPTIONS = {
  newtyres: { options: [{ value: 'all', label: 'Les 4 pneus (une seule intervention)', spec: { t: 'newtyres', w: [0, 1, 4, 5] }, qty: 4 },
    { value: 0, label: 'Avant gauche · crevé', spec: { t: 'newtyres', w: [0] }, qty: 1 }, { value: 1, label: 'Avant droit', spec: { t: 'newtyres', w: [1] }, qty: 1 }] },
  drift: { options: [{ value: 1, label: 'Pneus DRIFT', spec: { t: 'drift', on: true }, badge: 'DRIFT' }, { value: 0, label: 'Pneus route (retirer les DRIFT)', spec: { t: 'drift', on: false } }], current: 0 },
  body: { options: [{ value: -1, label: 'Origine', spec: { t: 'mod', id: 1, v: -1 } }, { value: 0, label: 'Pare-chocs sport', spec: { t: 'mod', id: 1, v: 0 } }], current: -1 },
};

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1600, height: 900 } });
  await page.route(/fonts\.(googleapis|gstatic)\.com/, (r) => r.abort());
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e)));
  await page.addInitScript(({ OPTIONS }) => {
    window.POSTS = [];
    window.EDemo = (name, data) => {
      window.POSTS.push({ name, data: JSON.parse(JSON.stringify(data || {})) });
      if (name === 'wsOptions') return OPTIONS[data.group] || { options: [] };
      if (name === 'wsSend') {
        const items = data.items.map((i) => ({ label: i.label, qty: i.qty || 1, total: 0 }));
        return { ok: true, quote: { uid: 'DEV-1', status: 'pending', total: 9100, items } };
      }
      if (name === 'wsInstall') return { ok: true, status: 'accepted' };
      return {};
    };
  }, { OPTIONS });
  await page.goto(PAGE);
  const send = (m) => page.evaluate((x) => window.postMessage(x, '*'), m);
  const posts = (n) => page.evaluate((k) => window.POSTS.filter((p) => p.name === k), n);
  const clearPosts = () => page.evaluate(() => { window.POSTS = []; });
  const wait = (ms) => page.waitForTimeout(ms);
  const clickConfirm = async () => { await page.waitForSelector('#confirm:not(.hidden) .btn.primary, #confirm:not(.hidden) .btn.danger'); await page.click('#confirm .actions .btn:last-child'); };

  console.log('[Atelier : ouverture et modes]');
  await send({ action: 'workshop', show: true, data: DATA, live: { engine: 1, brakes: 0, transmission: 0, suspension: 0, armor: 0, turbo: 0, drift: 0 },
    maxLv: { engine: 4, brakes: 3, transmission: 3, suspension: 4, armor: 0, turbo: 1 }, groups: { body: { subs: [{ id: '1', label: 'Pare-chocs avant' }, { id: '2', label: 'Pare-chocs arrière' }] }, paint: { subs: [{ id: '1', label: 'Peinture principale' }] }, newtyres: { empty: false }, drift: { empty: false }, wheels: { subs: [{ id: '0', label: 'Sport' }] } },
    model: 'Sultan', health: { engine: 92, body: 61 }, state: {} });
  await page.waitForSelector('#workshop:not(.hidden) .ws-modes');
  const modes = await page.$$eval('.ws-modes .mode', (b) => b.map((x) => x.textContent.trim()));
  check(modes.some((m) => m.includes('Esthétique')) && modes.some((m) => m.includes('Performance')) && modes.some((m) => m.includes('Prestations')), `trois modes séparés : ${modes.join(' / ')}`);
  check(!(await page.$('[data-wcat="carplay"]')) && !(await page.textContent('#workshop')).includes('CarPlay'), 'plus aucune trace du CarPlay dans l\'atelier');
  await page.screenshot({ path: path.join(OUT, 'meca_atelier_accueil.png') });

  console.log('[Performance]');
  await clearPosts();
  await page.click('[data-wmode="perf"]');
  await page.waitForSelector('.perf-card');
  check((await posts('wsCam')).some((p) => p.data.focus === 'hood'), 'la caméra se place sur le moteur');
  const eng = await page.$eval('.perf-card', (c) => c.textContent);
  check(eng.includes('Moteur') && eng.includes('Installé · niv. 1') && eng.includes('accélération'), 'carte moteur : niveau actuel, effet, état d\'installation');
  check(await page.$eval('[data-perf="engine_1"]', (b) => b.disabled), 'niveau déjà installé non proposé');
  await page.click('[data-perf="engine_3"]');
  const card = await page.$eval('.perf-card.sel', (c) => c.textContent);
  check(card.includes('Dans le devis') && card.includes('Proposé 3'), 'niveau proposé et état « Dans le devis »');
  check((await posts('wsPreview')).some((p) => p.data.spec.t === 'perf' && p.data.spec.level === 3), 'aperçu du niveau 3 envoyé au véhicule');
  check(await page.$eval('[data-perf="engine_3"]', (b) => b.textContent.includes('+2 paliers')), 'gain affiché (+2 paliers)');
  await page.click('[data-perf="brakes_2"]');
  await page.screenshot({ path: path.join(OUT, 'meca_atelier_performance.png') });

  console.log('[Esthétique : roues, 4 pneus, DRIFT, carrosserie]');
  await page.click('[data-wmode="cosmetic"]');
  await page.click('[data-wcat="wheels"]');
  await page.click('[data-witem="cosmetic_newtyres"]');
  await page.waitForSelector('[data-wopt="0"]');
  await page.click('[data-wopt="0"]');
  let cart = await page.$eval('.ws-cart', (c) => c.textContent);
  check(cart.includes('×4') && cart.replace(/\s/g, '').includes('1400$'), '4 pneus : une ligne ×4 à 350 $ = 1 400 $');
  await page.click('[data-wopt="1"]');
  cart = await page.$eval('.ws-cart', (c) => c.textContent);
  check(!cart.includes('×4') && cart.includes('Avant gauche'), 'un seul pneu choisi : la ligne remplace les 4 pneus');
  await page.click('[data-witem="cosmetic_drift"]');
  await page.waitForSelector('.badge-drift');
  check(await page.$eval('[data-witem="cosmetic_drift"]', (b) => b.textContent.includes('DRIFT')), 'pneus DRIFT identifiables (badge)');
  await page.click('[data-wopt="0"]');
  check((await page.$eval('.ws-cart', (c) => c.textContent)).includes('Pneus DRIFT'), 'pneus DRIFT ajoutés au devis');
  await clearPosts();
  await page.click('[data-wcat="cosmetic"]');
  await page.click('[data-wsub="1"]');
  check((await posts('wsCam')).some((p) => p.data.focus === 'front'), 'pare-chocs avant : caméra sur l\'avant du véhicule');
  await page.waitForSelector('[data-wopt="1"]');
  await page.click('[data-wopt="1"]');
  const groups = await page.$$eval('.cart-group .cg-title', (t) => t.map((x) => x.textContent.trim()));
  check(groups.includes('Esthétique') && groups.includes('Performance'), `devis classé Esthétique / Performance (${groups.join(', ')})`);
  await page.screenshot({ path: path.join(OUT, 'meca_atelier_esthetique.png') });

  console.log('[Devis : envoi, étapes, paiement, installation]');
  await page.selectOption('#wsCustomer', '7');
  await page.click('[data-ws="send"]');
  await clickConfirm();
  await page.waitForSelector('.timeline');
  const sent = (await posts('wsSend'))[0];
  check(sent && sent.data.customer === 7 && sent.data.items.length === 5, 'devis envoyé au client avec ses 5 lignes');
  check(sent && sent.data.items.some((i) => i.code === 'cosmetic_newtyres' && i.qty === 1 && i.spec.w.length === 1), 'pneu à l\'unité : 1 pneu dans la demande');
  check(!(await page.$('[data-ws="install"]')), 'devis en attente : pas de bouton d\'installation avant paiement');
  await page.screenshot({ path: path.join(OUT, 'meca_devis_attente.png') });
  await send({ action: 'wsQuote', quote: { uid: 'DEV-1', status: 'accepted', total: 9100, items: [{ label: 'Moteur niveau 3', qty: 1, total: 7500 }] } });
  await page.waitForSelector('[data-ws="install"]');
  check((await page.$$eval('.tl.done', (x) => x.length)) >= 1, 'paiement reçu : étape cochée, installation possible');
  await page.screenshot({ path: path.join(OUT, 'meca_devis_paye.png') });
  await page.click('[data-ws="install"]');
  await clickConfirm();
  await wait(100);
  check((await posts('wsInstall')).length === 1, 'installation lancée (une seule demande)');

  console.log('[Liste des interventions]');
  await send({ action: 'workshop', show: false });
  await send({ action: 'install', show: true, plate: 'ABC123', jobs: [
    { key: 'wheels', label: 'Roues et pneus', icon: 'wheel', done: false, next: true, lines: [{ label: 'Pneus DRIFT' }, { label: 'Pneus neufs : Avant gauche' }] },
    { key: 'engine', label: 'Moteur', icon: 'engine', done: false, lines: [{ label: 'Moteur niveau 3' }] },
    { key: 'paint', label: 'Peinture', icon: 'paint', done: true, lines: [{ label: 'Peinture : Rouge', done: true }] }] });
  check((await page.$eval('#install', (e) => e.textContent)).includes('1/3') && await page.$('.in-job.next'), 'liste : avancement 1/3 et prochaine intervention mise en avant');
  await page.screenshot({ path: path.join(OUT, 'meca_installation_liste.png') });

  // Robot : joue chaque mini-jeu
  async function play(game, extra = {}) {
    await clearPosts();
    const id = Math.floor(Math.random() * 1e6);
    await send(Object.assign({ action: 'minigame', show: true, id, game, label: `Test ${game}`, icon: 'service', parts: ['Pièce'], timeout: 60 }, extra));
    await page.waitForSelector('#minigame:not(.hidden) .mg-card');
    if (!extra.noShot) { await wait(350); await page.screenshot({ path: path.join(OUT, `meca_minijeu_${game}.png`) }); }
    const box = async (sel) => (await page.$(sel)).boundingBox();
    if (game === 'bolts') {
      for (const b of await page.$$('[data-bolt]')) { const r = await b.boundingBox(); await page.mouse.move(r.x + r.width / 2, r.y + r.height / 2); await page.mouse.down(); await wait(520); await page.mouse.up(); }
    } else if (game === 'align') {
      const p = await box('#mgPart'), s = await box('#mgSlot');
      await page.mouse.move(p.x + 10, p.y + 10); await page.mouse.down();
      for (let k = 1; k <= 10; k++) await page.mouse.move(p.x + 10 + (s.x - p.x) * k / 10, p.y + 10 + (s.y - p.y) * k / 10);
      await page.mouse.up();
      for (const c of await page.$$('[data-clip]')) await c.click();
    } else if (game === 'wires') {
      for (let i = 0; i < 4; i++) { await page.click(`[data-wl="${i}"]`); await page.click(`[data-wr="${i}"]`); }
    } else if (game === 'gauge') {
      for (let n = 0; n < 200; n++) {
        const inZone = await page.evaluate(() => { const z = document.querySelector('#mgZone'), nd = document.querySelector('#mgNeedle'); if (!z || !nd) return null;
          const a = z.getBoundingClientRect(), b = nd.getBoundingClientRect(); const x = b.left + b.width / 2; return x > a.left + 4 && x < a.right - 4; });
        if (inZone === null) break;
        if (inZone) await page.keyboard.press('Space');
        await wait(30);
      }
    } else if (game === 'wheels') {
      const stages = (extra.stages || []).length || 1;
      for (let s = 0; s < stages; s++) {
        await page.waitForFunction(() => document.querySelectorAll('.nut.off').length === 0);
        const nuts = await page.$$('[data-nut]');
        const r0 = await nuts[0].boundingBox();
        await page.mouse.move(r0.x + 8, r0.y + 8); await page.mouse.down();
        for (const n of nuts) { const r = await n.boundingBox(); await page.mouse.move(r.x + r.width / 2, r.y + r.height / 2, { steps: 3 }); }
        await page.mouse.up();
        await wait(700);
      }
    } else if (game === 'paint' || game === 'film') {
      const c = await box('#mgCanvas');
      await page.mouse.move(c.x + 5, c.y + 5); await page.mouse.down();
      for (let y = 0.2; y <= 0.95 && await page.$('#mgCanvas'); y += 0.06) {
        await page.mouse.move(c.x + c.width * 0.02, c.y + c.height * y, { steps: 2 });
        await page.mouse.move(c.x + c.width * 0.98, c.y + c.height * y, { steps: 14 });
        if (y > 0.45 && y < 0.52 && !extra.noShot) await page.screenshot({ path: path.join(OUT, `meca_minijeu_${game}_moitie.png`) });
      }
      await page.mouse.up();
    }
    await page.waitForFunction(() => window.POSTS.some((p) => p.name === 'mgDone'), null, { timeout: 8000 }).catch(() => {});
    const done = (await posts('mgDone'))[0];
    return { id, done, posts: await page.evaluate(() => window.POSTS) };
  }
  console.log('[Mini-jeux]');
  for (const g of ['bolts', 'align', 'wires', 'gauge']) {
    const r = await play(g, g === 'align' ? { part: 'front' } : {});
    check(r.done && r.done.data.ok === true && r.done.data.id === r.id, `${g} : terminé par le robot, pièce posée`);
  }
  const st4 = [{ idx: 0, label: 'avant gauche' }, { idx: 1, label: 'avant droite' }, { idx: 4, label: 'arrière gauche' }, { idx: 5, label: 'arrière droite' }];
  let r = await play('wheels', { stages: st4 });
  const stg = r.posts.filter((p) => p.name === 'mgStage');
  check(r.done && r.done.data.ok, '4 pneus : UN seul mini-jeu terminé');
  check(stg.filter((p) => p.data.phase === 'off').length === 4 && stg.filter((p) => p.data.phase === 'on').length === 4, '4 roues changées l\'une après l\'autre (pneu retiré puis remis) dans ce mini-jeu');
  r = await play('wheels', { stages: [{ idx: 0, label: 'avant gauche' }], noShot: true });
  const stg1 = r.posts.filter((p) => p.name === 'mgStage');
  check(r.done && r.done.data.ok && stg1.length === 2 && stg1.every((p) => p.data.stage === 1), 'un seul pneu : seule cette roue est changée');
  r = await play('paint', { from: '#555555', to: '#c00e1a' });
  const prog = r.posts.filter((p) => p.name === 'mgProgress').map((p) => p.data.p);
  check(r.done && r.done.data.ok, 'peinture : terminée');
  check(prog.length > 8 && prog.every((v, i) => i === 0 || v >= prog[i - 1]) && prog[prog.length - 1] === 1, `peinture progressive : ${prog.length} avancements croissants jusqu'à 100 % (couleur appliquée au fur et à mesure)`);
  check(prog.filter((v) => v > 0 && v < 1).length > 5, 'la couleur passe par des étapes intermédiaires (pas de changement instantané)');
  r = await play('film', { to: '#101418' });
  check(r.done && r.done.data.ok, 'film teinté : terminé');

  console.log('[Sécurité des mini-jeux]');
  await clearPosts();
  await send({ action: 'minigame', show: true, id: 99, game: 'bolts', label: 'Délai', timeout: 1 });
  await page.waitForFunction(() => window.POSTS.some((p) => p.name === 'mgDone'), null, { timeout: 4000 }).catch(() => {});
  let d = (await posts('mgDone'))[0];
  check(d && d.data.ok === false && d.data.reason === 'timeout' && await page.$eval('#minigame', (e) => e.classList.contains('hidden')), 'délai dépassé : mini-jeu fermé, rien n\'est posé');
  await clearPosts();
  await send({ action: 'minigame', show: true, id: 100, game: 'wires', label: 'Échap', timeout: 60 });
  await page.waitForSelector('#minigame:not(.hidden)');
  await page.keyboard.press('Escape');
  await wait(100);
  d = (await posts('mgDone'))[0];
  check(d && d.data.ok === false && d.data.reason === 'cancel' && await page.$eval('#minigame', (e) => e.classList.contains('hidden')), 'Échap : mini-jeu annulé et fermé');
  await clearPosts();
  await send({ action: 'minigame', show: true, id: 101, game: 'bolts', label: 'Fermé par le jeu', timeout: 60 });
  await send({ action: 'minigame', show: false, id: 101 });
  await wait(50);
  check(await page.$eval('#minigame', (e) => e.classList.contains('hidden')) && (await posts('mgDone')).length === 0, 'fermé par le jeu (interruption) : plus rien à l\'écran');
  await send({ action: 'minigame', show: true, id: 102, game: 'bolts', label: 'Ancien', timeout: 60 });
  await send({ action: 'minigame', show: false, id: 7 });
  check(!(await page.$eval('#minigame', (e) => e.classList.contains('hidden'))), 'un ancien message de fermeture ne ferme pas le mini-jeu en cours');
  await send({ action: 'minigame', show: false, id: 102 });

  console.log('[Client : suivi en direct, remise des clés]');
  await send({ action: 'install', show: false });
  await send({ action: 'watch', data: { uid: 'DEV-1', plate: 'ABC123', start: true, installed: 0, count: 5, mechanic: 'Max Meca' } });
  await send({ action: 'watch', data: { uid: 'DEV-1', job: 'Peinture', progress: 0.45, active: true, installed: 2, count: 5 } });
  let w = await page.$eval('#watch', (e) => e.textContent);
  check(w.includes('Peinture') && w.includes('2/5') && await page.$eval('#watch .bar i', (e) => e.style.width === '45%'), 'le client voit la peinture en cours (45 %) et 2/5 pièces');
  await page.screenshot({ path: path.join(OUT, 'meca_client_suivi.png') });
  await send({ action: 'watch', data: { uid: 'DEV-1', finished: true } });
  check((await page.$eval('#watch', (e) => e.textContent)).includes('remettre les clés'), 'véhicule prêt : le client attend ses clés');
  await send({ action: 'handover', show: true, name: 'Jean Dupont', plate: 'ABC123', done: 5, total: 5 });
  check((await page.$eval('#handover', (e) => e.textContent)).includes('Remettez les clés à Jean Dupont'), 'mécanicien : consigne de remise des clés');
  await page.screenshot({ path: path.join(OUT, 'meca_remise_cles.png') });
  await send({ action: 'handover', show: false });
  await send({ action: 'watch', data: { uid: 'DEV-1', closed: true, how: 'keys' } });
  check((await page.$eval('#watch', (e) => e.textContent)).includes('Clés remises') && await page.$eval('#handover', (e) => e.classList.contains('hidden')), 'clés remises : intervention clôturée des deux côtés');

  check(errors.length === 0, `aucune erreur JavaScript${errors.length ? ' : ' + errors.join(' | ') : ''}`);
  await browser.close();
  console.log(`Résultat : ${passes}/${passes + fails} vérifications réussies`);
  process.exit(fails ? 1 : 0);
})();
