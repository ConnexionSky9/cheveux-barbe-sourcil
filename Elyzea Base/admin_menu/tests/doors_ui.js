// Test de l’interface (portes par métier + pupitre) dans Chromium.
// node tests/doors_ui.js <dossier admin_menu> <dossier pour les captures>
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
  let fails = 0, n = 0;
  const check = (name, c) => { n++; if (c) console.log('OK   ' + name); else { fails++; console.log('FAIL ' + name); } };
  await page.evaluate(() => {
    const perms = {}; ['editor_doors'].forEach((p) => perms[p] = true);
    window.postMessage({ action: 'open' }, '*');
    window.postMessage({ action: 'data', data: {
      me: { id: 1, label: 'Fondateur', color: '#d9b56a', level: 100, perms, onDuty: true, duty: true },
      players: [{ id: 2, name: 'Officier' }], keys: [],
      jobs: [{ name: 'lspd', label: 'LSPD', grades: [] }, { name: 'bcso', label: 'BCSO', grades: [] }],
      config: { editor: { minLevel: 0, quickProps: [], quickPeds: [], npcPresets: [] }, doorDistance: 2.2, doorMinDistance: 0.8, doorMaxDistance: 15,
        doorJobCategories: [{ key: 'police', label: 'Police (toutes agences)', icon: '🚓' }, { key: 'ems', label: 'EMS (toutes agences)', icon: '🚑' }],
        doorPanelRadius: 1.5, doorPanelMinRadius: 0.8, doorPanelMaxRadius: 6 },
      editor: { spawns: [], props: [], peds: [], fields: [], stations: [], searches: [], hidden: [], zones: [], stashes: [],
        doors: [{ id: 1, name: 'Cellule 1', locked: true, owners: [], jobs: ['police'], dist: 3 }, { id: 2, name: 'Cellule 2', locked: false, owners: [], jobs: [], dist: 4 }],
        doorPanels: [{ id: 1, name: 'PC cellules', radius: 1.5, jobs: ['lspd'], doors: [1, 2], dist: 2 }] },
    } }, '*');
  });
  await page.waitForTimeout(300);
  await page.evaluate(() => { tab = 'editor'; editorSub = 'doors'; render(); });
  await page.waitForTimeout(200);
  const txt = await page.textContent('#content').catch(() => '');
  check('onglet portes affiché', txt.includes('Pupitres de commande'));
  check('pupitre listé', txt.includes('PC cellules') && txt.includes('LSPD'));
  check('métier de la porte affiché', txt.includes('Police (toutes agences)'));
  // gérer la porte 1 : ajouter un métier
  await page.click('[data-ed="door_manage"][data-id="1"]');
  await page.selectOption('select[data-draft="doorJob"]', 'lspd');
  await page.click('[data-ed="door_add_job"]');
  await page.waitForTimeout(150);
  const add = posts.find((p) => p.ep === 'action' && JSON.stringify(p.body).includes('editor_door_add_job'));
  check('ajout de métier envoyé', add && JSON.stringify(add.body).includes('lspd'));
  await page.click('[data-ed="door_rm_job"][data-job="police"]');
  await page.waitForTimeout(150);
  check('retrait de métier envoyé', posts.some((p) => JSON.stringify(p.body).includes('editor_door_remove_job')));
  // création d'un pupitre
  await page.fill('input[data-dpf="name"]', 'PC LSPD');
  await page.selectOption('select[data-draft="dpJob"]', 'police');
  await page.click('[data-ed="dp_add_job"]');
  await page.click('[data-ed="dp_door"][data-id="2"]');
  await page.screenshot({ path: out + '/portes_menu.png', fullPage: false });
  await page.click('[data-ed="dp_create"]');
  await page.waitForTimeout(150);
  const cr = posts.find((p) => JSON.stringify(p.body).includes('editor_add_doorpanel'));
  check('création de pupitre envoyée (nom, métier, porte)', cr && JSON.stringify(cr.body).includes('PC LSPD') && JSON.stringify(cr.body).includes('"police"') && JSON.stringify(cr.body).includes('[2]'));
  await page.click('[data-ed="dp_edit"][data-id="1"]');
  await page.click('[data-ed="dp_door"][data-id="1"]');
  await page.click('[data-ed="dp_save"]');
  await page.waitForTimeout(150);
  const up = posts.find((p) => JSON.stringify(p.body).includes('editor_doorpanel_update'));
  check('modification de pupitre envoyée (porte 1 retirée)', up && JSON.stringify(up.body).includes('"doors":[2]'));
  // interface joueur
  await page.evaluate(() => window.postMessage({ action: 'doorpanel', data: { id: 1, name: 'PC cellules', doors: [{ id: 1, name: 'Cellule 1', locked: true }, { id: 2, name: 'Cellule 2', locked: false }] } }, '*'));
  await page.waitForTimeout(150);
  check('pupitre joueur visible', await page.isVisible('#doorpanel .dp-box'));
  await page.screenshot({ path: out + '/pupitre_joueur.png' });
  await page.click('#doorpanel [data-dp="set"][data-door="1"]');
  await page.click('#doorpanel [data-dp="all_lock"]');
  await page.waitForTimeout(150);
  const set = posts.find((p) => p.ep === 'doorpanel_set');
  check('ouvrir cellule 1 envoyé', set && set.body.door === 1 && set.body.locked === false);
  check('tout verrouiller envoyé', posts.some((p) => p.ep === 'doorpanel_all' && p.body.locked === true));
  await page.keyboard.press('Escape');
  await page.waitForTimeout(100);
  check('Échap ferme le pupitre', !(await page.isVisible('#doorpanel .dp-box')) && posts.some((p) => p.ep === 'doorpanel_close'));
  // porte avec rôle métier
  await page.evaluate(() => window.postMessage({ action: 'door', data: { id: 1, name: 'Cellule 1', locked: true, role: 'job', hasCode: true } }, '*'));
  await page.waitForTimeout(100);
  check('porte « métier » : bouton sans pavé de code', await page.isVisible('#door [data-door="toggle"]') && !(await page.isVisible('#door .keypad')));
  check('aucune erreur JS', errors.length === 0);
  if (errors.length) console.log(errors);
  console.log(`\n${n - fails}/${n}`);
  await browser.close();
  process.exit(fails ? 1 : 0);
})();
