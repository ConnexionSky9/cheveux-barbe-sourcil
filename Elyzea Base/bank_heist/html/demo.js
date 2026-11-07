/* Aperçus hors jeu (navigateur) : index.html?demo=bank|talk|shop|menu|hack|wires|drill|hud|banner
   Ce fichier n'est pas déclaré dans fxmanifest.lua : il n'est jamais chargé en jeu. */
(() => {
  const mode = (location.search.match(/demo=([a-z]+)/) || [])[1];
  document.documentElement.style.setProperty('background', 'radial-gradient(ellipse at 30% 20%, #3a2f4a, #121018 70%)', 'important');
  document.body.style.setProperty('min-height', '100vh');
  const bank = { ok: true, bank: 'fleeca_legion', bankName: 'Fleeca · Legion Square', name: 'Lucas Moreau', account: 'FR76 ELYZ 0042 7781 93', phone: '555 0142',
    cash: 12450, balance: 284300, fee: 1, max: 500000, min: 1, transfers: true,
    history: [{ label: 'Dépôt · Fleeca · Legion Square', amount: 5000, t: 1794000000 }, { label: 'Virement à 555 0199', amount: -1200, t: 1793990000 },
      { label: 'Salaire · LSPD', amount: 3200, t: 1793900000 }, { label: 'Retrait · Fleeca · Legion Square', amount: -800, t: 1793800000 }] };
  window.MOCK = async (name, body) => {
    await new Promise((r) => setTimeout(r, 250));
    if (name === 'bank') {
      const a = body.data.amount;
      if (body.op === 'deposit') { bank.cash -= a; bank.balance += a; bank.history.unshift({ label: 'Dépôt · Fleeca · Legion Square', amount: a, t: Date.now() / 1000 }); return Object.assign({}, bank, { message: `Dépôt de ${a.toLocaleString('fr-FR')} $ effectué.` }); }
      if (body.op === 'withdraw') { if (a > bank.balance) return { error: 'Solde insuffisant.' }; bank.cash += a; bank.balance -= a; return Object.assign({}, bank, { message: 'Retrait effectué.' }); }
      return { error: 'Aucun compte à ce numéro.' };
    }
    if (name !== 'req') return {};
    const a = body.action;
    if (a === 'infoPay') return { ok: true, answer: '« Le gars que tu cherches, il traîne près des docks, derrière les conteneurs. Dis-lui que tu viens de ma part… et oublie ma tête. »', merchant: { name: 'Fournisseur', x: 1, y: 2, z: 3 }, minutes: 10 };
    if (a === 'shopBuy') return { ok: true };
    if (a === 'shopData') return shop;
    if (a === 'hackSubmit') return { done: true, success: true };
    if (a === 'alarmSubmit') return { done: true, success: true };
    return {};
  };
  const shop = { ok: true, id: 'fournisseur', name: 'Fournisseur', payment: 'Argent sale', list: [
    { id: 'laptop', item: 'bank_laptop', label: 'Ordinateur de piratage', price: 12000, description: 'Décrypte la porte du coffre (mini-jeu).', owned: 0, max: 1 },
    { id: 'c4', item: 'bank_c4', label: 'Charge C4', price: 9000, description: 'Fait sauter la porte du coffre. Bruyant.', owned: 1, max: 2 },
    { id: 'drill', item: 'bank_drill', label: 'Perceuse de coffre', price: 18000, description: 'Perce les coffres individuels.', owned: 0, max: 1 },
    { id: 'bag', item: 'bank_bag', label: 'Sac de braquage', price: 1500, description: 'Contient jusqu\'à 250 000 $.', owned: 0, max: 1 }] };
  const send = (m) => { if (m.action === 'open') m.imagePath = '../../elyzea_inventory/html/img/%s.png'; window.postMessage(m, '*'); };
  const hud = () => send({ action: 'hud', show: true, heist: { bank: 'Fleeca · Legion Square', total: 186000, mine: 94000, door: 'open', alarm: true, closeIn: 312, robbers: 3 }, bag: { money: 94000, capacity: 250000 } });
  setTimeout(() => {
    if (mode === 'bank') send({ action: 'open', panel: 'bank', data: bank });
    else if (mode === 'talk') send({ action: 'open', panel: 'talk', data: { id: 'indic_sud', name: 'Lenny « l\'Oreille »', price: 750, payment: 'Liquide', hasMerchant: true,
      greeting: '« T\'as l\'air de quelqu\'un qui cherche du matos… Moi je sais qui en vend. Mais ça a un prix. »' } });
    else if (mode === 'shop') send({ action: 'open', panel: 'shop', data: shop });
    else if (mode === 'menu') send({ action: 'open', panel: 'menu', data: { title: 'Banquier · Fleeca Legion', options: [{ id: 'bank', label: 'Accéder à mon compte', icon: 'bank' }, { id: 'rob', label: 'BRAQUER LA BANQUE', icon: 'rob', desc: 'La police sera prévenue' }] } });
    else if (mode === 'hack') send({ action: 'open', panel: 'hack', data: { game: 'circuit', label: 'Connexion de circuits', time: 45, difficulty: 2, attemptsLeft: 2, attemptsMax: 3,
      data: { nodes: [{ id: 1, x: 0, y: 0, label: 14 }, { id: 2, x: 2, y: 1, label: 3 }, { id: 3, x: 4, y: 0, label: 27 }, { id: 4, x: 1, y: 3, label: 9 }, { id: 5, x: 3, y: 2, label: 41 }, { id: 6, x: 5, y: 3, label: 18 }] } } });
    else if (mode === 'wires') send({ action: 'open', panel: 'wires', data: { time: 20, target: 'bleu', wires: [{ color: 'rouge', num: 4, led: 'verte' }, { color: 'bleu', num: 7, led: 'rouge' },
      { color: 'jaune', num: 2, led: 'éteinte' }, { color: 'bleu', num: 1, led: 'éteinte' }, { color: 'noir', num: 9, led: 'verte' }] } });
    else if (mode === 'drill') send({ action: 'open', panel: 'drill', data: { time: /hot/.test(location.search) ? 30 : 6, heatRate: 1 } });
    else if (mode === 'hud') { hud(); setInterval(() => send({ action: 'grabbed', amount: 5000 }), 1200); }
    else if (mode === 'banner') { hud(); send({ action: 'banner', title: 'BRAQUAGE EN COURS', sub: 'Fleeca · Legion Square · l\'alarme hurle, la police arrive', kind: 'danger', time: 60000 }); send({ action: 'alarm', on: true, volume: 0 }); document.getElementById('flash').classList.add('on'); }
  }, 150);
})();
