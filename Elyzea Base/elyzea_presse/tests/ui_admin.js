// Test de l'onglet « Annonces presse » d'admin_menu (admin_menu/html), hors jeu (Chromium).
// node tests/ui_admin.js [dossier des captures]   (depuis elyzea_presse/, paquet npm « playwright »)
const path = require('path');
const { chromium } = require('playwright');
const OUT = process.argv[2] || require('os').tmpdir();
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1600, height: 900 } });
  const errs = [], sent = [];
  p.on('pageerror', (e) => errs.push(e.message));
  await p.route('https://admin_menu/**', async (route) => {
    sent.push([route.request().url().split('/').pop(), JSON.parse(route.request().postData() || '{}')]);
    await route.fulfill({ status: 200, contentType: 'application/json', body: '{}' });
  });
  await p.goto('file://' + path.join(__dirname, '..', '..', 'admin_menu', 'html', 'index.html'));
  await p.waitForTimeout(300);
  const slot = (id, status, extra = {}) => ({ id, status, dueLabel: '21/10 14:00', uid: 'ANN-1', client_label: 'Mécano', text: 'Garage ouvert ce soir 🚗', mode: 'auto', ...extra });
  const D = { me: { perms: { presse_manage: true }, name: 'Alex', rank: 'fondateur', level: 100 }, players: [], ranks: {}, config: { noclipKey: 'F2' }, self: {},
    presse: { available: true, serverTime: '21/10/2026 14:02', now: 0, refundsFailed: 1,
      settings: { enabled: true, displaySeconds: 10, tickSeconds: 15, manualWindow: 300, maxLate: 7200, maxAttempts: 3, gapMs: 750, queuePaused: false },
      limits: { displaySeconds: [3, 60], tickSeconds: [5, 120], manualWindow: [30, 3600], maxLate: [300, 86400], maxAttempts: [1, 10] },
      counts: { queued: 2, offered: 1, scheduled: 40, sent: 12, failed: 1 }, current: { agency: 'Weazel News', text: 'Garage ouvert ce soir 🚗' },
      agencies: [{ job: 'journaliste', label: 'Weazel News', price: 500, available: true, orders: 2, revenue: 18000 }, { job: 'ls_times', label: 'Los Santos Times', price: 300, available: true, orders: 1, revenue: 600 }],
      pending: [slot(1, 'broadcasting'), slot(2, 'queued'), slot(3, 'offered'), slot(4, 'failed', { last_error: 'affichage impossible' })], upcoming: [slot(9, 'scheduled')],
      sent: [slot(5, 'sent', { mode: 'manual', sent_by_name: 'Julie', commission: 100, commission_status: 'paid', sentLabel: '21/10 13:00:10' })],
      orders: [{ id: 1, uid: 'ANN-1', agency_label: 'Weazel News', client_label: 'Mécano', client_name: 'Max', text: 'Garage ouvert ce soir 🚗', frequency: '1h', start_date: '2026-10-21', end_date: '2026-10-21', unit_price: 500, slots: 24, total: 12000, refunded: 0, status: 'active' }] } };
  await p.evaluate((d) => { window.postMessage({ action: 'data', data: d }, '*'); window.postMessage({ action: 'open' }, '*'); }, D);
  await p.waitForTimeout(300);
  let pass = 0, fail = 0;
  const check = async (label, fn) => { const r = await p.evaluate(fn); if (r) pass++; else fail++; console.log((r ? 'OK   ' : 'FAIL ') + label); };
  await check('onglet « Annonces presse » déclaré et visible pour presse_manage', () => TABS.some((t) => t.id === 'presse' && t.show()));
  await p.evaluate(() => { tab = 'presse'; render(); }); await p.waitForTimeout(200);
  await check('réglages : activation, durée d\'affichage, planificateur, délai, retard max, essais', () => ['displaySeconds', 'tickSeconds', 'manualWindow', 'maxLate', 'maxAttempts'].every((k) => document.querySelector(`[data-psf="${k}"]`)) && !!document.querySelector('[data-psb="enabled"]'));
  await check('rédactions, annonce à l\'écran, file (relancer / annuler)', () => /Los Santos Times/.test(document.body.textContent) && /À l'écran/.test(document.body.textContent)
    && !!document.querySelector('[data-psa="retry"][data-id="4"]') && !!document.querySelector('[data-psa="cancelSlot"][data-id="2"]') && !document.querySelector('[data-psa="cancelSlot"][data-id="1"]'));
  await p.screenshot({ path: path.join(OUT, 'admin_annonces_presse.png') });
  await p.fill('[data-psf="displaySeconds"]', '15');
  await p.click('[data-psa="save"]'); await p.waitForTimeout(150);
  const save = sent.filter((x) => x[0] === 'action').map((x) => x[1]).find((x) => x.name === 'presse' || (x.data && x.data.name === 'save'));
  const ok = JSON.stringify(sent).includes('"displaySeconds":15') && JSON.stringify(sent).includes('"save"');
  if (ok) { pass++; console.log('OK   Enregistrer : durée 15 s envoyée au serveur'); } else { fail++; console.log('FAIL Enregistrer', JSON.stringify(sent.slice(-3))); }
  for (const v of ['upcoming', 'sent', 'orders']) { await p.click(`[data-psv="${v}"]`); await p.waitForTimeout(100); }
  await check('vues Programmées / Diffusions effectuées / Commandes (annulation avec remboursement)', () => !!document.querySelector('[data-psa="cancelOrder"]'));
  console.log(`\n${pass} ok, ${fail} échec(s), erreurs JS : ${errs.length ? errs.join(' | ') : 'aucune'}`);
  await b.close();
  process.exit(fail || errs.length ? 1 : 0);
})();
