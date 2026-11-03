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
    elyMigrate();
    loadContacts().then(() => { if (S.currentApp && !S.locked) refreshCurrent(); });
    if (typeof svcLoadNames === 'function') svcLoadNames();   // noms des entreprises (numéros publics)
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
  idCard(d) { idtOnCard(d); },
  elypick(d) { epPush(d); },
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
  susp: { car: false, moto: true, truck: false, ppa: false },
  idDocs() {
    const base = { firstname: 'Léna', lastname: 'Duval', birthdate: '1998-04-12', gender: 1, nationality: 'Elyzéenne', citizenid: 'ABC12345' };
    return {
      id: { type: 'id', data: Object.assign({ number: 'ID-482913', issued: '02/11/2026' }, base) },
      licence: { type: 'licence', data: Object.assign({ number: 'EL-104223', categories: [{ key: 'car', short: 'B', label: 'Voiture', date: '03/10/2026', suspended: this.susp.car }, { key: 'moto', short: 'A', label: 'Moto', date: '05/10/2026', suspended: this.susp.moto }] }, base) },
      ppa: { type: 'ppa', sub: 'civil', suspended: this.susp.ppa, data: Object.assign({ number: 'PPA-551204', issued: '01/11/2026', expires: '30/01/2027', expiresAt: Math.floor(Date.now() / 1000) + 9e6, doctor: 'Dr Morel', categories: ['Pistolet'] }, base) },
    };
  },
  // Appli LaserGame (aperçu navigateur)
  lg(action, a, n) {
    const L = this.lgData = this.lgData || {
      posts: [
        { id: 1, kind: 'match', mode: 'pvp', map: 'pvp_medium', mapLabel: 'NEON PARKING', format: '2v2', formatLabel: '2 VS 2', stake: 2500, slots: 3, startsAt: 0, when: 'Dès que possible', message: 'Équipe de 2 cherche adversaires sérieux', author: 'Malik Benali', authorToken: 'tokmalik', created: n - 420, count: 1, players: ['Inès Morel'], joined: false, mine: false, canCancel: false, full: false },
        { id: 2, kind: 'match', mode: 'pvp', map: '', mapLabel: 'Carte au choix', format: '1v1', formatLabel: '1 VS 1', stake: 0, slots: 1, startsAt: n + 3600, when: "aujourd'hui à 21:30", message: '', author: 'Lena Duval', authorToken: 'tokme', created: n - 60, count: 0, players: [], joined: false, mine: true, canCancel: true, full: false },
        { id: 3, kind: 'event', mode: 'zombie', map: 'zombie_map', mapLabel: 'COMPLEXE ELYZEA-7', format: '', stake: 0, slots: 3, startsAt: n + 1500, when: "aujourd'hui à 21:30", message: 'Soirée survie : objectif manche 20 !', author: 'Inès Morel', authorToken: 'tokines', created: n - 3000, count: 2, players: ['Malik Benali', 'Tom Garcia'], joined: true, mine: false, canCancel: false, full: false },
        { id: 4, kind: 'event', mode: 'pvp', map: 'pvp_large', mapLabel: 'BLACKSITE', format: '4v4', formatLabel: '4 VS 4', stake: 0, slots: 7, startsAt: n + 86400 + 1800, when: 'demain à 22:00', message: 'Tournoi du vendredi', author: 'Tom Garcia', authorToken: 'toktom', created: n - 8000, count: 5, players: ['A. Roy', 'K. Diaz', 'S. Lin', 'P. Nowak', 'J. Petit'], joined: false, mine: false, canCancel: false, full: false },
      ],
      msgs: { tokmalik: [{ id: 1, mine: false, body: 'Partant pour un 2v2 ce soir ?', at: n - 900, post: 1 }, { id: 2, mine: true, body: 'Carrément, on se retrouve au LaserGame dans 10 min', at: n - 600 }] },
    };
    const names = { tokmalik: 'Malik Benali', tokines: 'Inès Morel', toktom: 'Tom Garcia' };
    const ranks = [['bronze', 'ELYZEA BRONZE', 0, '#C98A55'], ['silver', 'ELYZEA SILVER', 1100, '#C9D3E0'], ['gold', 'ELYZEA GOLD', 1250, '#FFC94A'], ['platinum', 'ELYZEA PLATINUM', 1400, '#7FE3D8'], ['diamond', 'ELYZEA DIAMOND', 1550, '#6FB6FF'], ['master', 'ELYZEA MASTER', 1700, '#B57BFF'], ['grandmaster', 'ELYZEA GRANDMASTER', 1850, '#FF4D8D'], ['legend', 'ELYZEA LEGEND', 2000, '#FFE7A3']].map(([id, label, min, color]) => ({ id, label, min, color }));
    if (action === 'home') return { ok: true, me: { name: 'Lena Duval', token: 'tokme' }, ranks, unread: 1, pvp: true, zombie: true, excluded: false,
      profile: { firstname: 'Lena', lastname: 'Duval', points: 1488, peak: 1532, rank: 'platinum', rankLabel: 'ELYZEA PLATINUM', progress: .59, next: { id: 'diamond', label: 'ELYZEA DIAMOND', min: 1550 }, position: 7,
        wins: 42, losses: 19, draws: 2, kills: 611, deaths: 402, matches: 63, ratio: 1.52, streak: 3, bestStreak: 9, zbBestRound: 17, zbBestSolo: 11, zbKills: 1840, zbGames: 24 },
      formats: [1, 2, 3, 4, 5, 6].map(k => ({ id: `${k}v${k}`, label: `${k} VS ${k}`, size: k })),
      maps: [['pvp_small', 'ELYSIUM COMBAT', 'pvp'], ['pvp_medium', 'NEON PARKING', 'pvp'], ['pvp_large', 'BLACKSITE', 'pvp'], ['pvp_xlarge', 'LAST STAND', 'pvp'], ['zombie_map', 'COMPLEXE ELYZEA-7', 'zombie']].map(([id, label, mode]) => ({ id, label, mode })),
      stake: { enabled: true, min: 0, max: 250000, step: 100 }, limits: { text: 160, message: 300, maxDays: 7, maxOpen: 3 },
      history: [{ mode: 'pvp', format: '3v3', result: 'win', points_delta: 22, map: 'pvp_medium', mapLabel: 'NEON PARKING', score_a: 2, score_b: 1, created_at: n - 3600 },
        { mode: 'zombie', round: 14, kills: 96, mapLabel: 'COMPLEXE ELYZEA-7', created_at: n - 9000 }, { mode: 'pvp', format: '1v1', result: 'loss', points_delta: -17, mapLabel: 'ELYSIUM COMBAT', score_a: 0, score_b: 2, created_at: n - 86000 }] };
    if (action === 'board') {
      const zb = a.kind.startsWith('zb'), team = a.kind === 'zb_teams';
      const people = ['Kenji Sato', 'Lena Duval', 'Malik Benali', 'Inès Morel', 'Tom Garcia', 'Sara Lind', 'Hugo Petit', 'Nora Diaz', 'Yanis Roy', 'Emma Nowak'];
      return { ok: true, kind: a.kind, page: 1, pages: 3, total: 27, rows: people.map((p, i) => team ? { pos: i + 1, names: `${p}, ${people[(i + 1) % 10]}`, v: 24 - i * 2, kills: 300 - i * 20, players: 2 + (i % 3) }
        : zb ? { pos: i + 1, firstname: p.split(' ')[0], lastname: p.split(' ')[1], v: a.kind === 'zb_kills' ? 2400 - i * 180 : 22 - i * 2, zb_kills: 2400 - i * 180, zb_games: 40 - i * 3 }
        : { pos: i + 1, firstname: p.split(' ')[0], lastname: p.split(' ')[1], v: a.kind === 'pvp_ratio' ? 2.4 - i * .15 : 2050 - i * 70, points: 2050 - i * 70, wins: 80 - i * 6, losses: 20 + i, rank: ranks[Math.max(0, 7 - Math.floor(i / 1.4))].id }) };
    }
    if (action === 'posts') return { ok: true, kind: a.kind, posts: L.posts.filter(p => p.kind === a.kind), now: n };
    if (action === 'create') { L.posts.unshift({ id: Date.now(), kind: a.kind, mode: a.mode, map: a.map, mapLabel: a.map || 'Carte au choix', format: a.format, formatLabel: a.format, stake: a.stake, slots: 3, startsAt: a.startsAt, when: a.startsAt ? 'aujourd\'hui' : 'Dès que possible', message: a.message, author: 'Lena Duval', authorToken: 'tokme', created: n, count: 0, players: [], joined: false, mine: true, canCancel: true, full: false }); return { ok: true, message: 'Publié.' }; }
    if (action === 'join') { const p = L.posts.find(x => x.id === a.id); if (p && !p.mine && !p.joined) { p.joined = true; p.count++; p.players.push('Lena Duval'); } return { ok: true, gps: { x: -1256.6, y: -1440.8, label: 'LaserGame ElyzeaFA' }, message: 'Point GPS posé : LaserGame ElyzeaFA.' }; }
    if (action === 'leave') { const p = L.posts.find(x => x.id === a.id); if (p) { p.joined = false; p.count--; p.players.pop(); } return { ok: true, message: 'Tu n\'es plus inscrit.' }; }
    if (action === 'cancel') { L.posts = L.posts.filter(x => x.id !== a.id); return { ok: true, message: 'Annonce retirée.' }; }
    if (action === 'gps') return { ok: true, gps: { x: -1256.6, y: -1440.8, label: 'LaserGame ElyzeaFA' }, message: 'Point GPS posé : LaserGame ElyzeaFA.' };
    if (action === 'threads') return { ok: true, unread: 0, threads: Object.entries(L.msgs).map(([tok, m]) => ({ token: tok, name: names[tok], last: m[m.length - 1].body, at: m[m.length - 1].at, mine: m[m.length - 1].mine, unread: 0 })) };
    if (action === 'thread') return { ok: true, token: a.token, name: names[a.token] || '?', messages: L.msgs[a.token] || [], unread: 0 };
    if (action === 'send') { const tok = a.token; (L.msgs[tok] = L.msgs[tok] || []).push({ id: Date.now(), mine: true, body: a.body, at: Math.floor(Date.now() / 1000), post: a.post }); return { ok: true, token: tok, name: names[tok] }; }
    return { ok: false };
  },
  handle(endpoint, d) {
    const n = Math.floor(Date.now() / 1000);
    if (endpoint === 'carplayAction') return this.carAction(d.action, d.value);
    if (endpoint === 'getLocation') return { x: 215.4, y: -810.2, street: 'Vespucci Boulevard', zone: 'Pillbox Hill' };
    if (endpoint === 'idPhoto') return { url: null };
    if (endpoint !== 'request') return { ok: true };
    const a = d.args || {};
    // Identité (aperçu)
    if (d.name === 'idDocs') return { ok: true, police: true, docs: this.idDocs() };
    if (d.name === 'idNearby') return { ok: true, devices: [{ id: 4, device: 'Aura Inès', distance: 1.8 }] };
    if (d.name === 'idShow') return { ok: true, device: 'Aura Inès' };
    if (d.name === 'idSaveOwn') { this.gallery.unshift({ id: Date.now(), type: 'card', card: this.idDocs()[a.kind], ts: n }); return { ok: true }; }
    if (d.name === 'idSave') return { ok: true };
    if (d.name === 'idSuspend') {
      if (a.what === 'ppa') this.susp.ppa = a.on; else if (a.what === 'licence') ['car', 'moto'].forEach(k => this.susp[k] = a.on); else this.susp[a.what] = a.on;
      return { ok: true, doc: this.idDocs()[a.what === 'ppa' ? 'ppa' : 'licence'] };
    }
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
    if (d.name === 'grossesseSuivi') return { ok: true, statut: 'en_cours', grossesse: { trimestre: 2, terme: false, etape: 'Léger arrondi', pct: 0.42,
      ecouleTexte: '5 j 21 h', joursEcoules: 5, joursTotal: 14, totalTexte: '14 j', avantTrimestreTexte: '3 j 11 h', avantTermeTexte: '8 j 3 h', joursAvantTerme: 9,
      debutTexte: '12/10/2026 18:40', bebes: 0 }, historique: [
      { kind: 'decouverte', titre: 'Grossesse découverte', description: 'Découverte grâce à un test de grossesse.', date: '13/10/2026 09:12' },
      { kind: 't2', titre: 'Deuxième trimestre', description: 'Entrée dans le deuxième trimestre.', date: '17/10/2026 10:40' }] };
    if (d.name === 'servicesList') return { ok: true, list: [
      { unit: 'elyzea_ems', label: 'SAMS', jobLabel: 'SAMS', color: '#ef4444', number: '912-0001', open: true, onDuty: 3 },
      { unit: 'elyzea_police', label: 'LSPD', jobLabel: 'LSPD', color: '#3b82f6', number: '911-0001', open: true, onDuty: 5 },
      { unit: 'elyzea_restaurant:1', label: 'Pizza This', jobLabel: 'Restaurant', color: '#ef4444', number: '918-0001', open: true, onDuty: 2 },
      { unit: 'elyzea_restaurant:2', label: 'Taco Libre', jobLabel: 'Restaurant', color: '#f59e0b', number: '918-0002', open: false, onDuty: 0 },
      { unit: 'elyzea_club:1', label: 'Bahama Mamas', jobLabel: 'Boîte de nuit', color: '#d946ef', number: '917-0001', open: false, onDuty: 1 }] };
    if (d.name === 'santeHome') {
      const gro = this.handle('request', { name: 'grossesseSuivi', args: {} });
      this.rdv = this.rdv || [{ id: 2, type: 'blood', typeLabel: 'Prise de sang', status: 'accepted', ems: 'Lucas Martin', created: n - 3600, accepted: n - 1800, reason: 'Bilan annuel' },
        { id: 1, type: 'medical', typeLabel: 'Consultation médicale', status: 'expired', created: n - 90000 }];
      return { ok: true, grossesse: gro,
        rdv: { ok: true, enabled: true, maxOpen: 2, expireMinutes: 120, list: this.rdv, types: [{ id: 'medical', label: 'Consultation médicale', icon: '🩺' },
          { id: 'psy', label: 'Consultation psychiatrique', icon: '🧠' }, { id: 'blood', label: 'Prise de sang', icon: '🩸' }, { id: 'pregnancy', label: 'Suivi de grossesse', icon: '🤰' }] },
        health: { ok: true, now: n, current: [{ kind: 'cold', label: 'Rhume', type: 'illness', cure: 'treat', since: n - 1200, expires: n + 2400 },
          { kind: 'leg', label: 'Blessure à la jambe', type: 'injury', cure: 'splint', since: n - 600 }], past: [{ label: 'Chlamydia', since: n - 400000, cured: n - 300000, curedBy: 'Lucas Martin' }] } };
    }
    if (d.name === 'lgCall') return this.lg(a.action, a.data || {}, n);
    if (d.name === 'santeRdvCreate') { this.rdv.unshift({ id: Date.now(), type: a.type, typeLabel: { medical: 'Consultation médicale', psy: 'Consultation psychiatrique', blood: 'Prise de sang', pregnancy: 'Suivi de grossesse' }[a.type], status: 'pending', created: n, reason: a.reason }); return { ok: true, message: 'Demande envoyée.' }; }
    if (d.name === 'santeRdvCancel') { const x = this.rdv.find(r => r.id === a.id); if (x) x.status = 'cancelled'; return { ok: true, message: 'Rendez-vous annulé.' }; }
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
    settings: { setup: false, lang: 'fr', theme: 'dark', wallpaper: 'elyzea', accent: 'elyzea', iconStyle: 'prisme', clockStyle: 'stack', frame: 'elyzea', edgeLight: true, faceid: false, lockOnClose: true, showBankWidget: true, auraDrop: true, deviceName: '', cardName: '', ringtone: 'cristal', silent: true, airplane: false, notifications: true, zoom: 100, installed: [] },
    services: [{ id: 'police', label: 'Police', color: '#9C8CFF', icon: 'shield' }, { id: 'ambulance', label: 'Secours', color: '#FF8FA3', icon: 'cross' }, { id: 'mechanic', label: 'Dépannage', color: '#F5C77E', icon: 'wrench' }, { id: 'taxi', label: 'Taxi', color: '#7ED6C1', icon: 'car' }],
    places: [{ id: 1, label: 'Commissariat de Mission Row' }, { id: 2, label: 'Hôpital Pillbox Hill' }]
  } });
  window.__elyzea = { handlers, openApp, S, Music, Dating, Mock, renderWizard, W, showLock, goHome, applySettings, saveSettings };
}
