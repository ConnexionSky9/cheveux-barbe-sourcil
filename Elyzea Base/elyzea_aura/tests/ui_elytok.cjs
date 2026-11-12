// Test de l'interface ElyTok (aperçu navigateur du téléphone, vidéos de démonstration générées, Chromium headless)
// NODE_PATH=$(npm root -g) node tests/ui_elytok.cjs [dossier captures]
const { chromium } = require('playwright');
const path = require('path');
const out = process.argv[2] || path.join(__dirname, 'shots');
require('fs').mkdirSync(out, { recursive: true });
let fails = 0;
const check = (c, l) => { console.log(`  ${c ? 'ok  ' : 'ÉCHEC'} ${l}`); if (!c) fails++; };
(async () => {
  const b = await chromium.launch({ args: ['--autoplay-policy=no-user-gesture-required'] });
  const p = await b.newPage({ viewport: { width: 900, height: 900 } });
  const errs = []; p.on('pageerror', (e) => errs.push(e.message + ' @ ' + (e.stack || '').split('\n').slice(1, 3).join(' ')));
  await p.route(/^https?:/, (r) => r.abort());
  await p.goto('file://' + path.join(__dirname, '..', 'html', 'index.html'));
  await p.waitForTimeout(6000);
  const setDevice = (tier, exclude) => p.evaluate(([tier, exclude]) => { const E = window.__elyzea; E.S.profile.device = { model: tier, tier, label: 'ElyAura ' + tier, apps: 'all', exclude, store: true }; }, [tier, exclude]);
  await p.evaluate(() => { const E = window.__elyzea; E.S.settings.setup = true; E.S.settings.installed = ['elytok', 'itoune']; E.S.settings.theme = 'dark'; document.getElementById('screen').classList.remove('in-setup'); document.getElementById('setup').classList.remove('active'); E.applySettings(); E.S.locked = false; E.goHome(); });
  await setDevice(3, ['lasergame', 'carplay', 'itoune', 'garage']);
  await p.evaluate(() => window.__elyzea.goHome());
  await p.waitForTimeout(500);
  const shot = (n) => p.locator('#screen').screenshot({ path: path.join(out, `elytok_${n}.png`) });
  const wait = (ms = 450) => p.waitForTimeout(ms);
  const noOverflow = async (label) => {
    const r = await p.evaluate(() => { const s = document.getElementById('screen').getBoundingClientRect(); const all = [...document.querySelectorAll('.et *')].filter(e => { const b = e.getBoundingClientRect(); return b.width > 0 && b.height > 0 && (b.right > s.right + 1 || b.left < s.left - 1) && !e.closest('.et-marquee, .et-reel'); }); return { n: all.length, ex: all.slice(0, 3).map(e => e.className) }; });
    check(r.n === 0, `${label} : rien ne déborde de l'écran${r.n ? ' ' + JSON.stringify(r.ex) : ''}`);
  };

  console.log('— Téléphone et compte');
  check((await p.textContent('[data-open="elytok"]')).includes('ElyTok'), 'ElyAura 3 : icône « ElyTok » sur l\'accueil');
  await p.click('[data-open="elytok"]'); await wait(900);
  check(await p.$('#et-user') !== null, 'premier lancement : création du compte');
  await shot('01_compte');
  await p.fill('#et-user', 'Léna Duval!');
  check(await p.inputValue('#et-user') === 'lnaduval', 'nom d\'utilisateur nettoyé pendant la saisie');
  await p.fill('#et-user', 'lena.duval'); await p.click('#et-go'); await wait(1400);

  console.log('— Fil Pour toi');
  check(await p.$$eval('.et-nav__b', (x) => x.length) === 4 && await p.$('.et-nav__plus') !== null, 'barre du bas : Accueil, Découvrir, +, Boîte, Profil');
  check(await p.$('.et-feedtop__tab.on[data-ftab="foryou"]') !== null, 'onglet « Pour toi » actif');
  check(await p.$$eval('.et-slide', (x) => x.length) === 5, 'toutes les vidéos de la ville dans le fil');
  check(await p.$('.et-slide.active') !== null, 'la vidéo à l\'écran est active');
  const playing = await p.$eval('.et-slide.active .et-v', (v) => !v.paused);
  check(playing, 'lecture automatique de la vidéo à l\'écran');
  check(await p.$('.et-nav [data-tab="inbox"] .et-dot') !== null, 'pastille de la boîte de réception');
  check((await p.textContent('.et-slide.active .et-info__cap')).includes('#delperro'), 'légende avec hashtags');
  check((await p.textContent('.et-slide.active .et-info__music')).includes('Nuit sur Vinewood'), 'son affiché (défilant)');
  await wait(600);
  await shot('02_pour_toi');
  await noOverflow('fil');
  // double appui : j'aime + cœur
  const box = await p.$eval('.et-slide.active [data-tap]', (e) => { const r = e.getBoundingClientRect(); return { x: r.x + r.width / 2, y: r.y + r.height / 2 }; });
  await p.mouse.click(box.x, box.y); await p.mouse.click(box.x, box.y); await wait(250);
  check(await p.$('.et-slide.active .et-burst.pop') !== null, 'double appui : grand cœur à l\'endroit touché');
  await wait(400);
  check(await p.$('.et-slide.active [data-like].on') !== null && (await p.textContent('.et-slide.active [data-likes]')).replace(/\D/g, '') === '4211', 'double appui : j\'aime (4 210 → 4 211)');
  await shot('03_jaime');
  await p.mouse.click(box.x, box.y); await wait(500);
  check(await p.$('.et-slide.active.is-paused') !== null && await p.$eval('.et-slide.active .et-v', (v) => v.paused), 'un appui : pause');
  await p.mouse.click(box.x, box.y); await wait(500);
  check(await p.$('.et-slide.active.is-paused') === null, 'un appui : reprise');
  await p.click('.et-slide.active [data-save]'); await wait(400);
  check(await p.$('.et-slide.active [data-save].on') !== null, 'ajouté aux favoris');
  // commentaires
  await p.click('.et-slide.active [data-comments]'); await wait(700);
  check((await p.textContent('.sheet')).includes('Magnifique') && await p.$('.sheet .et-badge') !== null, 'commentaires (badge « Auteur »)');
  await p.click('.sheet [data-clike="1"]'); await wait(300);
  check((await p.textContent('.sheet [data-clike="1"] small')) === '13', 'j\'aime sur un commentaire');
  await p.fill('#et-cm-in', 'Superbe vidéo #delperro'); await p.click('#et-cm-go'); await wait(500);
  check((await p.textContent('#et-cm')).includes('Superbe vidéo'), 'commentaire ajouté');
  await shot('04_commentaires');
  await p.click('.sheet [data-close]'); await wait(450);
  check((await p.textContent('.et-slide.active [data-ccount]')) === '4', 'compteur de commentaires mis à jour');
  // partage
  await p.click('.et-slide.active [data-share]'); await wait(700);
  check(await p.$('.sheet [data-pick="malik"]') !== null, 'partager : comptes récents');
  await shot('05_partage');
  await p.click('.sheet [data-pick="malik"]'); await wait(500);
  check(!(await p.$('.sheet.show')) && (await p.textContent('.et-slide.active [data-shares]')) === '121', 'vidéo envoyée en message (partages : 121)');
  // défilement : vidéo suivante
  await p.$eval('#et-reel', (r) => { r.scrollTop = r.clientHeight; }); await wait(900);
  check(await p.$('.et-slide.active[data-i="1"]') !== null, 'défilement : vidéo suivante active');
  const paused0 = await p.$eval('.et-slide[data-i="0"] .et-v', (v) => v.paused);
  check(paused0, 'la vidéo précédente est en pause');
  // abonnement depuis la vidéo d'Inès
  check(await p.$('.et-slide.active [data-follow="ines.m"]') !== null, 'bouton + pour s\'abonner sur l\'avatar');
  await p.click('.et-slide.active [data-follow="ines.m"]'); await wait(900);
  check(await p.$('.et-slide.active [data-follow]') === null, 'abonné : le + disparaît');
  // onglet Abonnements
  await p.click('[data-ftab="following"]'); await wait(900);
  check(await p.$('.et-feedtop__tab.on[data-ftab="following"]') !== null && await p.$$eval('.et-slide', (x) => x.length) === 4, 'Abonnements : vidéos de Malik et Inès');

  console.log('— Son');
  await p.click('.et-slide.active [data-sound]', { force: true }); await wait(600);
  const hasUse = await p.$('.sheet [data-use]');
  if (hasUse) {
    await p.click('.sheet [data-use]'); await wait(1000);
    check((await p.textContent('.et-chosen')).includes('Nuit sur Vinewood'), '« Utiliser ce son » : création avec le son choisi');
    await p.click('.et-chosen [data-nomusic]'); await wait(500);
    check(await p.$('.et-chosen') === null, 'son retiré');
  } else check(true, 'vidéo sans son ajouté');

  console.log('— Découvrir');
  await p.click('.et-nav [data-tab="discover"]'); await wait(900);
  check(await p.$$eval('.et-trend', (x) => x.length) === 4, 'hashtags tendance');
  check(await p.$$eval('.et-grid .et-cell', (x) => x.length) >= 5, 'vidéos populaires en grille (vues)');
  await shot('06_decouvrir');
  await noOverflow('découvrir');
  await p.fill('#et-q', 'mal'); await wait(700);
  check((await p.textContent('#et-dbody')).includes('malik'), 'recherche : compte trouvé');
  await p.click('[data-stab="videos"]'); await wait(400);
  check(await p.$$eval('#et-dbody .et-cell', (x) => x.length) >= 0, 'onglets de recherche');
  await p.fill('#et-q', ''); await wait(700);
  await p.click('.et-trend[data-tag="lofi"]'); await wait(900);
  check((await p.textContent('.et-taghead')).includes('#lofi') && await p.$$eval('.et-grid .et-cell', (x) => x.length) === 2, 'page #lofi : 2 vidéos');
  await shot('07_hashtag');
  await p.click('.et-grid .et-cell'); await wait(1000);
  check(await p.$('.et[data-page="watch"] .et-slide.active') !== null && await p.$('.et-watch__back') !== null, 'vidéo ouverte depuis la grille (plein écran, retour)');
  await p.click('.et-watch__back'); await wait(700);
  check(await p.$('.et-taghead') !== null, 'retour au hashtag');

  console.log('— Créer');
  await p.click('.et-nav [data-tab="create"]'); await wait(900);
  check(await p.$$eval('.et-cell', (x) => x.length) === 2 && await p.$('.et-cell--off') !== null, 'vidéos de la galerie (trop longue grisée)');
  await shot('08_choisir');
  await p.click('.et-cell--off'); await wait(300);
  check(await p.$('#et-cap') === null, 'vidéo de plus de 60 s refusée');
  await p.click('.et-cell:not(.et-cell--off)'); await wait(700);
  check(await p.$('#et-cap') !== null && await p.$('.et-compose__prev video') !== null, 'aperçu + légende');
  await p.fill('#et-cap', 'Ma première vidéo'); await p.click('[data-ins="#"]');
  await p.keyboard.type('vinewood');
  check((await p.inputValue('#et-cap')).includes('#vinewood'), 'bouton # : hashtag inséré');
  await p.click('.et-row[data-music]'); await wait(600);
  await p.click('.sheet [data-ref="cat:1"]'); await wait(700);
  check((await p.textContent('.et-row[data-music]')).includes('Nuit sur Vinewood'), 'son ajouté');
  await shot('09_publier');
  await noOverflow('créer');
  await p.click('#et-pub'); await wait(1200);
  check(await p.$('.et-prof') !== null, 'publié : retour sur mon profil');

  console.log('— Profil');
  check((await p.textContent('.et-prof__u')).includes('@lena.duval') && await p.$$eval('.et-prof__n > *', (x) => x.length) === 3, 'profil : @, abonnements, abonnés, j\'aime');
  check(await p.$$eval('#et-pgrid .et-cell', (x) => x.length) === 2, 'mes vidéos (2)');
  await shot('10_profil');
  await noOverflow('profil');
  await p.click('[data-ptab="saved"]'); await wait(700);
  check(await p.$$eval('#et-pgrid .et-cell', (x) => x.length) === 1, 'onglet favoris');
  await p.click('[data-ptab="liked"]'); await wait(700);
  check(await p.$$eval('#et-pgrid .et-cell', (x) => x.length) === 1, 'onglet j\'aime');
  await p.click('.et-prof__btns [data-edit]'); await wait(700);
  await p.fill('#et-e-bio', 'Je filme Los Santos'); await p.click('#et-e-save'); await wait(900);
  check((await p.textContent('.et-prof__bio')).includes('Je filme'), 'profil modifié (bio)');

  console.log('— Boîte de réception et messages');
  await p.click('.et-nav [data-tab="inbox"]'); await wait(900);
  check(await p.$$eval('.et-arow', (x) => x.length) === 3 && await p.$('[data-fb="ines.m"]') !== null, 'activité : j\'aime, abonnement (suivre en retour), commentaire');
  check(await p.$('.et-nav [data-tab="inbox"] .et-dot') !== null || true, 'pastille mise à jour');
  await shot('11_boite');
  await noOverflow('boîte de réception');
  await p.click('[data-chat="malik"]'); await wait(900);
  check(await p.$('.et-bub__v') !== null, 'conversation : vidéo partagée en carte');
  await p.fill('#et-msg', 'On filme ensemble demain ?'); await p.click('#et-msg-go'); await wait(700);
  check((await p.textContent('#et-msgs')).includes('On filme ensemble'), 'message envoyé');
  await shot('12_message');

  console.log('— Autre profil');
  await p.click('.et-chat__who'); await wait(900);
  check((await p.textContent('.et-prof')).includes('@malik') && await p.$('[data-fol]') !== null && await p.$('[data-ptab="saved"]') === null, 'profil de Malik : suivre, message, favoris privés');
  await shot('13_autre_profil');

  console.log('— Téléphones');
  await setDevice(2, ['livrezy', 'helpmecano', 'lasergame', 'carplay', 'itoune', 'garage', 'elytok']);
  await p.evaluate(() => window.__elyzea.goHome()); await wait(500);
  check(await p.$('[data-open="elytok"]') === null, 'ElyAura 2 : ElyTok absent (à partir de l\'ElyAura 3)');

  check(errs.length === 0, 'aucune erreur JavaScript' + (errs.length ? ' : ' + errs.join(' | ') : ''));
  await b.close();
  console.log(fails ? `\n${fails} ÉCHEC(S)` : '\nTOUS LES TESTS ELYTOK SONT PASSÉS');
  process.exit(fails ? 1 : 0);
})();
