/* =========================================================
   ARRIVÉE EN VILLE : affichage de la cinématique (piloté par le jeu)
   + onglet ✨ Arrivée en ville (permission « manage_welcome »)
   ========================================================= */
(() => {
    const W = document.getElementById('welcome');
    const el = (id) => document.getElementById(id);
    const PARTS = { head: 'Tête', torso: 'Buste', legs: 'Jambes', feet: 'Pieds' };
    const STATUS = { head: 'Reconstruction faciale', torso: 'Morphologie du buste', legs: 'Structure des jambes', feet: 'Finalisation' };
    let dataTimer = null;
    const hex = () => Array.from({ length: 6 }, () => Math.floor(Math.random() * 65536).toString(16).padStart(4, '0').toUpperCase()).join(' ');

    window.addEventListener('message', (e) => {
        const m = e.data || {};
        if (m.action !== 'welcome') return;
        switch (m.stage) {
            case 'intro':
                W.classList.remove('hidden', 'out');
                el('wlIntro').classList.remove('hidden');
                el('wlScan').classList.add('hidden');
                el('wlOutro').classList.add('hidden');
                el('wlTitle').textContent = m.title || 'Bienvenue sur';
                el('wlName').textContent = m.name || 'Elyzea FA';
                el('wlName').dataset.text = m.name || 'Elyzea FA';
                return;
            case 'scan': {
                el('wlIntro').classList.add('hidden');
                el('wlScan').classList.remove('hidden');
                const l = el('wlScan').querySelector('.wl-line');
                l.style.animation = 'none'; void l.offsetWidth; l.style.animation = '';
                el('wlSteps').innerHTML = Object.entries(PARTS).map(([k, v]) => `<div class="wl-step" data-part="${k}"><span>${v}</span><b>…</b></div>`).join('');
                el('wlStatus').className = 'wl-status';
                el('wlStatus').textContent = 'Initialisation…';
                el('wlBar').style.width = '0%';
                el('wlPct').textContent = '0 %';
                clearInterval(dataTimer);
                dataTimer = setInterval(() => {
                    const d = el('wlData');
                    d.innerHTML = `${hex()}<br>` + d.innerHTML.split('<br>').slice(0, 4).join('<br>');
                }, 120);
                return;
            }
            case 'part':
                document.querySelectorAll('.wl-step').forEach((s, i) => {
                    s.classList.toggle('ok', i + 1 < m.index);
                    s.classList.toggle('active', i + 1 === m.index);
                    s.querySelector('b').textContent = i + 1 < m.index ? '✓' : i + 1 === m.index ? '' : '…';
                });
                el('wlStatus').textContent = STATUS[m.part] || '';
                return;
            case 'progress':
                el('wlBar').style.width = `${m.pct}%`;
                el('wlPct').textContent = `${m.pct} %`;
                return;
            case 'done':
                document.querySelectorAll('.wl-step').forEach((s) => { s.className = 'wl-step ok'; s.querySelector('b').textContent = '✓'; });
                el('wlStatus').className = 'wl-status done';
                el('wlStatus').textContent = 'Citoyen généré ✓';
                clearInterval(dataTimer);
                return;
            case 'outro':
                el('wlScan').classList.add('hidden');
                el('wlOutro').classList.remove('hidden');
                el('wlMsg').textContent = m.message || '';
                el('wlSign').textContent = m.signature ? `— ${m.signature}` : '';
                return;
            case 'end':
                W.classList.add('out');
                setTimeout(() => { W.classList.add('hidden'); W.classList.remove('out'); }, 1200);
        }
    });

    /* ---------- Onglet du menu admin ---------- */
    const at = TABS.findIndex((t) => t.id === 'respawn');
    TABS.splice(at < 0 ? TABS.length : at + 1, 0, {
        id: 'welcome', group: 2, label: 'Arrivée en ville', ico: '✨',
        sub: 'Cinématique de bienvenue quand un joueur valide son nouveau personnage.',
        show: () => has('manage_welcome') && !!(D && D.welcome),
    });
    const F = { draft: null };

    VIEWS.welcome = () => {
        const w = D.welcome;
        if (!F.draft) F.draft = { enabled: w.enabled, title: w.title, name: w.name, message: w.message, signature: w.signature };
        const d = F.draft;
        return `
            <p class="hint">${w.creator ? 'Quand un joueur <b>valide son nouveau personnage dans ely_creator</b>, il voit'
                : 'À la <b>toute première arrivée en ville</b> de chaque personnage, il voit'} : le titre de bienvenue, puis sa génération « cyber »
                (la caméra descend de la tête aux pieds pendant que le corps se matérialise), puis le message final.
                Une seule fois par personnage. ${w.seen} personnage(s) l'ont déjà vue.</p>
            <div class="section"><h2>Réglages</h2>
                <div class="tile toggle-tile ${d.enabled ? 'on' : ''}" data-wl="enabled" style="max-width:420px;margin-bottom:12px"><div><strong>Cinématique de bienvenue</strong><span>${d.enabled ? 'Active pour les nouveaux personnages' : 'Désactivée'}</span></div><div class="switch"></div></div>
                <div class="form-grid" style="grid-template-columns:1fr 1fr;max-width:820px">
                    <div><label>Titre</label><input class="input" data-wlf="title" value="${esc(d.title)}" maxlength="60"></div>
                    <div><label>Nom du serveur</label><input class="input" data-wlf="name" value="${esc(d.name)}" maxlength="40"></div>
                    <div style="grid-column:span 2"><label>Message final</label><input class="input" data-wlf="message" value="${esc(d.message)}" maxlength="240"></div>
                    <div><label>Signature</label><input class="input" data-wlf="signature" value="${esc(d.signature)}" maxlength="60"></div>
                </div>
                <div class="btn-row" style="margin-top:12px"><button class="btn primary" data-wl="save">Enregistrer</button>
                    <button class="btn" data-wl="test">▶ Voir la cinématique (sur moi)</button></div>
            </div>
            <div class="section"><h2>Rejouer pour un joueur</h2>
                <p class="hint">La cinématique se rejoue tout de suite pour lui (utile après un bug ou une déconnexion pendant la cinématique).</p>
                <div class="inline" style="max-width:420px"><input class="input" id="wl-id" inputmode="numeric" placeholder="ID du joueur">
                    <button class="btn" data-wl="replay">Rejouer</button></div>
            </div>`;
    };

    document.addEventListener('input', (e) => {
        if (!isOpen || tab !== 'welcome' || !e.target.dataset.wlf || !F.draft) return;
        F.draft[e.target.dataset.wlf] = e.target.value;
    });
    document.addEventListener('click', (e) => {
        if (!isOpen || tab !== 'welcome') return;
        const b = e.target.closest('[data-wl]');
        if (!b) return;
        switch (b.dataset.wl) {
            case 'enabled': F.draft.enabled = !F.draft.enabled; return render();
            case 'save': action('welcome_save', F.draft); F.draft = null; return;
            case 'test': post('close'); return action('welcome_test');
            case 'replay': { const id = Number((el('wl-id') || {}).value); if (!id) return toast('Entre un ID.', 'error'); return action('welcome_replay', { target: id }); }
        }
    });
})();
