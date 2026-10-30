// Test de l'inventaire (navigateur Chromium, hors jeu, données fictives) : node tests/ui_inventory.cjs <dossier des captures>
const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');
const OUT = process.argv[2] || path.join(require('os').tmpdir(), 'inventory_ui');
fs.mkdirSync(OUT, { recursive: true });
let fails = 0, passes = 0;
const check = (ok, l) => { if (ok) { passes++; console.log('  ok   ' + l); } else { fails++; console.log('  ÉCHEC ' + l); } };

(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1920, height: 1080 } });
  const errs = [];
  p.on('pageerror', (e) => errs.push(e.message));
  p.on('console', (m) => { if (m.type() === 'error' && !/fonts|Failed to load resource|ERR_FILE_NOT_FOUND/.test(m.text())) errs.push(m.text()); });
  await p.goto('file://' + path.join(__dirname, '..', 'html', 'index.html'));
  await p.waitForTimeout(600);
  const shot = (n) => p.screenshot({ path: path.join(OUT, n + '.png') });
  const visible = () => p.$$eval('#grid .slot.has', (l) => l.filter((x) => getComputedStyle(x).display !== 'none').map((x) => x.querySelector('.name').textContent));
  const n = (c) => p.textContent(`#tabs [data-n="${c}"]`);

  console.log('\n[Onglets]');
  check(await p.isVisible('#app'), 'inventaire ouvert');
  check(await n('all') === '15' && await n('weapons') === '3' && await n('food') === '3' && await n('papers') === '3',
    `compteurs : tout ${await n('all')} · armes ${await n('weapons')} · nourriture ${await n('food')} · papiers ${await n('papers')}`);
  await shot('1_tout');
  await p.click('#tabs [data-cat="weapons"]'); await p.waitForTimeout(80);
  let v = await visible();
  check(v.length === 1 && v[0] === 'Couteau', 'Armes & munitions (hors raccourcis) : ' + v.join(', '));
  check(await p.$eval('#hotbar .slot:nth-child(4)', (e) => !e.classList.contains('dim')) && await p.$eval('#hotbar .slot:nth-child(5)', (e) => !e.classList.contains('dim')) && await p.$eval('#hotbar .slot:nth-child(1)', (e) => e.classList.contains('dim')),
    'raccourcis toujours visibles : pistolet et munitions ressortent, le reste est atténué');
  await shot('2_armes');
  await p.click('#tabs [data-cat="food"]'); await p.waitForTimeout(80);
  v = await visible();
  check(v.length === 1 && v[0] === 'Sandwich', 'Nourriture (hors raccourcis) : ' + v.join(', '));
  await p.click('#tabs [data-cat="papers"]'); await p.waitForTimeout(80);
  v = await visible();
  check(v.length === 3 && v.every((x) => /identité|Permis|PPA/.test(x)), 'Papiers : ' + v.join(', '));
  await shot('3_papiers');

  console.log('\n[Recherche]');
  await p.click('#tabs [data-cat="all"]');
  await p.fill('#search', 'perm'); await p.waitForTimeout(200);
  v = await visible();
  check(v.length === 1 && v[0] === 'Permis de conduire', 'recherche « perm » : ' + v.join(', '));
  await p.fill('#search', 'carte d identite'); await p.waitForTimeout(200);
  check((await visible()).length === 0 && /Aucun objet/.test(await p.textContent('#grid-empty')), 'recherche sans résultat : message clair');
  await p.fill('#search', 'IDENTITE'); await p.waitForTimeout(200);
  check((await visible())[0] === "Carte d'identité", 'recherche sans accents ni majuscules');
  await shot('4_recherche');
  await p.focus('#search'); await p.keyboard.press('Escape'); await p.waitForTimeout(150);
  check(await p.inputValue('#search') === '' && await p.isVisible('#app'), 'Échap dans la recherche : la vide sans fermer l\'inventaire');

  console.log('\n[Glisser-déposer dans un onglet]');
  await p.click('#tabs [data-cat="food"]'); await p.waitForTimeout(80);
  const src = await p.$('#grid .slot.has:not(.fx-hide)');
  const box = await src.boundingBox();
  const ground = await (await p.$('#drop-zone')).boundingBox();
  await p.mouse.move(box.x + box.width / 2, box.y + box.height / 2); await p.mouse.down();
  await p.mouse.move(box.x + 60, box.y + 40, { steps: 5 });
  await p.mouse.move(ground.x + ground.width / 2, ground.y + ground.height / 2, { steps: 10 });
  await p.mouse.up(); await p.waitForTimeout(200);
  check(/Sandwich/.test(await p.textContent('#ground-grid')) && (await visible()).length === 0, 'le sandwich glissé au sol depuis l\'onglet Nourriture');
  await p.click('#tabs [data-cat="all"]'); await p.waitForTimeout(80);
  check(await n('food') === '2', 'compteur Nourriture mis à jour (2)');

  console.log('\n[Performance]');
  const perf = await p.evaluate(async () => {
    const tabs = [...document.querySelectorAll('#tabs [data-cat]')];
    const t0 = performance.now();
    for (let i = 0; i < 200; i++) tabs[i % 4].click();
    return (performance.now() - t0) / 200;
  });
  check(perf < 8, `changer d'onglet : ${perf.toFixed(2)} ms (100 cases)`);
  check(await p.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth), 'pas de défilement horizontal');
  check(errs.length === 0, 'aucune erreur JavaScript' + (errs.length ? ' : ' + errs.join(' | ') : ''));
  await b.close();
  console.log(`\nRésultat : ${passes} réussis, ${fails} échec(s)`);
  process.exit(fails ? 1 : 0);
})();
