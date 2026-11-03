// Test de l'appli LaserGame (aperçu navigateur du téléphone, données de démonstration, Chromium headless)
// NODE_PATH=$(npm root -g) node tests/ui_lasergame.cjs [dossier captures]
const { chromium } = require('playwright');
const path = require('path');
const out = process.argv[2] || path.join(__dirname, 'shots');
require('fs').mkdirSync(out, { recursive: true });
let fails = 0;
const check = (c, l) => { console.log(`  ${c ? 'ok  ' : 'ÉCHEC'} ${l}`); if (!c) fails++; };
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 900, height: 900 }, deviceScaleFactor: 2 });
  const errs = []; p.on('pageerror', (e) => errs.push(e.message + ' @ ' + (e.stack || '').split('\n').slice(1, 3).join(' ')));
  const posts = []; // appels envoyés au client Lua
  await p.route(/^https?:/, (r) => r.abort());
  await p.goto('file://' + path.join(__dirname, '..', 'html', 'index.html'));
  await p.waitForTimeout(6000);
  await p.evaluate(() => { const E = window.__elyzea; E.S.settings.setup = true; E.S.settings.installed = ['lasergame']; E.S.settings.theme = 'dark'; document.getElementById('screen').classList.remove('in-setup'); document.getElementById('setup').classList.remove('active'); E.applySettings(); E.S.locked = false; E.goHome(); });
  await p.exposeFunction('__wp', (d) => posts.push(d));
  await p.evaluate(() => { const M = window.__elyzea.Mock, h = M.handle.bind(M); M.handle = (ep, d) => { if (ep === 'setWaypoint') window.__wp(d); return h(ep, d); }; });
  await p.waitForTimeout(500);
  const shot = (n) => p.locator('#screen').screenshot({ path: path.join(out, `lasergame_${n}.png`) });
  const wait = (ms = 500) => p.waitForTimeout(ms);
  const noOverflow = async (label) => {
    const r = await p.evaluate(() => { const s = document.getElementById('screen').getBoundingClientRect(); const bad = [...document.querySelectorAll('.lgp *, .lgp-sheet *')].filter(e => { const b = e.getBoundingClientRect(); return b.width > 0 && (b.right > s.right + 1 || b.left < s.left - 1) && !e.closest('.lgp-bg'); }); return bad.slice(0, 3).map(e => e.className || e.tagName); });
    check(r.length === 0, `${label} : rien ne déborde de l'écran${r.length ? ' ' + JSON.stringify(r) : ''}`);
  };

  check((await p.textContent('[data-open="lasergame"]')).includes('LaserGame'), 'icône « LaserGame » sur l\'accueil');
  await p.click('[data-open="lasergame"]'); await wait(900);
  console.log('— Profil');
  check(await p.$('.lgp-word') !== null && await p.$$eval('.lgp-nav button', x => x.length) === 5, 'logo LASER GAME + 5 onglets');
  check((await p.textContent('.lgp-hero .pts b')).replace(/\s/g, '') === '1488' && (await p.textContent('.lgp-hero .rl')).includes('PLATINUM'), 'mes points (1 488) et mon rang');
  check((await p.textContent('.lgp-pos b')) === '#7', 'ma position au classement');
  check(await p.$$eval('.lgp-hist .row', x => x.length) === 3, 'dernières parties');
  check(await p.$('.lgp-nav [data-lg-tab="msg"] .dot') !== null, 'pastille message non lu');
  await noOverflow('profil'); await shot('01_profil');
  await p.click('[data-lg-gps]'); await wait(300);
  check(posts.length === 1 && Math.abs(posts[0].x + 1256.6) < .1, 'bouton GPS : point posé sur le LaserGame');

  console.log('— Classement');
  await p.click('[data-lg-tab="board"]'); await wait(700);
  check(await p.$$eval('.lgp-lb', x => x.length) === 10 && await p.$('.lgp-lb.p1') !== null, 'classement PVP : 10 joueurs, podium');
  check(await p.$('.lgp-lb.me') !== null, 'ma ligne mise en avant');
  await noOverflow('classement'); await shot('02_classement');
  await p.click('[data-lg-mode="zombie"]'); await wait(700);
  check((await p.textContent('.lgp-chips button.on')).includes('Manche'), 'classement Zombie (meilleure manche)');
  await p.click('[data-lg-kind="zb_teams"]'); await wait(600);
  check((await p.textContent('.lgp-lb .tx b')).includes(','), 'classement des équipes Zombie');
  await shot('03_classement_zombie');

  console.log('— Matchs');
  await p.click('[data-lg-tab="match"]'); await wait(700);
  check(await p.$$eval('.lgp-card', x => x.length) === 2, 'demandes de match PVP');
  check((await p.textContent('.lgp-card[data-id="1"] .hour')).includes('MAINTENANT') && (await p.textContent('.lgp-card[data-id="1"]')).includes('Mise'), 'demande « dès que possible » avec mise');
  check(await p.$('.lgp-card[data-id="2"] [data-lg-cancel]') !== null && await p.$('.lgp-card[data-id="2"] [data-lg-write]') === null, 'ma demande : retirer, pas de message à moi-même');
  await noOverflow('matchs'); await shot('04_matchs');
  posts.length = 0;
  await p.click('.lgp-card[data-id="1"] [data-lg-join]'); await wait(700);
  check(posts.length === 1 && await p.$('.lgp-card[data-id="1"].joined') !== null, 'Rejoindre : inscrit + point GPS (pas de téléportation)');
  await p.click('.lgp-card[data-id="1"] [data-lg-write]'); await wait(500);
  check(await p.$('.lgp-sheet textarea') !== null, 'écrire à l\'auteur de la demande');
  await shot('05_message_auteur');
  await p.click('.lgp-sheet [data-yes]'); await wait(800);
  check(await p.$('.lgp-chat') !== null && (await p.textContent('.lgp-chat__head b')).includes('Malik') && await p.$$eval('.lgp-bub', x => x.length) === 3, 'conversation ouverte avec l\'auteur');
  await p.click('[data-lg-tab="match"]'); await wait(600);
  await p.click('[data-lg-new]'); await wait(500);
  check(await p.$$eval('.lgp-form [data-f-format]', x => x.length) === 6, 'formulaire : formats 1 VS 1 à 6 VS 6');
  await p.click('.lgp-form [data-f-format="3v3"]'); await p.click('.lgp-form [data-f-map="pvp_large"]'); await wait(200);
  await p.fill('.lgp-form [data-f-stake]', '1500'); await p.fill('.lgp-form [data-f-msg]', 'Qui pour un 3v3 ?');
  await noOverflow('formulaire match'); await shot('06_form_match');
  await p.click('.lgp-form [data-yes]'); await wait(800);
  check(await p.$$eval('.lgp-card', x => x.length) === 3 && (await p.textContent('.lgp-list')).includes('Qui pour un 3v3'), 'demande de match publiée');

  console.log('— Annonces');
  await p.click('[data-lg-tab="event"]'); await wait(700);
  const zb = '.lgp-card[data-id="3"]';
  check(await p.$(`${zb}.zb.joined`) !== null && (await p.textContent(`${zb} .hour small`)).match(/dans \d+ min/), 'annonce Zombie : heure + compte à rebours, déjà inscrit');
  check((await p.textContent(`${zb} .mode`)).includes('ZOMBIE'), 'badge ZOMBIE');
  await noOverflow('annonces'); await shot('07_annonces');
  await p.click('[data-lg-new]'); await wait(500);
  check(await p.$('.lgp-form [data-f-mode="zombie"].on') !== null && await p.$('.lgp-form [data-f-time]') !== null && await p.$('.lgp-form [data-f-when]') === null, 'annonce : Zombie par défaut, heure obligatoire');
  await p.click('.lgp-form [data-f-map="zombie_map"]'); await p.click('.lgp-form [data-f-day="1"]'); await wait(150);
  await p.fill('.lgp-form [data-f-time]', '21:30');
  await shot('08_form_annonce');
  await p.click('.lgp-form [data-yes]'); await wait(800);
  check(await p.$$eval('.lgp-card', x => x.length) === 3, 'annonce « demain 21:30 carte Zombie » publiée');
  await p.click('.lgp-card[data-id="4"] [data-lg-join]'); await wait(700);
  check(await p.$('.lgp-card[data-id="4"].joined') !== null, 'rejoindre l\'annonce PVP');

  console.log('— Messages');
  await p.click('[data-lg-tab="msg"]'); await wait(700);
  check(await p.$$eval('.lgp-th', x => x.length) >= 1, 'liste des conversations');
  await shot('09_messages');
  await p.click('.lgp-th'); await wait(600);
  await p.fill('.lgp-chat__in input', 'J\'arrive au LaserGame !'); await p.press('.lgp-chat__in input', 'Enter'); await wait(600);
  check((await p.textContent('.lgp-chat__list')).includes('J\'arrive au LaserGame'), 'message envoyé');
  await noOverflow('conversation'); await shot('10_conversation');

  check(errs.length === 0, 'aucune erreur JavaScript' + (errs.length ? ' : ' + errs.join(' | ') : ''));
  await b.close();
  console.log(fails ? `\n${fails} échec(s)` : '\nTout est bon');
  process.exit(fails ? 1 : 0);
})();
