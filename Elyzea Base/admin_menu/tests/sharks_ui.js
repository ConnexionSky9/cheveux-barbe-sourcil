// Test de l'onglet « Requins » dans Chromium : affichage, envois au jeu, saisie conservée.
// node tests/sharks_ui.js <dossier admin_menu> <dossier pour les captures>
const { chromium } = require(process.env.PLAYWRIGHT || 'playwright');
const path = require('path');
(async () => {
  const html = path.resolve(process.argv[2], 'html/index.html');
  const out = process.argv[3];
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined });
  const page = await browser.newPage({ viewport: { width: 1500, height: 1000 } });
  const errors = [], posts = [];
  page.on('pageerror', (e) => errors.push(String(e)));
  await page.route('https://admin_menu/**', (r) => { posts.push({ ep: r.request().url().split('/').pop(), body: JSON.parse(r.request().postData() || '{}') }); r.fulfill({ status: 200, body: '{}', contentType: 'application/json' }); });
  await page.goto('file://' + html);
  let fails = 0;
  const check = (name, c) => { if (c) console.log('OK   ' + name); else { fails++; console.log('FAIL ' + name); } };
  const last = (ep, name) => posts.filter((p) => p.ep === ep && (!name || p.body.name === name)).pop();
  const zone = [{ x: 0, y: 0, z: 0 }, { x: 100, y: 0, z: 0 }, { x: 100, y: 100, z: 0 }, { x: 0, y: 100, z: 0 }];
  const data = (extra = {}) => page.evaluate(([zone, extra]) => window.postMessage({ action: 'data', data: {
    me: { id: 1, label: 'Fondateur', color: '#d9b56a', level: 100, perms: { sharks_manage: true }, onDuty: true, duty: true },
    players: [{ id: 1, name: 'Moi' }, { id: 7, name: 'Sam' }], keys: [], jobs: [], config: { editor: { minLevel: 0, quickProps: [], quickPeds: [], npcPresets: [] } },
    sharks: Object.assign({
      enabled: true, alive: 2, models: [{ id: 'a_c_sharktiger', label: 'Requin tigre' }, { id: 'a_c_sharkhammer', label: 'Requin marteau' }],
      limits: { maxPerSpawn: 5, maxSpawns: 20, maxPerArea: 30, minRespawn: 10, maxRespawn: 3600, activate: 300 },
      areas: [{ id: 3, name: 'Baie de Paleto', enabled: true, model: 'a_c_sharktiger', respawn: 120, kills: 4, points: zone,
        spawns: [{ x: 20, y: 20, z: -3, count: 2 }, { x: 80, y: 70, z: -3, count: 1 }], total: 3, alive: 2, dead: 1, next: 75, center: { x: 50, y: 50, z: 0 }, radius: 70 }],
      immune: [{ index: 1, name: 'Sam', note: 'biologiste', by: 'Admin', at: 1760000000, online: 7 }],
    }, extra),
  } }, '*'), [zone, extra]);
  await page.evaluate(() => window.postMessage({ action: 'open' }, '*'));
  await data();
  await page.waitForTimeout(250);
  await page.evaluate(() => { tab = 'sharks'; render(); });
  await page.waitForTimeout(150);
  const txt = await page.textContent('#content');
  check('onglet Requins : zone, état, réapparition, joueurs protégés', txt.includes('Baie de Paleto') && txt.includes('2 / 3 en vie') && txt.includes('1 min 15 s') && txt.includes('Sam') && txt.includes('connecté (ID 7)'));
  await page.screenshot({ path: out + '/requins.png', fullPage: false });
  await page.fill('[data-skd="name"]', 'Plage nord');
  await data();                               // actualisation automatique pendant la saisie
  await page.waitForTimeout(200);
  check('saisie conservée pendant l\'actualisation automatique', (await page.inputValue('[data-skd="name"]')) === 'Plage nord');
  await page.click('[data-ska="new"]');
  await page.waitForTimeout(100);
  let p = last('editor', 'sharks_zone_draw');
  check('nouvelle zone : dessin lancé en jeu avec son nom', p && p.body.data.name === 'Plage nord' && !p.body.data.id);
  await page.click('[data-ska="spawns"]');
  await page.waitForTimeout(100);
  p = last('editor', 'sharks_spawns_draw');
  check('poser les points : zone et points existants envoyés au jeu', p && p.body.data.id === 3 && p.body.data.points.length === 4 && p.body.data.spawns.length === 2);
  await page.click('[data-ska="tp"]');
  await page.waitForTimeout(100);
  check('y aller', !!last('editor', 'sharks_tp'));
  await page.selectOption('[data-skidx="1"] [data-skcount]', '4');
  await page.waitForTimeout(100);
  p = last('action');
  check('nombre de requins d\'un point', p && p.body.name === 'sharks_spawn_count' && p.body.data.count === 4 && p.body.data.index === 1);
  await page.fill('[data-skf="respawn"]', '300');
  await page.press('[data-skf="respawn"]', 'Tab');
  await page.waitForTimeout(100);
  p = last('action');
  check('délai de réapparition', p && p.body.name === 'sharks_area_update' && p.body.data.respawn === 300);
  await page.selectOption('[data-skf="model"]', 'a_c_sharkhammer');
  await page.waitForTimeout(100);
  check('espèce', last('action').body.data.model === 'a_c_sharkhammer');
  await page.click('[data-ska="toggle"]');
  await page.waitForTimeout(100);
  check('désactiver la zone', last('action').body.data.enabled === false);
  await page.fill('[data-skd="target"]', '7');
  await page.fill('[data-skd="note"]', 'plongeur');
  await page.click('[data-ska="immune"]');
  await page.waitForTimeout(100);
  p = last('action');
  check('protéger un joueur par son ID', p && p.body.name === 'sharks_immune_add' && p.body.data.target === 7 && p.body.data.note === 'plongeur');
  await page.click('[data-ska="global"]');
  await page.waitForTimeout(100);
  check('désactiver tous les requins', last('action').body.name === 'sharks_settings' && last('action').body.data.enabled === false);
  await data({ areas: [], immune: [] });
  await page.waitForTimeout(200);
  check('aucune zone : message clair', (await page.textContent('#content')).includes('Aucune zone de requins'));
  check('aucune erreur JavaScript', errors.length === 0);
  if (errors.length) console.log(errors);
  console.log(`\n${fails} échec(s)`);
  await browser.close();
  process.exit(fails ? 1 : 0);
})();
