// Cartes « en main » (papiers + permis) au design Elyzea : NODE_PATH=$(npm root -g) node elyzea_papiers/tests/ui_cartes.cjs "$PWD" <dossier captures>   (depuis « Elyzea Base »)
const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch(); const p = await b.newPage({ viewport: { width: 1400, height: 800 } });
  const errs = []; p.on('pageerror', e => errs.push(e.message));
  let fails = 0; const check = (c, l) => { console.log(`  ${c ? 'ok  ' : 'ÉCHEC'} ${l}`); if (!c) fails++; };
  // Papiers : PPA montré puis état « suspendu » reçu du serveur
  await p.goto('file://' + process.argv[2] + '/elyzea_papiers/html/index.html'); await p.waitForTimeout(200);
  await p.evaluate(() => window.postMessage({ action: 'card', kind: 'ppa', sub: 'civil', reqId: 'papiers:1', own: true, slot: 3, now: 1, meta: { firstname: 'Léna', lastname: 'Duval', number: 'PPA-551204', issued: '01/11/2026', expires: '30/01/2027', doctor: 'Dr Morel', citizenid: 'ABC' } }, '*'));
  await p.waitForTimeout(400);
  check(await p.$('#doc .ely-card--ppa') !== null && !(await p.textContent('#doc')).includes('SUSPENDU'), 'papiers : PPA au nouveau design, pas suspendu au départ');
  await p.evaluate(() => window.postMessage({ action: 'cardState', reqId: 'papiers:1', state: { ppa: true, ppaReason: 'Contrôle' } }, '*'));
  await p.waitForTimeout(300);
  check((await p.textContent('#doc')).includes('SUSPENDU'), 'papiers : « SUSPENDU » après la réponse du serveur');
  await p.evaluate(() => window.postMessage({ action: 'cardState', reqId: 'papiers:0', state: { ppa: false } }, '*'));
  await p.waitForTimeout(200);
  check((await p.textContent('#doc')).includes('SUSPENDU'), 'papiers : une ancienne réponse est ignorée');
  await p.screenshot({ path: process.argv[3] + '/papiers_ppa.png' });
  // Permis : catégorie moto suspendue
  await p.goto('file://' + process.argv[2] + '/elyzea_permis/html/index.html'); await p.waitForTimeout(200);
  await p.evaluate(() => window.postMessage({ action: 'card', reqId: 'permis:1', own: false, meta: { firstname: 'Léna', lastname: 'Duval', number: 'EL-104223', categories: [{ short: 'B', label: 'Permis B', date: '03/10/2026' }, { short: 'A', label: 'Permis A', date: '05/10/2026' }] } }, '*'));
  await p.waitForTimeout(300);
  await p.evaluate(() => window.postMessage({ action: 'cardState', reqId: 'permis:1', state: { moto: true } }, '*'));
  await p.waitForTimeout(300);
  const t = await p.textContent('#license');
  check(t.includes('SUSPENDU') && await p.$('#license .c-cat.off') !== null, 'permis : catégorie moto « SUSPENDU »');
  await p.screenshot({ path: process.argv[3] + '/permis_moto.png' });
  check(errs.length === 0, 'aucune erreur JavaScript ' + errs.join(' | '));
  await b.close(); process.exit(fails ? 1 : 0);
})();
