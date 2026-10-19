/* ARENA PvP — interface. Le serveur décide de tout ; ici on affiche et on transmet des demandes. */
(() => {
    const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'pvp_arena';
    const $ = (s) => document.querySelector(s);
    const L = window.LANG || {};
    const t = (k, ...a) => String(L[k] ?? k).replace(/\{(\d+)\}/g, (_, i) => a[i] ?? '');
    const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const money = (n) => `${Math.floor(Number(n) || 0).toLocaleString('fr-FR')} $`;
    const post = (name, data) => fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data || {}) })
        .then((r) => r.json()).catch(() => null);
    const call = async (name, ...args) => {
        const r = await post('call', { name, args });
        if (!r) return null;
        if (!r.ok && r.err) toast(r.err, 'error');
        return r;
    };

    const S = { config: null, list: [], lobby: null, view: 'home', mode: '1v1', wpTab: null, pick: null, allowed: [], wpEnd: 0, wpTotal: 0,
        hud: null, myTeam: null, roundEnd: 0, timers: {}, betTeam: 'A', betAmount: '' };
    document.querySelectorAll('[data-t]').forEach((el) => { el.textContent = t(el.dataset.t); });

    function toast(text, kind) {
        const el = document.createElement('div');
        el.className = `toast ${kind === 'inform' ? '' : (kind || '')}`;
        el.textContent = text;
        $('#toasts').appendChild(el);
        setTimeout(() => el.remove(), 4200);
    }
    function confirmBox(title, text) {
        return new Promise((res) => {
            const m = $('#modal');
            m.innerHTML = `<div class="mbox"><h3>${esc(title)}</h3><p>${esc(text)}</p><div class="row"><span class="spacer"></span>
                <button class="btn" data-m="0">${t('cancel')}</button><button class="btn primary" data-m="1">${t('confirm')}</button></div></div>`;
            m.classList.remove('hidden');
            m.onclick = (e) => { const b = e.target.closest('[data-m]'); if (!b) return; m.classList.add('hidden'); m.onclick = null; res(b.dataset.m === '1'); };
        });
    }
    const teamName = (k) => (S.config && S.config.teams[k] ? S.config.teams[k].name : k);
    const stateTag = (st) => {
        const cls = st === 'LOBBY' ? 'wait' : (st === 'PREPARATION' ? 'prep' : 'live');
        return `<span class="tag ${cls}">${esc(t('st_' + st))}</span>`;
    };
    const accountLabel = () => t(S.config && S.config.account === 'cash' ? 'account_cash' : 'account_bank');

    /* ---------------------------------------------------------------- accueil */
    function renderHome() {
        const c = S.config;
        const modes = (c.modes || []).map((m) => `<option value="${esc(m.id)}" ${m.id === S.mode ? 'selected' : ''}>${esc(m.label)}</option>`).join('');
        const cards = S.list.map((l) => {
            const free = l.max - l.players;
            const open = l.state === 'LOBBY';
            return `<div class="lcard">
                <div class="row"><h3>${esc(l.name)}</h3><span class="spacer"></span>${stateTag(l.state)}</div>
                <div class="kv">
                    <div><small>${t('players')}</small><b>${l.players}/${l.max}</b></div>
                    <div><small>${t('stake')}</small><b>${l.stake > 0 ? money(l.stake) : '—'}</b></div>
                    <div><small>${t('wins')}</small><b>${esc(t('first_to', l.wins))}</b></div>
                    <div><small>${t('mode')}</small><b>${esc(l.mode)}</b></div>
                    <div><small>${t('arena')}</small><b>${esc(l.arena)}</b></div>
                    <div><small>${t('bets')}</small><b>${money(l.betPot)}</b></div>
                </div>
                <div class="bar"><i class="ia" style="width:${(l.a / l.max) * 100}%"></i><span style="flex:1"></span><i class="ib" style="width:${(l.b / l.max) * 100}%"></i></div>
                <div class="row"><span class="hint">${t('host')} : <b>${esc(l.host)}</b> · ${open ? (free > 0 ? t('free', free) : t('full')) : ''}</span><span class="spacer"></span>
                    ${open && free > 0 && !S.lobby ? `<button class="btn small A" data-join="${esc(l.uid)}" data-team="A">${esc(t('join_team', teamName('A')))}</button>
                        <button class="btn small B" data-join="${esc(l.uid)}" data-team="B">${esc(t('join_team', teamName('B')))}</button>` : ''}
                    <button class="btn small" data-watch="${esc(l.uid)}">${t('watch')}</button></div>
            </div>`;
        }).join('');
        $('#home').innerHTML = `<div class="home-head"><div><span class="lbl">${t('nav_matches')}</span><h2>${t('home_title')}</h2></div>
            ${S.lobby && S.lobby.member ? `<button class="btn primary" data-open-mine style="margin-left:auto">↩ ${esc(S.lobby.name)}</button>` : `<div class="create">
                <select class="input" id="create-mode" style="width:150px">${modes}</select>
                <button class="btn primary" data-act="create">${t('create')}</button></div>`}</div>
            ${cards ? `<div class="list">${cards}</div>` : `<div class="empty">${t('home_empty')}</div>`}`;
    }

    /* ---------------------------------------------------------------- lobby */
    function renderLobby() {
        const l = S.lobby, c = S.config;
        if (!l) return;
        const me = l.me;
        const isHost = l.host === me;
        const member = l.member;
        const mine = l.members.find((m) => m.id === me);
        const open = l.state === 'LOBBY';
        const size = l.settings.teamSize;
        const teamCol = (k) => {
            const ms = l.members.filter((m) => m.team === k);
            const slots = Array.from({ length: Math.max(0, size - ms.length) }, () => '<div class="slot">—</div>').join('');
            return `<div class="tcol ${k}"><div class="thead"><b>${esc(teamName(k))}</b><span>${ms.length}/${size}</span></div>
                ${ms.map((m) => `<div class="pl ${m.id === me ? 'me' : ''}">${m.host ? '<span class="crown" title="' + t('host') + '">♛</span>' : ''}
                    <span class="nm">${esc(m.name)}${m.id === me ? ` <span class="ic">(${t('you')})</span>` : ''}</span>
                    ${l.settings.stake > 0 ? `<span class="${m.paid ? 'ok' : 'no'}" title="${m.paid ? t('paid') : t('unpaid')}">$</span>` : ''}
                    <span class="${m.ready ? 'ok' : 'no'}" title="${m.ready ? t('ready') : t('not_ready')}">${m.ready ? '✔' : '○'}</span></div>`).join('')}
                ${slots}
                ${open && !member && ms.length < size ? `<button class="btn small ${k}" data-join="${esc(l.uid)}" data-team="${k}">${esc(t('join_team', teamName(k)))}</button>` : ''}
                ${open && member && mine && mine.team !== k && ms.length < size ? `<button class="btn small ${k}" data-team-switch="${k}">${t('switch')}</button>` : ''}
            </div>`;
        };
        const dis = !(isHost && open) ? 'disabled' : '';
        const seg = (key, opts, cur, fmt) => `<div class="seg">${opts.map((o) => `<button ${dis} class="${o === cur ? 'on' : ''}" data-set="${key}" data-v="${esc(o)}">${esc(fmt ? fmt(o) : o)}</button>`).join('')}</div>`;
        const allowed = new Set(l.settings.weapons);
        const wps = c.weapons.map((cat) => cat.weapons.map((w) => `<div class="chk ${allowed.has(w.name.toUpperCase()) ? 'on' : 'off'}" data-wtoggle="${esc(w.name.toUpperCase())}">
            ${allowed.has(w.name.toUpperCase()) ? '☑' : '☐'} ${esc(w.label)}</div>`).join('')).join('');
        const arenas = (c.arenas || []).filter((a) => a.valid).map((a) => `<option value="${esc(a.id)}" ${a.id === l.settings.arena ? 'selected' : ''}>${esc(a.label)}</option>`).join('');
        const fee = (p) => (p > 0 ? t('fee', p) : '');
        const bets = l.bets;
        const canBetTeams = (() => {
            if (!member) return ['A', 'B'];
            if (c.participantBets === 'none') return [];
            if (c.participantBets === 'own') return [mine ? mine.team : 'A'];
            return ['A', 'B'];
        })();
        if (!canBetTeams.includes(S.betTeam)) S.betTeam = canBetTeams[0] || 'A';
        const betTot = Math.max(1, bets.pot);
        const allReady = l.members.length > 0 && l.members.every((m) => m.ready);

        $('#lobby').innerHTML = `<div class="lobby">
            <div class="col">
                <div class="row"><span class="lbl" style="margin:0">${t('lobby_players')}</span><span class="spacer"></span>${stateTag(l.state)}</div>
                <div class="teams">${teamCol('A')}${teamCol('B')}</div>
                <p class="hint">${t('host')} : <b>${esc(l.hostName)}</b></p>
                <div class="actions">
                    ${member && open ? `<button class="btn ${mine && mine.ready ? '' : 'primary'}" data-act="ready">${mine && mine.ready ? t('set_unready') : t('set_ready')}</button>` : ''}
                    ${isHost && open ? `<button class="btn" data-act="shuffle">${t('shuffle')}</button>
                        <button class="btn primary" data-act="launch" ${allReady && l.a === l.b && l.a > 0 ? '' : 'disabled'}>▶ ${t('launch')}</button>` : ''}
                    ${member ? `<button class="btn danger" data-act="leave">${t('leave')}</button>` : ''}
                </div>
            </div>
            <div class="col card">
                <span class="lbl">${t('settings')}</span>
                ${!isHost ? `<p class="hint">${t('host_only')}</p>` : ''}
                <div><label>${t('mode')}</label>${seg('mode', c.modes.map((m) => m.id), l.settings.mode)}</div>
                <div><label>${t('wins_to_win')}</label>${seg('wins', c.wins, l.settings.wins)}</div>
                <div><label>${t('round_time')}</label>${seg('roundTime', c.roundTimes, l.settings.roundTime, (v) => t('seconds', v))}</div>
                <div class="set-grid">
                    <div><label>${t('arena')}</label><select class="input" data-set-sel="arena" ${dis}>${arenas}</select></div>
                    <div><label>${t('stake_set')}</label><input class="input" type="number" min="${c.stake.min}" max="${c.stake.max}" step="${c.stake.step}" value="${l.settings.stake}" data-set-num="stake" ${dis}></div>
                </div>
                ${c.ff ? `<div class="chk ${l.settings.friendlyFire ? 'on' : 'off'}" ${isHost && open ? 'data-set-ff' : ''}>${l.settings.friendlyFire ? '☑' : '☐'} ${t('ff')}</div>` : ''}
                <div><label>${t('weapons_allowed')}</label><div class="wpick">${wps}</div></div>
            </div>
            <div class="col">
                <div class="card">
                    <span class="lbl">${t('stake_title')}</span>
                    <div class="pot"><b>${money(l.stakePot)}</b><span class="hint">${l.settings.stake > 0 ? t('stake_each', l.settings.stake.toLocaleString('fr-FR')) : t('stake_none')}</span></div>
                    ${member && open && l.settings.stake > 0 ? (mine && mine.paid ? `<p class="hint" style="color:var(--ok)">✔ ${t('stake_paid_ok')}</p>`
                        : `<button class="btn primary" data-act="stake" style="margin-top:8px">${t('stake_pay', l.settings.stake.toLocaleString('fr-FR'))}</button>`) : ''}
                    <p class="hint" style="margin-top:8px">${t('stake_rules', fee(c.fee.stake))}</p>
                </div>
                ${c.bet.enabled ? `<div class="card">
                    <span class="lbl">${t('bet_title')}</span>
                    <div class="pot"><b>${money(bets.pot)}</b><span class="hint">${t('bet_pot')}</span></div>
                    <div class="betbar"><i class="ia" style="width:${(bets.A / betTot) * 100}%"></i><i class="ib" style="width:${(bets.B / betTot) * 100}%"></i></div>
                    <div class="row hint"><span style="color:var(--A)">${esc(teamName('A'))} ${money(bets.A)}</span><span class="spacer"></span><span style="color:var(--B)">${money(bets.B)} ${esc(teamName('B'))}</span></div>
                    ${bets.mine ? `<p style="margin-top:8px">${esc(t('bet_mine', bets.mine.amount.toLocaleString('fr-FR'), teamName(bets.mine.team)))}</p>
                        ${bets.open ? `<button class="btn small danger" data-act="unbet" style="margin-top:6px">${t('bet_cancel')}</button>` : ''}`
                    : !bets.open ? `<p class="hint" style="margin-top:8px">${t('bet_closed')}</p>`
                    : canBetTeams.length === 0 ? `<p class="hint" style="margin-top:8px">${t('none_bet')}</p>`
                    : `<div style="margin-top:10px"><label>${t('bet_on')}</label>
                        <div class="seg">${canBetTeams.map((k) => `<button class="${S.betTeam === k ? 'on' : ''}" data-betteam="${k}">${esc(teamName(k))}</button>`).join('')}</div>
                        ${member && c.participantBets === 'own' ? `<p class="hint" style="margin-top:4px">${t('own_only')}</p>` : ''}
                        <label style="margin-top:10px">${t('bet_amount')}</label>
                        <div class="row"><input class="input" type="number" min="${c.bet.min}" max="${c.bet.max}" id="bet-amount" value="${esc(S.betAmount)}" placeholder="${c.bet.min} – ${c.bet.max}" style="flex:1">
                        <button class="btn primary" data-act="bet">${t('bet_place')}</button></div></div>`}
                    <p class="hint" style="margin-top:8px">${t('bet_rules', fee(c.fee.bet))}</p>
                </div>` : ''}
            </div>
        </div>`;
    }

    function show(view) {
        S.view = view;
        $('#home').classList.toggle('hidden', view !== 'home');
        $('#lobby').classList.toggle('hidden', view !== 'lobby');
        $('#crumb-lobby').classList.toggle('hidden', view !== 'lobby');
        if (view === 'lobby' && S.lobby) $('#crumb-lobby').textContent = S.lobby.name;
        if (view === 'home') renderHome(); else renderLobby();
    }

    /* ---------------------------------------------------------------- actions du menu */
    document.addEventListener('click', async (e) => {
        const el = e.target.closest('[data-act],[data-join],[data-watch],[data-team-switch],[data-set],[data-wtoggle],[data-set-ff],[data-betteam],[data-open-mine],#crumb-home');
        if (!el) return;
        if (el.id === 'crumb-home') { if (S.lobby && !S.lobby.member) await call('close'); return show('home'); }
        if (el.dataset.openMine !== undefined) return show('lobby');
        if (el.dataset.join) {
            const r = await call('join', el.dataset.join, el.dataset.team);
            if (r && r.ok) { const w = await call('watch', el.dataset.join); if (w && w.ok) { S.lobby = w.data; show('lobby'); } }
            return;
        }
        if (el.dataset.watch) { const w = await call('watch', el.dataset.watch); if (w && w.ok) { S.lobby = w.data; show('lobby'); } return; }
        if (el.dataset.teamSwitch) return call('team', el.dataset.teamSwitch);
        if (el.dataset.set) return call('configure', { [el.dataset.set]: isNaN(Number(el.dataset.v)) ? el.dataset.v : Number(el.dataset.v) });
        if (el.dataset.setFf !== undefined) return call('configure', { friendlyFire: !S.lobby.settings.friendlyFire });
        if (el.dataset.wtoggle) {
            if (!S.lobby || S.lobby.host !== S.lobby.me || S.lobby.state !== 'LOBBY') return;
            const set = new Set(S.lobby.settings.weapons);
            if (set.has(el.dataset.wtoggle)) set.delete(el.dataset.wtoggle); else set.add(el.dataset.wtoggle);
            if (set.size === 0) return;
            return call('configure', { weapons: [...set] });
        }
        if (el.dataset.betteam) { S.betTeam = el.dataset.betteam; return renderLobby(); }
        const a = el.dataset.act;
        if (a === 'close') return closeMenu();
        if (a === 'create') {
            S.mode = ($('#create-mode') || {}).value || S.mode;
            const r = await call('create', { mode: S.mode });
            if (r && r.ok) { const w = await call('watch', r.data); if (w && w.ok) { S.lobby = w.data; show('lobby'); } }
            return;
        }
        if (a === 'leave') { const r = await call('leave'); if (r && r.ok) { S.lobby = null; show('home'); } return; }
        if (a === 'ready') { const mine = S.lobby.members.find((m) => m.id === S.lobby.me); return call('ready', !(mine && mine.ready)); }
        if (a === 'shuffle') return call('shuffle');
        if (a === 'launch') return call('launch');
        if (a === 'stake') {
            const amt = S.lobby.settings.stake;
            if (await confirmBox(t('stake_confirm'), t('stake_confirm_txt', amt.toLocaleString('fr-FR'), accountLabel()))) call('stake');
            return;
        }
        if (a === 'bet') {
            const amt = Math.floor(Number(($('#bet-amount') || {}).value) || 0);
            const c = S.config.bet;
            if (amt < c.min || amt > c.max) return toast(`${c.min} – ${c.max} $`, 'error');
            if (await confirmBox(t('bet_confirm'), t('bet_confirm_txt', amt.toLocaleString('fr-FR'), accountLabel(), teamName(S.betTeam)))) {
                const r = await call('bet', S.lobby.uid, S.betTeam, amt);
                if (r && r.ok) S.betAmount = '';
            }
            return;
        }
        if (a === 'unbet') return call('unbet', S.lobby.uid);
    });
    document.addEventListener('input', (e) => { if (e.target.id === 'bet-amount') S.betAmount = e.target.value; });
    document.addEventListener('change', (e) => {
        const el = e.target;
        if (el.dataset.setSel) call('configure', { [el.dataset.setSel]: el.value });
        if (el.dataset.setNum) call('configure', { [el.dataset.setNum]: Math.floor(Number(el.value) || 0) });
    });

    function closeMenu() {
        $('#menu').classList.add('hidden');
        $('#modal').classList.add('hidden');
        post('close');
    }

    /* ---------------------------------------------------------------- choix d'arme */
    function renderWeapons() {
        const cats = S.config ? S.config.weapons : [];
        const allowed = new Set(S.allowed);
        const visible = cats.filter((c) => c.weapons.some((w) => allowed.has(w.name.toUpperCase())));
        if (!S.wpTab || !visible.some((c) => c.id === S.wpTab)) S.wpTab = visible[0] && visible[0].id;
        $('#wp-tabs').innerHTML = visible.map((c) => `<button class="wp-tab ${c.id === S.wpTab ? 'on' : ''}" data-wtab="${esc(c.id)}">${esc(c.icon || '')} ${esc(c.label)}</button>`).join('');
        const cat = visible.find((c) => c.id === S.wpTab);
        const stat = (k, v) => `<div class="stat"><span>${t('st_' + k)}</span><div class="sb"><i style="width:${Math.max(0, Math.min(100, v || 0))}%"></i></div></div>`;
        $('#wp-grid').innerHTML = cat ? cat.weapons.filter((w) => allowed.has(w.name.toUpperCase())).map((w) => `
            <button class="wcard ${S.pick === w.name.toUpperCase() ? 'on' : ''}" data-wpick="${esc(w.name.toUpperCase())}">
                <div><h4>${esc(w.label)}</h4><span class="wid">${esc(w.name.replace('WEAPON_', ''))}</span></div>
                ${stat('damage', w.stats.damage)}${stat('rate', w.stats.rate)}${stat('range', w.stats.range)}${stat('accuracy', w.stats.accuracy)}
            </button>`).join('') : '';
        const chosen = S.chosen ? (cats.flatMap((c) => c.weapons).find((w) => w.name.toUpperCase() === S.chosen) || {}).label : null;
        $('#wp-hint').textContent = chosen ? t('wp_chosen', chosen) : t('wp_default');
        $('#wp-confirm').disabled = !S.pick;
    }
    document.addEventListener('click', async (e) => {
        const tab = e.target.closest('[data-wtab]');
        if (tab) { S.wpTab = tab.dataset.wtab; return renderWeapons(); }
        const c = e.target.closest('[data-wpick]');
        if (c) { S.pick = c.dataset.wpick; return renderWeapons(); }
        if (e.target.closest('#wp-confirm') && S.pick) {
            const r = await call('pick', S.pick);
            if (r && r.ok) {
                S.chosen = r.data;
                renderWeapons();
                const w = (S.config ? S.config.weapons : []).flatMap((c) => c.weapons).find((x) => x.name.toUpperCase() === r.data);
                toast(t('wp_chosen', w ? w.label : r.data), 'success');
            }
        }
    });
    function ring(el, timerEl, end, total) {
        const left = Math.max(0, (end - Date.now()) / 1000);
        if (el) el.style.strokeDashoffset = String(119.4 * (1 - left / Math.max(1, total)));
        if (timerEl) timerEl.textContent = Math.ceil(left);
        return left;
    }

    /* ---------------------------------------------------------------- HUD */
    function fmtTime(s) { s = Math.max(0, Math.ceil(s)); return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`; }
    function renderHud() {
        const h = S.hud;
        if (!h) return;
        $('#hud-na').textContent = h.teams.A.name; $('#hud-nb').textContent = h.teams.B.name;
        $('#hud-sa').textContent = h.score.A; $('#hud-sb').textContent = h.score.B;
        $('#hud-round').textContent = t('round', h.round);
        const pips = (k) => h.roster.filter((r) => r.team === k && !r.left).map((r) => `<i class="${r.alive ? '' : 'dead'}" title="${esc(r.name)}"></i>`).join('');
        $('#hud-pa').innerHTML = pips('A'); $('#hud-pb').innerHTML = pips('B');
        $('#hud-wins').textContent = t('first_to', h.wins);
        $('#myteam').innerHTML = `${t('team_you')} · <span style="color:var(--${S.myTeam})">${esc(h.teams[S.myTeam] ? h.teams[S.myTeam].name : '')}</span>`;
    }
    setInterval(() => {
        if (S.roundEnd) {
            const left = (S.roundEnd - Date.now()) / 1000;
            const el = $('#hud-time');
            el.textContent = fmtTime(left);
            el.classList.toggle('low', left <= 10);
        }
        if (S.wpEnd && !$('#weapons').classList.contains('hidden')) ring($('#wp-ring'), $('#wp-timer'), S.wpEnd, S.wpTotal);
    }, 250);

    function center(text, sub) {
        const c = $('#center');
        c.className = 'center';
        void c.offsetWidth;
        c.innerHTML = `${sub ? `<small>${esc(sub)}</small>` : ''}${esc(text)}`;
        c.classList.add('pop');
    }
    function banner(cls, title, sub, ms) {
        const b = $('#banner');
        b.className = `banner ${cls}`;
        b.innerHTML = `<h2>${esc(title)}</h2>${sub ? `<p>${esc(sub)}</p>` : ''}`;
        clearTimeout(S.timers.banner);
        S.timers.banner = setTimeout(() => b.classList.add('hidden'), ms || 3500);
    }

    /* ---------------------------------------------------------------- fin de partie */
    function renderEnd(s) {
        const box = $('#end');
        const my = S.myTeam;
        let title, cls;
        if (s.cancelled) { title = t('cancelled'); cls = 'cancel'; } else if (s.winner === my) { title = t('victory'); cls = 'win'; } else { title = t('defeat'); cls = 'lose'; }
        const rows = (s.players || []).slice().sort((a, b) => (a.team === b.team ? b.kills - a.kills : a.team < b.team ? -1 : 1)).map((p) => `<tr>
            <td class="${p.team}">${esc(p.name)}${p.left ? ` <span class="hint">(${t('left')})</span>` : ''}</td><td>${p.kills}</td><td>${p.deaths}</td>
            <td>${(p.kills / Math.max(1, p.deaths)).toFixed(2)}</td><td>${p.won > 0 ? money(p.won) : '—'}</td></tr>`).join('');
        const m = s.mine || { stake: 0, won: 0, bet: 0, betWon: 0 };
        box.innerHTML = `<div class="endbox"><h1 class="${cls}">${esc(title)}</h1>
            <div class="fscore"><span class="A">${esc(s.teams.A.name)} ${s.score.A}</span><span class="hint">—</span><span class="B">${s.score.B} ${esc(s.teams.B.name)}</span></div>
            ${s.cancelled ? `<p class="hint" style="text-align:center">${esc(s.reason || '')} · ${t('end_refund')}</p>` : `
            <table><tr><th>${t('col_player')}</th><th>${t('col_kills')}</th><th>${t('col_deaths')}</th><th>${t('col_kd')}</th><th>${t('col_won')}</th></tr>${rows}</table>
            <div class="money">
                <div><small>${t('end_stake')}</small><b>${money(m.stake)}</b></div>
                <div><small>${t('end_won')}</small><b class="${m.won + m.betWon > 0 ? 'pos' : ''}">${money(m.won + m.betWon)}</b></div>
                <div><small>${t('end_pot')}</small><b>${money(s.stakePot)}</b></div>
                <div><small>${t('end_betpot')}</small><b>${money(s.betPot)}</b>${s.betRefunded ? '<small>↺</small>' : ''}</div>
            </div>`}
            <p class="endfoot" id="end-foot"></p></div>`;
        box.classList.remove('hidden');
        const end = Date.now() + (s.seconds || 10) * 1000;
        clearInterval(S.timers.end);
        S.timers.end = setInterval(() => {
            const left = Math.max(0, Math.ceil((end - Date.now()) / 1000));
            const f = $('#end-foot'); if (f) f.textContent = t('end_back', left);
            if (left <= 0) clearInterval(S.timers.end);
        }, 250);
    }

    /* ---------------------------------------------------------------- messages du jeu */
    window.addEventListener('message', (e) => {
        const d = e.data || {};
        switch (d.action) {
            case 'open':
                S.config = d.data.config;
                S.list = d.data.list || [];
                S.lobby = d.data.mine || null;
                if (S.config.ui) { document.documentElement.style.setProperty('--accent', S.config.ui.accent); document.documentElement.style.setProperty('--accent2', S.config.ui.accent2); }
                if (S.config.teams) { document.documentElement.style.setProperty('--A', S.config.teams.A.color); document.documentElement.style.setProperty('--B', S.config.teams.B.color); }
                $('#menu').classList.remove('hidden');
                show(S.lobby ? 'lobby' : 'home');
                break;
            case 'list': S.list = d.list || []; if (S.view === 'home' && !$('#menu').classList.contains('hidden')) renderHome(); break;
            case 'lobby':
                S.lobby = d.lobby;
                if (!$('#menu').classList.contains('hidden')) { if (S.view === 'lobby') renderLobby(); else renderHome(); }
                break;
            case 'closed':
                if (S.lobby && S.lobby.uid === d.uid) { S.lobby = null; if (!$('#menu').classList.contains('hidden')) show('home'); }
                break;
            case 'toast': toast(d.text, d.kind); break;
            case 'betResult': {
                const r = d.result, el = $('#betres');
                el.textContent = r.refunded ? t('betres_refund', r.bet) : r.won > 0 ? t('betres_win', r.won.toLocaleString('fr-FR')) : t('betres_lose', r.bet.toLocaleString('fr-FR'));
                el.classList.remove('hidden');
                setTimeout(() => el.classList.add('hidden'), 6000);
                break;
            }
            case 'enter':
                S.myTeam = d.data.team;
                if (d.data.teams) S.config = Object.assign(S.config || {}, { teams: d.data.teams });
                $('#menu').classList.add('hidden');
                $('#end').classList.add('hidden');
                $('#hud').classList.remove('hidden');
                break;
            case 'weapons':
                S.allowed = d.data.allowed || [];
                S.pick = S.chosen && S.allowed.includes(S.chosen) ? S.chosen : null;
                S.chosen = null;
                S.wpTotal = d.data.seconds; S.wpEnd = Date.now() + d.data.seconds * 1000;
                $('#wp-round').textContent = t('wp_round', d.data.round);
                $('#spec').classList.add('hidden');
                $('#weapons').classList.remove('hidden');
                renderWeapons();
                break;
            case 'hideWeapons': $('#weapons').classList.add('hidden'); break;
            case 'countdown': {
                let n = d.seconds;
                S.roundEnd = 0; $('#hud-time').textContent = '--';
                center(String(n), t('round', d.round));
                clearInterval(S.timers.cd);
                S.timers.cd = setInterval(() => { n -= 1; if (n > 0) center(String(n), t('round', d.round)); else clearInterval(S.timers.cd); }, 1000);
                break;
            }
            case 'roundStart': clearInterval(S.timers.cd); center(t('go')); S.roundEnd = Date.now() + d.seconds * 1000; break;
            case 'roundEnd': {
                S.roundEnd = 0;
                const w = d.data.winner;
                banner(w ? (w === d.myTeam ? 'win' : 'lose') : 'draw', w ? (w === d.myTeam ? t('round_won') : t('round_lost')) : t('round_draw'),
                    `${d.data.score.A} — ${d.data.score.B} · ${d.data.reason || ''}`, 4000);
                break;
            }
            case 'hud': S.hud = d.hud; S.myTeam = d.myTeam || S.myTeam; renderHud(); break;
            case 'killfeed': {
                const k = d.kill, el = document.createElement('div');
                el.className = 'kill';
                el.innerHTML = k.killer ? `<span class="${k.killerTeam}">${esc(k.killer)}</span><span class="w">✦ ${esc(String(k.weapon || '').replace('WEAPON_', ''))}</span><span class="${k.victimTeam}">${esc(k.victim)}</span>`
                    : `<span class="w">☠</span><span class="${k.victimTeam}">${esc(k.victim)}</span>`;
                $('#feed').prepend(el);
                setTimeout(() => el.remove(), 6000);
                while ($('#feed').children.length > 5) $('#feed').lastChild.remove();
                break;
            }
            case 'eliminated': $('#spec').innerHTML = `<h3>${t('eliminated')}</h3><p>${t('spectating')}</p>`; $('#spec').classList.remove('hidden'); break;
            case 'spectating': break;
            case 'zoneWarn': banner('warn', t('zone'), '', 2000); break;
            case 'matchEnd': $('#weapons').classList.add('hidden'); $('#spec').classList.add('hidden'); S.roundEnd = 0; renderEnd(d.summary); break;
            case 'exit':
                ['#hud', '#end', '#weapons', '#menu', '#modal', '#spec'].forEach((s) => $(s).classList.add('hidden'));
                S.hud = null; S.roundEnd = 0; S.lobby = null; S.myTeam = null;
                break;
        }
    });

    document.addEventListener('keydown', (e) => {
        if (e.key !== 'Escape') return;
        if (!$('#modal').classList.contains('hidden')) { $('#modal').classList.add('hidden'); return; }
        if (!$('#menu').classList.contains('hidden')) return closeMenu();
        if (!$('#weapons').classList.contains('hidden')) { post('pickClosed'); }
    });
})();
