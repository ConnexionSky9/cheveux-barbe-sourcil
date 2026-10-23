'use strict';
/* =========================================================
   APPELS · VISIBILITÉ · ÉVÉNEMENTS
   ========================================================= */
async function startCall(number) {
  if (S.call) return;
  number = String(number).trim();
  S.call = { id: null, number, direction: 'out', status: 'dialing' };
  renderCall(); Sound.ringback();
  const res = await api('startCall', { number });
  if (!res.ok) { Sound.stop(); renderCall(t(res.error || 'Appel impossible')); setTimeout(endCallUI, 1800); return; }
  if (S.call) { S.call.id = res.id; S.call.status = 'ringing'; renderCall(); }
}
function renderCall(endedText) {
  const c = S.call; if (!c) return;
  const name = nameFor(c.number);
  const incoming = c.direction === 'in' && c.status === 'ringing';
  phoneEl.dataset.state = c.status === 'active' ? 'incall' : (endedText ? '' : 'ringing');
  const status = endedText ? esc(endedText)
    : c.status === 'active' ? `<span id="call-timer">${duration(Math.floor((Date.now() - c.start) / 1000))}</span>`
    : incoming ? t('Appel entrant') : c.status === 'dialing' ? t('Connexion…') : t('Ça sonne…');
  callView.innerHTML = `<div class="callscreen ${c.status !== 'active' && !endedText ? 'callscreen--ringing' : ''}">
    ${avatar(name, c.number, 'avatar--xl')}
    <h2 class="callscreen__name">${esc(name)}</h2>
    <p class="callscreen__status ${c.status === 'active' ? 'callscreen__status--live' : ''}">${status}</p>
    ${name !== c.number ? `<p class="callscreen__status">${esc(c.number)}</p>` : ''}
    ${c.status === 'active' && !endedText ? `<div class="callscreen__tools">
      ${S.locked ? '' : `<button class="tool" data-tool="msg"><span class="tool__circle">${icon('messages')}</span>${t('Message')}</button>`}
      <button class="tool" data-tool="min"><span class="tool__circle">${icon('minimize')}</span>${t('Réduire')}</button></div>` : '<div style="margin-top:auto"></div>'}
    ${endedText ? '' : `<div class="callscreen__actions">
      ${incoming ? `<button class="call-btn call-btn--end" data-end aria-label="${t('Refuser')}">${icon('phone')}</button>
        <button class="call-btn" data-accept aria-label="${t('Décrocher')}">${icon('phone')}</button>`
        : `<button class="call-btn call-btn--end" data-end aria-label="${t('Raccrocher')}">${icon('phone')}</button>`}</div>`}</div>`;
  callView.classList.add('active'); callView.setAttribute('aria-hidden', 'false');
  island.classList.remove('compact', 'music');
  if (!island.classList.contains('expanded')) $('.island__content', island).innerHTML = '';
  $('[data-end]', callView)?.addEventListener('click', hangup);
  $('[data-accept]', callView)?.addEventListener('click', async () => { Sound.stop(); await api('acceptCall', { id: c.id }); });
  $('[data-tool="msg"]', callView)?.addEventListener('click', () => { minimizeCall(); openApp('messages', { number: c.number }); });
  $('[data-tool="min"]', callView)?.addEventListener('click', minimizeCall);
}
async function hangup() {
  const c = S.call; if (!c) return;
  Sound.stop();
  if (c.id) await api('endCall', { id: c.id }); else endCallUI();
}
function minimizeCall() {
  callView.classList.remove('active'); callView.setAttribute('aria-hidden', 'true');
  showCallIsland();
}
function showCallIsland() {
  if (!S.call) return;
  island.classList.remove('music');
  island.classList.add('compact');
  const live = S.call.status === 'active';
  $('.island__content', island).innerHTML = `<span class="island__dot" style="${live ? '' : 'background:var(--ambre)'}"></span>
    <span class="island__timer" id="island-timer" style="${live ? '' : 'color:var(--ambre)'}">${live ? duration(Math.floor((Date.now() - S.call.start) / 1000)) : t('Appel')}</span>`;
  island.onclick = () => { if (S.call) { island.classList.remove('compact'); renderCall(); } };
}
function endCallUI() {
  clearInterval(S.callTimer); S.callTimer = null;
  Sound.stop();
  S.call = null;
  phoneEl.dataset.state = '';
  callView.classList.remove('active'); callView.setAttribute('aria-hidden', 'true');
  island.classList.remove('compact'); island.onclick = null;
  $('.island__content', island).innerHTML = '';
  if (Music.playing) showMusicIsland();
  if (!S.open) setVisibility();
  if (S.currentApp === 'phone') refreshCurrent();
}
function tickCall() {
  if (!S.call || S.call.status !== 'active') return;
  const v = duration(Math.floor((Date.now() - S.call.start) / 1000));
  const a = $('#call-timer'), b = $('#island-timer');
  if (a) a.textContent = v; if (b) b.textContent = v;
}

function setVisibility() {
  stage.classList.remove('hidden', 'peek', 'ghost');
  if (!S.open) {
    if (S.call && S.call.direction === 'in' && S.call.status === 'ringing') stage.classList.add('peek');
    else stage.classList.add('hidden');
  }
  updateToastOffset();
}

// ---------------------------------------------------------
//  Messages du client Lua
// ---------------------------------------------------------
const handlers = {
  // Interface préparée en arrière-plan dès la connexion (téléphone fermé)
  init({ profile, time }) {
    if (S.open) return;
    if (S.profile && S.profile.number !== profile.number) {
      for (const k in Accounts) delete Accounts[k];
      Dating.me = undefined; Dating.deck = [];
      Music.stop(); S.stack = []; S.currentApp = null;
      screenEl.classList.remove('in-app'); appView.classList.remove('active');
    }
    S.profile = profile;
    S.settings = Object.assign({}, profile.settings);
    S.gameTime = time || null;
    applySettings();
    loadContacts();
    if (!S.settings.setup) return;
    if (hasSecurity()) { S.locked = true; showLock(); }
    else { S.locked = false; renderHome(); }
  },
  open({ profile, time }) {
    endPeek();
    if (S.profile && S.profile.number !== profile.number) {
      for (const k in Accounts) delete Accounts[k];
      Dating.me = undefined; Dating.deck = [];
      Music.stop(); S.locked = true; S.stack = []; S.currentApp = null;
    }
    S.profile = profile;
    S.settings = Object.assign({}, profile.settings);
    S.gameTime = time || null;
    S.open = true;
    applySettings(); setVisibility();
    loadContacts().then(() => { if (S.currentApp && !S.locked) refreshCurrent(); });
    api('getConversations').then(r => {
      S.unread = (r.conversations || []).reduce((a, c) => a + c.unread, 0);
      if (!S.currentApp && !S.locked && !screenEl.classList.contains('in-setup')) renderHome();
    });

    if (!S.settings.setup) {
      if (!screenEl.classList.contains('in-setup')) startSetup();
    } else if (hasSecurity() && S.locked) {
      showLock();
    } else {
      S.locked = false;
      screenEl.classList.remove('locked');
      lockView.classList.remove('active');
      if (S.currentApp) refreshCurrent(); else renderHome();
      if (S.pendingDrops.length) setTimeout(() => showDropPrompt(S.pendingDrops[0]), 500);
    }
    if (S.call && S.call.direction === 'in' && S.call.status === 'ringing') renderCall();
  },
  looking({ state }) { document.body.classList.toggle('looking', !!state); },
  close() {
    typingState = false;
    document.activeElement?.blur?.();
    leaveApp();
    if (S.currentApp === 'camera') { S.stack.pop(); S.currentApp = S.stack[S.stack.length - 1]?.id || null; if (!S.currentApp) { screenEl.classList.remove('in-app'); appView.classList.remove('active'); } }
    S.open = false; closeSheet(true);
    $('.passcode', screenEl)?.remove();
    if (hasSecurity() && S.settings.lockOnClose !== false && S.settings.setup) {
      showLock(); // l'écran de verrouillage est affiché (et non un écran vide)
    }
    setVisibility();
  },
  hide() { stage.classList.add('ghost'); },
  show() { stage.classList.remove('ghost'); },
  time(tm) { S.gameTime = tm && tm.h !== undefined ? tm : null; updateClock(); },
  toast(d) { notify(d); },
  bank({ balance }) {
    if (!S.profile || balance === undefined) return;
    S.profile.bank = balance;
    const w = $('#widget-balance'); if (w) w.textContent = money(balance);
    const b = $('#bank-balance'); if (b) b.textContent = money(balance);
  },
  newMessage(d) {
    if (S.open && !S.locked && S.currentApp === 'messages' && S.thread === d.from) {
      appendBubble({ mine: false, message: d.message, ts: d.ts });
      api('getMessages', { number: d.from });
      Sound.ping(); return;
    }
    S.unread++;
    if (!S.currentApp && !S.locked && S.open) renderHome();
    Sound.ping();
    notify({ app: 'messages', title: nameFor(d.from), text: GEO.test(d.message) ? t('Position partagée') : CARD.test(d.message) ? t('Fiche contact') : d.message });
    if (S.open && S.currentApp === 'messages' && !S.thread) Views.messages();
  },
  incomingCall(d) {
    if (S.call) return;
    S.call = { id: d.id, number: d.number, direction: 'in', status: 'ringing' };
    Sound.ring(S.settings.ringtone);
    renderCall(); setVisibility();
    $('#peek-hint').innerHTML = t('Appuyez sur {key} pour décrocher', { key: '<kbd>F1</kbd>' });
  },
  callStarted() {
    if (!S.call) return;
    Sound.stop();
    S.call.status = 'active'; S.call.start = Date.now();
    clearInterval(S.callTimer); S.callTimer = setInterval(tickCall, 1000);
    if (callView.classList.contains('active') || S.open) renderCall(); else showCallIsland();
    setVisibility();
  },
  callEnded(d) {
    if (!S.call) return;
    Sound.stop();
    const txt = { declined: t('Appel refusé'), timeout: t('Pas de réponse'), dropped: t('Appel interrompu') }[d.reason] || t('Appel terminé');
    clearInterval(S.callTimer);
    if (S.open) { renderCall(txt); setTimeout(endCallUI, 1300); } else endCallUI();
  },
  delivery(d) { onDeliveryUpdate(d); },
  mechanic(d) { onMechanicUpdate(d); },
  valet(d) { onValetUpdate(d); },
  carplayOpen(d) { cpOpen(d); },
  carplayClose() { cpClose(); },
  carplayIntroEnd() { cpIntroEnd(); },
  carplayLive(d) { cpLive(d); },
  carMusic(d) { CarAudio.handle(d); },
  remoteMusic(d) { RemoteMusic.handle(d); },
  remoteVolumes(d) { RemoteMusic.volumes(d); },
  datingMessage(d) {
    const cur = S.stack[S.stack.length - 1];
    if (S.open && S.currentApp === 'etincelle' && cur?.params?.tab === 'chat' && Dating.chat === d.matchId) {
      appendBubble({ mine: false, message: d.message, ts: d.ts }); Sound.ping();
    }
  },
  auraDrop(d) {
    S.pendingDrops.push(d);
    if (S.open && !S.locked) showDropPrompt(d);
    else toast({ app: 'auradrop', title: 'AuraDrop', text: t('{device} veut partager une fiche contact', { device: d.device }) });
  },
};
function showMoveTip() {
  if (S.settings.moveWithPhone === false || !S.settings.setup) return;
  let seen = false;
  try { seen = localStorage.getItem('elyzea_tip_move') === '1'; localStorage.setItem('elyzea_tip_move', '1'); } catch (e) { seen = true; }
  if (!seen) setTimeout(() => notify({ app: 'settings', title: t('Bougez librement'), text: t('Clic droit maintenu pour regarder autour') }), 900);
}
window.addEventListener('message', (e) => { const { action, data } = e.data || {}; handlers[action]?.(data || {}); });

document.addEventListener('click', (e) => {
  const open = e.target.closest('[data-open]');
  if (open) { if (S.dragged) return; openApp(open.dataset.open); return; }
  const b = e.target.closest('[data-back]');
  if (b && !b.onclick) back();
});
$('#home-bar').addEventListener('click', goHome);
// Saisie : on prévient le jeu pour que les touches ne fassent pas bouger le personnage
const TYPING_SEL = 'input:not([type=range]):not([type=color]):not([type=checkbox]), textarea';
let typingState = false;
function setTyping(v) { if (v === typingState) return; typingState = v; post('typing', { state: v }); }
document.addEventListener('focusin', (e) => { if (e.target.matches?.(TYPING_SEL)) setTyping(true); });
document.addEventListener('focusout', () => setTimeout(() => { if (!document.activeElement?.matches?.(TYPING_SEL)) setTyping(false); }, 0));
// Clic sur le téléphone hors d'un champ : on quitte la saisie pour pouvoir bouger
document.addEventListener('pointerdown', (e) => {
  if (!e.target.closest(TYPING_SEL) && document.activeElement?.matches?.(TYPING_SEL)) document.activeElement.blur();
});
document.addEventListener('contextmenu', (e) => e.preventDefault());

document.addEventListener('keydown', (e) => {
  if (e.key !== 'Escape') return;
  if (CP.open) { post('carplayClose'); if (IS_BROWSER) cpClose(); return; }
  if (closeSheet()) return;
  post('close');
  if (IS_BROWSER) handlers.close();
});

// ---------------------------------------------------------
//  Mode aperçu navigateur (hors FiveM)
// ---------------------------------------------------------
const Mock = {
  accounts: {}, code: null,
  contacts: [{ id: 1, name: 'Inès Morel', number: '555-2841', favorite: 1 }, { id: 2, name: 'Malik Benali', number: '555-9013', favorite: 0 }, { id: 3, name: 'Garage Benny', number: '555-4400', favorite: 0 }],
  gallery: [], dating: null, order: null, job: null, deck: [
    { id: 11, name: 'Inès', age: 24, gender: 'woman', bio: 'Pilote amatrice, fan de couchers de soleil à Del Perro.', photos: ['https://picsum.photos/seed/ines/600/900'], tags: ['Voitures', 'Plage'] },
    { id: 12, name: 'Malik', age: 29, gender: 'man', bio: 'Cuisinier le jour, DJ la nuit.', photos: ['https://picsum.photos/seed/malik/600/900'], tags: ['Musique', 'Cuisine'], superMe: true },
  ],
  mechVehicles() { return { ok: true, maxDistance: 300, vehicles: [
    { netId: 1, name: 'Sultan RS', plate: 'ELY042', engine: 62, body: 48, clean: 30, upside: false, distance: 4 },
    { netId: 2, name: 'Kuruma', plate: 'LENA77', engine: 100, body: 92, clean: 80, upside: true, distance: 180, x: 10, y: 20 },
    { netId: 3, name: 'Bati 801', plate: 'MOTO01', engine: 90, body: 90, clean: 90, upside: false, distance: 1840, x: 10, y: 20 }] }; },
  garageList() { return { ok: true, price: 250, pay: ['bank', 'cash'], cash: true, active: this.valet || null, vehicles: [
    { plate: 'ELY042', model: 'sultan', name: 'Sultan RS', state: 'garage', garage: 'Garage de Pillbox Hill', fuel: 82, engine: 100, body: 97 },
    { plate: 'LENA77', model: 'kuruma', name: 'Kuruma', state: 'out', inWorld: true, distance: 640, x: 1, y: 2, fuel: 40, engine: 74, body: 61 },
    { plate: 'MOTO01', model: 'bati', name: 'Bati 801', state: 'impound', garage: '', fuel: 15, engine: 50, body: 30 }] }; },
  garageOrder(v) { this.valet = { id: 1, plate: v.plate, model: v.model, label: v.name, price: 250, status: 'enroute', readyIn: 0 }; return { ok: true, order: this.valet }; },
  car: { locked: false, neon: true, neonColor: [111, 231, 242], doors: [false, true, false, false, false, false], validDoors: [true, true, true, true, true, true], windows: [true, false, false, false], speed: 87, fuel: 64, engine: 92,
    music: { url: 'x', title: 'Nuit sur Vinewood', artist: 'Los Santos Lofi', thumb: '', volume: .6, paused: false }, engine: false, lights: false },
  carAction(action, value) {
    const c = this.car;
    if (action === 'lock') c.locked = value; if (action === 'neon') c.neon = value; if (action === 'neonColor') { c.neonColor = value; c.neon = true; }
    if (action === 'door') c.doors[value.index] = value.open; if (action === 'doorsAll') c.doors = c.doors.map(() => value);
    if (action === 'window') c.windows[value.index] = value.down; if (action === 'windowsAll') c.windows = c.windows.map(() => value);
    if (action === 'musicStop') c.music = null; if (action === 'musicPause' && c.music) c.music.paused = true; if (action === 'musicResume' && c.music) c.music.paused = false;
    if (action === 'music') c.music = { url: value, title: 'Lien ajouté', artist: 'YouTube', volume: .6 };
    if (action === 'engine') c.engine = value; if (action === 'lights') c.lights = value;
    return { ok: true, state: JSON.parse(JSON.stringify(c)) };
  },
  fleet() { return { ok: true, summonDistance: 350, vehicles: [
    { netId: 1, name: 'Sultan RS', plate: 'ELY042', distance: 35, locked: true, engine: false, neon: true, lights: false, doorsOpen: 0, music: 'Nuit sur Vinewood' },
    { netId: 2, name: 'Kuruma', plate: 'LENA77', distance: 640, locked: false, engine: true, neon: false, lights: true, doorsOpen: 2 },
    { netId: 3, name: 'Bati 801', plate: 'MOTO01', distance: 2300, locked: true, engine: false, neon: false, lights: false, doorsOpen: 0, occupied: true }] }; },
  carState() { return { ok: true, state: JSON.parse(JSON.stringify(this.car)), colors: [[124, 108, 255], [111, 231, 242], [255, 111, 158], [255, 181, 71], [79, 224, 176], [255, 255, 255]], x: 1, y: 2, distance: 40 }; },
  saveMedia(kind, url, secs) { this.gallery.unshift({ id: Date.now(), url, type: kind, duration: secs, ts: Math.floor(Date.now() / 1000) }); return { ok: true }; },
  handle(endpoint, d) {
    const n = Math.floor(Date.now() / 1000);
    if (endpoint === 'carplayAction') return this.carAction(d.action, d.value);
    if (endpoint === 'getLocation') return { x: 215.4, y: -810.2, street: 'Vespucci Boulevard', zone: 'Pillbox Hill' };
    if (endpoint !== 'request') return { ok: true };
    const a = d.args || {};
    if (d.name === 'createAccount') { this.accounts[a.app] = { username: a.username || 'lena', display_name: a.display || 'Lena Duval' }; return { ok: true, account: this.accounts[a.app] }; }
    if (d.name === 'setPasscode') { this.code = a.code; return { ok: true, length: a.code.length }; }
    if (d.name === 'unlock') return { ok: !this.code || a.code === this.code };
    if (d.name === 'removePasscode') { const ok = a.code === this.code; if (ok) this.code = null; return { ok, error: ok ? null : 'Code actuel incorrect' }; }
    if (d.name === 'saveSettings') return { ok: true, settings: a.settings };
    if (d.name === 'mechanicInfo') return { ok: true, pay: ['bank', 'cash'], cash: true, blocked: false, active: this.job, services: [
      { id: 'clean', label: 'Nettoyage', price: 150, duration: 10, desc: 'Lavage complet de la carrosserie et des vitres.' },
      { id: 'repair', label: 'Réparation', price: 850, duration: 16, desc: 'Moteur, carrosserie, pneus et réservoir remis à neuf.' },
      { id: 'flip', label: 'Remise sur roues', price: 300, duration: 8, desc: 'Le véhicule retourné est remis sur ses roues.' },
      { id: 'full', label: 'Formule complète', price: 1100, duration: 24, desc: 'Remise sur roues, réparation et nettoyage en une seule visite.' }] };
    if (d.name === 'mechanicOrder') { this.job = { id: 1, service: a.service, label: 'Formule complète', price: 1100, garage: 'Benny\'s Original Motor Works', vehicle: a.vehicle, plate: a.plate, status: 'pending', readyIn: 3 }; return { ok: true, job: this.job }; }
    if (d.name === 'deliveryCatalog') return { ok: true, fee: 25, pay: ['bank', 'cash'], cash: true, imagePath: '', maxItems: 20, maxPerItem: 10, active: this.order, categories: [
      { id: 'meals', label: 'Repas', items: [{ name: 'burger', label: 'Burger maison', price: 22 }, { name: 'sandwich', label: 'Sandwich club', price: 16 }, { name: 'tosti', label: 'Croque-monsieur', price: 14 }, { name: 'pizza', label: 'Pizza margherita', price: 28 }] },
      { id: 'drinks', label: 'Boissons', items: [{ name: 'water_bottle', label: 'Eau minérale', price: 5 }, { name: 'kurkakola', label: 'Kurkakola', price: 7 }, { name: 'coffee', label: 'Café', price: 8 }] },
      { id: 'alcohol', label: 'Alcool', items: [{ name: 'beer', label: 'Bière', price: 12 }, { name: 'whiskey', label: 'Whisky', price: 45 }] }] };
    if (d.name === 'deliveryOrder') {
      const items = a.cart.map(l => ({ name: l.name, label: l.name, qty: l.qty }));
      this.order = { id: 1, items, total: 99, shop: 'Pizza This, Little Seoul', status: 'preparing', readyIn: 3 };
      return { ok: true, order: this.order };
    }
    if (d.name === 'deliveryCancel') { this.order = null; return { ok: true, refund: 99 }; }
    if (d.name === 'datingSaveProfile') { this.dating = Object.assign({ id: 1, active: true }, a); return { ok: true }; }
    if (d.name === 'datingSwipe') return a.id === 12 && a.like ? { ok: true, match: { id: 5, profile: this.deck[1] } } : { ok: true };
    if (d.name === 'addTrack') return { ok: true, track: { id: 99, title: 'Lien ajouté', artist: 'YouTube', url: a.link, source: 'youtube', thumb: 'https://picsum.photos/seed/yt/300/300' } };
    const table = {
      getContacts: { ok: true, contacts: this.contacts },
      getConversations: { ok: true, conversations: [{ number: '555-2841', last: 'On se retrouve au Bahama Mamas ?', ts: n - 120, unread: 2 }, { number: '555-7730', last: 'Merci pour la voiture', ts: n - 7200, unread: 0 }] },
      getMessages: { ok: true, messages: [{ id: 1, mine: false, message: 'Tu es où ?', ts: n - 400 }, { id: 2, mine: true, message: 'Près de Legion Square, j\'arrive', ts: n - 380 }, { id: 3, mine: false, message: '%%GPS:215.4,-810.2|Vespucci Boulevard, Pillbox Hill', ts: n - 130 }, { id: 4, mine: false, message: '%%CARD:Malik Benali|555-9013', ts: n - 125 }, { id: 5, mine: false, message: 'On se retrouve au Bahama Mamas ?', ts: n - 120 }] },
      getCalls: { ok: true, calls: [{ id: 1, number: '555-9013', outgoing: false, status: 'missed', duration: 0, ts: n - 600 }, { id: 2, number: '555-2841', outgoing: true, status: 'answered', duration: 184, ts: n - 5000 }] },
      getBank: { ok: true, balance: 48250, pending: 1, history: [{ label: '555-2841 (Loyer)', amount: 1200, ts: n - 3000 }, { label: '555-4400', amount: -450, ts: n - 90000 }, { label: '555-9013', amount: 2600, ts: n - 190000 }, { label: '555-7730', amount: -980, ts: n - 290000 }, { label: '555-2841', amount: 640, ts: n - 390000 }] },
      getBalance: { ok: true, balance: 48250 },
      getRequests: { ok: true, requests: [{ id: 1, from_number: '555-9013', to_number: '555-0142', amount: 150, reason: 'Essence', status: 'pending', ts: n - 900, incoming: true }] },
      getNearby: { ok: true, devices: [{ id: 4, device: 'Aura Inès', distance: 2.4 }, { id: 7, device: 'Aura Malik', distance: 4.9 }] },
      getNotes: { ok: true, notes: [{ id: 1, title: 'Liste du week-end', content: 'Essence, paintball, réserver la table.', ts: n - 5000 }] },
      getGallery: { ok: true, photos: this.gallery },
      datingGetProfile: { ok: true, profile: this.dating },
      datingDiscover: { ok: true, profiles: this.deck.slice() },
      datingMatches: { ok: true, matches: [{ match_id: 5, name: 'Malik', age: 29, photo: 'https://picsum.photos/seed/malik/600/900', last: null, ts: n - 100 }] },
      datingMessages: { ok: true, messages: [], profile: this.deck[1] },
      getAccount: { ok: true, account: this.accounts[a.app] || null },
      getFeed: { ok: true, posts: a.app === 'birdy' ? [{ id: 3, content: 'Embouteillage sur la Great Ocean, évitez le secteur. @malik tu étais coincé aussi ?', ts: n - 300, username: 'ines.m', display_name: 'Inès Morel', mine: false, likes: 8, liked: true, reposts: 2, comments: 3 }] : [] },
      getTracks: { ok: true, tracks: [{ id: 1, title: 'Nuit sur Vinewood', artist: 'Los Santos Lofi', url: 'https://www.youtube.com/watch?v=x', source: 'youtube', thumb: 'https://picsum.photos/seed/lofi/300/300' }, { id: 2, title: 'Del Perro Drive', artist: 'Harbor Kids', url: 'https://example.com/b.mp3', source: 'direct' }] },
      getAds: { ok: true, ads: [{ id: 1, author_name: 'Garage Benny', number: '555-4400', title: 'Révision complète', content: 'Vidange, freins, pneus. Rendez-vous sous 24 h.', price: 450, ts: n - 3000, mine: false }] },
      getComments: { ok: true, comments: [] },
    };
    return table[d.name] || { ok: true };
  }
};
if (IS_BROWSER) {
  document.body.style.background = '#5b6170 linear-gradient(160deg,#7a8296,#3e4352)';
  handlers.open({ profile: {
    number: '555-0142', name: 'Lena Duval', bank: 48250, bankEnabled: true, auraDrop: true, cameraEnabled: true,
    camera: { method: 'server', maxVideo: 20, bitrate: 1500000 }, itoune: { spotify: true, distance: 12, maxVolume: .6 }, dating: { minAge: 18, maxPhotos: 4 },
    passcode: { set: false },
    settings: { setup: false, lang: 'fr', theme: 'dark', wallpaper: 'halo', accent: 'plasma', iconStyle: 'prisme', clockStyle: 'stack', frame: 'titane', edgeLight: true, faceid: false, lockOnClose: true, showBankWidget: true, auraDrop: true, deviceName: '', cardName: '', ringtone: 'cristal', silent: true, airplane: false, notifications: true, zoom: 100, installed: [] },
    services: [{ id: 'police', label: 'Police', color: '#9C8CFF', icon: 'shield' }, { id: 'ambulance', label: 'Secours', color: '#FF8FA3', icon: 'cross' }, { id: 'mechanic', label: 'Dépannage', color: '#F5C77E', icon: 'wrench' }, { id: 'taxi', label: 'Taxi', color: '#7ED6C1', icon: 'car' }],
    places: [{ id: 1, label: 'Commissariat de Mission Row' }, { id: 2, label: 'Hôpital Pillbox Hill' }]
  } });
  window.__elyzea = { handlers, openApp, S, Music, Dating, Mock, renderWizard, W, showLock, goHome, applySettings, saveSettings };
}
