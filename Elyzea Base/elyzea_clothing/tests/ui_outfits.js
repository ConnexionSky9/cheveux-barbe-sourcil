// Test de l'interface (navigateur Chromium, hors jeu) : node tests/Elyzea   (depuis elyzea_clothing/, paquet npm « playwright »)
// Les captures d'écran vont dans le dossier temporaire du système.
const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1600, height: 900 } });
  const errs = []; p.on('pageerror', (e) => errs.push(e.message)); p.on('console', (m) => { if (m.type() === 'error') errs.push(m.text()); });
  await p.goto('file://' + require('path').join(__dirname, '..', 'html', 'index.html'));
  await p.waitForTimeout(500);
  // fermer la boutique d'aperçu, ouvrir « Ma tenue »
  await p.evaluate(() => { document.querySelector('#app').classList.add('hidden');
    window.postMessage({ action: 'wardrobe', data: { sex: 'male', itemsMode: true, names: {}, list: [
      { id: 'tops', label: 'Hauts', single: 'Haut', icon: 'top', drawable: 12, texture: 0, naked: false, title: 'Haut n°12' },
      { id: 'hats', label: 'Chapeaux', single: 'Chapeau', icon: 'hat', drawable: -1, texture: 0, naked: true, title: '' } ] } }, '*'); });
  await p.waitForTimeout(200);
  const check = async (label, fn) => { const r = await p.evaluate(fn); console.log((r ? 'OK  ' : 'FAIL') + ' ' + label + (r === true ? '' : ' -> ' + JSON.stringify(r))); };
  await check('onglet Portée visible', () => !document.querySelector('#paneWorn').classList.contains('hidden') && document.querySelectorAll('#wList .wi').length === 2);
  await p.click('[data-wtab="outfits"]'); await p.waitForTimeout(300);
  await check('liste des tenues (2)', () => document.querySelectorAll('#oList .oi').length === 2);
  await check('catégories par défaut + Toutes + ajout', () => [...document.querySelectorAll('#oCats button')].map(b => b.textContent.trim()).join('|'));
  await check('avertissements pack/inventaire', () => [...document.querySelectorAll('.warnline')].map(e => e.textContent).join(' / '));
  await p.screenshot({ path: require('path').join(require('os').tmpdir(), 'ui_outfits_1.png') });
  // enregistrer
  await p.click('#oSaveBtn'); await p.fill('#oF_name', 'Tenue de sport'); await p.selectOption('#oF_cat', 'sport'); await p.click('#oDlgOk'); await p.waitForTimeout(300);
  await check('enregistrée (3 tenues)', () => document.querySelectorAll('#oList .oi').length === 3 && document.querySelector('#toast').textContent);
  // filtrer Sport
  await p.click('[data-ocat="sport"]'); await check('filtre Sport', () => [...document.querySelectorAll('#oList .oi b')].map(e => e.textContent));
  await p.click('[data-ocat="all"]');
  // modifier
  await p.click('.oi:has-text("Tenue de sport") [data-oact="edit"]'); await p.fill('#oF_name', 'Sport du dimanche'); await p.keyboard.press('Enter'); await p.waitForTimeout(300);
  await check('renommée', () => !!document.querySelector('#oList').textContent.includes('Sport du dimanche'));
  // nouvelle catégorie, renommer, supprimer
  await p.click('[data-ocatnew]'); await p.fill('#oF_name', 'Mariage'); await p.click('#oDlgOk'); await p.waitForTimeout(300);
  await check('catégorie créée', () => [...document.querySelectorAll('#oCats button')].some(b => b.textContent.includes('Mariage')));
  await p.click('#oCats button:has-text("Mariage")'); await check('barre catégorie perso', () => !!document.querySelector('[data-ocatren]'));
  await p.click('[data-ocatren]'); await p.fill('#oF_name', 'Mariages'); await p.click('#oDlgOk'); await p.waitForTimeout(300);
  await check('catégorie renommée', () => [...document.querySelectorAll('#oCats button')].some(b => b.textContent.includes('Mariages')));
  await p.click('[data-ocatdel]'); await p.click('#oDlgOk'); await p.waitForTimeout(300);
  await check('catégorie supprimée + retour Toutes', () => ![...document.querySelectorAll('#oCats button')].some(b => b.textContent.includes('Mariages')) && document.querySelector('#oCats .on').dataset.ocat === 'all');
  // supprimer avec confirmation (Annuler puis Valider)
  await p.click('[data-oid="1"] [data-oact="delete"]'); await p.click('#oDlgCancel');
  await check('annulation garde la tenue', () => document.querySelectorAll('#oList .oi').length === 3);
  await p.click('[data-oid="1"] [data-oact="delete"]'); await p.click('#oDlgOk'); await p.waitForTimeout(300);
  await check('suppression après confirmation', () => document.querySelectorAll('#oList .oi').length === 2);
  // Échap ferme d'abord la fenêtre, pas le panneau
  await p.click('[data-oid="2"] [data-oact="replace"]'); await p.keyboard.press('Escape');
  await check('Échap ferme la fenêtre seulement', () => document.querySelector('#oDlg').classList.contains('hidden') && !document.querySelector('#wardrobe').classList.contains('hidden'));
  await p.screenshot({ path: require('path').join(require('os').tmpdir(), 'ui_outfits_2.png') });
  await p.setViewportSize({ width: 390, height: 800 }); await p.waitForTimeout(200);
  await check('pas de débordement horizontal (mobile)', () => document.querySelector('#wardrobe').getBoundingClientRect().right <= innerWidth + 1);
  await p.screenshot({ path: require('path').join(require('os').tmpdir(), 'ui_outfits_mobile.png') });
  console.log('erreurs JS:', errs.length ? errs : 'aucune');
  await b.close();
})();
