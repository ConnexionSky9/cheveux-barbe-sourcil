// Test de l'interface ElyPick (aperçu navigateur du téléphone, données de démonstration, Chromium headless)
// NODE_PATH=$(npm root -g) node tests/ui_elypick.cjs [dossier captures]
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
  await p.route(/^https?:/, (r) => r.abort());
  await p.goto('file://' + path.join(__dirname, '..', 'html', 'index.html'));
  await p.waitForTimeout(6000);
  await p.evaluate(() => { const E = window.__elyzea; E.S.settings.setup = true; E.S.settings.installed = ['instapick', 'itoune']; E.S.settings.theme = 'dark'; document.getElementById('screen').classList.remove('in-setup'); document.getElementById('setup').classList.remove('active'); E.applySettings(); E.S.locked = false; E.goHome(); });
  await p.waitForTimeout(600);
  const shot = (n) => p.locator('#screen').screenshot({ path: path.join(out, `elypick_${n}.png`) });
  const wait = (ms = 450) => p.waitForTimeout(ms);
  const noOverflow = async (label) => {
    const r = await p.evaluate(() => { const m = document.querySelector('#ep-main') || document.querySelector('.ep'); const all = [...document.querySelectorAll('.ep *')].filter(e => { const b = e.getBoundingClientRect(); const s = document.getElementById('screen').getBoundingClientRect(); return b.width > 0 && (b.right > s.right + 1 || b.left < s.left - 1) && !e.closest('.ep-tray, .ep-hls, .ep-viewer'); }); return { x: m.scrollWidth - m.clientWidth, n: all.length, ex: all.slice(0, 3).map(e => e.className) }; });
    check(r.x <= 0 && r.n === 0, `${label} : rien ne déborde de l'écran${r.n ? ' ' + JSON.stringify(r.ex) : ''}`);
  };

  check((await p.textContent('[data-open="instapick"]')).includes('ElyPick'), 'icône « ElyPick » sur l\'accueil du téléphone');
  await p.click('[data-open="instapick"]'); await wait(700);
  check(await p.$('#ep-user') !== null, 'premier lancement : création du compte');
  await shot('01_compte');
  await p.fill('#ep-user', 'Léna Duval!');
  check(await p.inputValue('#ep-user') === 'lnaduval', 'nom d\'utilisateur nettoyé pendant la saisie');
  await p.fill('#ep-user', 'lena.duval'); await p.click('#ep-go'); await wait(800);

  console.log('— Accueil');
  check(await p.$$eval('.ep-nav__b', (x) => x.length) === 5, 'barre du bas : Accueil, Recherche, Créer, Messages, Profil');
  check(await p.$('.ep-word') !== null, 'logo ElyPick');
  check(await p.$('[data-story="malik"] .ep-av--new') !== null, 'story non vue de malik (anneau en couleur)');
  check(await p.$$eval('#ep-feed .ep-post', (x) => x.length) === 2, 'fil : publications des comptes suivis (2), pas celle d\'Inès');
  check(await p.$('#ep-feed [data-post="3"] .ep-mu') !== null, 'musique affichée sur la publication');
  check((await p.textContent('#ep-feed [data-post="3"] .ep-cap')).includes('@lena.duval'), 'description avec mention');
  check(await p.$('[data-activity].has') !== null && await p.$('.ep-nav [data-tab="inbox"] .ep-dot') !== null, 'pastilles : activité et message non lu');
  await noOverflow('accueil');
  await shot('02_accueil');
  await p.dblclick('#ep-feed [data-post="3"] .ep-post__img img'); await wait(500);
  check(await p.$('[data-like="3"].liked') !== null && (await p.textContent('[data-likes="3"]')).includes('2'), 'double-clic : j\'aime (2 J\'aime)');
  await p.click('[data-like="3"]'); await wait(300);
  check(await p.$('[data-like="3"].liked') === null && (await p.textContent('[data-likes="3"]')).includes('1'), 'retirer son j\'aime');
  await p.click('[data-post="3"] [data-music]'); await wait(200);
  check(await p.$('[data-post="3"] [data-music].playing') !== null, 'musique : lecture');
  await p.click('[data-post="3"] [data-music]'); await wait(200);
  check(await p.$('[data-post="3"] [data-music].playing') === null, 'musique : arrêt');

  await p.click('[data-post="3"] [data-comments]'); await wait(600);
  check((await p.textContent('.sheet')).includes('Magnifique'), 'commentaires affichés');
  await p.fill('#ep-cm-in', 'Trop belle !'); await p.click('#ep-cm-go'); await wait(500);
  check((await p.textContent('#ep-cm')).includes('Trop belle'), 'commentaire ajouté');
  await p.click('.sheet-backdrop'); await wait(450);
  check((await p.textContent('[data-post="3"] .ep-more')).includes('2'), 'compteur de commentaires mis à jour');

  await p.click('[data-post="3"] [data-share]'); await wait(600);
  check(await p.$('.sheet [data-pick="malik"]') !== null, 'partager : conversations récentes');
  await p.click('.sheet [data-pick="malik"]'); await wait(500);
  check(!(await p.$('.sheet.show')), 'publication envoyée en message privé');

  console.log('— Stories');
  await p.click('[data-story="malik"]'); await wait(700);
  check(await p.$$eval('.ep-viewer__bars i', (x) => x.length) === 2, 'visionneuse : barre de progression (2 stories)');
  check((await p.textContent('.ep-viewer__head')).includes('malik'), 'auteur affiché');
  await shot('03_story');
  await p.click('[data-vnext]'); await wait(400);
  check(await p.$eval('.ep-viewer__bars i:first-child b', (e) => e.style.width) === '100%', 'story suivante');
  await p.click('[data-vprev]'); await wait(300);
  check(await p.$eval('.ep-viewer__bars i:first-child b', (e) => parseFloat(e.style.width) < 100), 'story précédente');
  await p.click('[data-vclose]'); await wait(600);
  check(!(await p.$('.ep-viewer')) && await p.$('[data-story="malik"] .ep-av--seen') !== null, 'fermée : anneau gris (vue)');

  console.log('— Recherche et explorer');
  await p.click('.ep-nav [data-tab="search"]'); await wait(700);
  check(await p.$$eval('#ep-ex-grid .ep-tile', (x) => x.length) === 3, 'explorer : toutes les photos du serveur (grille)');
  await noOverflow('recherche');
  await shot('04_explorer');
  await p.fill('#ep-q', 'inès'); await wait(700);
  check((await p.textContent('#ep-res')).includes('ines.m'), 'recherche par nom affiché');
  const avb = await p.$eval('#ep-res .ep-av', (e) => { const r = e.getBoundingClientRect(); return [r.width, r.height]; });
  check(Math.abs(avb[0] - avb[1]) < 1, 'photo de profil bien ronde dans les résultats');
  await shot('05_recherche');
  await p.click('#ep-res [data-fol="ines.m"]'); await wait(300);
  check((await p.textContent('#ep-res [data-fol="ines.m"]')).includes('Abonné'), 's\'abonner depuis la recherche');
  await p.click('#ep-q-x'); await wait(400);
  await p.click('#ep-ex-grid [data-open-post="2"]'); await wait(700);
  check(await p.$('.ep[data-page="post"] [data-post="2"]') !== null, 'photo ouverte en grand');
  await p.click('.ep-top [data-back]'); await wait(700);
  check(await p.$('#ep-ex-grid') !== null, 'retour à l\'explorer');
  await p.click('.ep-nav [data-tab="home"]'); await wait(700);
  check(await p.$$eval('#ep-feed .ep-post', (x) => x.length) === 3, 'fil mis à jour après l\'abonnement (3)');

  console.log('— Profil');
  await p.click('.ep-nav [data-tab="me"]'); await wait(700);
  const stats = await p.$$eval('.ep-prof__stats b', (x) => x.map(e => e.textContent));
  check(stats[0] === '1' && stats[1] === '1' && stats[2] === '2', `compteurs publications / abonnés / abonnements (${stats.join(' / ')})`);
  check(await p.$$eval('.ep-hls [data-hl]', (x) => x.length) === 1, 'stories à la une');
  await noOverflow('profil');
  await shot('06_profil');
  await p.click('.ep-hls [data-hl]'); await wait(600);
  check((await p.textContent('.ep-viewer__head')).includes('Vinewood'), 'à la une : visionneuse');
  await p.click('[data-vclose]'); await wait(400);
  await p.click('[data-flist="following"]'); await wait(600);
  check(await p.$$eval('#ep-fl .ep-urow', (x) => x.length) === 2, 'liste des abonnements');
  await p.click('.ep-top [data-back]'); await wait(600);
  await p.click('.ep-prof__btns [data-edit2]'); await wait(600);
  await p.fill('#ep-e-bio', 'Photographe à Vinewood 📸\nDispo pour des shootings');
  await p.click('#ep-av-btn'); await wait(600);
  await p.click('.sheet [data-url]'); await wait(500);
  check(await p.$('#ep-av-btn .ep-av img') !== null, 'photo de profil choisie dans la galerie');
  await shot('07_modifier');
  await p.click('#ep-e-save'); await wait(800);
  check((await p.textContent('.ep-prof__bio')).includes('shootings'), 'biographie enregistrée');

  console.log('— Créer');
  await p.click('.ep-nav [data-tab="new"]'); await wait(700);
  check(await p.$$eval('#ep-new [data-url]', (x) => x.length) === 4, 'choix de la photo dans la galerie');
  await p.click('#ep-new [data-url]'); await wait(600);
  await p.fill('#ep-n-cap', 'Golden hour à Vespucci 🌇');
  await p.click('[data-murow]'); await wait(600);
  check((await p.textContent('.sheet')).includes('Ma bibliothèque Itoune'), 'musiques : catalogue + bibliothèque Itoune');
  await p.click('.sheet [data-use="lib:4"]'); await wait(600);
  check((await p.textContent('[data-murow]')).includes('Sunset Drive'), 'musique associée');
  await shot('08_creer');
  await p.click('#ep-n-prev'); await wait(600);
  check(await p.$('.sheet .ep-post') !== null, 'aperçu de la publication');
  await shot('09_apercu');
  await p.click('.sheet [data-close]'); await wait(450);
  await p.click('#ep-n-go'); await wait(900);
  check(await p.$('.ep[data-page="me"]') !== null && await p.$$eval('#ep-pgrid .ep-tile', (x) => x.length) === 2, 'publiée : visible sur le profil (grille)');
  check(await p.$('#ep-pgrid .ep-tile__mu') !== null, 'icône musique sur la miniature');

  await p.click('.ep-nav [data-tab="new"]'); await wait(600);
  await p.click('.ep-seg [data-m="story"]'); await wait(600);
  await p.click('#ep-new [data-url]'); await wait(600);
  await p.click('[data-hlrow]'); await wait(600);
  await p.click('.sheet [data-hnew]'); await wait(500);
  await p.fill('#ep-pr', 'Plage'); await p.click('#ep-pr-ok'); await wait(600);
  check((await p.textContent('#ep-hl-lbl')).includes('Plage'), 'story : nouvelle catégorie « à la une »');
  await shot('10_story_creer');
  await p.click('#ep-n-go'); await wait(900);
  check(await p.$('[data-mystory] .ep-av--new') !== null, 'ma story apparaît sur l\'accueil');
  await p.click('.ep-nav [data-tab="me"]'); await wait(700);
  check(await p.$$eval('.ep-hls [data-hl]', (x) => x.length) === 2, 'catégorie « Plage » sur le profil');

  console.log('— Messages');
  await p.click('.ep-nav [data-tab="inbox"]'); await wait(700);
  check(await p.$('.ep-conv') !== null, 'liste des conversations');
  await noOverflow('messages');
  await shot('11_messages');
  await p.click('.ep-conv'); await wait(800);
  check(await p.$$eval('#ep-msgs .ep-msg', (x) => x.length) >= 3, 'messages dans l\'ordre (avec publication partagée)');
  check(await p.$('#ep-msgs .ep-sharedpost img') !== null, 'publication partagée affichée dans la bulle');
  await p.fill('#ep-c-in', 'Oui, j\'arrive ! 🎉'); await p.press('#ep-c-in', 'Enter'); await wait(500);
  check((await p.textContent('#ep-msgs .ep-msg.mine:last-child')).includes('j\'arrive'), 'message envoyé (bulle à droite)');
  await p.evaluate(() => window.__elyzea.handlers.elypick({ type: 'dm', conv: 1, message: { id: 999, mine: false, body: 'Parfait, à tout de suite', ts: Math.floor(Date.now() / 1000) }, badges: { notifs: 0, dms: 0 } }));
  await wait(400);
  check((await p.textContent('#ep-msgs .ep-msg:last-child')).includes('Parfait'), 'message reçu en direct dans la conversation');
  await noOverflow('conversation');
  await shot('12_conversation');
  await p.click('.ep-top [data-back]'); await wait(600);

  console.log('— Activité');
  await p.click('.ep-nav [data-tab="home"]'); await wait(700);
  await p.click('[data-activity]'); await wait(700);
  check(await p.$$eval('.ep-act-row', (x) => x.length) === 2, 'activité : nouvel abonné + j\'aime');
  await shot('13_activite');
  await p.click('.ep-top [data-back]'); await wait(600);
  check(await p.$('[data-activity].has') === null, 'activité lue : pastille retirée');

  // Thème clair
  await p.evaluate(() => { const E = window.__elyzea; E.S.settings.theme = 'light'; E.applySettings(); });
  await wait(300);
  await shot('14_accueil_clair');

  // Fermer l'appli comme les autres : bouton d'accueil
  await p.click('#home-bar'); await wait(600);
  check(await p.$('.ep') === null || !(await p.$eval('#app', (e) => e.classList.contains('active'))), 'fermeture par la barre d\'accueil, comme les autres applis');
  check(errs.length === 0, 'aucune erreur JavaScript' + (errs.length ? ' : ' + errs.join(' | ') : ''));
  await b.close();
  console.log(`\nTOTAL : ${fails} échec(s)`);
  process.exit(fails ? 1 : 0);
})();
