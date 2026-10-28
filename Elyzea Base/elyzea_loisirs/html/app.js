/* =========================================================
   ELYZEA LOISIRS - interface (lobby, tableaux de score, contrôles, classement)
   Tout ce qui compte (scores, tours) vient du serveur : l'interface n'affiche que l'état reçu.
   ========================================================= */
const $ = (s) => document.querySelector(s);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'elyzea_loisirs';
const post = (name, data = {}) => fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) })
    .then((r) => r.json()).catch(() => ({ error: 'Pas de réponse.' }));

const STATE = { WAITING: ['En attente', 'wait'], STARTING: ['Démarrage…', 'run'], IN_PROGRESS: ['En cours', 'run'], FINISHED: ['Terminée', 'end'], CANCELLED: ['Annulée', 'end'] };
const ICO = { bowling: '🎳', billiards: '🎱', golf: '⛳' };
const L = { lobby: null, tab: 'party', me: 0, sessions: {}, my: null, watch: null, resultsShown: {} };

/* ------------------------------------------------ lobby */
function lobbyRender() {
    const lb = L.lobby;
    if (!lb) return;
    $('#lobbyIco').textContent = ICO[lb.inst.kind] || '🎮';
    $('#lobbyGame').textContent = (lb.game && lb.game.label || '').toUpperCase();
    $('#lobbyTitle').textContent = lb.inst.name;
    document.querySelectorAll('.tab').forEach((t) => t.classList.toggle('on', t.dataset.tab === L.tab));
    const body = $('#lobbyBody');
    if (L.tab === 'rules') {
        body.innerHTML = `<div class="card"><h3>Règles</h3><ul class="rules">${(lb.rules || []).map((r) => `<li>${esc(r)}</li>`).join('')}</ul></div>
            <p class="muted">Quitter à tout moment : /loisirs_quitter. ${lb.game && lb.game.price ? `Droit d'entrée : ${lb.game.price} $ (remboursé si la partie ne commence pas).` : 'Gratuit.'}</p>`;
        return;
    }
    const s = lb.sessions && lb.sessions[0];
    if (!s) {
        const g = lb.game || {};
        let opts = '';
        for (let n = g.minPlayers || 1; n <= (g.maxPlayers || 4); n++) opts += `<option value="${n}" ${n === g.maxPlayers ? 'selected' : ''}>${n} joueur${n > 1 ? 's' : ''}</option>`;
        body.innerHTML = `<p class="muted">Aucune partie ici. Crée-la : tu en seras l'hôte.</p>
            <label for="fName">Nom de la partie</label><input class="in" id="fName" maxlength="32" placeholder="Ma partie">
            <div class="row"><div><label for="fMax">Places</label><select class="in" id="fMax">${opts}</select></div>
            ${lb.holes ? `<div><label for="fHoles">Trous</label><select class="in" id="fHoles">${Array.from({ length: lb.holes }, (_, i) => `<option value="${i + 1}" ${i + 1 === lb.holes ? 'selected' : ''}>${i + 1}</option>`).join('')}</select></div>` : ''}</div>
            <label for="fPass">Mot de passe (facultatif)</label><input class="in" id="fPass" maxlength="16" type="password" autocomplete="off">
            <label class="check"><input type="checkbox" id="fPriv"> Partie privée (sur invitation de l'hôte)</label>
            <div class="btns"><button class="btn primary" data-act="create">Créer la partie</button></div>`;
        return;
    }
    const st = STATE[s.state] || [s.state, ''];
    const iAmIn = (s.players || []).some((p) => p.id === L.me && p.status !== 'left');
    const host = s.host === L.me;
    const list = (s.players || []).map((p) => `<li><span>${p.host ? '👑 ' : ''}${esc(p.name)}${p.id === L.me ? ' <span class="muted">(toi)</span>' : ''}</span>
        <span>${p.status === 'left' ? '<span class="muted">parti</span>' : ''}${host && s.state === 'WAITING' && p.id !== L.me ? `<button class="mini" data-act="kick" data-id="${p.id}">Retirer</button>` : ''}</span></li>`).join('');
    let actions = '';
    if (iAmIn) {
        if (host && s.state === 'WAITING') actions += `<button class="btn primary" data-act="start">Lancer la partie</button>`;
        actions += `<button class="btn danger" data-act="leave">${s.state === 'IN_PROGRESS' ? 'Abandonner' : 'Quitter'}</button>`;
    } else if (s.state === 'WAITING' && s.players.length < s.max) {
        actions += `${s.locked ? '<input class="in" id="jPass" type="password" placeholder="Mot de passe" maxlength="16" autocomplete="off">' : ''}<button class="btn primary" data-act="join">Rejoindre</button>`;
    }
    body.innerHTML = `<div class="card"><h3>${esc(s.name)} <span class="badge ${st[1]}">${st[0]}</span>${s.locked ? '<span class="badge">🔒</span>' : ''}${s.private ? '<span class="badge">Privée</span>' : ''}</h3>
        <span class="muted">${s.players.length} / ${s.max} joueur(s)${s.price ? ` · ${s.price} $` : ''}${s.state === 'STARTING' && s.startIn != null ? ` · départ dans ${s.startIn} s` : ''}</span>
        <ul class="plist">${list}</ul></div>
        ${host && s.state === 'WAITING' ? `<div class="row" style="margin-top:8px"><input class="in" id="invId" type="number" min="1" placeholder="ID du joueur à inviter"><button class="btn" data-act="invite" style="flex:0 0 auto">Inviter</button></div>` : ''}
        <div class="btns">${actions}</div>`;
}

function closeLobby() { L.lobby = null; $('#lobby').classList.add('hidden'); }

document.addEventListener('click', async (e) => {
    const tab = e.target.closest('[data-tab]');
    if (tab) { L.tab = tab.dataset.tab; lobbyRender(); return; }
    const b = e.target.closest('[data-act]');
    if (!b) return;
    const act = b.dataset.act;
    if (act === 'close') { closeLobby(); post('close'); return; }
    if (!L.lobby) return;
    b.disabled = true;
    let r;
    if (act === 'create') {
        r = await post('create', { inst: L.lobby.inst.id, name: $('#fName').value, max: Number($('#fMax').value), password: $('#fPass').value,
            private: $('#fPriv').checked, holes: $('#fHoles') ? Number($('#fHoles').value) : undefined });
    } else if (act === 'join') r = await post('join', { session: L.lobby.sessions[0].id, password: $('#jPass') ? $('#jPass').value : '' });
    else if (act === 'leave') r = await post('leave');
    else if (act === 'start') r = await post('start');
    else if (act === 'invite') r = await post('invite', { target: Number($('#invId').value) });
    else if (act === 'kick') r = await post('kick', { target: Number(b.dataset.id) });
    if (r && r.session && L.lobby) { L.lobby.sessions = [r.session]; }
    if (act === 'leave' && r && r.ok && L.lobby) { L.lobby.sessions = []; }
    if (act === 'start' && r && r.ok) { closeLobby(); post('close'); return; }
    b.disabled = false;
    lobbyRender();
});
document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && L.lobby) { closeLobby(); post('close'); } });

/* ------------------------------------------------ tableaux de score */
function nameOf(s, id) { const p = (s.players || []).find((x) => x.id === id); return p ? p.name : `#${id}`; }
function statusOf(s, id) { const p = (s.players || []).find((x) => x.id === id); return p ? p.status : 'left'; }

function rollText(fr, i, f) {
    const v = fr[i];
    if (v == null) return '';
    if (f < 10) {
        if (i === 0) return v === 10 ? 'X' : (v === 0 ? '-' : v);
        return fr[0] + v === 10 ? '/' : (v === 0 ? '-' : v);
    }
    const prev = fr[i - 1];
    if (v === 10 && (i === 0 || prev === 10 || (i === 2 && fr[0] !== 10 && fr[0] + fr[1] === 10))) return 'X';
    if (i > 0 && prev !== 10 && prev + v === 10 && !(i === 2 && fr[0] + fr[1] === 10 && fr[0] !== 10)) return '/';
    return v === 0 ? '-' : v;
}
function bowlingHud(s) {
    const d = s.data || {};
    const head = '<tr><th></th>' + Array.from({ length: 10 }, (_, i) => `<th>${i + 1}</th>`).join('') + '<th>Total</th></tr>';
    const rows = (d.players || []).map((p) => {
        const cells = Array.from({ length: 10 }, (_, f) => {
            const fr = (p.frames || [])[f] || [];
            const n = f === 9 ? 3 : 2;
            const rolls = Array.from({ length: n }, (_, i) => rollText(fr, i, f + 1)).join(' ');
            const cum = p.cum && p.cum[f + 1] != null ? p.cum[f + 1] : (p.cum && p.cum[String(f + 1)] != null ? p.cum[String(f + 1)] : '');
            return `<td><span class="roll">${rolls || '&nbsp;'}</span><span class="cum">${cum}</span></td>`;
        }).join('');
        return `<tr class="${s.turn === p.id ? 'active' : ''} ${statusOf(s, p.id) === 'left' ? 'left' : ''}"><td class="name">${esc(nameOf(s, p.id))}</td>${cells}<td><b>${p.total}</b></td></tr>`;
    }).join('');
    const up = new Set(d.standing || []);
    const pins = [7, 8, 9, 10, 4, 5, 6, 0, 2, 3, 0, 0, 1].map((n) => n ? `<div class="pin ${up.has(n) ? 'up' : ''}"></div>` : '<div></div>').join('');
    return `<table>${head}${rows}</table><div class="row" style="margin-top:6px;justify-content:flex-start;gap:14px"><span class="muted">Quilles debout</span><div class="pins">${pins}</div></div>`;
}
const ballHtml = (n) => `<span class="ball ${n === 8 ? 'e' : (n < 8 ? 's' : 't')}">${n}</span>`;
function billiardsHud(s) {
    const d = s.data || {};
    const G = { solids: 'Pleines (1-7)', stripes: 'Rayées (9-15)' };
    const cards = (d.seat || []).map((id, i) => `<div class="pl ${s.turn === id ? 'active' : ''}">
        <span>${s.turn === id ? '▶ ' : ''}<b>${esc(nameOf(s, id))}</b> <span class="muted">${d.groups && d.groups[i] ? G[d.groups[i]] : 'table ouverte'}${d.remaining && d.remaining[i] != null ? ` · reste ${d.remaining[i]}` : ''}</span></span>
        <span class="ballset">${((d.pocketed || [])[i] || []).map(ballHtml).join('')}</span></div>`).join('');
    const extra = [d.ballInHand ? `Blanche en main${d.ballInHand === 'kitchen' ? ' (zone de tête)' : ''}` : '', d.lastFoul ? `Dernière faute : ${esc(d.lastFoul)}` : ''].filter(Boolean).join(' · ');
    return cards + (extra ? `<div class="muted" style="margin-top:6px">${extra}</div>` : '');
}
function golfHud(s) {
    const d = s.data || {};
    const h = d.current || {};
    const par = (d.pars || [])[d.hole - 1];
    const rows = (d.players || []).slice().sort((a, b) => a.total - b.total).map((p) => {
        const rel = p.toPar === 0 ? 'E' : (p.toPar > 0 ? `+${p.toPar}` : p.toPar);
        const hs = (p.strokes || {})[d.hole] ?? (p.strokes || {})[String(d.hole)] ?? 0;
        return `<tr class="${s.turn === p.id ? 'active' : ''} ${statusOf(s, p.id) === 'left' ? 'left' : ''}"><td class="name">${esc(nameOf(s, p.id))}</td>
            <td>${hs}${p.done ? ' ✓' : ''}</td><td>${p.dist != null && !p.done ? Math.round(p.dist) + ' m' : '—'}</td><td>${esc(LIE[p.lie] || '')}</td><td><b>${p.total}</b></td><td>${rel}</td></tr>`;
    }).join('');
    return `<div class="muted">Trou <b>${d.hole} / ${d.holes}</b> · Par ${par} · max ${d.maxStrokes} coups</div>
        <table style="margin-top:4px"><tr><th>Joueur</th><th>Coups</th><th>Distance</th><th>Balle</th><th>Total</th><th>Par</th></tr>${rows}</table>`;
}
const LIE = { tee: 'départ', fairway: 'fairway', rough: 'rough', bunker: 'bunker', green: 'green', holed: 'au trou' };

function hudRender() {
    const s = (L.my && L.sessions[L.my]) || (L.watch && L.sessions[L.watch]);
    const hud = $('#hud');
    if (!s || (s.state !== 'IN_PROGRESS' && s.state !== 'STARTING' && s.state !== 'WAITING')) { hud.classList.add('hidden'); return; }
    let body = '';
    if (s.state === 'IN_PROGRESS') body = s.game === 'bowling' ? bowlingHud(s) : (s.game === 'billiards' ? billiardsHud(s) : golfHud(s));
    else body = `<div class="muted">${s.state === 'STARTING' ? `Départ dans ${s.startIn ?? 0} s…` : `En attente des joueurs (${s.players.length} / ${s.max})`}</div>`;
    const turn = s.turn ? `Au tour de <b>${esc(nameOf(s, s.turn))}</b>${s.turnLeft != null ? ` · ${s.turnLeft} s` : ''}` : '';
    hud.innerHTML = `<div class="title"><span>${ICO[s.game] || ''} ${esc(s.name).toUpperCase()}${L.my === s.id ? '' : ' · SPECTATEUR'}</span><span style="color:var(--ink);letter-spacing:0">${turn}</span></div>${body}`;
    hud.classList.remove('hidden');
}

function resultsRender(s) {
    const r = s.results || {};
    const rk = r.ranking || [];
    let rows = '';
    if (s.game === 'bowling') rows = rk.map((p, i) => `<div class="rank"><span>${i + 1}. ${esc(p.name)}${p.left ? ' <span class="muted">(abandon)</span>' : ''}</span><span><b>${p.score}</b> <span class="muted">· ${p.strikes} strike(s), ${p.spares} spare(s)</span></span></div>`).join('');
    else if (s.game === 'billiards') rows = rk.map((p) => `<div class="rank"><span>${p.winner ? '🏆 ' : ''}${esc(p.name)}${p.left ? ' <span class="muted">(abandon)</span>' : ''}</span><span class="muted">${p.group === 'solids' ? 'pleines' : (p.group === 'stripes' ? 'rayées' : 'table ouverte')} · ${p.pocketed} empochée(s)</span></div>`).join('')
        + `<p class="muted">${r.shots || 0} tir(s) joué(s).</p>`;
    else rows = rk.map((p, i) => `<div class="rank"><span>${i + 1}. ${esc(p.name)}${p.left ? ' <span class="muted">(abandon)</span>' : ''}</span><span><b>${p.total}</b> coups <span class="muted">(${p.toPar === 0 ? 'par' : (p.toPar > 0 ? '+' + p.toPar : p.toPar)}, pénalités ${p.penalties})</span></span></div>`).join('')
        + `<p class="muted">${r.holes} trou(s), par ${r.parTotal}.</p>`;
    $('#resGame').textContent = `${(ICO[s.game] || '')} FIN DE PARTIE${s.reason ? ' · ' + s.reason : ''}`.toUpperCase();
    $('#resTitle').textContent = s.name;
    $('#resBody').innerHTML = rows || '<p class="muted">Aucun résultat.</p>';
    $('#results').classList.remove('hidden');
    setTimeout(() => $('#results').classList.add('hidden'), 15000);
}

/* ------------------------------------------------ contrôles et messages */
function controlsRender(m) {
    const c = $('#controls');
    if (!m.show) { c.classList.add('hidden'); return; }
    $('#ctlHint').textContent = m.hint || '';
    $('#ctlInfo').textContent = m.info || '';
    const p = $('#ctlPower');
    if (m.power != null) {
        p.classList.remove('hidden');
        p.classList.toggle('over', !!m.over);
        p.querySelector('i').style.width = `${Math.round(m.power * 100)}%`;
        p.querySelector('.mark').style.display = m.game === 'golf' ? 'block' : 'none';
    } else p.classList.add('hidden');
    $('#ctlKeys').innerHTML = (m.keys || []).filter(Boolean).map((k) => `<span>${esc(k)}</span>`).join('');
    c.classList.remove('hidden');
}
/* ------------------------------------------------ sons des jeux (synthétisés, aucun fichier)
   Chocs de billes, bandes, poches, roulement et fracas du bowling, frappe et rebonds du golf.
   Le volume et la position gauche / droite sont calculés par le client selon la distance. */
const SFX = { ctx: null, noise: null, count: 0 };
function audio() {
    if (!SFX.ctx) {
        const AC = window.AudioContext || window.webkitAudioContext;
        if (!AC) return null;
        SFX.ctx = new AC();
        const len = SFX.ctx.sampleRate;           // 1 s de bruit blanc réutilisé
        const buf = SFX.ctx.createBuffer(1, len, SFX.ctx.sampleRate);
        const d = buf.getChannelData(0);
        for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;
        SFX.noise = buf;
    }
    if (SFX.ctx.state === 'suspended') SFX.ctx.resume();
    return SFX.ctx;
}
// sortie commune : volume + panoramique
function out(ctx, vol, pan) {
    const g = ctx.createGain(); g.gain.value = Math.max(0, Math.min(1, vol));
    let node = g;
    if (ctx.createStereoPanner) { const p = ctx.createStereoPanner(); p.pan.value = Math.max(-1, Math.min(1, pan || 0)); g.connect(p); p.connect(ctx.destination); }
    else g.connect(ctx.destination);
    return node;
}
// petit « toc » : bruit filtré + ton bref, enveloppe rapide
function knock(ctx, dest, at, { freq = 2500, q = 2, tone = 0, toneDecay = 0.04, decay = 0.03, gain = 1, type = 'bandpass' }) {
    const n = ctx.createBufferSource(); n.buffer = SFX.noise;
    const f = ctx.createBiquadFilter(); f.type = type; f.frequency.value = freq; f.Q.value = q;
    const e = ctx.createGain(); e.gain.setValueAtTime(gain, at); e.gain.exponentialRampToValueAtTime(0.0008, at + decay);
    n.connect(f); f.connect(e); e.connect(dest); n.start(at, Math.random() * 0.5); n.stop(at + decay + 0.02);
    if (tone) {
        const o = ctx.createOscillator(); o.frequency.value = tone;
        const eg = ctx.createGain(); eg.gain.setValueAtTime(gain * 0.5, at); eg.gain.exponentialRampToValueAtTime(0.0008, at + toneDecay);
        o.connect(eg); eg.connect(dest); o.start(at); o.stop(at + toneDecay + 0.02);
    }
}
function rumble(ctx, dest, at, dur, freq) {
    const n = ctx.createBufferSource(); n.buffer = SFX.noise; n.loop = true;
    const f = ctx.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = freq || 160;
    const e = ctx.createGain();
    e.gain.setValueAtTime(0.0001, at); e.gain.linearRampToValueAtTime(0.9, at + 0.25);
    e.gain.setValueAtTime(0.9, at + Math.max(0.3, dur - 0.4)); e.gain.linearRampToValueAtTime(0.0001, at + dur);
    n.connect(f); f.connect(e); e.connect(dest); n.start(at); n.stop(at + dur + 0.05);
}
function sfx(kind, vol, pan, extra) {
    const ctx = audio();
    if (!ctx || !(vol > 0)) return;
    if (SFX.count > 40) return;                     // garde-fou : pas d'avalanche de sons
    SFX.count++; setTimeout(() => { SFX.count--; }, 300);
    const dest = out(ctx, vol, pan);
    const t = ctx.currentTime + 0.005;
    const r = (a, b) => a + Math.random() * (b - a);
    switch (kind) {
        case 'ball':   knock(ctx, dest, t, { freq: r(2600, 3400), q: 3, tone: r(2100, 2600), decay: 0.035, toneDecay: 0.05, gain: 1 }); break;          // clac bille / bille
        case 'cue':    knock(ctx, dest, t, { freq: 1800, q: 1.5, tone: 1300, decay: 0.03, toneDecay: 0.03, gain: 0.9 }); break;                         // procédé contre la blanche
        case 'rail':   knock(ctx, dest, t, { freq: 320, q: 1, type: 'lowpass', decay: 0.09, gain: 1 }); break;                                           // bande en caoutchouc
        case 'pocket': [0, 0.07, 0.16].forEach((d, i) => knock(ctx, dest, t + d, { freq: 500 - i * 80, q: 2, decay: 0.08, gain: 0.9 - i * 0.2 })); break;  // chute dans la poche
        case 'roll':   rumble(ctx, dest, t, Math.min(8, Math.max(0.5, Number(extra) || 2)), 140); break;                                                 // boule de bowling qui roule
        case 'pin':    knock(ctx, dest, t, { freq: r(900, 1300), q: 2.5, tone: r(700, 950), decay: 0.07, toneDecay: 0.09, gain: 1 }); break;          // boule contre quille
        case 'pinpin': knock(ctx, dest, t, { freq: r(1100, 1600), q: 3, tone: r(900, 1200), decay: 0.05, toneDecay: 0.06, gain: 0.8 }); break;        // quille contre quille
        case 'kick':   knock(ctx, dest, t, { freq: 400, q: 1, type: 'lowpass', decay: 0.07, gain: 0.7 }); break;
        case 'gutter': rumble(ctx, dest, t, 1.2, 260); break;
        case 'swing':  knock(ctx, dest, t, { freq: 4200, q: 4, tone: r(3600, 4200), decay: 0.02, toneDecay: 0.12, gain: 1 }); break;          // frappe du club
        case 'putt':   knock(ctx, dest, t, { freq: 2200, q: 2, tone: 1700, decay: 0.02, toneDecay: 0.05, gain: 0.6 }); break;
        case 'land':   knock(ctx, dest, t, { freq: 250, q: 1, type: 'lowpass', decay: 0.07, gain: 0.8 }); break;                                       // balle qui retombe sur l'herbe
        case 'sand':   knock(ctx, dest, t, { freq: 3000, q: 0.6, type: 'highpass', decay: 0.18, gain: 0.5 }); break;
        case 'water':  knock(ctx, dest, t, { freq: 900, q: 0.7, decay: 0.35, gain: 0.8 }); break;
        case 'cup':    [0, 0.05, 0.12, 0.2].forEach((d, i) => knock(ctx, dest, t + d, { freq: 2600, q: 5, tone: 2300 - i * 120, decay: 0.03, toneDecay: 0.05, gain: 0.8 - i * 0.15 })); break;
        default: break;
    }
}

/* ------------------------------------------------ pole dance */
let POLE = null;
function poleRender(m) {
    const box = $('#pole');
    if (!m.show) { POLE = null; box.classList.add('hidden'); return; }
    POLE = m;
    $('#poleName').textContent = m.name || 'Barre';
    box.classList.toggle('dim', !m.cursor);
    const item = (cmd, i, ico, label, desc, key, on) => `<button class="pd ${on ? 'on' : ''}" data-pd="${cmd}" ${i != null ? `data-i="${i}"` : ''} ${m.entering ? 'disabled' : ''}>
        <span class="ico">${esc(ico || '💃')}</span><span><b>${esc(label)}</b>${desc ? `<small>${esc(desc)}</small>` : ''}</span><kbd>${key}</kbd></button>`;
    const list = (m.dances || []).map((d) => item('dance', d.i, d.icon, d.label, d.desc, d.i, m.mode === 'pole' && m.current === d.i && !m.entering)).join('')
        + (m.private ? item('private', null, m.private.icon, m.private.label, m.private.desc, 4, m.mode === 'private') : '');
    const c = m.calib;
    const ax = (k, label, step, unit) => `<div class="ax"><span>${label}</span><button class="mini" data-pd="nudge" data-axis="${k}" data-d="${-step}">−</button>
        <span class="v">${Number(c[k] || 0).toFixed(unit === '°' ? 0 : 2)}${unit}</span><button class="mini" data-pd="nudge" data-axis="${k}" data-d="${step}">+</button></div>`;
    $('#poleBody').innerHTML = `<p class="pd-status">${m.entering ? '⏳ Tu montes sur la barre…' : (m.auto ? '🔁 Enchaînement automatique' : 'Choisis ta danse')}</p>
        <div class="pd-list">${list}</div>
        <div class="pd-row"><button class="btn ${m.auto ? 'on' : ''}" data-pd="auto" ${m.entering ? 'disabled' : ''}>🔁 Auto <kbd>5</kbd></button>
            <button class="btn ${m.cam ? 'on' : ''}" data-pd="cam">🎥 Caméra</button></div>
        <div class="pd-row"><button class="btn" data-pd="cursor">🖱️ ${m.cursor ? 'Cacher' : 'Afficher'} <kbd>H</kbd></button>
            <button class="btn danger" data-pd="stop">⬇️ Descendre</button></div>
        ${c ? `<div class="pd-cal"><h3>🎯 RÉGLAGE DE LA BARRE (STAFF)</h3>
            ${ax('ox', 'Gauche / droite', 0.01, ' m')}${ax('oy', 'Avant / arrière', 0.01, ' m')}${ax('oz', 'Hauteur', 0.01, ' m')}${ax('h', 'Orientation', 5, '°')}
            <div class="pd-row"><button class="btn primary" data-pd="calibSave">💾 Enregistrer</button><button class="btn" data-pd="calibQuit">Fermer</button></div>
            <p class="pd-help">Curseur caché : flèches = gauche/droite et avant/arrière, Page préc. / suiv. = hauteur, MAJ = pas de 5 cm, ENTRÉE = enregistrer.</p></div>` : ''}
        <p class="pd-help">${m.cursor ? 'H ou Échap : cacher le curseur et tourner la caméra librement.' : 'H : réafficher le curseur. 1 à 5 : danses. RETOUR ou E : descendre.'}</p>`;
    box.classList.remove('hidden');
}
document.addEventListener('click', (e) => {
    const b = e.target.closest('[data-pd]');
    if (!b || !POLE || b.disabled) return;
    const d = { cmd: b.dataset.pd };
    if (b.dataset.i) d.i = Number(b.dataset.i);
    if (b.dataset.axis) { d.axis = b.dataset.axis; d.d = Number(b.dataset.d); }
    post('pole', d);
});
document.addEventListener('keydown', (e) => {
    if (!POLE || !POLE.cursor || L.lobby) return;
    const k = e.key;
    if (k >= '1' && k <= '3') post('pole', { cmd: 'dance', i: Number(k) });
    else if (k === '4') post('pole', { cmd: 'private' });
    else if (k === '5') post('pole', { cmd: 'auto' });
    else if (k === 'h' || k === 'H' || k === 'Escape') post('pole', { cmd: 'cursor' });
    else if (k === 'Backspace') post('pole', { cmd: 'stop' });
});

function toast(text, kind) {
    const t = document.createElement('div');
    t.className = `toast ${kind || ''}`;
    t.textContent = text;
    $('#toasts').prepend(t);
    while ($('#toasts').children.length > 3) $('#toasts').lastChild.remove();
    setTimeout(() => t.remove(), 3200);
}

/* ------------------------------------------------ messages du jeu */
window.addEventListener('message', (e) => {
    const m = e.data || {};
    switch (m.action) {
        case 'lobby':
            if (!m.open) { closeLobby(); return; }
            L.lobby = m; L.me = m.me; L.tab = 'party';
            $('#lobby').classList.remove('hidden');
            lobbyRender();
            setTimeout(() => { const f = $('#lobby .btn.primary') || $('#lobby .x'); if (f) f.focus(); }, 50);
            return;
        case 'lobbySession':
            if (L.lobby && L.lobby.inst.id === m.session.inst) { L.lobby.sessions = [m.session]; lobbyRender(); }
            return;
        case 'session': {
            const s = m.session;
            L.me = m.me;
            L.sessions[s.id] = s;
            if (m.mine) L.my = s.id; else if (L.my === s.id) L.my = null;
            if (!m.mine && !L.my) L.watch = s.id;
            if (L.lobby && L.lobby.inst.id === s.inst) { L.lobby.sessions = [s]; lobbyRender(); }
            if (s.state === 'FINISHED' && !L.resultsShown[s.id] && (m.mine || L.watch === s.id)) { L.resultsShown[s.id] = true; resultsRender(s); }
            hudRender();
            return;
        }
        case 'sessionEnd':
            delete L.sessions[m.id];
            if (L.my === m.id) L.my = null;
            if (L.watch === m.id) L.watch = null;
            if (L.lobby && L.lobby.sessions && L.lobby.sessions[0] && L.lobby.sessions[0].id === m.id) { L.lobby.sessions = []; lobbyRender(); }
            hudRender();
            return;
        case 'controls': controlsRender(m); return;
        case 'pole': poleRender(m); return;
        case 'sfx': sfx(m.kind, m.vol, m.pan, m.extra); return;
        case 'toast': toast(m.text, m.kind); return;
        default:
    }
});
// compte à rebours du temps de jeu (affichage seulement)
setInterval(() => {
    for (const s of Object.values(L.sessions)) {
        if (s.turnLeft != null && s.turnLeft > 0) s.turnLeft -= 1;
        if (s.startIn != null && s.startIn > 0) s.startIn -= 1;
    }
    hudRender();
}, 1000);
