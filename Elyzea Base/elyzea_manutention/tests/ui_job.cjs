// Test de l'interface du métier (suivi, menu du responsable, annonces) dans Chromium.
// NODE_PATH=$(npm root -g) node tests/ui_job.cjs [dossier captures]
const { chromium } = require('playwright');
const path = require('path');
const out = process.argv[2] || path.join(__dirname, 'shots');
require('fs').mkdirSync(out, { recursive: true });
let fails = 0;
const check = (c, l) => { console.log(`  ${c ? 'ok  ' : 'ÉCHEC'} ${l}`); if (!c) fails++; };
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1600, height: 900 }, deviceScaleFactor: 2 });
  const posts = [];
  p.on('pageerror', (e) => { console.log('  ERREUR JS', e.message); fails++; });
  await p.route('https://elyzea_manutention/**', (r) => { posts.push({ ep: r.request().url().split('/').pop(), body: JSON.parse(r.request().postData() || '{}') }); r.fulfill({ status: 200, body: '{}' }); });
  await p.route(/^https?:\/\/(?!elyzea_manutention)/, (r) => r.abort());
  await p.goto('file://' + path.join(__dirname, '..', 'html', 'index.html'));
  await p.evaluate(() => { document.body.style.background = 'linear-gradient(160deg,#55606f,#2b313b)'; });
  const msg = (action, data) => p.evaluate(({ action, data }) => window.postMessage({ action, data }, '*'), { action, data });

  await msg('menu', { open: true, working: false, enabled: true, boxes: 20, pay: 250, account: 'bank', sprint: false, forklift: true });
  await p.waitForTimeout(500);
  const t1 = await p.textContent('#menu');
  check(t1.includes('MANUTENTIONNAIRE') && t1.includes('exactement 20 cartons') && t1.includes('250 $') && t1.includes('en plus de ton métier principal'), 'menu : présentation du métier (20 cartons, 250 $, en complément)');
  await p.screenshot({ path: path.join(out, 'manut_menu.png') });
  await p.click('[data-act="accept"]'); await p.waitForTimeout(100);
  check(posts.some((x) => x.ep === 'menu' && x.body.action === 'accept'), 'bouton « Accepter le travail »');
  await msg('menu', { open: true, working: true, enabled: true, boxes: 20, pay: 250, delivered: 3, earned: 750, forklift: true, hasForklift: true });
  await p.waitForTimeout(200);
  check((await p.textContent('#menu')).includes('Terminer le travail') && (await p.textContent('#menu')).includes('750 $'), 'déjà au travail : bilan + « Terminer le travail » + « Remplacer mon Fenwick »');
  await p.click('[data-act="finish"]'); await p.waitForTimeout(100);
  check(posts.some((x) => x.body.action === 'finish'), 'bouton « Terminer le travail »');
  await msg('menu', { open: false });

  await msg('hud', { show: true, stage: 1, stageTitle: 'Constitution de la palette', objective: 'Pose le carton sur ta palette', boxes: 12, required: 20, destination: 'Palette', distance: 8, carrying: true, delivered: 0, earned: 0, pay: 250, sprint: false });
  await p.waitForTimeout(500);
  check((await p.textContent('#hud-boxes')) === '12/20' && (await p.textContent('#hud-stage')).includes('Constitution'), 'suivi : « Constitution de la palette · Cartons déposés : 12/20 »');
  check((await p.$eval('#hud-bar', (e) => e.style.width)) === '60%', 'barre de progression 60 %');
  check((await p.textContent('#hud-tip')).includes('course impossible'), 'rappel : course impossible avec un carton');
  await p.screenshot({ path: path.join(out, 'manut_hud_cartons.png') });
  await msg('hud', { show: true, stage: 1, stageTitle: 'Constitution de la palette', objective: 'Glisse les fourches…', boxes: 20, required: 20, destination: 'Palette', distance: 3, delivered: 0, earned: 0, pay: 250 });
  await msg('banner', { title: 'PALETTE COMPLÈTE !', text: 'Votre palette contient 20 cartons.\nVous pouvez maintenant passer à l\'étape du transport.', kind: 'ok' });
  await p.waitForTimeout(600);
  check(await p.$('#hud-boxes.full') !== null, 'palette complète : compteur en vert');
  check((await p.textContent('#banner')).includes('PALETTE COMPLÈTE'), 'annonce « PALETTE COMPLÈTE ! »');
  await p.screenshot({ path: path.join(out, 'manut_palette_complete.png') });
  await msg('hud', { show: true, stage: 3, stageTitle: 'Transport et livraison', objective: 'Dépose la palette dans la zone de livraison', boxes: 20, required: 20, destination: 'Quai d\'expédition', distance: 42, delivered: 2, earned: 500, pay: 250 });
  await msg('banner', { title: 'LIVRAISON TERMINÉE !', text: 'Vous avez livré une palette contenant 20 cartons.\nVous avez reçu : 250 $', kind: 'ok' });
  await p.waitForTimeout(600);
  check((await p.textContent('#hud-step')) === '3/3' && (await p.textContent('#hud-dest-txt')).includes('42 m'), 'étape 3/3, destination et distance');
  check((await p.textContent('#banner')).includes('Vous avez reçu : 250 $'), 'annonce « LIVRAISON TERMINÉE ! Vous avez reçu : 250 $ »');
  await p.screenshot({ path: path.join(out, 'manut_livraison.png') });
  await msg('hud', { show: false });
  check(await p.$('#hud.hidden') !== null, 'fin du travail : suivi masqué');
  await b.close();
  console.log(fails ? `\n${fails} échec(s)` : '\nTout est bon');
  process.exit(fails ? 1 : 0);
})();
