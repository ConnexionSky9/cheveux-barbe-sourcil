// Test de l'appli « Commande » dans le téléphone de service (elyzea_jobphone), hors jeu.
// Usage : NODE_PATH=$(npm root -g) node tests/ui_phone.cjs [dossier de captures]
const path = require('path');
const fs = require('fs');
const { chromium } = require('playwright');
const ROOT = path.resolve(__dirname, '..');
const PHONE = path.resolve(ROOT, '..', 'elyzea_jobphone', 'html', 'index.html');
const OUT = process.argv[2] || path.join(ROOT, 'tests', 'shots');
fs.mkdirSync(OUT, { recursive: true });
let fails = 0, passes = 0;
const check = (ok, l) => { if (ok) { passes++; console.log('  ok   ' + l); } else { fails++; console.log('  ÉCHEC ' + l); } };
const now = Math.floor(Date.now() / 1000);
const ord = (id, status, extra = {}) => Object.assign({ id, num: '#00' + id, status, statusLabel: { pending: 'En attente', preparing: 'En préparation', ready: 'Terminée' }[status], t: now - 90,
  customer: 'Claire Cliente', units: 3, done: 0, lines: [{ label: 'Le Classic', qty: 2, done: 0 }, { label: 'Cola', qty: 1, done: 0 }] }, extra);
let state = { pending: [ord(1, 'pending'), ord(2, 'pending')], mine: [], others: [], history: [{ num: '#000', statusLabel: 'Livrée', lines: [{ label: 'Frites', qty: 1 }], customer_name: 'Bob', employee_name: 'Paul' }],
  can: { take: true, cook: true, deliver: true, manage: true } };
const calls = [];
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1600, height: 900 } });
  const errs = [];
  page.on('pageerror', (e) => errs.push(String(e)));
  await page.route(/^https:\/\/[^/]+\/(.+)$/, async (route) => {
    const name = route.request().url().split('/').pop();
    const body = JSON.parse(route.request().postData() || '{}');
    calls.push({ name, body });
    let r = {};
    if (name === 'req' && body.action === 'home') r = { job: { res: 'elyzea_restaurant', label: 'Restaurant', color: '#f97316' }, me: { duty: true, name: 'Paul Patron', grade: 'Patron', matricule: 'RS-001', number: '918-0001', times: { session: 60, total: 600 }, health: { hp: 100, life: 'ok' } }, unread: 0, alerts: 0 };
    else if (name === 'req' && body.action === 'cmd') {
      const op = body.data.op;
      if (op === 'take') { const o = state.pending.shift(); o.status = 'preparing'; o.statusLabel = 'En préparation'; state.mine.push(o); r = { ok: true, message: 'Commande prise en charge.' }; }
      else if (op === 'deliver') r = { ok: true, message: 'Commande remise.' };
      else r = state;
    }
    await route.fulfill({ contentType: 'application/json', body: JSON.stringify(r) });
  });
  await page.goto('file://' + PHONE);
  await page.evaluate(() => window.postMessage({ action: 'open', job: { res: 'elyzea_restaurant', label: 'Restaurant', color: '#f97316' }, map: {}, levels: {} }, '*'));
  await page.waitForTimeout(600);
  check(await page.locator('[data-app="cmd"]').count() === 1, 'icône « Commande » sur l\'accueil (restaurant)');
  await page.screenshot({ path: path.join(OUT, 'p1_accueil.png') });
  await page.click('[data-app="cmd"]');
  await page.waitForTimeout(500);
  check((await page.locator('#cmd [data-take]').count()) === 2, 'Commandes en attente : 2, bouton « Prendre en charge »');
  check((await page.textContent('#cmd')).includes('#001') && (await page.textContent('#cmd')).includes('2 × Le Classic'), 'numéro, produits et quantités affichés');
  await page.screenshot({ path: path.join(OUT, 'p2_attente.png') });
  await page.click('#cmd [data-take="1"]');
  await page.waitForTimeout(600);
  const take = calls.find((c) => c.body.action === 'cmd' && c.body.data.op === 'take');
  check(take && take.body.data.data.id === 1, 'prise en charge envoyée (op take, id 1)');
  check((await page.textContent('#cmd')).includes('Mes commandes (1)'), 'passe sur « Mes commandes »');
  await page.screenshot({ path: path.join(OUT, 'p3_mes_commandes.png') });
  await page.click('#cmd [data-tab="history"]');
  await page.waitForTimeout(400);
  check((await page.textContent('#cmd')).includes('Livrée'), 'Historique affiché');
  await page.evaluate(() => window.postMessage({ action: 'push', what: 'cmd' }, '*'));
  await page.waitForTimeout(300);
  check(errs.length === 0, 'aucune erreur JavaScript' + (errs.length ? ' : ' + errs.join(' | ') : ''));
  await browser.close();
  console.log(`\nTOTAL : ${passes} ok, ${fails} échec(s)`);
  process.exit(fails ? 1 : 0);
})();
