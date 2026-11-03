// Test de l'appli Identité + thème Elyzea (aperçu navigateur du téléphone, Chromium headless)
// NODE_PATH=$(npm root -g) node tests/ui_identite.cjs [dossier captures]
const { chromium } = require('playwright');
const path = require('path');
const out = process.argv[2] || path.join(__dirname, 'shots');
require('fs').mkdirSync(out, { recursive: true });
let fails = 0;
const check = (c, l) => { console.log(`  ${c ? 'ok  ' : 'ÉCHEC'} ${l}`); if (!c) fails++; };
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 900, height: 900 } });
  const errs = []; p.on('pageerror', (e) => errs.push(e.message + ' @ ' + (e.stack || '').split('\n').slice(1, 3).join(' ')));
  await p.route('https://fonts.googleapis.com/**', (r) => r.abort());
  await p.goto('file://' + path.join(__dirname, '..', 'html', 'index.html'));
  await p.waitForTimeout(400);
  await p.waitForTimeout(2200); await p.screenshot({ path: path.join(out, 'aura_demarrage.png') }); await p.waitForTimeout(3400);
  await p.evaluate(() => { const E = window.__elyzea; E.S.settings.setup = true; document.getElementById('screen').classList.remove('in-setup'); const sv = document.getElementById('setup'); sv.classList.remove('active'); E.applySettings(); E.S.locked = false; E.goHome(); });
  await p.waitForTimeout(600);
  check(await p.$('[data-open="identite"]') !== null, 'icône « Identité » sur l\'accueil');
  check(await p.$eval('#wp', (e) => e.dataset.wp) === 'elyzea', 'fond d\'écran Elyzea');
  check(await p.$eval('#phone', (e) => e.dataset.frame) === 'elyzea', 'cadre Elyzea');
  check(await p.$('#ely-wp .ely-mark') !== null && await p.$('#ely-wp .ely-skyline') !== null, 'décor : emblème + ville');
  await p.screenshot({ path: path.join(out, 'aura_accueil.png') });

  await p.click('[data-open="identite"]');
  await p.waitForTimeout(900);
  check((await p.textContent('#app')).includes("Carte d'identité"), 'appli ouverte : carte d\'identité');
  check(await p.$('#app .ely-card--id') !== null, 'carte d\'identité dessinée');
  await p.screenshot({ path: path.join(out, 'aura_identite.png') });
  await p.click('[data-dot="1"]'); await p.waitForTimeout(600);
  const lic = await p.textContent('#app .ely-card');
  check(lic.includes('PERMIS DE CONDUIRE') || lic.toLowerCase().includes('permis de conduire'), 'permis affiché');
  check(lic.includes('SUSPENDU'), 'catégorie moto suspendue : « SUSPENDU » sur le permis');
  await p.screenshot({ path: path.join(out, 'aura_permis.png') });

  // Enregistrer sa carte dans la galerie
  await p.click('[data-idt-save]'); await p.waitForTimeout(300);
  // Montrer : liste des téléphones sortis
  await p.click('[data-idt-show]'); await p.waitForTimeout(700);
  check((await p.textContent('.sheet')).includes('Aura Inès'), 'montrer : téléphone sorti listé');
  await p.click('.sheet [data-dev]'); await p.waitForTimeout(500);
  check(!(await p.$('.sheet')), 'carte montrée : feuille fermée');

  // Réception d'une carte (policier) : suspension du PPA
  await p.evaluate(() => {
    const docs = window.__elyzea.Mock.idDocs();
    window.__elyzea.handlers.idCard({ shareId: 9, doc: docs.ppa, kind: 'ppa', device: 'Aura Marco', from: 3, police: true });
  });
  await p.waitForTimeout(800);
  check((await p.textContent('.sheet')).includes('Aura Marco vous montre'), 'carte reçue affichée');
  check(await p.$('.sheet [data-susp="ppa"]') !== null, 'policier : bouton « Suspendre le PPA »');
  await p.fill('#idt-reason', 'Port d\'arme en état d\'ivresse');
  await p.click('.sheet [data-susp="ppa"]'); await p.waitForTimeout(800);
  check((await p.textContent('.sheet .ely-card')).includes('SUSPENDU'), 'PPA suspendu : « SUSPENDU » sur la carte');
  check((await p.textContent('.sheet [data-susp="ppa"]')).includes('Rétablir'), 'bouton devient « Rétablir le PPA »');
  await p.screenshot({ path: path.join(out, 'aura_ppa_suspendu.png') });
  await p.click('.sheet [data-save]'); await p.waitForTimeout(300);
  check((await p.textContent('.sheet [data-save]')).includes('Enregistrée'), 'carte reçue enregistrée dans la galerie');
  await p.evaluate(() => { document.querySelector('.sheet-backdrop')?.click(); });
  await p.waitForTimeout(500);

  // Galerie : onglet Cartes
  await p.evaluate(() => window.__elyzea.openApp('gallery', { filter: 'card' }));
  await p.waitForTimeout(800);
  check(await p.$('.gal-card .ely-card') !== null, 'galerie : la carte enregistrée apparaît');
  await p.screenshot({ path: path.join(out, 'aura_galerie.png') });

  // Écran verrouillé : emblème
  await p.evaluate(() => window.__elyzea.showLock());
  await p.waitForTimeout(500);
  check(await p.$('.lock__brand .ely-mark') !== null, 'écran verrouillé : emblème Elyzea');
  await p.screenshot({ path: path.join(out, 'aura_verrou.png') });
  check(errs.length === 0, `aucune erreur JavaScript${errs.length ? ' : ' + errs.join(' | ') : ''}`);
  await b.close();
  console.log(`\nIdentité / thème : ${fails} échec(s)`);
  process.exit(fails ? 1 : 0);
})();
