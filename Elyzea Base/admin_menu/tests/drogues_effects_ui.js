// Test de l'onglet « Gestion des drogues › Effets » dans Chromium : durée × et force × de chaque produit
// (gâteaux aux champignons), enregistrement envoyé au jeu. node tests/drogues_effects_ui.js <dossier admin_menu> <dossier captures>
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
  const drogues = {
    available: true, full: false, emsLinked: true, users: [], creatures: [{ model: 'a_c_chimp', label: 'Chimpanzé' }], labels: {},
    drugs: [{ id: 'mushrooms', label: 'Champignons hallucinogènes', icon: '🍄', desc: 'Hallucinations.' }],
    products: [{ item: 'shroom_cake_s', label: 'Petit gâteau aux champignons', drug: 'mushrooms', mult: 0.7, power: 0.7 },
      { item: 'shroom_cake_m', label: 'Gâteau moyen aux champignons', drug: 'mushrooms', mult: 1.4, power: 1.1 },
      { item: 'shroom_cake_l', label: 'Gros gâteau aux champignons', drug: 'mushrooms', mult: 2.2, power: 1.6 }],
    settings: { drugs: { mushrooms: { enabled: true, duration: 150, cooldown: 120, intensity: 100 } },
      trip: { maxCreatures: 4, spawnEvery: 7, hitCooldown: 4, fallTime: 3, lifetime: 30 }, creatures: { a_c_chimp: true },
      products: { shroom_cake_s: { mult: 0.7, power: 0.7 }, shroom_cake_m: { mult: 1.4, power: 1.1 }, shroom_cake_l: { mult: 2.2, power: 1.6 } } },
  };
  await page.evaluate(() => window.postMessage({ action: 'open' }, '*'));
  await page.evaluate((drogues) => window.postMessage({ action: 'data', data: {
    me: { id: 1, label: 'Modo', color: '#ccc', level: 50, perms: { drugs_effects: true }, onDuty: true, duty: true },
    players: [{ id: 1, name: 'Moi' }], keys: [], jobs: [], config: { editor: { minLevel: 0, quickProps: [], quickPeds: [], npcPresets: [] } }, drogues,
  } }, '*'), drogues);
  await page.waitForTimeout(250);
  await page.evaluate(() => { tab = 'drogues'; render(); });
  await page.waitForTimeout(150);
  const txt = await page.textContent('#content');
  check('onglet Effets : les 3 gâteaux avec leur effet (durée · force)', txt.includes('Gros gâteau aux champignons') && txt.includes('5 min 30 s · 160 %') && txt.includes('1 min 45 s · 70 %'));
  check('durée × et force × modifiables pour chaque gâteau', (await page.$$('[data-dn^="products."]')).length === 6);
  await page.fill('[data-dn="products.shroom_cake_l.mult"]', '3');
  await page.fill('[data-dn="products.shroom_cake_l.power"]', '2');
  await page.screenshot({ path: out + '/drogues_effets_gateaux.png', fullPage: false });
  await page.click('[data-dsave]');
  await page.waitForTimeout(150);
  const p = posts.filter((x) => x.ep === 'action').pop();
  const sec = p && p.body.data && p.body.data.data && p.body.data.data.sections;
  check('enregistrer : section « products » envoyée avec les nouvelles valeurs', sec && sec.products && sec.products.shroom_cake_l.mult === 3 && sec.products.shroom_cake_l.power === 2 && sec.drugs);
  check('aucune erreur JavaScript', errors.length === 0 || (console.log(errors.join(' | ')), false));
  await browser.close();
  console.log(`Résultat : ${fails ? fails + ' échec(s)' : 'tout est bon'}`);
  process.exit(fails ? 1 : 0);
})();
