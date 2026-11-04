// Test des interfaces : mode éditeur de décoration + danseuse (styles, tarifs). NODE_PATH=$(npm root -g) node tests/ui_editor.cjs [captures]
const { chromium } = require('playwright');
const path = require('path');
const out = process.argv[2] || path.join(__dirname, 'shots');
require('fs').mkdirSync(out, { recursive: true });
let fails = 0;
const check = (c, l) => { console.log(`  ${c ? 'ok  ' : 'ÉCHEC'} ${l}`); if (!c) fails++; };
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1600, height: 900 } });
  const errs = []; p.on('pageerror', (e) => errs.push(e.message));
  await p.route(/^https?:/, (r) => r.abort());
  await p.goto('file://' + path.join(__dirname, '..', 'html', 'index.html'));
  await p.evaluate(() => { window.calls = []; window.EDemo = (n, d) => { window.calls.push({ n, d }); return { ok: true }; }; document.body.style.background = 'linear-gradient(135deg,#3a3550,#1c1a26)'; });
  const cat = [['prop_couch_01', 'Canapé', 'Salon'], ['prop_table_03', 'Table basse', 'Salon'], ['prop_tv_flat_01', 'Télévision', 'Salon'], ['v_res_msonbed', 'Lit double', 'Chambre'], ['prop_plant_int_01a', 'Plante', 'Décoration'], ['v_res_m_lampstand', 'Lampadaire', 'Éclairage']].map(([model, label, c]) => ({ model, label, cat: c }));
  await p.evaluate((catalog) => window.postMessage({ action: 'hedit', show: true, data: { name: 'Villa Vinewood', catalog, placed: 12, limit: 40 } }, '*'), cat);
  await p.waitForTimeout(300);
  check(await p.$$eval('#hedit .he-item', (x) => x.length) === 6, 'éditeur : liste des objets');
  await p.hover('[data-he-pick="prop_tv_flat_01"]'); await p.waitForTimeout(150);
  check(await p.evaluate(() => calls.some((c) => c.n === 'he' && c.d.a === 'preview' && c.d.model === 'prop_tv_flat_01')), 'survol : aperçu demandé au jeu');
  await p.click('[data-he-cat="Chambre"]'); await p.waitForTimeout(100);
  check(await p.$$eval('#hedit .he-item', (x) => x.length) === 1, 'catégorie : filtre');
  await p.click('[data-he-cat=""]');
  await p.fill('#he-q', 'lamp'); await p.waitForTimeout(100);
  check(await p.$$eval('#hedit .he-item', (x) => x.length) === 1, 'recherche');
  check(await p.evaluate(() => calls.some((c) => c.d && c.d.a === 'typing' && c.d.on === true)), 'saisie : le jeu arrête de voler pendant la recherche');
  await p.fill('#he-q', '');
  await p.click('[data-he-pick="prop_couch_01"]'); await p.waitForTimeout(100);
  check(await p.evaluate(() => calls.some((c) => c.d && c.d.a === 'pick' && c.d.model === 'prop_couch_01')), 'clic : objet en main');
  await p.evaluate(() => window.postMessage({ action: 'hedit', state: true, snap: true, model: 'prop_couch_01', placed: 12, limit: 40, valid: true }, '*')); await p.waitForTimeout(150);
  await p.screenshot({ path: path.join(out, 'editeur.png') });
  await p.mouse.click(1000, 450); await p.waitForTimeout(100);
  check(await p.evaluate(() => calls.some((c) => c.d && c.d.a === 'click')), 'clic dans la pièce : poser');
  await p.click('[data-he="snap"]'); await p.waitForTimeout(100);
  check(await p.evaluate(() => calls.some((c) => c.d && c.d.a === 'snap' && c.d.on === false)), 'coller au sol : interrupteur');
  await p.evaluate(() => window.postMessage({ action: 'hedit', state: true, snap: true, sel: { id: 4, model: 'prop_tv_flat_01' }, placed: 12, limit: 40 }, '*')); await p.waitForTimeout(150);
  check(await p.$('[data-he="move"]') !== null && await p.$('[data-he="delete"]') !== null, 'objet posé sélectionné : déplacer / retirer');
  // Tous les objets du jeu (allprops.txt) + image d'aperçu
  const allTxt = require('fs').readFileSync(path.join(__dirname, '..', 'html', 'allprops.txt'), 'utf-8');
  await p.evaluate((t) => { const f = window.fetch; window.fetch = (u, o) => (String(u).endsWith('allprops.txt') ? Promise.resolve(new Response(t)) : f(u, o)); }, allTxt);
  await p.evaluate((catalog) => window.postMessage({ action: 'hedit', show: true, data: { name: 'Villa Vinewood', catalog, placed: 12, limit: 40, allProps: true, imageUrl: 'https://img.test/{name}.jpg' } }, '*'), cat);
  await p.waitForTimeout(400);
  check(await p.$('[data-he-cat="__all"]') !== null && (await p.textContent('[data-he-cat="__all"]')).includes('21'), 'chip « Tous les objets » (~21 000)');
  await p.click('[data-he-cat="__all"]'); await p.waitForTimeout(200);
  check(await p.$$eval('#hedit .he-item', (x) => x.length) === 240 && (await p.textContent('#he-list')).includes('autres objets'), 'tous les objets : affichage limité + « précisez la recherche »');
  await p.fill('#he-q', 'bench_01a'); await p.waitForTimeout(150);
  check(await p.$('[data-he-pick="prop_bench_01a"]') !== null, 'recherche dans tous les objets du jeu');
  await p.hover('[data-he-pick="prop_bench_01a"]'); await p.waitForTimeout(250);
  check((await p.textContent('#he-pv')).includes('prop_bench_01a'), 'survol : aperçu (image si disponible + nom)');
  check(await p.evaluate(() => calls.some((c) => c.d && c.d.a === 'preview' && c.d.model === 'prop_bench_01a')), 'survol : aperçu 3D demandé au jeu');
  await p.fill('#he-q', ''); await p.click('[data-he-cat=""]'); await p.fill('#he-q', 'prop_bench_01'); await p.waitForTimeout(150);
  check(await p.$$eval('#hedit .he-item.raw', (x) => x.length) > 1, '« Tout » + recherche : cherche aussi dans tous les objets');
  await p.screenshot({ path: path.join(out, 'editeur_tous_objets.png') });
  // Danseuse en main
  await p.evaluate(() => window.postMessage({ action: 'hedit', state: true, snap: true, model: 'Danseuse', dancer: true, placed: 12, limit: 40, valid: true }, '*')); await p.waitForTimeout(150);
  check((await p.textContent('.he-bar')).includes('Danseuse') && (await p.textContent('.he-bar')).includes('Annuler'), 'danseuse en main : barre « Placement : Danseuse »');
  await p.evaluate(() => window.postMessage({ action: 'hedit', state: true, snap: true, sel: { dancer: 1, model: 'Danseuse' }, placed: 12, limit: 40 }, '*')); await p.waitForTimeout(150);
  check(await p.$('[data-he="move"]') !== null && await p.$('[data-he="delete"]') === null, 'danseuse sélectionnée : déplacer (pas de retrait)');
  await p.evaluate(() => window.postMessage({ action: 'hedit', show: true, data: { name: 'Villa', catalog: [], placed: 0, limit: 0, dancerOnly: true } }, '*')); await p.waitForTimeout(150);
  check(await p.$('#he-q') === null && (await p.textContent('#he-list')).includes('danseuse'), 'droit « Danseuse » seul : éditeur limité à la danseuse');
  await p.evaluate(() => window.postMessage({ action: 'hedit', show: false }, '*'));
  // Danseuse dans la gestion du logement
  const d = { prop: { id: 1, name: 'Villa', address: 'Hillcrest', category: 'Villa' }, contract: { kind: 'sale', holder: 'Alice', starts: 1, paid: 0, uid: 'X' }, role: 'holder',
    rights: { holder: true, manage: true, dancer: true, upgrades: true }, tenants: [], near: [], rent: {},
    upgrades: { rights: { dancer: true, upgrades: true }, list: [{ kind: 'cameras', label: 'Caméras', enabled: true, price: 15000, owned: false }],
      dancer: { active: null, max: 1, styles: [{ id: 'glamour', label: 'Glamour', desc: 'Danse privée élégante' }, { id: 'sensuelle', label: 'Sensuelle', desc: 'Lap dance lascive' }, { id: 'intense', label: 'Intense', desc: 'Lap dance très rythmée' }],
        tariffs: [{ i: 1, minutes: 30, price: 2500 }, { i: 2, minutes: 60, price: 4500 }, { i: 3, minutes: 120, price: 8000 }] } } };
  await p.evaluate((data) => { window.postMessage({ action: 'manage', show: true, data }, '*'); }, d); await p.waitForTimeout(200);
  await p.click('[data-mgt="upgrades"]'); await p.waitForTimeout(150);
  check(await p.$$eval('.dn-style', (x) => x.length) === 3 && await p.$$eval('.dn-tariff', (x) => x.length) === 3, 'danseuse : 3 styles, 3 tarifs (30 min, 1 h, 2 h)');
  await p.click('[data-dn-style="intense"]'); await p.click('[data-dn-tariff="3"]'); await p.waitForTimeout(100);
  await p.screenshot({ path: path.join(out, 'danseuse.png') });
  await p.click('[data-up="dancerStart"]'); await p.waitForTimeout(150);
  await p.click('[data-cf="yes"]'); await p.waitForTimeout(150);
  const st = await p.evaluate(() => calls.filter((c) => c.n === 'upAct').pop());
  check(st && st.d.data.style === 'intense' && st.d.data.tariff === 3, 'commande envoyée : style « Intense », 2 h');
  check(errs.length === 0, 'aucune erreur JavaScript' + (errs.length ? ' : ' + errs.join(' | ') : ''));
  await b.close();
  console.log(fails ? `${fails} ÉCHEC(S)` : 'TOUS LES TESTS INTERFACE SONT PASSÉS');
  process.exit(fails ? 1 : 0);
})();
