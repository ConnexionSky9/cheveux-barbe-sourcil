// Test de l'interface (navigateur Chromium, hors jeu) : node tests/Elyzea   (depuis elyzea_animations/, paquet npm « playwright »)
// Les captures d'écran vont dans le dossier temporaire du système.
const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1600, height: 900 } });
  const errs = []; p.on('pageerror', (e) => errs.push(e.message)); p.on('console', (m) => { if (m.type() === 'error' && !m.text().includes('ERR_')) errs.push(m.text()); });
  await p.route('**/*', (r) => r.request().url().startsWith('file:') ? r.continue() : r.abort());   // pas d'internet (icônes)
  await p.goto('file://' + require('path').join(__dirname, '..', 'html', 'index.html'));
  await p.waitForTimeout(600);
  const check = async (label, fn) => { const r = await p.evaluate(fn); console.log((r ? 'OK  ' : 'FAIL') + ' ' + label + (r === true ? '' : ' -> ' + JSON.stringify(r))); };
  await check('menu normal ouvert, catégories habituelles', () => document.querySelector('#panel').classList.contains('open') && [...document.querySelectorAll('#rail .cat')].length > 10 && document.querySelector('#proposeBar').hidden);
  await p.keyboard.press('Escape'); await p.waitForTimeout(200);
  const cats = [
    { id: 'px_salut', name: 'Salutations', icon: 'hand', desc: 'Se saluer entre amis.', mode: 'shared', items: [['Check entre potes', 'nearby_bro', ''], ['Check entre potes 2', 'nearby_bro2', '']] },
    { id: 'px_calins', name: 'Accolades et câlins', icon: 'heart-handshake', desc: 'Câlins', mode: 'shared', items: [['Câlin', 'nearby_hug', ''], ['Câlin 2', 'nearby_hug2', '']] },
    { id: 'px_couple', name: 'En couple', icon: 'heart', desc: 'Bisous', mode: 'shared', items: [['Bisou sur la joue (homme)', 'nearby_kisscutecheek', 'm'], ['Bisou sur la joue (femme)', 'nearby_kisscutecheek2', 'f']] },
    { id: 'px_slow', name: 'Slow', icon: 'heart-pulse', desc: 'chacun sa danse', mode: 'together', items: [['Slow', 'danceslow', ''], ['Slow 2', 'danceslow2', '']] },
  ];
  await p.evaluate((cats) => window.postMessage({ action: 'env', env: { hidden: ['nearby_hug2'], male: true, inVehicle: false } }, '*'), cats);
  await p.evaluate((cats) => window.postMessage({ action: 'open', propose: { id: 12, name: 'Personne · ID 12', cats } }, '*'), cats);
  await p.waitForTimeout(300);
  await check('mode proposer : bandeau « Proposer à »', () => !document.querySelector('#proposeBar').hidden && document.querySelector('#proposeName').textContent);
  await check('mode proposer : seulement les catégories à deux', () => [...document.querySelectorAll('#rail .cat')].map(b => b.textContent.trim()));
  await check('première catégorie affichée', () => [...document.querySelectorAll('#grid .emote b')].map(e => e.textContent));
  await p.click('#rail .cat[data-id="px_calins"]');
  await check('fichier manquant masqué (Câlin 2)', () => [...document.querySelectorAll('#grid .emote b')].map(e => e.textContent).join('|') === 'Câlin');
  await p.click('#rail .cat[data-id="px_couple"]');
  await check('rôle de l\'autre sexe masqué (perso homme)', () => [...document.querySelectorAll('#grid .emote b')].map(e => e.textContent).join('|') === 'Bisou sur la joue (homme)');
  await check('pas de favori / placement en mode proposer', () => getComputedStyle(document.querySelector('#grid .emote .fav')).display === 'none' && !document.querySelector('#grid .emote .place'));
  await p.fill('#q', 'slow'); await p.waitForTimeout(100);
  await check('recherche limitée aux animations à deux', () => [...document.querySelectorAll('#grid .emote b')].map(e => e.textContent));
  await p.fill('#q', '');
  await p.screenshot({ path: require('path').join(require('os').tmpdir(), 'ui_anim_propose.png') });
  await p.click('#rail .cat[data-id="px_slow"]');
  await p.click('#grid .emote[data-cmd="danceslow"]'); await p.waitForTimeout(250);
  await check('choix : menu fermé, bandeau « invitation envoyée »', () => !document.querySelector('#panel').classList.contains('open') && document.querySelector('#out').classList.contains('show') && document.querySelector('#outLabel').textContent);
  await p.screenshot({ path: require('path').join(require('os').tmpdir(), 'ui_anim_outgoing.png') });
  await p.click('#outCancel'); await p.waitForTimeout(250);
  await check('annulation : bandeau caché', () => !document.querySelector('#out').classList.contains('show'));
  await p.waitForTimeout(600);
  await p.keyboard.press('KeyK'); await p.waitForTimeout(300);
  await check('réouverture K : mode normal rétabli', () => document.querySelector('#proposeBar').hidden && [...document.querySelectorAll('#rail .cat')].length > 10 && document.querySelector('#catTitle').textContent);
  await p.setViewportSize({ width: 390, height: 800 }); await p.waitForTimeout(200);
  await p.evaluate(() => window.postMessage({ action: 'outgoing', name: 'Joueur 5', label: 'Câlin', timeout: 15, key: 'L' }, '*')); await p.waitForTimeout(300);
  await check('bandeau dans l\'écran (mobile)', () => { const r = document.querySelector('#out').getBoundingClientRect(); return r.left >= 0 && r.right <= innerWidth; });
  console.log('erreurs JS:', errs.length ? errs : 'aucune');
  await b.close();
})();
