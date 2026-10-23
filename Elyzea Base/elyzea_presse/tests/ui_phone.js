// Test des applications « Annonce » et « Planning » du téléphone de service (elyzea_jobphone/html), hors jeu (Chromium).
// node tests/ui_phone.js [dossier des captures]   (depuis elyzea_presse/, paquet npm « playwright »)
// Les réponses du serveur sont simulées en interceptant les requêtes NUI https://elyzea_jobphone/…
const path = require('path');
const { chromium } = require('playwright');
const OUT = process.argv[2] || require('os').tmpdir();

(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1280, height: 760 } });
  const errs = [];
  p.on('pageerror', (e) => errs.push(e.message));
  const sent = [];
  let job = { res: 'elyzea_meca', label: 'Mécano', color: '#f59e0b' };
  let payFails = 1;   // le premier paiement est refusé (fonds insuffisants), le second réussit
  const today = new Date().toISOString().slice(0, 10);
  await p.route('https://elyzea_jobphone/**', async (route) => {
    const body = JSON.parse(route.request().postData() || '{}');
    const name = route.request().url().split('/').pop();
    sent.push([name, body]);
    let r = {};
    if (name === 'req') {
      const a = body.action, d = body.data || {};
      if (a === 'home') r = { me: { name: 'Max Garagiste', grade: 'Patron', matricule: 'MECA-001', number: '913-0001', duty: true, canDuty: true, tablet: true, times: {} }, job, unread: 0, levels: {} };
      else if (a === 'annonce' && d.op === 'agencies') r = { enabled: true, textMax: 150, daily: '19h00', maxDays: 31, today,
        frequencies: [{ id: '30m', label: 'Toutes les 30 minutes' }, { id: '1h', label: 'Toutes les heures' }, { id: '1d', label: 'Une fois par jour', daily: true }],
        client: { label: 'Mécano', canPay: true, balance: 100000, job: 'mechanic' },
        list: [{ job: 'journaliste', label: 'Weazel News', color: '#e11d48', price: 500, available: true }, { job: 'ls_times', label: 'Los Santos Times', price: 300, available: false }] };
      else if (a === 'annonce' && d.op === 'quote') r = { quote: { job: 'journaliste', agency: 'Weazel News', text: d.data.text, length: 42, freq: d.data.freq, freqLabel: 'Toutes les heures',
        startLabel: '21/10/2026', endLabel: '21/10/2026', first: '21/10/2026 00:00', last: '21/10/2026 23:00', count: 24, unit: 500, total: 12000, client: 'Mécano', canPay: true } };
      else if (a === 'annonce' && d.op === 'order') r = payFails-- > 0 ? { error: 'Paiement refusé : le compte de Mécano n\'a que 200 $ pour 12000 $.', refused: true }
        : { ok: true, uid: 'ANN-261021-001', quote: { agency: 'Weazel News', count: 24, total: 12000 } };
      else if (a === 'annonce' && d.op === 'myOrders') r = { list: [{ uid: 'ANN-1', agency_label: 'Weazel News', text: 'Garage ouvert ce soir 🚗', slots: 24, sent: 3, total: 12000, refunded: 0, status: 'active', start: '21/10/2026', end: '21/10/2026', next: '21/10 04:00' }] };
      else if (a === 'planning' && d.op === 'planning') r = { me: { duty: true, enabled: true, agency: 'Weazel News' }, displaySeconds: 10,
        due: [{ id: 5, dueLabel: '21/10 14:00', client: 'Mécano', text: 'Garage ouvert ce soir 🚗', status: 'offered', available: true, late: false, unit: 500, orderTotal: 12000, myCommission: 100 },
          { id: 6, dueLabel: '21/10 13:00', client: 'Burger Shot', text: 'Menu à 5 $', status: 'offered', available: true, late: true, unit: 500, orderTotal: 500, myCommission: 100 }],
        queued: [], today: [{ id: 7, dueLabel: '21/10 15:00', client: 'Mécano', text: 'Garage ouvert ce soir 🚗', status: 'scheduled', available: false, unit: 500, orderTotal: 12000, myCommission: 100 }],
        next: [], sent: [{ id: 4, dueLabel: '21/10 12:00', client: 'Mécano', text: 'Garage ouvert ce soir 🚗', status: 'sent', mode: 'manual', by: 'Julie', commission: 100, unit: 500, orderTotal: 12000 }] };
      else if (a === 'planning' && d.op === 'planSend') r = { ok: true, message: 'Annonce envoyée. Prime : 100 $ une fois diffusée.' };
    }
    await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(r) });
  });
  await p.goto('file://' + path.join(__dirname, '..', '..', 'elyzea_jobphone', 'html', 'index.html'));
  let pass = 0, fail = 0;
  const check = async (label, fn) => { const r = await p.evaluate(fn); if (r) pass++; else fail++; console.log((r ? 'OK   ' : 'FAIL ') + label + (r === true || !r ? '' : ' -> ' + JSON.stringify(r))); };
  const shot = (n) => p.locator('#phone').screenshot({ path: path.join(OUT, n) });
  const open = async () => { await p.evaluate((j) => window.postMessage({ action: 'open', job: j, levels: {} }, '*'), job); await p.waitForTimeout(250); };

  await open();
  await check('accueil (entreprise cliente) : application « Annonce », pas de « Planning »', () => !!document.querySelector('[data-app="annonce"]') && !document.querySelector('[data-app="planning"]'));
  await p.click('[data-app="annonce"]'); await p.waitForTimeout(200);
  await check('Annonce : rédactions avec leur prix, rédaction fermée grisée', () => document.querySelectorAll('[data-ag]').length === 2 && /500/.test(document.querySelector('[data-ag="journaliste"]').textContent)
    && document.querySelector('[data-ag="ls_times"]').classList.contains('off'));
  await shot('telephone_annonce_redactions.png');
  await p.click('[data-ag="journaliste"]'); await p.waitForTimeout(150);
  const t150 = 'A'.repeat(149) + '!';
  await p.fill('#annText', t150);
  await check('compteur 150/150, bouton actif', () => document.querySelector('#annCount').textContent === '150/150' && !document.querySelector('#annNext').disabled);
  await p.fill('#annText', t150 + 'x');
  await check('151/150 : message explicite, validation impossible', () => document.querySelector('#annCount').textContent === '151/150' && document.querySelector('#annNext').disabled && /151/.test(document.querySelector('#annErr').textContent));
  await p.fill('#annText', 'Le garage ouvre ses portes à 20 h ! 🚗 👨‍👩‍👧 🇫🇷');
  await check('emojis comptés comme on les voit (👨‍👩‍👧 = 1, 🇫🇷 = 1)', () => document.querySelector('#annCount').textContent === '41/150');
  await p.click('[data-freq="1h"]');
  await p.fill('#annStart', today); await p.fill('#annEnd', '2000-01-01'); await p.dispatchEvent('#annEnd', 'change');
  await check('date de fin avant le début : refusée', () => document.querySelector('#annNext').disabled && /avant/.test(document.querySelector('#annErr').textContent));
  await p.fill('#annEnd', today); await p.dispatchEvent('#annEnd', 'change');
  await shot('telephone_annonce_formulaire.png');
  await p.click('#annNext'); await p.waitForTimeout(250);
  await check('récapitulatif : rédaction, texte, fréquence, dates, nombre, prix unitaire, total', () => /Weazel News/.test(document.body.textContent) && /24/.test(document.querySelector('.recap').textContent)
    && /12\s?000/.test(document.querySelector('.recap .total').textContent) && document.querySelector('.recap .txt b').textContent.includes('🚗'));
  await shot('telephone_annonce_recapitulatif.png');
  await p.click('#annPay'); await p.waitForTimeout(250);
  await check('paiement refusé : message, bouton « réessayer »', () => /refusé/.test(document.querySelector('#annErr').textContent) && /réessayer/.test(document.querySelector('#annPay').textContent));
  await p.click('#annPay'); await p.waitForTimeout(250);
  const orders = sent.filter((x) => x[1].action === 'annonce' && x[1].data.op === 'order').map((x) => x[1].data.data);
  if (orders.length === 2 && orders[0].requestKey !== orders[1].requestKey && orders[0].expectedTotal === 12000 && orders[0].expectedCount === 24) { pass++; console.log('OK   après un refus du serveur, nouvel essai = nouvelle demande ; total et nombre vus envoyés pour contrôle'); }
  else { fail++; console.log('FAIL clé / montants', JSON.stringify(orders)); }
  // Double clic : le bouton se désactive pendant le paiement
  await check('paiement réussi : commande confirmée', () => /Commande confirmée/.test(document.querySelector('.head h1').textContent) && /ANN-261021-001/.test(document.body.textContent));
  await shot('telephone_annonce_confirmee.png');
  await p.click('#annOk'); await p.waitForTimeout(200);
  await check('mes commandes : progression 3/24', () => /3\/24/.test(document.querySelector('#annOrd').textContent));

  // Journaliste : Planning
  job = { res: 'elyzea_presse', label: 'Weazel News', color: '#e11d48' };
  await p.evaluate(() => window.postMessage({ action: 'close' }, '*'));
  await open();
  await check('accueil (journaliste) : « Planning » présent', () => !!document.querySelector('[data-app="planning"]'));
  await p.click('[data-app="planning"]'); await p.waitForTimeout(250);
  await check('Planning : à envoyer (dont une en retard), aujourd\'hui, envoyées ; prime affichée', () => document.querySelectorAll('[data-send]').length === 3 && /en retard/.test(document.body.textContent)
    && /prime 100/.test(document.body.textContent.replace(/\s/g, ' ')) && /Par Julie/.test(document.body.textContent));
  await check('bouton désactivé tant que l\'heure n\'est pas atteinte', () => document.querySelector('[data-send="7"]').disabled && /Disponible à 15:00/.test(document.querySelector('[data-send="7"]').textContent));
  await shot('telephone_planning.png');
  await p.click('[data-send="5"]'); await p.waitForTimeout(250);
  await check('« Envoyer l\'annonce » : demande envoyée au serveur, message de confirmation', () => /Annonce envoyée/.test(document.querySelector('#toast').textContent));
  if (!sent.some((x) => x[1].action === 'planning' && x[1].data.op === 'planSend' && x[1].data.data.id === 5)) { fail++; console.log('FAIL planSend non envoyé'); } else pass++;

  console.log(`\n${pass} ok, ${fail} échec(s), erreurs JS : ${errs.length ? errs.join(' | ') : 'aucune'}`);
  await b.close();
  process.exit(fail || errs.length ? 1 : 0);
})();
