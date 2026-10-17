const { chromium } = require('playwright');
const fs = require('fs');
const S = process.argv[2], HTML = process.argv[3];
const open = JSON.parse(fs.readFileSync(S + '/open.json', 'utf8'));
const results = [];
const ok = (name, cond) => { results.push((cond ? 'RÉUSSI  ' : 'ÉCHEC   ') + name); };
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1600, height: 900 } });
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.addInitScript(() => {
    window.__calls = [];
    let prefs = { adult: false, dnd: false }, favs = [];
    window.__rpaMock = (name, data) => {
      window.__calls.push({ name, data });
      if (name === 'nearby') return [{ id: 2, dist: 1.4, canInvite: true }, { id: 5, dist: 4.2, canInvite: false }];
      if (name === 'favorite') { favs = favs.filter((x) => x !== data.id); if (data.on) favs.push(data.id); return favs; }
      if (name === 'prefs') { prefs = { ...prefs, ...data }; return prefs; }
      return 'ok';
    };
  });
  await page.goto('file://' + HTML);
  await page.evaluate(() => { document.body.style.background = 'radial-gradient(circle at 30% 40%, #3a2a4a, #0b0b12)'; });
  await page.evaluate((m) => window.__rpaHandle(m), open);
  await page.waitForTimeout(400);
  const calls = () => page.evaluate(() => window.__calls);
  await page.screenshot({ path: S + '/ui_1_menu.png' });
  ok('Menu ouvert avec catégories', (await page.$$('.cat')).length === 12);
  ok('Catégorie par défaut : cartes affichées', (await page.$$('#list .card')).length > 0);

  await page.click('[data-cat="slow"]');
  await page.waitForTimeout(150);
  const slowCards = await page.$$eval('#list .card .c-name', (n) => n.map((x) => x.textContent));
  ok('Slow : 9 entrées dont les « à créer » en fin de liste', slowCards.length === 9 && slowCards[slowCards.length - 1].startsWith('Valse'));
  ok('« À créer » grisée et bouton désactivé', (await page.$$('#list .card.off .go[disabled]')).length === 3);
  await page.screenshot({ path: S + '/ui_2_slow.png' });

  await page.click('#list .card.off');
  await page.waitForTimeout(100);
  ok('Clic sur « à créer » : message clair', (await page.textContent('#toasts')).includes('à créer'));

  await page.fill('#search', 'bachata');
  await page.waitForTimeout(100);
  const found = await page.$$eval('#list .card .c-name', (n) => n.map((x) => x.textContent));
  ok('Recherche « bachata » : ' + found.length + ' résultats', found.length >= 4 && found.every((t) => /bachata/i.test(t)));
  await page.fill('#search', '');

  await page.click('[data-cat="solo"]');
  await page.click('#search');
  await page.keyboard.press('ArrowDown');
  await page.keyboard.press('Enter');
  await page.waitForTimeout(100);
  let c = await calls();
  ok('Clavier : flèche + Entrée lance une danse solo', c.some((x) => x.name === 'play'));
  await page.keyboard.press('f');
  await page.waitForTimeout(100);
  c = await calls();
  ok('Clavier : F ajoute aux favoris', c.some((x) => x.name === 'favorite' && x.data.on === true));
  await page.click('[data-cat="favoris"]');
  ok('Favoris : la danse apparaît', (await page.$$('#list .card')).length === 1);

  await page.click('[data-cat="slow"]');
  await page.click('#list .card:not(.off) .go');
  await page.waitForTimeout(300);
  ok('Duo : fenêtre d\'invitation ouverte', await page.isVisible('#modalInvite.open'));
  ok('Joueur trop loin désactivé', (await page.$$('#invPeople .person[disabled]')).length === 1);
  await page.click('#invRole [data-r="B"]');
  await page.click('#invPeople .person:not([disabled])');
  await page.screenshot({ path: S + '/ui_3_invite.png' });
  await page.click('#invSend');
  c = await calls();
  const inv = c.find((x) => x.name === 'invite');
  ok('Invitation envoyée avec cible 2 et rôle B', inv && inv.data.target === 2 && inv.data.role === 'B');

  await page.click('[data-cat="adulte"]');
  ok('Adulte verrouillé sans option', (await page.textContent('#list')).includes('réservée'));
  await page.click('#btnSettings');
  await page.check('#stAdult');
  await page.waitForTimeout(100);
  await page.screenshot({ path: S + '/ui_4_settings.png' });
  await page.click('#modalSettings [data-close]');
  ok('Adulte : entrées visibles après activation', (await page.$$('#list .card')).length === 10);

  await page.evaluate(() => window.__rpaHandle({ action: 'invite', invite: { id: 77, anim: 'adulte_scene_privee', label: 'Transition vers une scène privée', from: 'Une personne (ID 2)', adult: true, fade: true, role: 'B', roleLabel: 'Partenaire', timeout: 20 } }));
  await page.waitForTimeout(200);
  ok('Invitation adulte : bouton Accepter désactivé tant que non coché', await page.isDisabled('#cfYes'));
  await page.screenshot({ path: S + '/ui_5_confirm.png' });
  await page.check('#cfOk');
  await page.click('#cfYes');
  c = await calls();
  const r = c.find((x) => x.name === 'respond');
  ok('Acceptation adulte avec confirmation explicite', r && r.data.accept === true && r.data.confirmAdult === true && r.data.id === 77);

  await page.evaluate(() => window.__rpaHandle({ action: 'current', id: 'slow_classique', label: 'Slow classique', role: 'A' }));
  ok('Barre : animation en cours, bouton Arrêter actif', !(await page.isDisabled('#btnStop')));
  await page.click('#btnStop');
  c = await calls();
  ok('Bouton Arrêter envoie stop', c.some((x) => x.name === 'stop'));

  await page.keyboard.press('Escape');
  await page.waitForTimeout(50);
  c = await calls();
  ok('Échap ferme le menu', c.some((x) => x.name === 'close'));
  await page.evaluate(() => window.__rpaHandle({ action: 'close' }));
  await page.evaluate(() => window.__rpaHandle({ action: 'invite', invite: { id: 78, label: 'Slow classique', from: 'Une personne (ID 3)', adult: false, role: 'B', timeout: 20 } }));
  await page.waitForTimeout(300);
  ok('Menu fermé : invitation visible en haut de l\'écran', await page.isVisible('#toastIn'));
  ok('Menu fermé : panneau masqué', !(await page.$eval('#panel', (p) => p.classList.contains('open'))));
  await page.screenshot({ path: S + '/ui_6_toast.png' });

  const mobile = await browser.newPage({ viewport: { width: 390, height: 800 } });
  await mobile.addInitScript(() => { window.__rpaMock = () => 'ok'; });
  await mobile.goto('file://' + HTML);
  await mobile.evaluate((m) => window.__rpaHandle(m), open);
  await mobile.waitForTimeout(300);
  const sw = await mobile.evaluate(() => document.documentElement.scrollWidth);
  ok('Petit écran : pas de défilement horizontal', sw <= 390);

  ok('Aucune erreur JavaScript', errors.length === 0);
  if (errors.length) console.log(errors.join('\n'));
  console.log(results.join('\n'));
  await browser.close();
})();
