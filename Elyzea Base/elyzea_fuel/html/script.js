/* =====================================================================
   ELYZEA FUEL · ÉCRAN DE LA POMPE (NUI, sans focus : le clavier reste au jeu)
   Messages du client : prompt · open · state · pumping · flow · receipt · hide
   Les chiffres viennent du serveur toutes les 250 ms et défilent en douceur (comme une vraie pompe).
   Hors FiveM : index.html?demo=1 simule un plein complet avec débordement (tests, captures).
   ===================================================================== */
'use strict';
const IN_GAME = typeof GetParentResourceName === 'function';
const $ = (s) => document.querySelector(s);
const fr2 = (n) => Number(n || 0).toLocaleString('fr-FR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
const fr0 = (n) => Number(n || 0).toLocaleString('fr-FR', { maximumFractionDigits: 0 });

const P = { open: false, mode: null, price: 0, tank: 60, start: 0, chargeSpill: true, pumping: false,
  target: { cost: 0, liters: 0, spilled: 0, fuel: 0 }, shown: { cost: 0, liters: 0, spilled: 0, fuel: 0 },
  full: false, spill: false, broke: false, engine: false, receiptT: null };

/* ---------------------------------------------------------------- son de la pompe (WebAudio, sans fichier) */
const Snd = {
  ctx: null, hum: null,
  init() {
    if (this.ctx) return this.ctx;
    try { this.ctx = new (window.AudioContext || window.webkitAudioContext)(); } catch (e) { this.ctx = null; }
    return this.ctx;
  },
  click(freq = 900, vol = 0.05) {
    const c = this.init(); if (!c) return;
    const o = c.createOscillator(), g = c.createGain();
    o.type = 'square'; o.frequency.value = freq;
    g.gain.setValueAtTime(vol, c.currentTime); g.gain.exponentialRampToValueAtTime(0.0001, c.currentTime + 0.08);
    o.connect(g).connect(c.destination); o.start(); o.stop(c.currentTime + 0.09);
  },
  // moteur de la pompe + écoulement : bruit filtré bas et léger ronronnement
  start(spill) {
    const c = this.init(); if (!c) return;
    if (c.state === 'suspended') c.resume().catch(() => {});
    if (this.hum) { this.hum.f.frequency.setTargetAtTime(spill ? 1400 : 650, c.currentTime, 0.1); return; }
    const len = c.sampleRate * 2, buf = c.createBuffer(1, len, c.sampleRate), d = buf.getChannelData(0);
    let last = 0;
    for (let i = 0; i < len; i++) { last = (last + 0.02 * (Math.random() * 2 - 1)) / 1.02; d[i] = last * 3.5; }
    const src = c.createBufferSource(); src.buffer = buf; src.loop = true;
    const f = c.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = spill ? 1400 : 650;
    const o = c.createOscillator(); o.type = 'sine'; o.frequency.value = 58;
    const og = c.createGain(); og.gain.value = 0.025;
    const g = c.createGain(); g.gain.setValueAtTime(0.0001, c.currentTime); g.gain.exponentialRampToValueAtTime(0.09, c.currentTime + 0.15);
    src.connect(f).connect(g); o.connect(og).connect(g); g.connect(c.destination);
    src.start(); o.start();
    this.hum = { src, o, g, f };
  },
  stop() {
    const c = this.ctx, h = this.hum; if (!c || !h) return;
    this.hum = null;
    h.g.gain.setTargetAtTime(0.0001, c.currentTime, 0.06);
    setTimeout(() => { try { h.src.stop(); h.o.stop(); } catch (e) { /* déjà arrêté */ } }, 300);
  },
};

/* ---------------------------------------------------------------- affichage */
function setKeys() {
  const k = (key, label, mouse) => `<span><kbd class="${mouse ? 'mouse' : ''}">${key}</kbd>${label}</span>`;
  $('#keys').innerHTML = P.mode === 'car'
    ? k('CLIC DROIT', 'maintenir pour remplir', true) + k('E', 'reprendre le pistolet')
    : k('E', 'insérer dans la trappe') + k('E', 'raccrocher à la pompe');
}

function setStatus() {
  const s = $('#status');
  let text, cls = '';
  if (P.mode !== 'car') { text = 'Insère le pistolet dans la trappe du véhicule'; }
  else if (P.engine) { text = 'Moteur allumé : la pompe est bloquée'; cls = 'warn'; }
  else if (P.broke) { text = 'Fonds insuffisants : la pompe s\'est arrêtée'; cls = 'warn'; }
  else if (P.spill && P.pumping) { text = 'Réservoir plein : l\'essence déborde sur le sol !'; cls = 'bad'; }
  else if (P.full) { text = 'Réservoir plein : relâche la gâchette'; cls = 'warn'; }
  else if (P.pumping) { text = 'Remplissage en cours…'; cls = 'go'; }
  else { text = 'Maintiens le clic droit pour remplir, lâche quand tu veux'; }
  if (s.textContent !== text) s.textContent = text;
  s.className = `status ${cls}`;
  const p = $('#pump');
  p.classList.toggle('pumping', P.pumping && P.mode === 'car' && !P.broke && !P.engine);
  p.classList.toggle('spilling', P.spill && P.pumping);
  p.classList.toggle('full', P.full);
}

function draw() {
  const sh = P.shown;
  $('#cost').textContent = fr2(sh.cost);
  $('#liters').textContent = fr2(sh.liters);
  $('#spilled').textContent = fr2(sh.spilled);
  $('#spillBox').classList.toggle('hidden', !(P.target.spilled > 0.004));
  const pct = Math.max(0, Math.min(100, sh.fuel));
  $('#fill').style.width = `${pct}%`;
  $('#pct').textContent = `${Math.floor(pct + 0.0001)} %`;
  $('#startMark').style.left = `${Math.max(0, Math.min(100, P.start))}%`;
  $('#startMark').classList.toggle('hidden', P.mode !== 'car');
  const inTank = P.tank * pct / 100;
  $('#tankL').textContent = `${fr0(inTank)} / ${fr0(P.tank)} L`;
  $('#free').textContent = pct >= 99.95 ? 'PLEIN' : `${fr2(Math.max(0, P.tank - inTank))} L libres`;
}

// Défilement doux vers les valeurs du serveur (constante de temps ~200 ms)
let lastT = performance.now();
function frame(t) {
  const dt = Math.min(0.1, (t - lastT) / 1000); lastT = t;
  if (P.open) {
    const k = 1 - Math.exp(-dt / 0.2);
    let moving = false;
    for (const key of ['cost', 'liters', 'spilled', 'fuel']) {
      const a = P.shown[key], b = P.target[key];
      const n = Math.abs(b - a) < 0.004 ? b : a + (b - a) * k;
      if (n !== a) moving = true;
      P.shown[key] = n;
    }
    if (moving) draw();
  }
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);

function resetNumbers(v) {
  P.target = { cost: v?.cost || 0, liters: v?.liters || 0, spilled: v?.spilled || 0, fuel: v?.fuel ?? v?.start ?? 0 };
  P.shown = { ...P.target };
}

/* ---------------------------------------------------------------- messages du jeu */
const ON = {
  prompt(d) {
    const p = $('#prompt');
    if (!d) return p.classList.add('hidden');
    $('#pkey').textContent = d.key || '';
    $('#ptext').textContent = d.text || '';
    p.classList.toggle('nokey', !d.key);
    p.classList.remove('hidden');
  },
  open(d) {
    P.open = true; P.mode = d.mode || 'hand'; P.price = d.price || 0; P.chargeSpill = d.chargeSpill !== false;
    P.full = P.spill = P.broke = P.engine = P.pumping = false;
    $('#station').textContent = d.station || 'Station-service';
    $('#price').textContent = `${fr2(P.price)} $ / L`;
    $('#mark').innerHTML = window.Ely ? Ely.mark({ size: 34, live: true }) : '';
    $('#receipt').classList.add('hidden');
    resetNumbers(null);
    $('#pump').classList.remove('hidden');
    setKeys(); setStatus(); draw();
    Snd.click(1200, 0.04);
  },
  state(d) {
    P.mode = d.mode;
    if (d.station) $('#station').textContent = d.station;
    if (d.price != null) { P.price = d.price; $('#price').textContent = `${fr2(P.price)} $ / L`; }
    if (d.mode === 'car' && d.view) {
      P.tank = d.view.tank || 60; P.start = d.view.start || 0;
      P.full = d.view.full; P.spill = false; P.broke = false; P.engine = false;
      resetNumbers(d.view);
      $('#receipt').classList.add('hidden');
      Snd.click(700, 0.05);
    }
    if (d.mode === 'hand') { P.pumping = false; P.spill = false; Snd.stop(); }
    setKeys(); setStatus(); draw();
  },
  pumping(on) {
    if (P.pumping === !!on) return;
    P.pumping = !!on;
    if (P.pumping && P.mode === 'car') { Snd.click(500, 0.05); if (!P.broke) Snd.start(P.spill); } else { Snd.stop(); P.spill = false; }
    setStatus();
  },
  flow(v) {
    if (!v) return;
    P.target.cost = v.cost; P.target.liters = v.liters; P.target.spilled = v.spilled; P.target.fuel = v.fuel;
    P.tank = v.tank || P.tank; P.start = v.start ?? P.start;
    const wasSpill = P.spill;
    P.full = v.full; P.spill = !!v.spill; P.broke = !!v.broke; P.engine = !!v.engine;
    if (P.pumping && P.mode === 'car') {
      if (P.broke || P.engine) Snd.stop(); else if (P.spill !== wasSpill || !Snd.hum) Snd.start(P.spill);
    }
    setStatus();
  },
  receipt(r) {
    if (!r) return;
    Snd.stop(); P.pumping = false; P.spill = false;
    P.target.cost = r.cost; P.target.liters = r.liters; P.target.spilled = r.spilled; P.target.fuel = r.fuel;
    const el = $('#receipt');
    el.classList.toggle('ko', r.paid === false);
    el.innerHTML = `<h3>TICKET <b>ELYZEA</b></h3>
      <div class="line"><span>Essence mise</span><b>${fr2(r.liters)} L</b></div>
      ${r.spilled > 0.004 ? `<div class="line"><span>Essence renversée${P.chargeSpill ? ' (comptée)' : ''}</span><b>${fr2(r.spilled)} L</b></div>` : ''}
      <div class="line"><span>Prix du litre</span><b>${fr2(r.price)} $</b></div>
      <div class="line"><span>Réservoir</span><b>${fr0(r.start)} % → ${fr0(r.fuel)} %</b></div>
      <div class="total"><small>${r.paid === false ? 'IMPAYÉ' : 'PAYÉ'}</small><span>${fr0(r.amount)} $</span></div>
      <div class="note">${r.paid === false ? 'Paiement refusé : le réservoir est revenu à son niveau d\'avant.' : `Montant arrondi au dollar (${fr2(r.cost)} $ au compteur).`}</div>`;
    el.classList.remove('hidden');
    Snd.click(1500, 0.04); setTimeout(() => Snd.click(1900, 0.035), 110);
    clearTimeout(P.receiptT);
    P.receiptT = setTimeout(() => { el.classList.add('hidden'); setStatus(); }, 5000);
    setStatus(); draw();
  },
  hide() {
    P.open = false; P.mode = null; P.pumping = false; Snd.stop();
    clearTimeout(P.receiptT);
    const show = !$('#receipt').classList.contains('hidden');
    // le ticket reste lisible 3 s si le pistolet est raccroché juste après le paiement
    setTimeout(() => { if (!P.open) $('#pump').classList.add('hidden'); }, show ? 3000 : 0);
  },
  scale(v) { document.documentElement.style.setProperty('--s', Math.max(0.6, Math.min(1.6, Number(v) || 1))); },
};

window.addEventListener('message', (e) => {
  const m = e.data || {};
  const fn = ON[m.action];
  if (fn) { try { fn(m.data); } catch (err) { console.error('[elyzea_fuel]', m.action, err); } }
});

/* ---------------------------------------------------------------- démo (navigateur) */
(function demo() {
  if (IN_GAME) return;
  const q = new URLSearchParams(location.search);
  if (!q.has('demo')) return;
  document.body.classList.add('demo');
  const send = (action, data) => window.postMessage({ action, data }, '*');
  const step = q.get('demo');
  const price = 3.15, tank = 65, flow = 1.2;
  let fuel = step === 'spill' ? 96 : 18, liters = 0, spilled = 0;
  const start = fuel;
  const view = () => ({ id: 1, liters, spilled, cost: Math.round((liters + spilled) * price * 100) / 100, fuel, tank, price, start, full: fuel >= 99.95, spill: false });
  send('prompt', { key: 'E', text: 'Prendre le pistolet · 3,15 $/L' });
  if (step === 'prompt') return;
  setTimeout(() => {
    send('prompt', false);
    send('open', { station: 'Station LTD Grove Street', price, flowRate: flow, chargeSpill: true, mode: 'hand' });
    if (step === 'hand') return;
    send('state', { mode: 'car', view: view(), price });
    send('pumping', true);
    let n = 0;
    const iv = setInterval(() => {
      const add = Math.min(flow * 0.25, (100 - fuel) / 100 * tank);
      const sp = flow * 0.25 - add;
      liters += add; spilled += sp; fuel = Math.min(100, fuel + add / tank * 100);
      const v = view(); v.spill = sp > 0.0001;
      send('flow', v);
      n++;
      if ((step === 'spill' && n > 24) || (step !== 'spill' && n > 16)) {
        clearInterval(iv);
        if (step === 'receipt') { send('pumping', false); send('receipt', { ...view(), amount: Math.round(view().cost), paid: true }); }
      }
    }, 250);
  }, 300);
})();
