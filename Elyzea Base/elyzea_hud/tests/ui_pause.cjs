// Menu Échap Elyzea FA. NODE_PATH=$(npm root -g) node tests/ui_pause.cjs [captures]
const { chromium } = require('playwright');
const path = require('path');
const out = process.argv[2] || __dirname;
let fails = 0;
const check = (c, l) => { console.log(`  ${c ? 'ok  ' : 'ÉCHEC'} ${l}`); if (!c) fails++; };
(async () => {
  const b = await chromium.launch(); const p = await b.newPage({ viewport: { width: 1920, height: 1080 } });
  const errs = []; p.on('pageerror', (e) => errs.push(e.message));
  const posts = [];
  await p.route(/^https?:/, (r) => { if (r.request().url().includes('/pause')) { posts.push(JSON.parse(r.request().postData() || '{}').a); return r.fulfill({ status: 200, body: '{}' }); } r.abort(); });
  await p.goto('file://' + path.join(__dirname, '..', 'html', 'index.html')); await p.waitForTimeout(300);
  await p.evaluate(() => { document.body.style.background = 'linear-gradient(135deg,#556,#223)'; window.postMessage({ action: 'pause', open: true, server: 'ELYZEA FA', maxPlayers: 128, discord: 'discord.gg/elyzea',
    tips: ['Appuyez sur F1 pour sortir votre téléphone.'], player: { firstname: 'Léna', lastname: 'Duval', job: 'LSPD', grade: 'Sergent', cash: 25000, bank: 148250, id: 12, health: 92, hour: 21, minute: 47, zone: 'Vinewood', street: 'Vinewood Blvd', cross: 'Power St', heading: 40 } }, '*');
    window.postMessage({ action: 'pauseInfo', data: { players: 87 } }, '*'); });
  await p.waitForTimeout(1500);
  check(await p.$$eval('.pz-menu .pz-btn', (x) => x.length) === 5, 'menu : 5 entrées');
  check((await p.textContent('#pz-name')).includes('DUVAL') && (await p.textContent('#pz-pl')) === '87', 'joueur et serveur affichés');
  await p.screenshot({ path: path.join(out, 'echap.png') });
  await p.keyboard.press('ArrowDown'); await p.keyboard.press('Enter'); await p.waitForTimeout(200);
  check(posts.includes('map'), 'clavier : ↓ + Entrée → Carte');
  await p.click('[data-pz="quit"]'); await p.waitForTimeout(400);
  check(await p.$('#pz-modal.on') !== null, 'Quitter : confirmation');
  await p.screenshot({ path: path.join(out, 'echap_quitter.png') });
  await p.click('[data-pz="cancel"]'); await p.keyboard.press('Escape'); await p.waitForTimeout(200);
  check(posts.includes('resume'), 'Échap : reprendre');
  check(errs.length === 0, 'aucune erreur JavaScript' + (errs.length ? ' : ' + errs.join(' | ') : ''));
  await b.close(); console.log(fails ? `${fails} ÉCHEC(S)` : 'TOUS LES TESTS ÉCHAP SONT PASSÉS'); process.exit(fails ? 1 : 0);
})();
