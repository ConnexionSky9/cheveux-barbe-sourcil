// Test de l'interface des téléporteurs (éditeur + choix de destination côté joueur) dans Chromium.
// node tests/teleports_ui.cjs <dossier admin_menu> <dossier pour les captures>
const { chromium } = require(process.env.PLAYWRIGHT || 'playwright');
const path = require('path');
(async () => {
  const html = path.resolve(process.argv[2], 'html/index.html');
  const out = process.argv[3];
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1500, height: 1000 } });
  const errors = [], posts = [];
  page.on('pageerror', (e) => errors.push(String(e)));
  await page.route('https://admin_menu/**', (r) => {
    const ep = r.request().url().split('/').pop(), body = JSON.parse(r.request().postData() || '{}');
    posts.push({ ep, body });
    const res = ep === 'self' && body.name === 'coords' ? { coords: 'vector4(-75.25, -818.90, 326.18, 92.50)' } : {};
    r.fulfill({ status: 200, body: JSON.stringify(res), contentType: 'application/json' });
  });
  await page.goto('file://' + html);
  let fails = 0, n = 0;
  const check = (name, c) => { n++; if (c) console.log('OK   ' + name); else { fails++; console.log('FAIL ' + name); } };
  const saves = () => posts.filter((p) => p.ep === 'action' && p.body.name === 'editor_tp_save');
  await page.evaluate(() => {
    const perms = { editor_spawns: true };
    window.postMessage({ action: 'open' }, '*');
    window.postMessage({ action: 'data', data: {
      me: { id: 1, label: 'Fondateur', color: '#d9b56a', level: 100, perms, onDuty: true, duty: true },
      players: [], keys: [], jobs: [],
      config: { editor: { minLevel: 0, quickProps: [], quickPeds: [], npcPresets: [] } },
      editor: { spawns: [], props: [], peds: [], fields: [], stations: [], searches: [], hidden: [], zones: [], stashes: [], doors: [], doorPanels: [],
        teleports: [{ id: 1, name: 'Ascenseur Maze Bank', mode: 'multi', radius: 1.5, marker: true, vehicle: false, twoWay: false, dist: 12,
          from: { name: 'Hall', x: 1, y: 2, z: 3, h: 0 }, dests: [{ name: 'Toit', x: 4, y: 5, z: 6, h: 0 }, { name: 'Parking', x: 7, y: 8, z: 9, h: 0 }] }] },
    } }, '*');
  });
  await page.waitForTimeout(300);
  await page.evaluate(() => { tab = 'editor'; editorSub = 'teleports'; render(); });
  await page.waitForTimeout(200);
  const txt = await page.textContent('#content');
  check('onglet Téléporteurs dans l\'éditeur', (await page.$('[data-esub="teleports"]')) !== null);
  check('téléporteur existant listé avec ses destinations', txt.includes('Ascenseur Maze Bank') && txt.includes('Toit') && txt.includes('Parking'));
  // création A → B
  await page.fill('[data-tpf="name"]', 'Passage secret');
  await page.click('[data-tpx="create"]');
  check('création refusée sans coordonnées', saves().length === 0);
  await page.click('[data-tpx="mypos"][data-path="from"]');
  await page.waitForTimeout(150);
  check('« Ma position » remplit le départ (x, y, z, cap)', (await page.inputValue('[data-tpf="from.x"]')) === '-75.25' && (await page.inputValue('[data-tpf="from.h"]')) === '92.5');
  await page.fill('[data-tpf="dests.0.x"]', '100.5'); await page.fill('[data-tpf="dests.0.y"]', '-200.25');
  await page.fill('[data-tpf="dests.0.z"]', '30'); await page.fill('[data-tpf="dests.0.h"]', '180');
  await page.screenshot({ path: path.join(out, 'tp_editor_ab.png') });
  await page.click('[data-tpx="create"]');
  let sent = saves().pop();
  check('A → B envoyé avec coordonnées précises', sent && sent.body.data.mode === 'ab' && sent.body.data.dests.length === 1 && sent.body.data.dests[0].x === 100.5
    && sent.body.data.dests[0].y === -200.25 && sent.body.data.from.z === 326.18 && sent.body.data.twoWay === true);
  // mode multiple
  await page.evaluate(() => window.postMessage({ action: 'tpSaved', id: 2 }, '*'));
  await page.waitForTimeout(100);
  check('formulaire vidé après confirmation du serveur', (await page.inputValue('[data-tpf="name"]')) === '');
  await page.fill('[data-tpf="name"]', 'Métro');
  await page.click('[data-tpx="mode"][data-mode="multi"]');
  await page.click('[data-tpx="add_dest"]');
  await page.click('[data-tpx="add_dest"]');
  check('3 destinations dans le formulaire', (await page.$$('[data-tpf$=".x"]')).length === 4);
  await page.click('[data-tpx="rm_dest"][data-i="2"]');
  check('destination retirée', (await page.$$('[data-tpf$=".x"]')).length === 3);
  for (const [p, v] of [['from', [1, 2, 3]], ['dests.0', [10, 20, 30]], ['dests.1', [40, 50, 60]]]) {
    for (const [i, k] of ['x', 'y', 'z'].entries()) await page.fill(`[data-tpf="${p}.${k}"]`, String(v[i]));
  }
  await page.fill('[data-tpf="dests.0.name"]', 'Station Sud'); await page.fill('[data-tpf="dests.1.name"]', 'Station Nord');
  await page.click('[data-tpx="tog_vehicle"]');
  await page.screenshot({ path: path.join(out, 'tp_editor_multi.png'), fullPage: true });
  await page.click('[data-tpx="create"]');
  sent = saves().pop();
  check('multi envoyé : 2 destinations nommées, véhicules autorisés', sent && sent.body.data.mode === 'multi' && sent.body.data.dests.length === 2
    && sent.body.data.dests[1].name === 'Station Nord' && sent.body.data.vehicle === true && sent.body.data.twoWay === false);
  // modifier l'existant
  await page.click('[data-tpx="edit"][data-id="1"]');
  check('modification : formulaire prérempli', (await page.inputValue('[data-tpf="dests.1.name"]')) === 'Parking');
  await page.click('[data-tpx="back"]');
  // côté joueur
  await page.evaluate(() => window.postMessage({ action: 'close' }, '*'));
  await page.evaluate(() => window.postMessage({ action: 'tpchoose', data: { id: 1, name: 'Ascenseur Maze Bank', dests: [{ i: 1, name: 'Toit' }, { i: 2, name: 'Parking' }] } }, '*'));
  await page.waitForTimeout(400);
  check('choix de destination affiché', await page.isVisible('#tpchoose') && (await page.textContent('#tpchoose')).includes('Parking'));
  await page.screenshot({ path: path.join(out, 'tp_choose.png') });
  await page.click('[data-tpc="pick"][data-idx="2"]');
  const pick = posts.filter((p) => p.ep === 'tpchoose_pick').pop();
  check('clic : destination 2 envoyée (id + numéro seulement)', pick && pick.body.id === 1 && pick.body.idx === 2 && Object.keys(pick.body).length === 2);
  check('fenêtre refermée', !(await page.isVisible('#tpchoose')));
  await page.evaluate(() => window.postMessage({ action: 'tpchoose', data: { id: 1, name: 'A', dests: [{ i: 1, name: 'Toit' }] } }, '*'));
  await page.waitForTimeout(100);
  await page.keyboard.press('Escape');
  check('Échap ferme et prévient le jeu', !(await page.isVisible('#tpchoose')) && posts.some((p) => p.ep === 'tpchoose_close'));
  check('aucune erreur JS', errors.length === 0);
  if (errors.length) console.log(errors);
  console.log(`\n${n - fails}/${n}`);
  await browser.close();
  process.exit(fails ? 1 : 0);
})();
