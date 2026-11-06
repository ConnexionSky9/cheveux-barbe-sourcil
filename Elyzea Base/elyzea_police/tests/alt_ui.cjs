// Menu ALT dans Chromium : rendu (DA Elyzea), clavier (↑ ↓ Entrée, 1-9), clic, double clic, Échap, clic à côté.
//   node tests/alt_ui.cjs [dossier_captures]
const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');
const OUT = process.argv[2] || path.join(__dirname, 'shots');
fs.mkdirSync(OUT, { recursive: true });
let fails = 0;
const check = (c, l) => { console.log(`  ${c ? 'ok  ' : 'ÉCHEC'} ${l}`); if (!c) fails++; };
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1600, height: 900 } });
  const posts = [];
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.route(/^https:\/\/(elyzea_police|nui-resource)\//, (r) => { posts.push({ ep: r.request().url().split('/').pop(), body: JSON.parse(r.request().postData() || '{}') }); r.fulfill({ status: 200, body: '{}', contentType: 'application/json' }); });
  await page.route(/fonts\.g/, (r) => r.abort());
  await page.addInitScript(() => { window.GetParentResourceName = () => 'elyzea_police'; });
  await page.goto('file://' + path.join(__dirname, '..', 'html', 'index.html'));
  await page.evaluate(() => { document.body.style.background = 'radial-gradient(900px 600px at 40% 40%, #3a3550, #12101c)'; });
  const open = (m) => page.evaluate((m) => window.postMessage(Object.assign({ action: 'altMenu', show: true }, m), '*'), m);
  const opts = [
    { key: 1, label: 'Menotter', icon: 'cuff' },
    { key: 2, label: 'Escorter', icon: 'escort', disabled: true, desc: 'La personne doit être menottée' },
    { key: 3, label: 'Porter', icon: 'carry' },
    { key: 4, label: 'Examiner', icon: 'examine', desc: 'EMS en service' },
    { key: 5, label: 'Copier l\'animation', icon: 'anim_copy' },
  ];
  await open({ title: 'Personne · ID 12', kind: 'player', options: opts, x: 0.45, y: 0.3 });
  await page.waitForTimeout(500);
  check(await page.isVisible('#alt') && (await page.textContent('#alt')).includes('Personne · ID 12') && (await page.textContent('#alt .tt em')).includes('4 actions'), 'menu ouvert au curseur : titre, type, 4 actions possibles');
  check(await page.$eval('#alt button.on', (b) => b.dataset.key) === '1', 'première action surlignée');
  await page.keyboard.press('ArrowDown');
  check(await page.$eval('#alt button.on', (b) => b.dataset.key) === '3', '↓ saute l\'action grisée (escorter) et va sur « Porter »');
  await page.keyboard.press('ArrowUp'); await page.keyboard.press('ArrowUp');
  check(await page.$eval('#alt button.on', (b) => b.dataset.key) === '5', '↑ fait le tour de la liste');
  const r = await page.$eval('#alt', (e) => { const b = e.getBoundingClientRect(); return [b.left, b.top, b.right, b.bottom]; });
  await page.screenshot({ path: path.join(OUT, 'alt_menu.png'), clip: { x: Math.max(0, r[0] - 40), y: Math.max(0, r[1] - 40), width: r[2] - r[0] + 80, height: r[3] - r[1] + 80 } });
  await page.keyboard.press('Enter');
  await page.waitForTimeout(200);
  let sel = posts.filter((p) => p.ep === 'altSelect');
  check(sel.length === 1 && sel[0].body.key === 5 && !(await page.isVisible('#alt')), 'Entrée : action 5 envoyée, menu fermé');
  // double clic / clic + touche : une seule action
  await open({ title: 'Véhicule · ELY 123', kind: 'vehicle', options: opts, x: 0.98, y: 0.95 });
  await page.waitForTimeout(400);
  const b = await page.$eval('#alt', (e) => [e.offsetLeft + e.offsetWidth, e.offsetTop + e.offsetHeight]);
  check(b[0] <= 1600 && b[1] <= 900, 'ouvert au bord de l\'écran : le menu reste entièrement visible');
  posts.length = 0;
  await page.click('#alt button[data-key="3"]', { clickCount: 2 });
  await page.keyboard.press('1');
  await page.waitForTimeout(200);
  sel = posts.filter((p) => p.ep === 'altSelect');
  check(sel.length === 1 && sel[0].body.key === 3, 'double clic puis touche : une seule action envoyée');
  await open({ title: 'Personne', kind: 'player', options: opts, x: 0.3, y: 0.3 });
  await page.waitForTimeout(300);
  posts.length = 0;
  await page.keyboard.press('2');
  check(posts.filter((p) => p.ep === 'altSelect').length === 0 && await page.isVisible('#alt'), 'action grisée (2) : rien ne se passe');
  await page.keyboard.press('Escape');
  await page.waitForTimeout(100);
  check(!(await page.isVisible('#alt')) && posts.filter((p) => p.ep === 'altClose').length === 1, 'Échap : fermé, une seule fermeture envoyée');
  await open({ title: 'Bijouterie', kind: 'ext', options: opts.slice(0, 2), x: 0.3, y: 0.3 });
  await page.waitForTimeout(500);
  posts.length = 0;
  await page.mouse.click(1400, 800);
  await page.waitForTimeout(100);
  check(!(await page.isVisible('#alt')) && posts.filter((p) => p.ep === 'altClose').length === 1, 'clic à côté : fermé');
  check(errors.length === 0, 'aucune erreur JavaScript' + (errors.length ? ' → ' + errors.join(' | ') : ''));
  await browser.close();
  console.log(`\nMenu ALT (interface) : ${fails} échec(s)`);
  process.exit(fails ? 1 : 0);
})();
