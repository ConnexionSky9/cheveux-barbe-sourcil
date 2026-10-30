// Tests hors jeu de l'interface d'elyzea_club (Chromium + Playwright, données fictives).
// node tests/ui.cjs <dossier des captures>
const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

const OUT = process.argv[2] || path.join(__dirname, 'out');
fs.mkdirSync(OUT, { recursive: true });
const PAGE = 'file://' + path.join(__dirname, '..', 'html', 'index.html');
let fails = 0, passes = 0;
const check = (ok, label) => { if (ok) { passes++; console.log('  ok   ' + label); } else { fails++; console.log('  ÉCHEC ' + label); } };

const CFG = {
  perms: [{ key: 'duty', group: 'Service', label: 'Prendre son service' }, { key: 'music', group: 'Musique', label: 'Utiliser les enceintes' }],
  statuses: [{ id: 'available', label: 'Disponible', color: '#22c55e' }, { id: 'bar', label: 'Au bar', color: '#f59e0b' }],
  drinks: [], wristband: 14400,
  music: { models: [{ model: 'ba_prop_battle_club_speaker_large', label: 'Grande enceinte de club' }, { model: 'none', label: 'Invisible' }], maxSpeakers: 10, minRange: 8, maxRange: 120 },
};
const ALL = ['duty', 'tablet', 'bar', 'menu', 'stock', 'sales_all', 'stash', 'door', 'lists', 'open', 'announce', 'music', 'speakers', 'stats', 'direction', 'recruit',
  'employees_view', 'finance', 'payroll', 'perms_manage', 'history_view'];
const STATE = { shop: 1, shopName: 'Galaxy Club', matricule: 'BN-001', name: 'Alice Patron', grade: 'Patron', level: 5, perms: Object.fromEntries(ALL.map((k) => [k, true])), duty: true, status: 'available', open: true };
const MENU = [
  { item: 'nc_mojito', label: 'Mojito', cat: 'Cocktails', price: 45, stock: 18, available: true, enabled: true, cost: 12 },
  { item: 'nc_shot', label: 'Shot', cat: 'Shots', price: 15, stock: 2, available: true, enabled: true, cost: 4 },
  { item: 'nc_champagne', label: 'Bouteille de champagne', cat: 'Bouteilles', price: 450, stock: 0, available: false, enabled: true, cost: 140 },
];
const now = Math.floor(Date.now() / 1000);
const MUSIC = {
  state: { playing: true, paused: false, track: 2, startAt: now - 42, volume: 70, range: 35, shuffle: false, loop: true },
  tracks: [{ id: 1, yt: 'dQw4w9WgXcQ', title: 'Daft Punk - One More Time', duration: 320 }, { id: 2, yt: '9bZkp7q19f0', title: 'Gala - Freed From Desire (Club Mix)', duration: 210 },
    { id: 3, yt: 'aaaaaaaaaaa', title: 'Vidéo bloquée', duration: 0, broken: true }],
  speakers: [{ id: 7, model: 'ba_prop_battle_club_speaker_large', label: 'Grande enceinte de club', x: 101.2, y: 99.4, z: 30.1, h: 90 }],
  near: true, canMusic: true, canSpeakers: true, models: CFG.music.models, maxSpeakers: 10, maxTracks: 100, minRange: 8, maxRange: 120, now,
};

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1600, height: 900 } });
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e)));
  page.on('console', (m) => { if (m.type() === 'error' && !/fonts|Failed to load resource/.test(m.text())) errors.push(m.text()); });
  await page.goto(PAGE);
  await page.evaluate(([CFG, STATE, MENU, MUSIC]) => {
    window.calls = [];
    window.EDemo = (name, data) => {
      window.calls.push({ name, data });
      const a = data && data.action;
      if (name === 'req') {
        if (a === 'dashboard') return { shop: { name: 'Galaxy Club' }, publicOpen: true, fee: 50, bands: 12, speakers: 1, music: { title: 'Gala - Freed From Desire' },
          stats: { barToday: { n: 14, total: 920 }, barWeek: { n: 80, total: 6100 }, entryToday: { n: 22, total: 1100 }, entryWeek: { n: 140, total: 7000 } },
          crew: [{ name: 'Bruno Serveur', grade: 'Serveur', session: 3600, status: 'bar' }], lowStock: [{ label: 'Shot', stock: 2 }], balance: 25300,
          last: [{ kind: 'bar', lines: [{ qty: 2, label: 'Mojito' }], price: 90, buyer_name: 'Dan Client', seller_name: 'Bruno', t: 1800000000 }, { kind: 'entry', price: 50, buyer_name: 'Eva', t: 1800000000 }],
          me: { grade: 'Patron', matricule: 'BN-001', duty: true, status: 'available', times: { session: 3600, unpaid: 7200, unpaidAmount: 2400, rate: 1200, commission: 0 } } };
        if (a === 'menu') return { list: MENU, canEdit: true, canStock: true, balance: 25300, maxPrice: 100000, maxStock: 5000 };
        if (a === 'sales') return { all: true, list: [{ kind: 'bar', lines: [{ qty: 2, label: 'Mojito' }], price: 90, method: 'cash', buyer_name: 'Dan', seller_name: 'Bruno', t: 1800000000 }, { kind: 'entry', price: 50, method: 'bank', buyer_name: 'Eva', t: 1800000000 }] };
        if (a === 'openState') return { publicOpen: true, fee: 50, maxFee: 10000, canEdit: true, hasDoor: true, hasInside: true, canAnnounce: true, announceIn: 0 };
        if (a === 'lists') return { vip: [{ cid: 'A1', name: 'Sam Staff', by: 'Alice' }], ban: [{ cid: 'B1', name: 'Fred Bagarreur', reason: 'Bagarre', expires: 1800300000, by: 'Alice' }],
          bands: [{ cid: 'C', name: 'Dan Client', expires: 1800010000, online: true }], canEdit: true, now: 1800000000, maxBanDays: 365 };
        if (a === 'music' || a === 'musicPlay' || a === 'musicSet') return MUSIC;
        if (a === 'config') return { shop: { name: 'Galaxy Club', address: 'Vinewood', job: 'club_galaxy', society: 'club_galaxy', requireDuty: true },
          points: { door: true, inside: true, bar: true, stash: false, manage: true }, speakers: 1, maxSpeakers: 10 };
        if (a === 'menuSet' || a === 'stockOrder' || a === 'openSet') return { ok: true, message: 'Enregistré.' };
        return { error: 'Données de démonstration absentes.' };
      }
      if (name === 'f6' && data.action === 'doorCheck') return { target: { id: 5, name: 'Dan Client', band: 1800010000, vip: false, staff: false }, now: 1800000000 };
      if (name === 'barRefresh') return {};
      if (name === 'admReload') return {};
      return { ok: true };
    };
    window.postMessage({ action: 'init', cfg: CFG }, '*');
    window.postMessage({ action: 'state', state: STATE }, '*');
  }, [CFG, STATE, MENU, MUSIC]);
  const send = async (m) => { await page.evaluate((m) => window.postMessage(m, '*'), m); await page.waitForTimeout(80); };
  const shot = (n) => page.screenshot({ path: path.join(OUT, n + '.png') });
  const vis = (sel) => page.isVisible(sel);

  console.log('\n[Menu F6]');
  await send({ action: 'f6', show: true, state: STATE, times: { session: 600, unpaid: 3600, total: 9000 }, timesAt: 0 });
  await page.waitForTimeout(100);
  const f6 = await page.textContent('#f6');
  check(/Servir au bar/.test(f6) && /Platine DJ/.test(f6) && /Poser une enceinte/.test(f6) && /Contrôler la personne proche/.test(f6), 'F6 : bar, entrée, platine, enceintes');
  await shot('f6');
  await page.click('[data-f6="check"]');
  await page.waitForTimeout(100);
  check(/Dan Client/.test(await page.textContent('#f6')) && /Raccompagner/.test(await page.textContent('#f6')), 'F6 : contrôle du videur (bracelet, actions)');
  await shot('f6_check');
  await page.click('[data-f6="back"]');
  await page.click('[data-f6="place"]');
  check(/Grande enceinte de club/.test(await page.textContent('#f6')), 'F6 : choix du modèle d\'enceinte');
  await page.click('[data-f6="placeModel"]');
  check((await page.evaluate(() => window.calls.slice(-1)[0])).data.model === 'ba_prop_battle_club_speaker_large', 'F6 : le modèle choisi est envoyé au jeu');
  await send({ action: 'f6', show: false });

  console.log('\n[Bar : servir]');
  await send({ action: 'bar', show: true, data: { customers: [{ id: 5, name: 'Dan Client', distance: 1.4 }, { id: 9, name: 'Zoé', distance: 2.2 }], menu: MENU } });
  await page.waitForTimeout(100);
  check(await vis('#bar'), 'panneau du bar ouvert');
  check(await page.isDisabled('[data-bar="send"]'), 'envoi impossible sans client ni boisson');
  await page.click('[data-cust="5"]');
  await page.click('[data-dq="nc_mojito"][data-d="1"]');
  await page.click('[data-dq="nc_mojito"][data-d="1"]');
  await page.click('[data-dq="nc_shot"][data-d="1"]');
  check(/105/.test(await page.textContent('#bar .bill-total')), 'total calculé : 2 mojitos + 1 shot = 105 $');
  check(await page.isDisabled('[data-dq="nc_champagne"][data-d="1"]'), 'boisson épuisée : impossible d\'en ajouter');
  await shot('bar');
  await page.click('[data-bar="send"]');
  const sell = await page.evaluate(() => window.calls.find((c) => c.name === 'barSell'));
  check(sell && sell.data.target === 5 && sell.data.lines.length === 2 && sell.data.lines[0].qty === 2, 'commande envoyée (client 5, 2 lignes)');
  await send({ action: 'bar', show: false });

  console.log('\n[Commande reçue, carte, entrée, annonce]');
  await send({ action: 'barOffer', show: true, offer: { id: 3, shop: 'Galaxy Club', seller: 'Bruno', total: 135, timeout: 45, lines: [{ qty: 2, label: 'Mojito', unit: 45, total: 90 }, { qty: 1, label: 'Shot', unit: 15, total: 15 }] } });
  check(await vis('#barOffer') && /Payer en espèces/.test(await page.textContent('#barOffer')), 'le client voit la commande et choisit carte ou espèces');
  await shot('bar_offer');
  await page.click('[data-bo="cash"]');
  check((await page.evaluate(() => window.calls.find((c) => c.name === 'barAnswer'))).data.method === 'cash', 'paiement en espèces envoyé');
  await send({ action: 'barOffer', show: false });
  await send({ action: 'card', show: true, data: { shop: 'Galaxy Club', list: MENU } });
  check(/épuisé/.test(await page.textContent('#card')), 'carte publique : boisson épuisée signalée');
  await send({ action: 'card', show: false });
  await send({ action: 'entry', show: true, data: { shop: 'Galaxy Club', open: true, fee: 50 } });
  check(/50 \$/.test((await page.textContent('#entry')).replace(/\s/g, ' ')), 'entrée : prix affiché');
  await shot('entry');
  await send({ action: 'entry', show: true, data: { shop: 'Galaxy Club', open: true, fee: 50, banned: { reason: 'Bagarre', expires: 1800300000 } } });
  check(/liste noire/.test(await page.textContent('#entry')) && !(await page.isVisible('[data-en="bank"]')), 'liste noire : entrée refusée, pas de bouton payer');
  await send({ action: 'entry', show: false });
  await send({ action: 'announce', data: { shop: 'Galaxy Club', text: 'Soirée Neon ce soir à 22 h !', open: true, fee: 50 } });
  check(await vis('#announce'), 'bandeau d\'annonce affiché');
  await shot('announce');

  console.log('\n[Platine DJ]');
  await send({ action: 'dj', show: true, data: MUSIC });
  await page.waitForTimeout(200);
  const dj = await page.textContent('#dj');
  check(/Freed From Desire/.test(dj) && /refusée par YouTube/.test(dj) && /Grande enceinte de club/.test(dj), 'platine : titre en cours, titre refusé, enceintes');
  await shot('dj');
  await page.click('#dj [data-dj="pause"]');
  check(await page.evaluate(() => window.calls.some((c) => c.name === 'req' && c.data.action === 'musicPause')), 'bouton pause envoyé au serveur');
  await send({ action: 'dj', show: true, data: { ...MUSIC, near: false } });
  check(await page.isDisabled('#dj [data-dj="next"]') && /Approchez-vous/.test(await page.textContent('#dj')), 'loin des enceintes : commandes grisées');
  await send({ action: 'dj', show: true, data: { ...MUSIC, canMusic: false } });
  check(/permission/.test(await page.textContent('#dj')), 'sans la permission : message clair');
  await send({ action: 'dj', show: false });

  console.log('\n[Son]');
  await send({ action: 'audio', list: [{ shop: 1, yt: 'dQw4w9WgXcQ', track: 1, at: 12, paused: false, vol: 0.5 }] });
  check(!!(await page.$('#audioBox')), 'zone audio invisible présente (lecteur chargé en jeu seulement)');

  console.log('\n[Tablette]');
  await send({ action: 'tablet', show: true, state: STATE, cfg: CFG });
  for (const p of ['dashboard', 'bar', 'sales', 'entry', 'music', 'config']) {
    await page.click(`[data-nav="${p}"]`);
    await page.waitForTimeout(250);
    const t = await page.textContent('#tabBody');
    check(t.length > 40 && !/Données de démonstration absentes/.test(t), `page « ${p} » affichée`);
    await shot('tablet_' + p);
  }
  await page.click('[data-nav="bar"]');
  await page.waitForTimeout(150);
  check(/Stock/.test(await page.textContent('#tabBody')) && !!(await page.$('[data-mstock="nc_shot"]')), 'carte : prix, stock, commander');

  console.log('\n[Administration (staff)]');
  await send({ action: 'tablet', show: false });
  await send({ action: 'admin', show: true, data: { shops: [{ id: 1, name: 'Galaxy Club', address: 'Vinewood', job: 'club_galaxy', society: 'club_galaxy', matPrefix: 'BN-', enabled: true,
    options: { blipSprite: 614, blipColor: 27 }, points: { door: { x: 1, y: 2, z: 3 }, bar: { x: 4, y: 5, z: 6 } }, employees: 4, balance: 25300, publicOpen: true, fee: 50,
    speakers: [{ id: 7, label: 'Grande enceinte', x: 1, y: 2, z: 3 }], tracks: 12, music: { title: 'Gala' } }, { id: 2, name: 'Bahama Mamas', job: 'bahama', society: 'bahama', enabled: false,
    options: {}, points: {}, employees: 0, balance: 0, speakers: [], tracks: 0 }], grades: {} } });
  await page.waitForTimeout(100);
  const ad = await page.textContent('#admin');
  check(/Galaxy Club/.test(ad) && /Bahama Mamas/.test(ad) && /Nommer le patron/.test(ad), 'liste des boîtes et actions staff');
  await shot('admin');
  await page.click('[data-ad="new"]');
  check(!!(await page.$('[data-af="name"]')), 'formulaire de nouvelle boîte');

  // Rang staff avec seulement « voir » et « points » (cases du menu admin) : le reste est masqué
  const SHOP = { id: 1, name: 'Galaxy Club', address: 'Vinewood', job: 'club_galaxy', society: 'club_galaxy', matPrefix: 'BN-', enabled: true, options: {},
    points: { door: { x: 1, y: 2, z: 3 } }, employees: 4, balance: 25300, publicOpen: true, fee: 50, speakers: [{ id: 7, label: 'Grande enceinte', x: 1, y: 2, z: 3 }], tracks: 12, music: { title: 'Gala' } };
  await send({ action: 'admin', show: false });
  await send({ action: 'admin', show: true, data: { shops: [SHOP], grades: {}, can: { view: true, points: true } } });
  await page.waitForTimeout(100);
  const has = async (sel) => !!(await page.$(sel));
  check(await has('[data-pt="bar"]') && await has('[data-ptdel="door"]') && await has('[data-tp="door"]'), 'case « points » : placer, retirer, aller');
  check(!(await has('[data-ad="enable"]')) && !(await has('[data-ad="edit"]')) && !(await has('[data-ad="boss"]')) && !(await has('[data-ad="delete"]'))
    && !(await has('[data-ad="musicStop"]')) && !(await has('[data-spdel="7"]')) && !(await has('[data-ad="new"]')), 'sans les autres cases : activer, modifier, patron, supprimer, musique, nouvelle boîte masqués');
  check(/Tes droits \(menu admin\) : points/.test(await page.textContent('#admin')), 'le panneau affiche les droits du rang');
  await shot('admin_droits_limites');

  const scroll = await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth);
  check(scroll, 'pas de défilement horizontal');
  check(errors.length === 0, `aucune erreur JavaScript${errors.length ? ' : ' + errors.join(' | ') : ''}`);
  await browser.close();
  console.log(`\nRésultat : ${passes} réussis, ${fails} échec(s)`);
  process.exit(fails ? 1 : 0);
})();
