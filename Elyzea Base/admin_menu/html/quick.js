/* =========================================================
   MENU RAPIDE (F9) + MESSAGES PRIVÉS À L'ÉCRAN
   Chargé après script.js : utilise D, has, esc, post, toast.
   ========================================================= */
(() => {
    'use strict';

    const Q = { open: false, nearby: [], idInput: '', selected: null, notFound: null, pm: '', sc: '', ann: '', tpc: '', view: 'main' };
    const pending = () => ((D && D.reports) || []).filter((r) => !r.claimedBy);
    const box = document.getElementById('quick');
    const self = () => (D && D.self) || {};
    const duty = () => (D && D.self && typeof D.self.duty === 'boolean') ? D.self.duty : true;
    const qpost = (name, data) => post('action', { name, data: data || {} });

    function close() { post('quick_close'); }
    function selfThen(name, data, closeFirst) {
        if (closeFirst) close();
        return post('self', { name, data: data || {} }).then((res) => {
            if (res && res.self && D) { D.self = res.self; if (Q.open) draw(); }
        });
    }

    // ---------- Rendu ----------
    function tile(perm, id, ico, label, on) {
        if (perm && !has(perm)) return '';
        return `<button class="q-tile ${on ? 'on' : ''}" data-q="${id}"><span class="q-ico">${ico}</span><span>${label}</span></button>`;
    }

    // Choisir un joueur par son ID (champ texte, Entrée pour valider)
    function pickId() {
        const id = parseInt(String(Q.idInput).trim(), 10);
        if (!id) { Q.selected = null; Q.notFound = null; return draw(); }
        const p = D && D.players.find((x) => x.id === id);
        Q.selected = p ? id : null;
        Q.notFound = p ? null : id;
        Q.pm = '';
        draw();
        if (p) setTimeout(() => { const f = document.querySelector('[data-qa]'); if (f) f.focus(); }, 30);
    }

    function playerActions(p) {
        const isAbove = p.level !== undefined && p.level >= D.me.level;
        const a = (perm, id, label, cls = '', disabled = false) => (has(perm) ? `<button class="btn ${cls}" data-qa="${id}" ${disabled ? 'disabled' : ''}>${label}</button>` : '');
        return `<div class="q-sel">
            <div class="q-sel-head"><b>${esc(p.name)}</b> <span class="muted">[${p.id}]</span>${p.rankLabel ? ` <span class="badge" style="color:${esc(p.rankColor)}">${esc(p.rankLabel)}</span>` : ''}
                ${p.frozen ? ' <span class="badge">🧊 Freeze</span>' : ''}${p.back ? ' <span class="badge">↩️ Peut être renvoyé</span>' : ''}</div>
            <div class="q-actions">
                ${a('goto', 'goto', '📍 Aller vers lui')}${a('bring', 'bring', '🧲 L\'amener', '', isAbove)}
                ${a('bring', 'bring_back', '↩️ Le renvoyer', p.back ? 'on' : '', isAbove || !p.back)}${a('spectate', 'spectate', '👁️ Spectate')}
                ${a('heal', 'heal', '❤️ Soigner')}${a('revive', 'revive', '💉 Réanimer')}${a('freeze', 'freeze', p.frozen ? '🔓 Libérer' : '🧊 Freeze', p.frozen ? 'on' : '', isAbove)}
                <button class="btn" data-qa="full">📋 Fiche complète</button>
            </div>
            ${has('staff_pm') ? `<div class="q-msg">
                <textarea class="input" id="q-pm" maxlength="300" placeholder="Message privé à ${esc(p.name)}… (Entrée pour envoyer)">${esc(Q.pm)}</textarea>
                <button class="btn primary" data-qa="pm">✉️ Envoyer le MP</button></div>` : ''}
        </div>`;
    }

    // Liste des reports pas encore pris
    function reportsView() {
        const list = pending().sort((a, b) => a.id - b.id);
        return `<div class="q-sec"><button class="btn" data-q="back">← Retour</button></div>
            <div class="q-sec"><h3>Reports en attente (${list.length})</h3>
            ${list.length ? list.map((r) => `<div class="q-rep">
                <div class="q-rep-head"><span>#${r.id} · ${esc(r.name)} <span class="muted">[${r.src}]</span></span><span class="muted">${esc(r.time || '')}</span></div>
                <div class="q-rep-msg">${esc(r.msg)}</div>
                ${r.offline ? '<p class="q-hint" style="color:var(--danger)">Joueur déconnecté.</p>' : ''}
                <div class="btn-row">
                    <button class="btn primary" data-qr="claim" data-id="${r.id}">✋ Prendre en charge</button>
                    ${!r.offline && has('goto') ? `<button class="btn" data-qr="goto" data-id="${r.id}" data-src="${r.src}">📍 Aller vers lui</button>` : ''}
                    ${!r.offline && has('bring') ? `<button class="btn" data-qr="bring" data-id="${r.id}" data-src="${r.src}">🧲 L'amener</button>` : ''}
                    <button class="btn danger" data-qr="close" data-id="${r.id}">Clôturer</button>
                </div></div>`).join('') : '<div class="q-empty">Aucun report en attente. 👍</div>'}</div>`;
    }

    function draw() {
        if (!Q.open) return;
        if (!D) { box.innerHTML = '<div class="q-panel"><div class="q-empty">Chargement…</div></div>'; return; }
        const s = self();
        const onDuty = duty();
        const sel = Q.selected && D.players.find((p) => p.id === Q.selected);
        const meTiles = [
            tile('tp_waypoint', 'tpm', '📍', 'TP au marqueur'),
            tile('noclip', 'noclip', '🕊️', 'Noclip', s.noclip),
            tile('godmode', 'godmode', '🛡️', 'Godmode', s.godmode),
            tile('invisible', 'invisible', '👻', 'Invisible', s.invisible),
            tile('player_ids', 'ids', '🏷️', 'Noms et IDs', s.showIds),
            tile('wallhack', 'wallhack', '👁️', 'Wallhack', s.wallhack),
            tile('heal', 'heal_me', '❤️', 'Me soigner'),
            tile('revive', 'revive_me', '💉', 'Me réanimer'),
            tile('vehicle_tools', 'repair', '🔧', 'Réparer mon véhicule'),
            tile('revive_area', 'revive_area', '🚑', 'Réanimer autour'),
        ].join('');

        box.innerHTML = `<div class="q-panel">
            <div class="q-head">
                <div><strong>⚡ Menu rapide</strong><span class="muted">${esc(D.me.label || '')}</span></div>
                <button class="q-duty ${onDuty ? 'on' : 'off'}" data-q="duty">${onDuty ? '🛡️ En service' : '🎭 Mode RP'}</button>
                <button class="sb-close" data-q="close" title="Fermer (Échap)">✕</button>
            </div>
            <div class="q-body">
            ${!onDuty ? `<div class="q-empty">Tu es en mode RP : reprends ton service pour utiliser les outils staff.</div>`
            : Q.view === 'reports' && has('reports') ? reportsView() : `
                ${has('reports') ? `<button class="q-reports-btn ${pending().length ? '' : 'none'}" data-q="reports"><span>📨 Reports en attente</span><span class="n">${pending().length}</span></button>` : ''}
                <div class="q-sec"><h3>Moi</h3><div class="q-grid">${meTiles}</div></div>

                ${has('tp_coords') ? `<div class="q-sec"><h3>Téléportation</h3>
                    <div class="q-tp"><input class="input" id="q-tpc" placeholder="Coordonnées : vector3(…) ou x, y, z (Entrée)" value="${esc(Q.tpc)}">
                    <button class="btn primary" data-q="tpc">📍 TP</button></div>
                    <div class="q-hint" id="q-tpc-preview">${typeof tpcPreview === 'function' ? tpcPreview(Q.tpc) : ''}</div>
                    ${typeof tpChips === 'function' ? tpChips('quick') : ''}</div>` : ''}

                <div class="q-sec"><h3>Joueur</h3>
                    <div class="q-tp"><input class="input" id="q-id" inputmode="numeric" maxlength="6" placeholder="ID du joueur (Entrée)" value="${esc(Q.idInput)}">
                    <button class="btn primary" data-q="pick">Valider</button></div>
                    ${sel ? playerActions(sel)
                        : Q.notFound ? `<p class="q-hint" style="color:var(--danger)">Aucun joueur connecté avec l'ID ${Q.notFound}.</p>`
                        : '<p class="q-hint">Entre l\'ID d\'un joueur : tu pourras aller vers lui, l\'amener, le renvoyer, le freeze, le soigner, lui écrire…</p>'}
                </div>

                ${has('staff_chat') ? `<div class="q-sec"><h3>Message aux staffs</h3>
                    <div class="q-msg"><input class="input" id="q-sc" maxlength="300" placeholder="Visible seulement par le staff… (Entrée)" value="${esc(Q.sc)}">
                    <button class="btn" data-q="sc">🛡️ Envoyer</button></div></div>` : ''}

                ${has('announce') ? `<div class="q-sec"><h3>Annonce rapide</h3>
                    <div class="q-msg"><input class="input" id="q-ann" maxlength="400" placeholder="Bandeau pour tout le serveur… (Entrée)" value="${esc(Q.ann)}">
                    <button class="btn" data-q="ann">📢 Diffuser</button></div></div>` : ''}

                <button class="btn q-full" data-q="menu">Ouvrir le menu complet</button>`}
            </div>
        </div>`;
    }

    // ---------- Actions ----------
    function sendPm() {
        const msg = Q.pm.trim();
        if (!Q.selected) return toast('Choisis un joueur.', 'error');
        if (!msg) return toast('Écris un message.', 'error');
        qpost('staff_pm', { target: Q.selected, message: msg });
        Q.pm = '';
        draw();
    }
    function goTpc() {
        const c = parseCoords(Q.tpc);
        if (!c) return toast('Coordonnées non reconnues. Exemple : 215.7, -810.1, 30.7', 'error');
        Q.tpc = '';
        close();
        tpTo(c);
    }
    function sendSc() {
        const msg = Q.sc.trim();
        if (!msg) return toast('Écris un message.', 'error');
        qpost('staff_chat', { message: msg });
        Q.sc = '';
        draw();
    }
    function sendAnn() {
        const msg = Q.ann.trim();
        if (!msg) return toast('Écris le texte de l\'annonce.', 'error');
        qpost('announce', { title: '', message: msg, image: 'logo', style: 'info', duration: 10, ticker: false });
        Q.ann = '';
        draw();
    }

    box.addEventListener('click', (e) => {
        const chip = e.target.closest('[data-tpc], [data-tpcfav], [data-tpcdel]');
        if (chip) {
            if (chip.dataset.tpc) {
                const [, kind, i] = chip.dataset.tpc.split(':');
                const c = tpLoad(kind === 'fav' ? TP_FAV : TP_HIST)[Number(i)];
                if (c) { close(); tpTo(c); }
            } else if (chip.dataset.tpcdel !== undefined) {
                const fav = tpLoad(TP_FAV); fav.splice(Number(chip.dataset.tpcdel), 1); tpStore(TP_FAV, fav); draw();
            } else {
                tpFavorite(tpLoad(TP_HIST)[Number(chip.dataset.tpcfav)]).then(draw);
            }
            return;
        }
        const t = e.target.closest('[data-q], [data-qp], [data-qa], [data-qr]');
        if (!t) {
            if (e.target === box) close(); // clic à côté du panneau
            return;
        }
        if (t.dataset.qp) { Q.selected = Number(t.dataset.qp); Q.pm = ''; return draw(); }
        if (t.dataset.qr) {
            const id = Number(t.dataset.id), src = Number(t.dataset.src);
            switch (t.dataset.qr) {
                case 'claim': return qpost('report_claim', { id });
                case 'goto': qpost('report_claim', { id }); close(); return qpost('goto', { target: src });
                case 'bring': qpost('report_claim', { id }); return qpost('bring', { target: src });
                case 'close': return qpost('report_close', { id });
            }
            return;
        }
        const me = D.me.id;
        if (t.dataset.qa) {
            const id = Q.selected;
            switch (t.dataset.qa) {
                case 'goto': close(); return qpost('goto', { target: id });
                case 'spectate': close(); return qpost('spectate', { target: id });
                case 'bring': case 'bring_back': case 'heal': case 'revive': case 'freeze': return qpost(t.dataset.qa, { target: id });
                case 'full': return post('quick_full', { id });
                case 'pm': return sendPm();
            }
            return;
        }
        switch (t.dataset.q) {
            case 'close': return close();
            case 'reports': Q.view = 'reports'; return draw();
            case 'back': Q.view = 'main'; return draw();
            case 'pick': return pickId();
            case 'duty': return selfThen('duty');
            case 'tpm': return selfThen('tp_waypoint', null, true);
            case 'noclip': return selfThen('noclip', null, true);
            case 'godmode': return selfThen('godmode');
            case 'invisible': return selfThen('invisible');
            case 'ids': return selfThen('showIds');
            case 'wallhack': return selfThen('wallhack');
            case 'heal_me': return qpost('heal', { target: me });
            case 'revive_me': return qpost('revive', { target: me });
            case 'repair': return qpost('vehicle_tool', { tool: 'repair' });
            case 'revive_area': return selfThen('revive_preview', { radius: (D.config && D.config.reviveRadius) || 30 }, true);
            case 'sc': return sendSc();
            case 'tpc': return goTpc();
            case 'ann': return sendAnn();
            case 'menu': return post('quick_full', {});
        }
    });

    box.addEventListener('input', (e) => {
        const t = e.target;
        if (t.id === 'q-id') { t.value = t.value.replace(/\D/g, ''); Q.idInput = t.value; }
        if (t.id === 'q-pm') Q.pm = t.value;
        if (t.id === 'q-sc') Q.sc = t.value;
        if (t.id === 'q-ann') Q.ann = t.value;
        if (t.id === 'q-tpc') {
            Q.tpc = t.value;
            const pv = document.getElementById('q-tpc-preview');
            if (pv) pv.innerHTML = tpcPreview(t.value);
        }
    });

    box.addEventListener('keydown', (e) => {
        if (e.key !== 'Enter' || e.shiftKey) return;
        if (e.target.id === 'q-id') { e.preventDefault(); pickId(); }
        if (e.target.id === 'q-pm') { e.preventDefault(); sendPm(); }
        if (e.target.id === 'q-sc') { e.preventDefault(); sendSc(); }
        if (e.target.id === 'q-ann') { e.preventDefault(); sendAnn(); }
        if (e.target.id === 'q-tpc') { e.preventDefault(); goTpc(); }
    });

    document.addEventListener('keydown', (e) => {
        if (!Q.open) return;
        if (e.key === 'Escape' || e.key === 'F9') { e.preventDefault(); close(); }
    });

    // ---------- Messages Lua ----------
    window.addEventListener('message', (ev) => {
        const m = ev.data;
        if (!m) return;
        if (m.action === 'reportHud') {
            const el = document.getElementById('reporthud');
            const n = Number(m.count) || 0;
            const before = Number(el.dataset.n || 0);
            el.dataset.n = n;
            if (n <= 0) { el.classList.add('hidden'); return; }
            const key = (D && D.keys && (D.keys.find((k) => k.label === 'Menu rapide') || {}).current) || 'F9';
            el.innerHTML = `📨 ${n} REPORT${n > 1 ? 'S' : ''} EN ATTENTE<small>${esc(typeof keyName === 'function' ? keyName(key) : key)} › Reports</small>`;
            el.classList.remove('hidden');
            if (n > before) { el.classList.remove('pulse'); void el.offsetWidth; el.classList.add('pulse'); }
            return;
        }
        if (m.action === 'quick') {
            Q.open = !!m.open;
            if (Q.open) Q.view = m.view === 'reports' ? 'reports' : 'main';
            box.classList.toggle('hidden', !Q.open);
            document.body.classList.toggle('quick-open', Q.open);
            if (Q.open) {
                Q.nearby = Array.isArray(m.nearby) ? m.nearby : [];
                if (Q.selected && D && !D.players.find((p) => p.id === Q.selected)) { Q.selected = null; Q.idInput = ''; }
                Q.notFound = null;
                draw();
                setTimeout(() => { const s = document.getElementById('q-id'); if (s) { s.focus(); s.select(); } }, 30);
            } else {
                box.innerHTML = '';
            }
            return;
        }
        if (m.action === 'data' && Q.open) {
            // On ne casse pas une saisie en cours
            const a = document.activeElement;
            if (a && box.contains(a) && ['INPUT', 'TEXTAREA'].includes(a.tagName)) return;
            draw();
            return;
        }
        if (m.action === 'pm') showPm(m.data || {});
    });

    // =====================================================
    //  MESSAGES PRIVÉS À L'ÉCRAN
    // =====================================================
    const stack = document.getElementById('pmstack');
    function showPm(p) {
        let head = '', foot = '', cls = p.kind || 'staff', dur = Number(p.duration) || 15;
        const rank = p.rank ? ` <span class="pm-rank" style="color:${esc(p.color || '#d9b56a')}">${esc(p.rank)}</span>` : '';
        if (p.kind === 'staff') {
            head = `✉️ Message du staff · <b>${esc(p.from)}</b>${rank}`;
            foot = `Réponds avec <span class="keycap">/${esc(p.reply || 'r')} ton message</span>`;
        } else if (p.kind === 'reply') {
            head = `↩️ Réponse de <b>${esc(p.from)}</b>`;
            foot = `Lui répondre : <span class="keycap">/${esc(p.reply || 'mp')} ${esc(p.fromId)} ton message</span> ou le menu rapide`;
        } else if (p.kind === 'staffchat') {
            head = `🛡️ Staff · <b>${esc(p.from)}</b>${rank}`;
        } else if (p.kind === 'sent') {
            head = `✉️ MP envoyé à <b>${esc(p.to)}</b>`;
            dur = 6;
        } else if (p.kind === 'sentReply') {
            head = '↩️ Réponse envoyée au staff';
            dur = 5;
        } else {
            return;
        }
        const card = document.createElement('div');
        card.className = `pm-card pm-${cls}`;
        if (p.color && (p.kind === 'staff' || p.kind === 'staffchat')) card.style.setProperty('--pmc', p.color);
        card.innerHTML = `<div class="pm-head">${head}</div><div class="pm-text">${esc(p.message || '')}</div>
            ${foot ? `<div class="pm-foot">${foot}</div>` : ''}<div class="pm-bar" style="animation-duration:${dur}s"></div>`;
        stack.prepend(card);
        while (stack.children.length > 4) stack.lastChild.remove();
        setTimeout(() => { card.classList.add('pm-out'); setTimeout(() => card.remove(), 350); }, dur * 1000);
    }
})();
