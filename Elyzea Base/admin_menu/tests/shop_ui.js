// Test de l'onglet « Boutique » (elyzea_shop) dans Chromium : lecture seule vs Fondateur, formulaires, envois.
// node tests/shop_ui.js <dossier admin_menu> <dossier pour les captures>
const { chromium } = require(process.env.PLAYWRIGHT || 'playwright');
const path = require('path');
(async () => {
  const html = path.resolve(process.argv[2], 'html/index.html');
  const out = process.argv[3];
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined });
  const page = await browser.newPage({ viewport: { width: 1500, height: 1000 } });
  const errors = [], posts = [];
  page.on('pageerror', (e) => errors.push(String(e)));
  page.on('dialog', (d) => d.accept());
  await page.route('https://admin_menu/**', (r) => { posts.push({ ep: r.request().url().split('/').pop(), body: JSON.parse(r.request().postData() || '{}') }); r.fulfill({ status: 200, body: '{}', contentType: 'application/json' }); });
  await page.goto('file://' + html);
  let fails = 0;
  const check = (name, c) => { if (c) console.log('OK   ' + name); else { fails++; console.log('FAIL ' + name); } };
  const shopPosts = () => posts.filter((p) => p.ep === 'action' && JSON.stringify(p.body).includes('"shop"')).map((p) => p.body.data || p.body);
  const lastShop = () => { const l = shopPosts(); return l[l.length - 1]; };
  const send = (canEdit, extra = {}) => page.evaluate(([canEdit, extra]) => {
    window.postMessage({ action: 'data', data: {
      me: { id: 1, label: canEdit ? 'Fondateur' : 'Admin', color: '#d9b56a', level: canEdit ? 100 : 30, perms: { shop_view: true }, onDuty: true, duty: true },
      players: [], keys: [], jobs: [], config: { editor: { minLevel: 0, quickProps: [], quickPeds: [], npcPresets: [] } },
      shop: Object.assign({
        available: true, canEdit,
        products: [
          { key: 'sapphire', label: 'Elyzea Sapphire', category: 'vip', enabled: true, fromConfig: true, tebexPackageId: 111, durationDays: 30, perks: ['Prioritaire'], rewards: [{ type: 'group', name: 'vip_sapphire' }] },
          { key: 'coins_1000', label: '1 000 Elyzea Coins', category: 'coins', enabled: false, fromConfig: true, perks: [], rewards: [{ type: 'coins', amount: 1000 }] },
        ],
        categories: [{ id: 'vip', label: 'VIP', icon: 'crown' }, { id: 'coins', label: 'Elyzea Coins', icon: 'coin' }],
        rewardTypes: ['group', 'perk', 'coins', 'vehicle', 'item', 'money', 'command'], commands: [],
        coins: { enabled: true, label: 'Elyzea Coins', short: 'EC', total: 4200 }, integrations: { vehicles: true, items: true, money: false },
        tebex: { storeUrl: 'https://elyzea.tebex.io', secretSet: true }, stats: { pending: 1, failed: 2, tebex: 10, coins: 3 },
        deliveries: [{ id: 7, transaction_id: 'tbx-7', product_key: 'sapphire', label: 'Elyzea Sapphire', action: 'grant', account: '123456789', source: 'tebex', status: 'failed', attempts: 10, last_error: 'Joueur introuvable', created_at: '2026-10-20 12:00:00' }],
        logs: [{ level: 'warn', action: 'admin_coins', account: '123456789', ref: 'x', details: '+10 par Test', created_at: '2026-10-20 12:00:00' }],
      }, extra),
    } }, '*');
  }, [canEdit, extra]);
  await page.evaluate(() => window.postMessage({ action: 'open' }, '*'));
  // ---------- Lecture seule (grade avec shop_view, pas Fondateur)
  await send(false);
  await page.waitForTimeout(250);
  await page.evaluate(() => { tab = 'shop'; render(); });
  await page.waitForTimeout(150);
  let txt = await page.textContent('#content');
  check('onglet Boutique affiché (général : stats, Tebex)', txt.includes('Livraisons échouées') && txt.includes('sv_tebexSecret') && txt.includes('elyzea_shop_deliver'));
  await page.click('[data-ssub="products"]');
  txt = await page.textContent('#content');
  check('lecture seule : bandeau « seuls les Fondateurs »', txt.includes('seuls les Fondateurs'));
  check('lecture seule : aucun bouton de modification', !(await page.$('[data-sa="new"]')) && !(await page.$('[data-stoggle]')));
  await page.click('[data-sedit="sapphire"]');
  check('lecture seule : fiche produit non modifiable', await page.$eval('[data-sp="label"]', (e) => e.disabled) && !(await page.$('[data-sa="save"]')));
  await page.screenshot({ path: out + '/boutique_lecture_seule.png' });
  await page.click('[data-sa="cancel"]');
  await page.click('[data-ssub="deliveries"]');
  check('lecture seule : pas de relance / annulation', !(await page.$('[data-sretry]')));
  await page.click('[data-ssub="players"]');
  await page.fill('[data-slook]', 'fivem:123456789');
  await page.click('[data-sa="lookup"]');
  await page.waitForTimeout(100);
  check('lecture seule : recherche d\'un joueur envoyée', JSON.stringify(lastShop()).includes('account_lookup'));
  // ---------- Fondateur
  await send(true, { lookup: { account: '123456789', coins: 500, vip: [{ name: 'vip_sapphire' }], coinHistory: [{ delta: 500, balance_after: 500, reason: 'Achat', created_at: '2026-10-20 12:00:00' }], deliveries: [] } });
  await page.waitForTimeout(250);
  txt = await page.textContent('#content');
  check('fiche joueur affichée après la recherche (solde, grades)', txt.includes('500 EC') && txt.includes('vip_sapphire'));
  await page.fill('[data-sadj="amount"]', '-50');
  await page.fill('[data-sadj="reason"]', 'erreur');
  await page.click('[data-sa="coins"]');
  await page.waitForTimeout(100);
  check('ajustement de coins envoyé', shopPosts().some((b) => JSON.stringify(b).includes('coins_adjust') && JSON.stringify(b).includes('-50')));
  await page.click('[data-ssub="products"]');
  check('Fondateur : boutons de modification', !!(await page.$('[data-sa="new"]')) && !!(await page.$('[data-stoggle="sapphire"]')));
  await page.click('[data-stoggle="coins_1000"]');
  await page.waitForTimeout(100);
  check('afficher / masquer envoyé', JSON.stringify(lastShop()).includes('product_toggle') && JSON.stringify(lastShop()).includes('coins_1000'));
  await page.click('[data-sa="new"]');
  await page.fill('[data-skey]', 'pack_ete');
  await page.fill('[data-sp="label"]', 'Pack été');
  await page.selectOption('[data-sp="category"]', 'vip');
  await page.fill('[data-sp="coinsPrice"]', '250');
  await page.fill('[data-sperks]', 'Un\nDeux');
  await page.click('[data-sradd]');
  await page.fill('[data-srf="0:name"]', 'phone');
  await page.fill('[data-srf="0:count"]', '2');
  await page.click('[data-sradd]');
  await page.selectOption('[data-srt="1"]', 'perk');
  await page.fill('[data-srf="1:name"]', 'ete');
  // l'actualisation automatique ne doit pas effacer la saisie
  await send(true);
  await page.waitForTimeout(200);
  check('saisie conservée pendant l\'actualisation automatique', (await page.inputValue('[data-sp="label"]')) === 'Pack été');
  await page.click('[data-sena]');
  await page.screenshot({ path: out + '/boutique_fondateur_produit.png' });
  await page.click('[data-sa="save"]');
  await page.waitForTimeout(100);
  const sv = lastShop();
  const p = sv && sv.data && sv.data.product;
  check('enregistrement : clé, nom, prix, avantages, récompenses typés', sv && sv.name === 'product_save' && sv.data.key === 'pack_ete' && sv.data.isNew === true && p.coinsPrice === 250
    && p.perks.length === 2 && p.rewards[0].count === 2 && p.rewards[1].type === 'perk' && p.rewards[1].name === 'ete' && p.enabled === true && p.tebexPackageId === null);
  await page.click('[data-ssub="categories"]');
  await page.click('[data-sa="cat_add"]');
  await page.fill('[data-sc="2:label"]', 'Saison');
  await page.click('[data-sa="cat_save"]');
  await page.waitForTimeout(100);
  check('catégories envoyées', JSON.stringify(lastShop()).includes('categories_save') && JSON.stringify(lastShop()).includes('Saison'));
  await page.click('[data-ssub="deliveries"]');
  await page.click('[data-sretry="7"]');
  await page.waitForTimeout(100);
  check('relance d\'une livraison échouée', JSON.stringify(lastShop()).includes('delivery_retry'));
  await page.screenshot({ path: out + '/boutique_livraisons.png' });
  await send(true, { available: false, error: true });
  await page.waitForTimeout(200);
  check('elyzea_shop arrêtée : message clair', (await page.textContent('#content')).includes('ne répond pas'));
  check('aucune erreur JavaScript', errors.length === 0);
  if (errors.length) console.log(errors);
  console.log(`\n${fails} échec(s)`);
  await browser.close();
  process.exit(fails ? 1 : 0);
})();
