// Les 6 téléphones ElyAura : design, applications, personnalisation, vendeur. NODE_PATH=$(npm root -g) node tests/ui_devices.cjs [captures]
const { chromium } = require('playwright');
const path = require('path');
const out = process.argv[2] || path.join(__dirname, 'shots');
require('fs').mkdirSync(out, { recursive: true });
let fails = 0;
const check = (c, l) => { console.log(`  ${c ? 'ok  ' : 'ÉCHEC'} ${l}`); if (!c) fails++; };
const DEVS = {
  1: { n: 1, label: 'ElyAura 1', tier: 1, apps: ['phone', 'messages', 'contacts', 'bank', 'identite', 'settings'], exclude: [], faceId: false, store: false, fold: false },
  2: { n: 2, label: 'ElyAura 2', tier: 2, exclude: ['livrezy', 'helpmecano', 'lasergame', 'carplay', 'itoune', 'garage'], faceId: true, store: true, fold: false },
  3: { n: 3, label: 'ElyAura 3', tier: 3, exclude: ['lasergame', 'carplay', 'itoune', 'garage'], faceId: true, store: true, fold: false },
  4: { n: 4, label: 'ElyAura 4', tier: 4, exclude: ['carplay', 'garage'], faceId: true, store: true, fold: false },
  5: { n: 5, label: 'ElyAura 5 Fold', tier: 5, exclude: ['carplay', 'garage'], faceId: true, store: true, fold: true },
  6: { n: 6, label: 'ElyAura 6 Ultra', tier: 6, exclude: [], faceId: true, store: true, fold: false },
};
const LOOKS = {
  1: { wallpaper: 'nebuleuse', accent: 'rose' },
  2: { wallpaper: 'halo', accent: 'glace', theme: 'dark' },
  3: { wallpaper: 'glacier', accent: 'cobalt', frame: 'titane' },
  4: { wallpaper: 'aube', accent: '#ff7a3d', frame: 'graphite', effect: 'etoiles', case: 'silicone_rose' },
  5: { wallpaper: 'nebuleuse', accent: 'elyzea', frame: 'titane', effect: 'aurore', widgets: ['analog', 'calendar'] },
  6: { wallpaper: 'galaxie', accent: '#b45cff', frame: 'obsidienne', effect: 'holo', edgeMode: 'rainbow', iconShape: 'cercle', widgets: ['calendar', 'music'], case: 'none' },
};
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1300, height: 950 }, deviceScaleFactor: 1 });
  const errs = []; p.on('pageerror', (e) => errs.push(e.message));
  await p.route(/^https?:/, (r) => r.abort());
  await p.goto('file://' + path.join(__dirname, '..', 'html', 'index.html'));
  await p.waitForTimeout(6000);
  await p.evaluate(() => { const E = window.__elyzea; E.S.settings.setup = true; document.getElementById('screen').classList.remove('in-setup'); document.getElementById('setup').classList.remove('active'); E.S.locked = false; });
  for (let n = 1; n <= 6; n++) {
    await p.evaluate(([d, look]) => {
      const E = window.__elyzea;
      E.S.profile.device = d;
      Object.assign(E.S.settings, { theme: 'dark', effect: 'none', case: 'none', widgets: [], edgeMode: 'auto', iconShape: 'squircle', installed: ['birdy', 'instapick', 'itoune', 'livrezy', 'helpmecano', 'garage', 'carplay', 'lasergame'] }, look);
      Fold.set(false, false);
      applySettings(); E.goHome();
    }, [DEVS[n], LOOKS[n]]);
    await p.waitForTimeout(700);
    const ids = await p.$$eval('#home [data-open]', (x) => x.map((e) => e.dataset.open));
    if (n === 1) {
      check(!ids.includes('store') && !ids.includes('camera') && !ids.includes('maps') && ids.includes('bank') && ids.includes('identite') && ids.includes('messages'), 'ElyAura 1 : seulement appels, messages, contacts, banque, papiers, réglages');
      check(await p.$eval('#phone', (e) => getComputedStyle(e).paddingBottom) === '92px', 'ElyAura 1 : gros bords et bouton physique');
    }
    if (n === 2) check(!ids.includes('livrezy') && !ids.includes('helpmecano') && !ids.includes('lasergame') && !ids.includes('carplay') && ids.includes('birdy'), 'ElyAura 2 : sans Livrézy, HelpMécano, LaserGame, CarPlay');
    if (n === 3) check(ids.includes('livrezy') && ids.includes('helpmecano') && !ids.includes('itoune'), 'ElyAura 3 : Livrézy et HelpMécano ajoutés');
    if (n === 4) check(ids.includes('itoune') && !ids.includes('carplay') && await p.$eval('#fx', (e) => e.children.length) > 10 && await p.$eval('.case', (e) => getComputedStyle(e).display) === 'block', 'ElyAura 4 : Itoune, effet animé et coque');
    if (n === 5) check(await p.$$eval('.wd-grid .wd', (x) => x.length) === 2, 'ElyAura 5 : widgets sur l\'accueil');
    if (n === 6) check(ids.includes('carplay') && ids.includes('garage'), 'ElyAura 6 : CarPlay et Garage');
    await p.screenshot({ path: path.join(out, `elyaura_${n}.png`), clip: await p.$eval('#stage', (e) => { const r = e.getBoundingClientRect(); return { x: r.x - 60, y: r.y - 40, width: r.width + 120, height: r.height + 60 }; }) });
  }
  // 5 déplié
  await p.evaluate(([d, look]) => { const E = window.__elyzea; E.S.profile.device = d; Object.assign(E.S.settings, look); applySettings(); E.goHome(); Fold.set(true, false); }, [DEVS[5], LOOKS[5]]);
  await p.waitForTimeout(900);
  check((await p.$eval('#phone', (e) => e.getBoundingClientRect().width)) > 700, 'ElyAura 5 : se déplie en deux écrans');
  await p.screenshot({ path: path.join(out, 'elyaura_5_deplie.png') });
  // Seul le 5 se déplie
  await p.evaluate((d) => { window.__elyzea.S.profile.device = d; applySettings(); Fold.set(true, false); }, DEVS[6]);
  await p.waitForTimeout(500);
  check((await p.$eval('#phone', (e) => e.getBoundingClientRect().width)) < 420, 'les autres modèles ne se déplient pas');
  // Réglages : avancé sur le 6, rien sur le 1
  await p.evaluate(() => { window.__elyzea.openApp('settings', { page: 'device' }); });
  await p.waitForTimeout(500);
  check(await p.$('[data-dset="edgeMode"]') !== null && await p.$('#ring-url') !== null && await p.$('[data-wd]') !== null, 'ElyAura 6 : LED, sonnerie perso, widgets, police, icônes');
  await p.screenshot({ path: path.join(out, 'elyaura_6_reglages.png'), clip: await p.$eval('#stage', (e) => { const r = e.getBoundingClientRect(); return { x: r.x - 20, y: r.y - 20, width: r.width + 40, height: r.height + 30 }; }) });
  await p.evaluate((d) => { const E = window.__elyzea; E.S.profile.device = d; applySettings(); E.goHome(); E.openApp('settings'); }, DEVS[1]);
  await p.waitForTimeout(500);
  const txt = await p.textContent('#app');
  check(!txt.includes('Apparence') && !txt.includes('Face ID') && txt.includes('Code'), 'ElyAura 1 : pas de personnalisation, code seulement (pas de Face ID)');
  await p.evaluate(() => window.__elyzea.openApp('store'));
  await p.waitForTimeout(300);
  check(await p.evaluate(() => window.__elyzea.S.currentApp) !== 'store', 'ElyAura 1 : pas de magasin d\'applications');
  // Vendeur
  await p.evaluate(() => window.postMessage({ action: 'phoneShop', data: { name: 'ElyAura Store Vinewood', vip: false, cash: 25000, bank: 8000, allowBank: true,
    list: [1, 2, 3, 4, 5, 6].map((n) => ({ n, label: ['ElyAura 1', 'ElyAura 2', 'ElyAura 3', 'ElyAura 4', 'ElyAura 5 Fold', 'ElyAura 6 Ultra'][n - 1], price: [500, 2500, 6000, 12000, 25000, 60000][n - 1], tagline: 'Démo', tier: n, vip: n === 6, fold: n === 5, owned: n === 1 })) } }, '*'));
  await p.waitForTimeout(500);
  check(await p.$$eval('#pshop .ps-range button', (x) => x.length) === 6, 'vendeur : les 6 téléphones');
  await p.screenshot({ path: path.join(out, 'vendeur_1.png') });
  await p.click('[data-ps="sel"][data-n="5"]'); await p.waitForTimeout(300);
  await p.screenshot({ path: path.join(out, 'vendeur_5.png') });
  await p.click('[data-ps="sel"][data-n="6"]'); await p.waitForTimeout(300);
  check((await p.textContent('.ps-info')).includes('Royale') && await p.$('[data-ps="buy"]') === null, 'vendeur : ElyAura 6 verrouillé sans abonnement Royale');
  await p.screenshot({ path: path.join(out, 'vendeur_6.png') });
  check(errs.length === 0, 'aucune erreur JavaScript' + (errs.length ? ' : ' + errs.join(' | ') : ''));
  await b.close();
  console.log(fails ? `${fails} ÉCHEC(S)` : 'TOUS LES TESTS TÉLÉPHONES SONT PASSÉS');
  process.exit(fails ? 1 : 0);
})();
