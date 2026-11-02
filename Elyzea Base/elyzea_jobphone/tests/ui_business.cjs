// Interface du téléphone de service : appli « Entreprise » (ouvrir / fermer, portes, messages des clients)
// et appel d'un client (sonnerie, décrocher). Le jeu est imité (requêtes interceptées).
// Usage : NODE_PATH=$(npm root -g) node tests/ui_business.cjs [dossier de captures]
const path = require('path');
const fs = require('fs');
const { chromium } = require('playwright');
const ROOT = path.resolve(__dirname, '..');
const OUT = process.argv[2] || path.join(ROOT, 'tests', 'shots');
fs.mkdirSync(OUT, { recursive: true });
let fails = 0, passes = 0;
const check = (ok, label) => { if (ok) { passes++; console.log('  ok   ' + label); } else { fails++; console.log('  ÉCHEC ' + label); } };

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 700, height: 900 } });
  const errs = []; page.on('pageerror', (e) => errs.push(String(e)));
  const state = { open: false, canOpen: true, posts: [], threadRead: false };
  const biz = () => ({ unit: 'elyzea_restaurant:1', label: 'Pizza This', jobLabel: 'Restaurant', number: '918-0001', open: state.open, onDuty: 2 });
  await page.route('https://elyzea_jobphone/**', async (route) => {
    const name = route.request().url().split('/').pop();
    const body = JSON.parse(route.request().postData() || '{}');
    state.posts.push({ name, body });
    let r = {};
    if (name === 'req') {
      const a = body.action, d = body.data || {};
      if (a === 'home') r = { me: { name: 'Paul Patron', grade: 'Patron', matricule: 'RS-001', number: '918-4521', duty: true, canDuty: true, tablet: true, times: {} },
        job: { res: 'elyzea_restaurant', label: 'Restaurant', color: '#f97316' }, unread: 0, levels: {} };
      else if (a === 'biz' && d.op === 'state') r = { business: biz(), canOpen: state.canOpen, unread: state.threadRead ? 0 : 1,
        doors: [{ id: 1, name: 'Entrée', locked: !state.open }, { id: 2, name: 'Porte arrière', locked: !state.open }],
        threads: [{ number: '555-1234', name: 'Claire Cliente', unread: state.threadRead ? 0 : 1, last: 'Vous livrez ce soir ?', t: Date.now() / 1000 - 60 }] };
      else if (a === 'biz' && d.op === 'toggle') { state.open = d.data.open; r = { ok: true, open: state.open, message: state.open ? 'Pizza This est ouverte. 2 porte(s) déverrouillée(s).' : 'Pizza This est fermée. 2 porte(s) verrouillée(s).' }; }
      else if (a === 'biz' && d.op === 'thread') { state.threadRead = true; r = { list: [{ id: 1, mine: false, from: 'Claire Cliente', body: 'Vous livrez ce soir ?', t: Date.now() / 1000 - 60 }].concat(state.replied ? [{ id: 2, mine: true, from: 'Paul Patron', body: state.replied, t: Date.now() / 1000 }] : []) }; }
      else if (a === 'biz' && d.op === 'reply') { state.replied = d.data.body; r = { ok: true }; }
      else if (a === 'answer') r = { ok: true };
      else if (a === 'hangup') r = { ok: true };
    }
    await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(r) });
  });
  await page.addInitScript(() => { window.GetParentResourceName = () => 'elyzea_jobphone'; });
  await page.goto('file://' + path.join(ROOT, 'html', 'index.html'));
  const send = (m) => page.evaluate((x) => window.postMessage(x, '*'), m);
  await send({ action: 'open', job: { res: 'elyzea_restaurant', label: 'Restaurant', color: '#f97316' }, map: {}, levels: {} });
  await page.waitForTimeout(500);
  check(await page.isVisible('[data-app="biz"]'), 'icône « Entreprise » sur l\'accueil');
  await page.click('[data-app="biz"]');
  await page.waitForTimeout(500);
  let txt = await page.textContent('#biz');
  check(txt.includes('Pizza This') && txt.includes('918-0001') && txt.includes('Fermée'), 'fiche : nom, numéro public, « Fermée »');
  check(txt.includes('Entrée 🔒') && txt.includes('Porte arrière 🔒'), 'portes principales affichées verrouillées');
  check(txt.includes('Claire Cliente') && txt.includes('livrez'), 'message client non lu dans la liste');
  await page.screenshot({ path: path.join(OUT, 'jp_entreprise_fermee.png') });
  await page.click('#bizToggle');
  await page.waitForTimeout(600);
  txt = await page.textContent('#biz');
  check(state.posts.some((p) => p.body.action === 'biz' && p.body.data.op === 'toggle' && p.body.data.data.open === true), 'ouverture envoyée au serveur');
  check(txt.includes('Ouverte') && txt.includes('Entrée 🔓') && (await page.textContent('#bizToggle')).includes('Fermer'), 'affiché « Ouverte », portes déverrouillées, bouton « Fermer »');
  await page.screenshot({ path: path.join(OUT, 'jp_entreprise_ouverte.png') });
  await page.click('[data-th="555-1234"]');
  await page.waitForTimeout(500);
  check((await page.textContent('#chat')).includes('Vous livrez ce soir ?'), 'conversation du client ouverte');
  await page.fill('#msg', 'Oui, jusqu\'à 23 h !');
  await page.click('#send');
  await page.waitForTimeout(500);
  check(state.replied === 'Oui, jusqu\'à 23 h !' && (await page.textContent('#chat')).includes('23 h'), 'réponse envoyée et affichée');
  await page.screenshot({ path: path.join(OUT, 'jp_entreprise_chat.png') });
  // Grade sans droit
  state.canOpen = false;
  await page.click('[data-back]');
  await page.waitForTimeout(500);
  check(!(await page.$('#bizToggle')) && (await page.textContent('#biz')).includes('Direction'), 'grade sans droit : pas de bouton, explication affichée');
  // Appel d'un client
  await send({ action: 'call', call: { state: 'incoming', id: 7, name: 'Claire Cliente (client)', number: '555-1234', business: 'Pizza This' } });
  await page.waitForTimeout(500);
  check((await page.textContent('#screen')).includes('Claire Cliente (client)') && await page.isVisible('#ans'), 'appel client : écran d\'appel entrant');
  await page.screenshot({ path: path.join(OUT, 'jp_appel_client.png') });
  await page.click('#hang');
  await page.waitForTimeout(300);
  const hang = state.posts.find((p) => p.body.action === 'hangup');
  check(hang && hang.body.data.id === 7, 'refuser : l\'identifiant de l\'appel est envoyé (les collègues continuent de sonner)');
  check(errs.length === 0, 'aucune erreur JavaScript' + (errs.length ? ' : ' + errs.join(' | ') : ''));
  await browser.close();
  console.log(`\nTOTAL : ${passes} ok, ${fails} échec(s)`);
  process.exit(fails ? 1 : 0);
})();
