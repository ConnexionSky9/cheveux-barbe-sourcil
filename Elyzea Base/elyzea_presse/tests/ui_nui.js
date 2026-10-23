// Test de l'interface (navigateur Chromium, hors jeu) : node tests/ui_nui.js   (depuis elyzea_presse/, paquet npm « playwright »)
// Les réponses du serveur sont simulées (window.EDemo). Captures d'écran : dossier donné en argument, sinon dossier temporaire.
const path = require('path');
const { chromium } = require('playwright');
const OUT = process.argv[2] || require('os').tmpdir();

(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1600, height: 900 } });
  const errs = [];
  p.on('pageerror', (e) => errs.push(e.message));
  p.on('console', (m) => { if (m.type() === 'error' && !/fonts\.g/.test(m.text())) errs.push(m.text()); });
  await p.addInitScript(() => {
    const now = Math.floor(Date.now() / 1000);
    const perms = {}; ['duty', 'tablet', 'write', 'publish', 'review', 'edit_any', 'archive', 'delete', 'interview', 'media', 'flash', 'ads', 'ads_manage', 'gear', 'wardrobe', 'stash', 'garage',
      'cards_manage', 'points_manage', 'direction', 'recruit', 'employees_view', 'employees_edit', 'promote', 'demote', 'fire', 'history_view', 'grades_manage', 'perms_manage', 'finance', 'payroll'].forEach((k) => { perms[k] = true; });
    window.ST = { job: 'journaliste', agency: 'Weazel News', short: 'WZL', matricule: 'WZL-001', name: 'Diane Rédac', grade: 'Directeur de la rédaction', level: 6, perms, duty: true, status: 'field' };
    const art = { id: 7, title: 'Le marché couvert de Vespucci', summary: 'Mobilisation des riverains', category: 'societe', status: 'pending', author: 'Sam Stagiaire', version: 3,
      created: now - 7200, updated: now - 600, submitted: now - 600, body: 'Les habitants de Vespucci se sont réunis ce matin.\n\nIls demandent la réouverture du marché.', media: [{ id: 1, kind: 'photo', caption: 'Les riverains', street: 'Vespucci Blvd', author_name: 'Sam', t: now }],
      mediaIds: [1], mine: false, canEdit: true, canPublish: true, canReject: true, canDelete: true, log: [{ action: 'Création', actor_name: 'Sam', t: now - 7200 }, { action: 'Soumis à validation', actor_name: 'Sam', t: now - 600 }] };
    window.LAST = [];
    window.EDemo = (name, data) => {
      window.LAST.push([name, data]);
      const a = data && data.action;
      if (name === 'pub') {
        if (a === 'news') return { list: [{ id: 7, job: 'journaliste', title: art.title, summary: art.summary, category: 'societe', author_name: 'Sam Stagiaire', t: now, agency: 'Weazel News', color: '#e11d48' },
          { id: 8, job: 'ls_times', title: 'Course de côte à Vinewood', category: 'sport', author_name: 'Léo', t: now - 3000, agency: 'Los Santos Times', color: '#2563eb' }],
          agencies: [{ job: 'journaliste', label: 'Weazel News', color: '#e11d48' }, { job: 'ls_times', label: 'Los Santos Times', color: '#2563eb' }],
          categories: [{ id: 'societe', label: 'Société' }, { id: 'sport', label: 'Sport' }], staff: true, more: false, page: 0 };
        if (a === 'newsGet') return { article: { ...art, agency: 'Weazel News', color: '#e11d48', published: now, reviewer: 'Chloé' }, staff: true };
        return { ok: true, message: 'ok' };
      }
      if (name !== 'req') return {};
      switch (a) {
        case 'dashboard': return { counts: { published: 12, pending: 2 }, mine: { draft: 1 }, week: 5, last: [{ id: 7, title: art.title, author_name: 'Sam', category: 'societe', t: now }], agency: 'Weazel News',
          crew: [{ name: 'Julie Journaliste', grade: 'Journaliste', status: 'live', street: 'Legion Square' }], me: { name: 'Diane', grade: 'Directeur de la rédaction', matricule: 'WZL-001', duty: true, status: 'field', times: { session: 1800, unpaid: 3600, unpaidAmount: 1100, rate: 1100 } },
          interview: { id: 3, subject: 'La circulation', other: 'Carl Citoyen', role: 'journalist' } };
        case 'articles': return { list: [{ ...art, status: data.data.box === 'mine' ? 'rejected' : data.data.box === 'archived' ? 'archived' : data.data.box === 'pending' ? 'pending' : 'published', note: 'Ajoutez une source' }] };
        case 'article': return { article: art };
        case 'media': return { list: [{ id: 1, kind: 'photo', caption: 'Les riverains devant le marché', street: 'Vespucci Blvd', author_name: 'Sam', t: now, mine: true }, { id: 2, kind: 'video', caption: 'Le cortège', seconds: 42, author_name: 'Julie', t: now }], canDeleteAll: true };
        case 'interviews': return { list: [{ id: 3, subject: 'La circulation', guest: 'Anonyme', anonymous: true, journalist: 'Diane', status: 'ended', started: now - 900, ended: now - 300, endReason: 'terminée par la personne interviewée', mine: true, hasNotes: true }], canAll: true };
        case 'interviewGet': return { interview: { id: 3, subject: 'La circulation', guest: 'Anonyme', anonymous: true, notes: 'Q : …\nR : …', started: now } };
        case 'flashes': return { list: [{ kind: 'flash', author_name: 'Chloé', title: 'Alerte', text: 'Incendie sur le port', t: now }], wait: 0, waitMe: 0 };
        case 'adSettings': return { price: 500, enabled: true, system: true, canManage: true, maxPrice: 100000, grades: [{ id: 3, name: 'Journaliste', level: 3, commission: 100 }],
          orders: [{ id: 1, uid: 'ANN-1', client_label: 'Mécano', client_name: 'Max', text: 'Garage ouvert ce soir 🚗', freqLabel: 'Toutes les heures', start: '20/10/2026', end: '20/10/2026', unit_price: 500, slots: 24, sent: 11, total: 12000, refunded: 0, status: 'active' }] };
        case 'cards': return { list: [{ number: 'WZL-26-0001', name: 'Julie Journaliste', matricule: 'WZL-003', issued_by: 'Diane', t: now }, { number: 'WZL-26-0002', name: 'Sam', matricule: 'WZL-002', t: now, r: now, revoke_reason: 'départ' }],
          employees: [{ cid: 'A', name: 'Julie Journaliste', matricule: 'WZL-003', online: true }, { cid: 'B', name: 'Sam Stagiaire', matricule: 'WZL-002', online: false }] };
        case 'pointsSettings': return { settings: { gear: { x: 100.2, y: 200.4, z: 30 }, vehicles: [{ model: 'rumpo', label: 'Fourgon de reportage', minLevel: 1, type: 'automobile' }], kiosks: [{ x: 1, y: 2, z: 3, label: 'Kiosque' }] },
          outfits: [{ id: 'journaliste', label: 'Tenue de journaliste', minLevel: 1, male: true, female: false }], levels: [], kinds: { garage: 'Véhicules de service', spawn: 'Place de sortie', stash: 'Coffre', gear: 'Matériel', wardrobe: 'Vestiaire' }, maxKiosks: 12 };
        case 'finance': return { balance: 100000, grades: [{ id: 1, name: 'Stagiaire', level: 1, rate: 250, members: 1, editable: true, commission: 5, commissionEditable: true }], employees: [{ cid: 'A', name: 'Julie', matricule: 'WZL-003', grade: 'Journaliste', level: 3, seconds: 3600, total: 7200, rate: 500, due: 500, duty: true }],
          totalDue: 500, sums: { 'in:ad': { total: 250, n: 1 } }, all: { 'in:ad': { total: 250, n: 1 } }, logs: [], canPay: true, now };
        case 'rateHistory': return { list: [] };
        case 'employees': return { list: [{ cid: 'A', name: 'Julie', matricule: 'WZL-003', gradeId: 3, grade: 'Journaliste', level: 3, total: 7200, unpaid: 3600, unpaidAmount: 500, online: true, duty: true }], grades: [{ id: 3, name: 'Journaliste', level: 3 }], myLevel: 6, myCid: 'D' };
        case 'grades': return { list: [{ id: 1, name: 'Stagiaire', level: 1, isDefault: true, perms: ['duty'], members: 1, active: true }], myLevel: 6, myPerms: perms, permList: [{ key: 'duty', group: 'Service', label: 'Prendre son service' }], canGrades: true, canPerms: true };
        case 'history': return { list: [] };
        case 'transactions': return { list: [{ txid: 'TX-1', type: 'in', category: 'ad', amount: 250, reason: 'Petite annonce', target_name: 'Carl', actor_name: 'Julie', t: now }] };
        case 'articleSave': return { ok: true, id: 7, version: 4, message: 'Article enregistré.' };
        default: return { ok: true };
      }
    };
  });
  await p.goto('file://' + path.join(__dirname, '..', 'html', 'index.html'));
  await p.waitForTimeout(300);
  let pass = 0, fail = 0;
  const check = async (label, fn) => { const r = await p.evaluate(fn); if (r) pass++; else fail++; console.log((r ? 'OK   ' : 'FAIL ') + label + (r === true || !r ? '' : ' -> ' + JSON.stringify(r))); };
  const msg = (m) => p.evaluate((x) => window.postMessage(x, '*'), m);
  const shot = (n) => p.screenshot({ path: path.join(OUT, n) });

  await msg({ action: 'init', cfg: { statuses: [{ id: 'field', label: 'Sur le terrain', color: '#3b82f6' }, { id: 'live', label: 'En direct', color: '#ef4444' }],
    categories: [{ id: 'societe', label: 'Société' }, { id: 'sport', label: 'Sport' }, { id: 'interview', label: 'Interview' }], limits: { titleMin: 6, titleMax: 120, summaryMax: 300, bodyMin: 40, bodyMax: 12000, maxMedia: 6 }, flash: { maxLength: 200, titleMax: 60 } } });
  await msg({ action: 'tablet', show: true, state: await p.evaluate(() => window.ST) });
  await p.waitForTimeout(300);
  await check('tablette : tableau de bord affiché', () => document.querySelectorAll('.stat').length === 4 && document.querySelector('#tabTitle').textContent === 'Tableau de bord');
  await check('menu : toutes les sections pour la direction', () => document.querySelectorAll('.nav-btn').length === 19);
  await shot('presse_tableau_de_bord.png');
  for (const page of ['write', 'mine', 'pending', 'published', 'archives', 'interviews', 'media', 'flash', 'ads', 'cards', 'setup', 'recruit', 'employees', 'grades', 'perms', 'history', 'finance', 'transactions']) {
    await p.click(`[data-nav="${page}"]`); await p.waitForTimeout(150);
    await check(`page « ${page} » rendue sans erreur`, () => !document.querySelector('.loading-bar') || document.querySelector('#tabBody').children.length > 1);
    if (['write', 'pending', 'setup', 'finance', 'ads'].includes(page)) await shot(`presse_${page}.png`);
  }
  await p.click('[data-nav="pending"]'); await p.waitForTimeout(150);
  await p.click('[data-art="7"]'); await p.waitForTimeout(150);
  await check('fiche article : boutons Publier / Renvoyer / Retirer', () => ['publish', 'reject', 'delete'].every((k) => document.querySelector(`[data-aa="${k}"]`)));
  await shot('presse_article.png');
  await p.click('[data-aa="edit"]'); await p.waitForTimeout(200);
  await check('éditeur prérempli (version gardée)', () => document.querySelector('#edTitle').value === 'Le marché couvert de Vespucci' && document.querySelector('[data-med="1"]').checked);
  await p.fill('#edBody', 'Texte modifié '.repeat(10));
  await p.click('[data-ed="save"]'); await p.waitForTimeout(200);
  await check('enregistrer envoie la version et les médias', () => { const s = window.LAST.filter((x) => x[1] && x[1].action === 'articleSave').pop(); return s && s[1].data.version === 3 && s[1].data.media[0] === 1 && s[1].data.id === 7; });
  await p.click('[data-nav="interviews"]'); await p.waitForTimeout(150);
  await p.click('[data-ivart="3"]'); await p.waitForTimeout(200);
  await check('article depuis une interview anonyme : titre et chapeau sans nom', () => document.querySelector('#edTitle').value === 'Interview : La circulation' && /anonyme/.test(document.querySelector('#edSummary').value));
  await p.click('#tabClose');
  await msg({ action: 'tablet', show: false });

  // F6
  await msg({ action: 'f6', show: true, state: await p.evaluate(() => window.ST), times: { session: 60, unpaid: 60, total: 600 }, timesAt: 0, interview: { id: 3, subject: 'La circulation', other: 'Carl', role: 'journalist' }, hold: 'camera', uniform: true });
  await p.waitForTimeout(100);
  await check('F6 : service, interview en cours, matériel en main, tenue personnelle', () => ['dutyOff', 'ivNotes', 'ivEnd', 'stopHold', 'civil', 'reader'].every((k) => document.querySelector(`[data-f6="${k}"]`)));
  await shot('presse_f6.png');
  await msg({ action: 'f6', show: false });

  // Demande d'interview (citoyen) : accepter / refuser + anonymat
  await msg({ action: 'ivOffer', show: true, offer: { id: 1, from: 'Julie Journaliste', agency: 'Weazel News', subject: 'La circulation à Vespucci', timeout: 30 } });
  await p.waitForTimeout(100);
  await check('demande d\'interview : Refuser, Accepter, case anonymat', () => document.querySelector('[data-iv="no"]') && document.querySelector('[data-iv="yes"]') && document.querySelector('#ivAnon'));
  await shot('presse_demande_interview.png');
  await p.click('[data-iv="no"]');
  await check('refus envoyé au jeu', () => { const s = window.LAST.filter((x) => x[0] === 'ivAnswer').pop(); return s && s[1].accept === false; });
  await msg({ action: 'ivOffer', show: false });

  // Annonce diffusée : au-dessus de la mini-carte (rectangle donné par le jeu)
  await msg({ action: 'annonce', show: true, agency: 'Weazel News', color: '#e11d48', text: 'Le garage ouvre ses portes à 20 h ! 🚗 👨‍🔧', seconds: 3, rect: { x: 0.015, y: 0.78, w: 0.16, h: 0.18 } });
  await p.waitForTimeout(200);
  await check('annonce : nom de la rédaction puis texte (emojis gardés), posée juste au-dessus de la mini-carte', () => {
    const el = document.querySelector('#annonce'), r = el.getBoundingClientRect();
    return !el.classList.contains('hidden') && el.querySelector('.ann-head').textContent === 'Weazel News' && el.querySelector('.ann-text').textContent.includes('🚗 👨‍🔧')
      && Math.abs(r.bottom - innerHeight * 0.78) < innerHeight * 0.02 && r.left < innerWidth * 0.03;
  });
  await shot('presse_annonce_minicarte.png');
  await p.waitForTimeout(3300);
  await check('annonce : disparaît après la durée reçue (3 s)', () => document.querySelector('#annonce').classList.contains('hidden'));

  // Flash, carte, viseur, bandeau d'interview
  await msg({ action: 'flash', flash: { kind: 'flash', agency: 'Weazel News', color: '#e11d48', title: 'Alerte', text: 'Incendie en cours sur le port de Los Santos.', author: 'Chloé', seconds: 12 } });
  await msg({ action: 'card', own: false, card: { number: 'WZL-26-0001', name: 'Julie Journaliste', matricule: 'WZL-003', agency: 'Weazel News', issued: '19/10/2026', grade: 'Journaliste', valid: true, shownBy: 'Julie Journaliste' } });
  await msg({ action: 'viewfinder', show: true, kind: 'video', zoom: 2.5, rec: true, recSeconds: 42, street: 'Vespucci Blvd' });
  await msg({ action: 'ivBanner', iv: { subject: 'La circulation', role: 'guest', other: 'Julie', agency: 'Weazel News' } });
  await p.waitForTimeout(200);
  await check('flash info, carte de presse valide, viseur REC, bandeau d\'interview', () => document.querySelector('.flash') && /valide/.test(document.querySelector('#card').textContent)
    && /REC/.test(document.querySelector('#viewfinder').textContent) && !document.querySelector('#ivBanner').classList.contains('hidden'));
  await shot('presse_flash_carte_viseur.png');
  await msg({ action: 'viewfinder', show: false });

  // Journal public
  const news = await p.evaluate(() => window.EDemo('pub', { action: 'news' }));
  await msg({ action: 'reader', show: true, data: news, job: '' });
  await p.waitForTimeout(150);
  await check('journal : 2 articles de 2 rédactions', () => document.querySelectorAll('.paper .art').length === 2);
  await shot('presse_journal.png');
  await p.click('.paper .art[data-art="7"]'); await p.waitForTimeout(150);
  await check('journal : article complet, crédit photo, bouton staff', () => /Vespucci Blvd/.test(document.querySelector('.paper .media').textContent) && document.querySelector('[data-rd="modArt"]'));
  await shot('presse_journal_article.png');
  await p.keyboard.press('Escape');
  await check('Échap : retour à la liste', () => document.querySelectorAll('.paper .art').length === 2);

  // Largeur réduite (petit écran)
  await p.setViewportSize({ width: 1024, height: 640 });
  await p.waitForTimeout(100);
  await check('journal lisible en 1024 × 640 (pas de débordement horizontal)', () => document.querySelector('.paper').scrollWidth <= document.querySelector('.paper').clientWidth + 1);

  console.log(`\n${pass} ok, ${fail} échec(s), erreurs JS : ${errs.length ? errs.join(' | ') : 'aucune'}`);
  await b.close();
  process.exit(fail || errs.length ? 1 : 0);
})();
