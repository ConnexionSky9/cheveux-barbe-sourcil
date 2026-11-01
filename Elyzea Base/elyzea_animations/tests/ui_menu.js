// Test de l'interface (Chromium, hors jeu) : NODE_PATH=$(npm root -g) node tests/ui_menu.js   (depuis elyzea_animations/)
// Aucune connexion internet autorisée pendant le test (le menu ne doit rien charger de l'extérieur).
// Les captures d'écran vont dans le dossier temporaire du système (ou ANIM_SHOTS).
const { chromium } = require('playwright');
const path = require('path');
const shots = process.env.ANIM_SHOTS || require('os').tmpdir();
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1600, height: 900 } });
  const errs = [], external = [];
  p.on('pageerror', (e) => errs.push(e.message));
  p.on('console', (m) => { if (m.type() === 'error') errs.push(m.text()); });
  await p.route('**/*', (r) => { const u = r.request().url(); if (u.startsWith('file:')) return r.continue(); external.push(u); return r.abort(); });
  // Callbacks NUI simulés (comme client.lua)
  await p.addInitScript(() => {
    window.__calls = [];
    window.GetParentResourceName = () => 'elyzea_animations';
    const real = window.fetch;
    window.fetch = (url, o) => {
      if (String(url).startsWith('https://elyzea_animations/')) {
        const ev = String(url).split('/').pop();
        window.__calls.push([ev, JSON.parse((o && o.body) || '{}')]);
        const res = ev === 'getNearbyPlayers' ? [{ id: 7, name: 'Lina', dist: 1.2 }, { id: 9, name: 'Max', dist: 2.6 }] : true;
        return Promise.resolve({ json: () => Promise.resolve(res) });
      }
      return real(url, o);
    };
  });
  await p.goto('file://' + path.join(__dirname, '..', 'html', 'index.html'));
  await p.waitForTimeout(300);
  let fails = 0;
  const check = async (label, fn, arg) => {
    const r = await p.evaluate(fn, arg);
    if (r !== true) fails++;
    console.log((r === true ? 'OK  ' : 'FAIL') + ' ' + label + (r === true ? '' : ' -> ' + JSON.stringify(r)));
  };
  const calls = () => p.evaluate(() => window.__calls.splice(0));
  const post = (msg) => p.evaluate((m) => window.postMessage(m, '*'), msg);
  // Fait défiler la liste jusqu'à la carte (elle n'existe dans la page que si elle est visible)
  const show = async (cmd) => { await p.evaluate((cmd) => { const v = window.__ely.view(), i = v.findIndex(x => x.cmd === cmd);
    const w = document.querySelector('#listwrap'); w.scrollTop = Math.max(0, Math.floor(i / window.__ely.cols()) * 66 - 60); }, cmd); await p.waitForTimeout(80); };
  const tileSel = (cmd) => `#spacer .emote[data-cmd="${cmd}"]`;

  await post({ action: 'init', settings: { openKey: 'K', stopKey: 'X' }, binds: {}, keys: { accept: 'Y', refuse: 'L', place: 'J', fx: 'G' } });
  await post({ action: 'env', env: { hidden: ['wave2'], male: true, inVehicle: false } });
  await post({ action: 'open' }); await p.waitForTimeout(300);
  await check('menu ouvert, 16 catégories', () => document.querySelector('#panel').classList.contains('open') && document.querySelectorAll('#rail .cat').length === 16 || document.querySelectorAll('#rail .cat').length);
  await check('aucune icône vide (sprite intégré)', () => [...document.querySelectorAll('#rail .cat svg use')].every(u => document.querySelector(u.getAttribute('href'))));
  await check('total des animations > 1700', () => window.__ely.total > 1700 || window.__ely.total);
  await check('liste virtualisée : peu de cartes dans la page', () => { const n = document.querySelectorAll('#spacer .emote').length; return (n > 0 && n < 80) || n; });
  await p.click('#rail .cat[data-id="objets"]'); await p.waitForTimeout(150);
  await check('catégorie Objets : 400+ animations, < 80 cartes rendues', () => { const v = window.__ely.view().length, n = document.querySelectorAll('#spacer .emote').length; return (v > 400 && n < 80) || [v, n]; });
  const t0 = Date.now();
  for (let i = 0; i < 40; i++) { await p.evaluate(() => { const w = document.querySelector('#listwrap'); w.scrollTop += 900; }); await p.waitForTimeout(16); }
  console.log('     défilement de toute la liste : ' + (Date.now() - t0) + ' ms');
  await check('après défilement : cartes du bas affichées', () => { const last = [...document.querySelectorAll('#spacer .emote')].map(e => +e.dataset.i); return Math.max(...last) === window.__ely.view().length - 1 || Math.max(...last); });
  // Recherche
  await p.fill('#q', 'cigar'); await p.waitForTimeout(200);
  await check('recherche « cigar »', () => window.__ely.view().length > 0 && document.querySelector('#catTitle').textContent === 'Recherche' || window.__ely.view().length);
  await p.fill('#q', 'pres cafe'); await p.waitForTimeout(200);
  await p.fill('#q', 'smoke'); await p.waitForTimeout(200);
  await check('recherche par commande « smoke » trouve /anim smoke', () => window.__ely.view().some(i => i.cmd === 'smoke'));
  const t1 = Date.now();
  for (const s of ['d', 'da', 'dan', 'danc', 'dance', 'dance 2', '']) { await p.fill('#q', s); }
  await p.waitForTimeout(150);
  console.log('     7 recherches tapées à la suite : ' + (Date.now() - t1) + ' ms');
  await check('recherche vidée : retour à la catégorie', () => document.querySelector('#catTitle').textContent === 'Objets' || document.querySelector('#catTitle').textContent);
  // Fichier manquant masqué
  await p.click('#rail .cat[data-id="gestes"]'); await p.waitForTimeout(100);
  await check('animation indisponible masquée (wave2)', () => !window.__ely.view().some(i => i.cmd === 'wave2') && window.__ely.view().some(i => i.cmd === 'wave'));
  // Lancer une animation
  await calls();
  await show('wave'); await p.click(tileSel('wave')); await p.waitForTimeout(150);
  let c = await calls();
  console.log((c.some(x => x[0] === 'playEmote' && x[1].emote === 'wave' && x[1].type === 'emote') ? 'OK  ' : 'FAIL') + ' clic : playEmote(wave, emote) -> ' + JSON.stringify(c));
  await check('barre « En cours » affichée', () => !document.querySelector('#nowbar').hidden && document.querySelector('#nowName').textContent.length > 0);
  await check('carte en cours surlignée', () => !!document.querySelector('#spacer .emote.playing[data-cmd="wave"]'));
  await p.screenshot({ path: path.join(shots, 'ui_anim_menu.png') });
  await post({ action: 'stopped' }); await p.waitForTimeout(100);
  await check('message stopped : barre cachée', () => document.querySelector('#nowbar').hidden);
  // Clavier : flèches + Entrée
  await p.focus('#q'); await calls();
  await p.keyboard.press('ArrowDown'); await p.keyboard.press('Enter'); await p.waitForTimeout(150);
  c = await calls();
  console.log((c.some(x => x[0] === 'playEmote') ? 'OK  ' : 'FAIL') + ' flèche bas + Entrée lance la carte choisie -> ' + JSON.stringify(c.map(x => x[1].emote)));
  // Effet (touche G)
  await p.fill('#q', 'smoke2'); await p.waitForTimeout(150);
  await p.click('#spacer .emote[data-cmd="smoke2"]'); await p.waitForTimeout(100);
  await check('animation avec effet : « G effet » affiché', () => !document.querySelector('#fxHint').hidden && document.querySelector('#fxKey').textContent === 'G');
  await p.fill('#q', ''); await p.waitForTimeout(100);
  // Favoris + raccourci
  await show('wave'); await p.click('#spacer .emote[data-cmd="wave"] .fav'); await p.waitForTimeout(100);
  await p.click('#rail .cat[data-id="fav"]'); await p.waitForTimeout(100);
  await check('favori ajouté', () => window.__ely.view().map(i => i.cmd).join() === 'wave' || window.__ely.view().map(i => i.cmd));
  await p.click('#spacer .emote[data-cmd="wave"] [data-bind]'); await p.waitForTimeout(150);
  await p.keyboard.press('Digit7'); await p.waitForTimeout(150);
  c = await calls();
  await check('touche 7 assignée', () => document.querySelector('#spacer .emote[data-cmd="wave"] .keybtn').textContent === '7');
  console.log((c.some(x => x[0] === 'saveBinds' && x[1].binds['7'] && x[1].binds['7'].emote === 'wave') ? 'OK  ' : 'FAIL') + ' saveBinds envoyé');
  await p.click('#spacer .emote[data-cmd="wave"] [data-bind]'); await p.waitForTimeout(100);
  await p.keyboard.press('KeyE'); await p.waitForTimeout(100);
  await check('touche réservée (E) refusée', () => document.querySelector('#toast').textContent.includes('déjà utilisée'));
  await p.keyboard.press('Escape'); await p.waitForTimeout(100);
  // À deux : choix du joueur
  await p.click('#rail .cat[data-id="duo"]'); await p.waitForTimeout(100);
  await show('nearby_hug'); await p.click(tileSel('nearby_hug')); await p.waitForTimeout(250);
  await check('à deux : liste des joueurs proches', () => document.querySelector('#picker').classList.contains('open') && document.querySelectorAll('#pickList .player').length === 2);
  await calls();
  await p.click('#pickList .player[data-pid="9"]'); await p.waitForTimeout(150);
  c = await calls();
  console.log((c.some(x => x[0] === 'playEmote' && x[1].type === 'shared' && x[1].target === 9) ? 'OK  ' : 'FAIL') + ' demande envoyée au joueur 9 -> ' + JSON.stringify(c));
  // Démarche / humeur
  await p.click('#rail .cat[data-id="marches"]'); await p.waitForTimeout(100);
  await check('démarches : « Par défaut » en premier', () => window.__ely.view()[0].cmd === 'walk_reset');
  await calls(); await show('walk_Alien'); await p.click(tileSel('walk_Alien')); await p.waitForTimeout(100);
  c = await calls();
  console.log((c.some(x => x[0] === 'playEmote' && x[1].type === 'walk') ? 'OK  ' : 'FAIL') + ' démarche envoyée');
  // Placement (clic droit)
  await p.click('#rail .cat[data-id="assis"]'); await p.waitForTimeout(100);
  await calls(); await p.click('#spacer .emote', { button: 'right' }); await p.waitForTimeout(100);
  c = await calls();
  console.log((c.some(x => x[0] === 'placeEmote') ? 'OK  ' : 'FAIL') + ' clic droit : placeEmote');
  // Paramètres
  await p.click('#settingsBtn'); await p.waitForTimeout(150);
  await p.click('#segPos button[data-v="right"]'); await p.waitForTimeout(100);
  await p.screenshot({ path: path.join(shots, 'ui_anim_settings.png') });
  await check('position droite appliquée', () => !document.querySelector('#panel').classList.contains('left'));
  await p.click('#settings [data-close]'); await p.waitForTimeout(150);
  // Véhicule
  await post({ action: 'env', env: { inVehicle: true } }); await p.waitForTimeout(100);
  await p.fill('#q', 'sit'); await p.waitForTimeout(150);
  await check('en véhicule : animations « pas en véhicule » cachées', () => !window.__ely.view().some(i => i.f.includes('n')));
  await post({ action: 'env', env: { inVehicle: false } }); await p.fill('#q', ''); await p.waitForTimeout(100);
  // Demande reçue
  await post({ action: 'request', name: 'Lina', label: 'Câlin', emote: 'hug', timeout: 15 }); await p.waitForTimeout(250);
  await p.screenshot({ path: path.join(shots, 'ui_anim_request.png') });
  await p.click('#reqYes'); await p.waitForTimeout(100);
  c = await calls();
  console.log((c.some(x => x[0] === 'respond' && x[1].accept === true) ? 'OK  ' : 'FAIL') + ' accepter une demande');
  // Mode proposer (menu ALT)
  await p.keyboard.press('Escape'); await p.waitForTimeout(150);
  const cats = [
    { id: 'px_salut', name: 'Salutations', icon: 'hand', desc: 'Se saluer.', mode: 'shared', items: [['Check', 'nearby_bro', ''], ['Check 2', 'nearby_bro2', '']] },
    { id: 'px_couple', name: 'En couple', icon: 'heart', desc: 'Bisous', mode: 'shared', items: [['Bisou (homme)', 'nearby_kisscutecheek', 'm'], ['Bisou (femme)', 'nearby_kisscutecheek2', 'f']] },
    { id: 'px_slow', name: 'Slow', icon: 'heart-pulse', desc: 'même danse', mode: 'together', items: [['Slow', 'danceslow', '']] },
  ];
  await post({ action: 'open', propose: { id: 12, name: 'Personne · ID 12', cats } }); await p.waitForTimeout(250);
  await check('proposer : 3 catégories seulement', () => document.querySelectorAll('#rail .cat').length === 3 && !document.querySelector('#proposeBar').hidden);
  await p.click('#rail .cat[data-id="px_couple"]'); await p.waitForTimeout(100);
  await check('proposer : rôle de l\'autre sexe caché', () => window.__ely.view().map(i => i.cmd).join() === 'nearby_kisscutecheek');
  await p.click('#rail .cat[data-id="px_slow"]'); await p.waitForTimeout(100);
  await calls(); await p.click('#spacer .emote[data-cmd="danceslow"]'); await p.waitForTimeout(150);
  c = await calls();
  console.log((c.some(x => x[0] === 'propose' && x[1].emote === 'danceslow' && x[1].target === 12) ? 'OK  ' : 'FAIL') + ' proposer : propose(danceslow, 12)');
  await check('proposer : menu fermé après choix', () => !document.querySelector('#panel').classList.contains('open'));
  await post({ action: 'outgoing', name: 'Joueur 12', label: 'Slow', timeout: 15, key: 'L' }); await p.waitForTimeout(250);
  await p.screenshot({ path: path.join(shots, 'ui_anim_outgoing.png') });
  await post({ action: 'outgoingEnd' }); await p.waitForTimeout(250);
  await check('bandeau d\'invitation caché', () => !document.querySelector('#out').classList.contains('show'));
  await post({ action: 'open' }); await p.waitForTimeout(200);
  await check('réouverture : mode normal', () => document.querySelectorAll('#rail .cat').length === 16);
  // Petit écran
  await p.setViewportSize({ width: 390, height: 800 }); await p.waitForTimeout(250);
  await check('petit écran : panneau dans l\'écran, pas de défilement horizontal', () => { const r = document.querySelector('#panel').getBoundingClientRect(); return r.left >= 0 && r.right <= innerWidth && document.documentElement.scrollWidth <= innerWidth; });
  await p.screenshot({ path: path.join(shots, 'ui_anim_mobile.png') });
  if (external.length) { fails++; console.log('FAIL requêtes externes : ' + external.join(', ')); } else console.log('OK   aucune requête vers internet');
  if (errs.length) fails++;
  console.log('erreurs JS : ' + (errs.length ? errs.join(' | ') : 'aucune'));
  console.log(`\n${fails} échec(s)`);
  await b.close();
  process.exit(fails ? 1 : 0);
})();
