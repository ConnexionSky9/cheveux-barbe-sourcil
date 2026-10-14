/* NOIR X — données simulées pour l'APERÇU HORS JEU (ouverture de html/index.html au navigateur).
 * Ignoré en jeu. Sert uniquement à visualiser l'interface ; la logique réelle est côté serveur. */
(function () {
  'use strict';
  if (NX.inGame) return;

  const db = {
    wallet: { dirty: 48250, clean: 12900, pending: { clean: 0, dirty: 0 } },
    identities: [{ id: 1, handle: 'corvus_07', kind: 'main', reputation: 4, expiresAt: null }],
    informants: [
      { id: 1, name: 'Le Fermier', tagline: 'Connaît chaque champ du comté', greeting: 'Ouais ? Fais vite.' },
      { id: 2, name: 'Silk', tagline: 'Les rues, les vendeurs, les rumeurs', greeting: 'Nouvelle tête. Tu cherches quoi ?' },
    ],
    intel: {
      1: [
        { id: 11, category: 'weed', categoryLabel: 'Champs', title: 'Où pousse la weed ?', price: 1500, currency: 'dirty', reliability: 'fiable', purchased: false, hasGps: true,
          answer: 'Derrière les serres de Grapeseed, côté est. Je te mets le point.', gps: { x: 2220, y: 5577, z: 53 } },
        { id: 12, category: 'weed', categoryLabel: 'Champs', title: 'Un coin plus discret ?', price: 2500, currency: 'dirty', reliability: 'rumeur', purchased: false, hasGps: true,
          answer: 'Près de Sandy Shores. Ça bouge souvent, vérifie avant.', gps: { x: 1700, y: 3300, z: 41 } },
      ],
      2: [
        { id: 21, category: 'dealer', categoryLabel: 'Revendeurs', title: 'Qui vend à Grove Street ?', price: 1000, currency: 'dirty', reliability: 'fiable', purchased: false, hasGps: true,
          answer: 'Un type en survêt vert près du terrain de basket. Weed et pochons, cash.', gps: { x: 105, y: -1940, z: 20 } },
        { id: 22, category: 'rumor', categoryLabel: 'Rumeurs', title: 'Des nouvelles ?', price: 0, currency: 'dirty', reliability: 'probable', purchased: false, hasGps: false,
          answer: 'Patrouilles doublées à Davis cette semaine. Évite.' },
      ],
    },
    log: { 1: [], 2: [] },
    launderJob: null,
    history: [],
    cooldownUntil: 0,
    burners: [],
  };

  const ok = (o) => Promise.resolve(Object.assign({ ok: true }, o));
  const fail = (code, message) => Promise.resolve({ ok: false, error: code, message });

  const handlers = {
    'wallet.get': () => ok(Object.assign({ linked: { inventory: true, economy: true } }, db.wallet)),
    'ghost.me': () => ok({ identities: db.identities, rules: { min: 3, max: 20 } }),
    'ghost.create': (a) => { db.identities = [{ id: 1, handle: a.handle || 'corvus_07', kind: 'main', reputation: 0, expiresAt: null }]; return ok({ identities: db.identities }); },

    'ratline.list': () => ok({ informants: db.informants.map(i => ({ id: i.id, name: i.name, tagline: i.tagline, last: (db.log[i.id].slice(-1)[0] || null) && { body: db.log[i.id].slice(-1)[0].body, at: db.log[i.id].slice(-1)[0].at, mine: db.log[i.id].slice(-1)[0].mine } })) }),
    'ratline.open': (a) => { const inf = db.informants.find(i => i.id === a.informant); return ok({ informant: inf, topics: db.intel[a.informant], history: db.log[a.informant], symbol: '$' }); },
    'ratline.ask': (a) => {
      const t = db.intel[a.informant].find(x => x.id === a.intel);
      if (!t) return fail('not_found', 'Plus rien là-dessus.');
      if (!t.purchased && t.price > 0) { if (db.wallet.dirty < t.price) return fail('funds', 'Fonds insuffisants.'); db.wallet.dirty -= t.price; }
      t.purchased = true;
      db.log[a.informant].push({ mine: true, body: t.title, at: Date.now() / 1000 }, { mine: false, body: t.answer, at: Date.now() / 1000, intel: t.id, gps: t.hasGps });
      return ok({ answer: t.answer, intel: t.id, gps: t.gps, charged: t.price, currency: t.currency, delay: 900 });
    },
    'ratline.say': (a) => {
      const topics = db.intel[a.informant];
      const low = a.text.toLowerCase();
      const m = topics.filter(t => low.includes('weed') && t.category === 'weed' || low.includes('vend') && t.category === 'dealer' || low.includes('news') || low.includes('nouvel'));
      return ok(m.length ? { reply: 'Ça, je peux t\'en parler.', suggestions: m, delay: 800 } : { reply: 'Connais pas. Essaie plutôt ça :', suggestions: topics.slice(0, 2), delay: 800 });
    },
    'ratline.gps': (a) => { for (const k in db.intel) { const t = db.intel[k].find(x => x.id === a.intel); if (t && t.gps) return ok({ gps: t.gps }); } return fail('not_found', 'Indisponible.'); },

    'launder.state': () => ok({
      rules: { min: 1000, max: 100000, feePercent: 30, baseSeconds: 60, secondsPer1000: 6, maxSeconds: 900, symbol: '$' },
      dirty: db.wallet.dirty, job: db.launderJob, cooldown: Math.max(0, db.cooldownUntil - Date.now() / 1000), history: db.history,
    }),
    'launder.start': (a) => {
      if (db.launderJob) return fail('busy', 'Déjà en cours.');
      if (a.amount > db.wallet.dirty) return fail('funds', 'Pas assez d\'argent sale.');
      db.wallet.dirty -= a.amount;
      const fee = Math.floor(a.amount * 0.3), net = a.amount - fee;
      const total = Math.min(900, 60 + Math.ceil(a.amount / 1000) * 6);
      db.launderJob = { id: 1, amount: a.amount, fee, net, stolen: 0, payout: net, remaining: total, total, underAttack: false };
      // aperçu : déclenche un duel de démonstration à mi-parcours
      setTimeout(() => { if (db.launderJob) { db.launderJob.underAttack = true; NX.emit('duel:start', { attack: 99, role: 'defender', line: 'inject --node raven-21 --key 4f8a2c --relay 7731', remainingMs: 25000, windowMs: 25000, npc: true }); } }, 6000);
      setTimeout(() => { db.history.unshift({ id: 1, amount: a.amount, net, stolen: db.launderJob ? db.launderJob.stolen : 0, payout: net, status: 'done', at: Date.now() / 1000 }); db.wallet.clean += net; db.launderJob = null; db.cooldownUntil = Date.now() / 1000 + 120; NX.emit('launder:done', { payout: net, stolen: 0 }); }, total * 1000);
      return ok({ job: db.launderJob });
    },
    'duel.submit': (a) => {
      if (a.text && a.text.length > 5) { setTimeout(() => { if (db.launderJob) db.launderJob.underAttack = false; NX.emit('duel:end', { attack: a.attack, role: 'defender', won: true, loss: 0 }); }, 300); return ok({ correct: true }); }
      return ok({ correct: false });
    },
    'duel.active': () => ok({ duel: null }),

    'burner.list': () => ok({ burners: db.burners, offer: { price: 2500, currency: 'clean', durations: [3600, 21600, 86400], maxActive: 1, symbol: '$' } }),
    'burner.create': (a) => { const id = 100 + db.burners.length; const dur = [3600, 21600, 86400][a.duration - 1]; const handle = a.handle || ('burn-' + Math.random().toString(36).slice(2, 7)); db.burners.unshift({ id, handle, kind: 'burner', reputation: 0, active: true, revoked: false, remaining: dur }); db.wallet.clean -= 2500; return ok({ identity: id, handle }); },
    'burner.revoke': (a) => { const b = db.burners.find(x => x.id === a.identity); if (b) { b.active = false; b.revoked = true; } return ok(); },

    'mercs.state': () => ok({
      rules: { tiers: [{ id: 'solo', label: 'Tireur isolé', size: 1, price: 15000 }, { id: 'team', label: 'Équipe', size: 3, price: 40000 }, { id: 'squad', label: 'Escouade', size: 5, price: 75000 }],
        currency: 'dirty', symbol: '$', validity: 1200, deployDelay: 60, engageSeconds: 480 },
      active: db.mercs || [], cooldown: 0,
      history: [{ id: 1, targetName: 'Tony Vercetti', label: 'Équipe', size: 3, price: 40000, currency: 'dirty', status: 'failed', refund: 0, at: Date.now() / 1000 - 7200 }],
    }),
    'mercs.quote': (a) => (a.target.trim().split(/\s+/).length < 2 ? fail('not_found', 'Aucune cible localisable sous ce nom.')
      : ok({ quote: 'q1', targetName: a.target.trim(), tier: a.tier, label: a.tier === 'solo' ? 'Tireur isolé' : a.tier === 'team' ? 'Équipe' : 'Escouade', size: a.tier === 'solo' ? 1 : a.tier === 'team' ? 3 : 5, price: a.tier === 'solo' ? 15000 : a.tier === 'team' ? 40000 : 75000, currency: 'dirty', validity: 1200, deployDelay: 60, quoteExpires: 60 })),
    'mercs.order': () => { db.mercs = [{ id: 7, targetName: 'Marco Rossi', label: 'Équipe', tier: 'team', size: 3, price: 40000, currency: 'dirty', status: 'engaged', createdAt: Date.now() / 1000 - 300, deployIn: 0, expiresIn: 900, engagedAt: Date.now() / 1000 - 40, engageLeft: 440, alive: 2 }]; return ok({ contract: db.mercs[0] }); },
    'market.browse': () => ok({
      rules: { categories: [{ id: 'drugs', label: 'Stupéfiants' }, { id: 'heist', label: 'Matériel de braquage' }, { id: 'valuables', label: 'Objets de valeur' }], currencies: ['dirty', 'clean'], durations: [21600, 86400, 259200], feePercent: 10, listingFee: 0, offerHours: 24, symbol: '$' },
      listings: [
        { id: 3, item: 'thermite', label: 'Thermite', category: 'heist', categoryLabel: 'Matériel de braquage', image: '', quantity: 4, initial: 5, price: 6500, currency: 'dirty', note: 'Livraison discrète.', seller: 'corvus_07', mine: false, rep: { sales: 12, up: 9, down: 1 }, expiresIn: 51000 },
        { id: 2, item: 'cokebaggy', label: 'Pochon de cocaïne', category: 'drugs', categoryLabel: 'Stupéfiants', image: '', quantity: 40, initial: 50, price: 320, currency: 'dirty', note: null, seller: 'nyx', mine: false, rep: { sales: 3, up: 2, down: 0 }, expiresIn: 7300 },
        { id: 1, item: 'goldbar', label: 'Lingot d\'or', category: 'valuables', categoryLabel: 'Objets de valeur', image: '', quantity: 2, initial: 2, price: 18000, currency: 'clean', note: null, seller: 'Toi', mine: true, rep: null, expiresIn: 200000 },
      ],
    }),
    'market.sellable': () => ok({ alias: 'corvus_07', rules: { currencies: ['dirty', 'clean'], durations: [21600, 86400, 259200], feePercent: 10, listingFee: 0, symbol: '$' },
      items: [{ item: 'weed_pouch', label: 'Pochon de weed', category: 'drugs', count: 35, image: '' }, { item: 'lockpick', label: 'Crochet', category: 'tools', count: 3, image: '' }] }),
    'market.mine': () => ok({
      rules: { currencies: ['dirty', 'clean'], durations: [21600, 86400, 259200], feePercent: 10, listingFee: 0, symbol: '$' },
      profile: { alias: 'corvus_07', rep: { sales: 12, up: 9, down: 1 }, purchases: 4, volume: 81000, banned: false },
      pickups: [{ id: 1, label: 'Thermite', quantity: 1, reason: 'purchase', image: '', at: Date.now() / 1000 - 120 }],
      incoming: [{ id: 5, listing: 1, from: 'nyx', quantity: 1, unit: 16000, total: 16000, currency: 'clean', label: 'Lingot d\'or', image: '', listPrice: 18000, expiresIn: 70000 }],
      listings: [{ id: 1, label: 'Lingot d\'or', quantity: 2, initial: 2, price: 18000, currency: 'clean', status: 'active', expiresIn: 200000, image: '', mine: true, categoryLabel: 'Objets de valeur', seller: 'corvus_07' }],
      sent: [], history: [{ id: 9, bought: true, other: 'nyx', label: 'Thermite', quantity: 1, total: 6500, fee: 0, currency: 'dirty', canRate: true, image: '', at: Date.now() / 1000 - 3600 }],
    }),
    'contacts.list': () => ok({ contacts: [] }),
    'chat.list': () => ok({ conversations: [] }),
  };

  NX.mock = {
    call(name, args) {
      const fn = handlers[name];
      if (fn) return fn(args);
      return fail('offline', 'Aperçu : « ' + name + ' » non simulé.');
    },
  };
})();
