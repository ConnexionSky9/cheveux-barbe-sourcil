/* =========================================================
   ELYZEA CASINO - interface (guichet, blackjack, roulette, roue de la fortune)
   L'interface n'envoie que des demandes ; le serveur vérifie tout et renvoie l'état.
   ========================================================= */
const $ = (id) => document.getElementById(id);
const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'elyzea_casino';
const post = (name, data = {}) => fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) })
    .then((r) => r.json()).catch(() => ({}));
const fmt = (n) => Number(n || 0).toLocaleString('fr-FR');
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const nonce = () => `${Date.now()}-${Math.floor(Math.random() * 1e9)}`;

function toast(msg, type = 'info') {
    if (!msg) return;
    const d = document.createElement('div');
    d.className = type; d.textContent = msg;
    $('toast').appendChild(d);
    setTimeout(() => d.remove(), 3500);
}

const CHIP_VALUES = [10, 50, 100, 500, 1000, 5000, 25000];
const CHIP_COLORS = { 10: '#1e4fd6', 50: '#c8102e', 100: '#151515', 500: '#7b1fa2', 1000: '#d4af37', 5000: '#0a7d3b', 25000: '#e67e22' };
const SUIT = { c: '♣', d: '♦', h: '♥', s: '♠' };

// Cartes : seules les nouvelles s'animent (les autres restent en place), la carte cachée se retourne en 3D
const SEEN = new Map();   // clé → 'up' | 'down'
function cardHtml(c, key) {
    const was = key ? SEEN.get(key) : undefined;
    if (!c || c.hidden) {
        if (key) SEEN.set(key, 'down');
        return `<div class="card back ${was ? 'still' : ''}"><div class="f"></div><div class="b"></div></div>`;
    }
    if (key) SEEN.set(key, 'up');
    const red = c.s === 'd' || c.s === 'h';
    const anim = was === 'down' ? 'flip' : was === 'up' ? 'still' : '';
    return `<div class="card ${red ? 'red' : ''} ${anim}"><div class="f"><span>${esc(c.r)}</span><span class="s">${SUIT[c.s] || ''}</span></div><div class="b"></div></div>`;
}

let myChips = null;
function refreshChips() {
    post('chips').then((r) => {
        if (!r || r.chips === undefined) return;
        const changed = myChips !== null && r.chips !== myChips;
        myChips = r.chips;
        ['bj-chips', 'rl-chips'].forEach((id) => {
            const el = $(id); el.textContent = fmt(myChips);
            if (changed) { el.classList.add('bump'); setTimeout(() => el.classList.remove('bump'), 300); }
        });
    });
}

/* ------------------------------------------------------------------ guichet */
const CA = { id: null, info: null, mode: 'buy', pending: false };
function caRender() {
    const i = CA.info; if (!i) return;
    $('ca-title').textContent = i.name || 'Caisse du casino';
    $('ca-chips').textContent = fmt(i.chips); $('ca-cash').textContent = `${fmt(i.cash)} $`; $('ca-bank').textContent = `${fmt(i.bank)} $`;
    document.querySelectorAll('[data-catab]').forEach((b) => b.classList.toggle('on', b.dataset.catab === CA.mode));
    document.querySelector('#cashier .seg').dataset.mode = CA.mode;
    const closed = !i.open;
    $('ca-closed').classList.toggle('hidden', !closed);
    $('ca-body').classList.toggle('hidden', closed);
    if (closed) $('ca-closed').textContent = !i.enabled ? 'Le guichet est fermé.' : `Le guichet est fermé. Ouverture de ${i.hoursFrom} h à ${i.hoursTo} h.`;
    const acct = $('ca-acct');
    [...acct.options].forEach((o) => { o.disabled = !(i.accounts || {})[o.value]; });
    if (acct.selectedOptions[0] && acct.selectedOptions[0].disabled) acct.value = [...acct.options].find((o) => !o.disabled)?.value || 'cash';
    const q = Math.max(0, Math.floor(Number($('ca-qty').value) || 0));
    let total, fee;
    if (CA.mode === 'buy') { const base = Math.ceil(q * i.buyRate); fee = Math.ceil(base * (i.buyFeePct || 0) / 100); total = base + fee; }
    else { const base = Math.floor(q * i.sellRate); fee = Math.ceil(base * (i.sellFeePct || 0) / 100); total = Math.max(0, base - fee); }
    $('ca-rate').innerHTML = CA.mode === 'buy'
        ? `Taux : <b>1 jeton = ${i.buyRate} $</b>${i.buyFeePct ? ` · commission ${i.buyFeePct} % (${fmt(fee)} $)` : ''}`
        : `Taux : <b>1 jeton = ${i.sellRate} $</b>${i.sellFeePct ? ` · commission ${i.sellFeePct} % (${fmt(fee)} $)` : ''}`;
    $('ca-total-l').textContent = CA.mode === 'buy' ? 'Total à payer' : 'Montant crédité';
    $('ca-total').textContent = `${fmt(total)} $`;
    $('ca-limits').textContent = `De ${fmt(i.minTx)} à ${fmt(i.maxTx)} jetons par transaction${i.maxChips ? ` · ${fmt(i.maxChips)} jetons maximum par joueur` : ''}.`;
    $('ca-ok').textContent = CA.mode === 'buy' ? `Acheter ${fmt(q)} jetons` : `Revendre ${fmt(q)} jetons`;
    $('ca-ok').disabled = CA.pending || q <= 0;
}
document.querySelectorAll('[data-catab]').forEach((b) => b.addEventListener('click', () => { CA.mode = b.dataset.catab; caRender(); }));
document.querySelectorAll('[data-caq]').forEach((b) => b.addEventListener('click', () => {
    $('ca-qty').value = Math.max(1, (Number($('ca-qty').value) || 0) + Number(b.dataset.caq)); caRender();
}));
document.querySelectorAll('[data-caset]').forEach((b) => b.addEventListener('click', () => {
    const i = CA.info || {};
    let v = Number(b.dataset.caset);
    if (b.dataset.caset === 'max') {
        if (CA.mode === 'sell') v = Math.min(i.chips || 0, i.maxTx || 0);
        else { const money = $('ca-acct').value === 'bank' ? i.bank : i.cash; v = Math.min(Math.floor((money || 0) / (i.buyRate * (1 + (i.buyFeePct || 0) / 100))), i.maxTx || 0); }
    }
    $('ca-qty').value = Math.max(0, v); caRender();
}));
$('ca-qty').addEventListener('input', caRender);
$('ca-acct').addEventListener('change', caRender);
$('ca-ok').addEventListener('click', async () => {
    if (CA.pending) return;
    CA.pending = true; caRender();
    const r = await post('cashierTx', { pedId: CA.id, kind: CA.mode, chips: Math.floor(Number($('ca-qty').value) || 0), account: $('ca-acct').value, nonce: nonce() });
    CA.pending = false;
    toast(r.msg || (r.ok ? 'Transaction effectuée.' : 'Transaction refusée.'), r.ok ? 'success' : 'error');
    const info = await post('cashierInfo', { pedId: CA.id });
    if (info && !info.error) CA.info = info;
    caRender();
});

/* ------------------------------------------------------------------ tables (commun) */
const T = { game: null, id: null, idx: null, me: null, state: null, deadline: 0 };
function phaseLabel(p, game) {
    return ({ idle: 'En attente de joueurs', betting: 'Faites vos jeux', dealing: 'Distribution', players: 'Au tour des joueurs', dealer: 'Le croupier joue',
        payout: 'Résultats', spinning: 'Rien ne va plus', result: 'Résultat', insurance: 'Assurance ?' })[p] || p;
}
setInterval(() => {
    const leftMs = Math.max(0, T.deadline - Date.now());
    const left = Math.ceil(leftMs / 1000);
    const frac = T.deadline && T.total ? Math.min(1, leftMs / (T.total * 1000)) : 0;
    [['blackjack', 'bj'], ['roulette', 'rl']].forEach(([g, p]) => {
        const on = T.game === g && T.deadline;
        $(`${p}-timer`).textContent = on ? left : '';
        const ring = $(`${p}-ring`);
        ring.style.strokeDashoffset = String(119.4 * (1 - (on ? frac : 0)));
        ring.classList.toggle('low', !!on && left <= 5);
    });
}, 200);

function chipRow(el, max, onPick, sel) {
    el.innerHTML = CHIP_VALUES.filter((v) => !max || v <= max).map((v) => `<div class="chip ${sel === v ? 'sel' : ''}" data-v="${v}" style="background:${CHIP_COLORS[v]}">${v >= 1000 ? `${v / 1000}k` : v}</div>`).join('');
    el.querySelectorAll('.chip').forEach((c) => c.addEventListener('click', () => onPick(Number(c.dataset.v))));
}

function banner(id, text, cls) {
    const b = $(id);
    b.textContent = text; b.className = `banner ${cls || ''}`;
    clearTimeout(b._t); b._t = setTimeout(() => b.classList.add('hidden'), 4500);
}

document.querySelectorAll('[data-leave]').forEach((b) => b.addEventListener('click', () => post('leave')));

/* ------------------------------------------------------------------ blackjack */
const BJ = { pending: 0, chip: 100, lastRound: -1, resultShown: -1 };
function bjMySeat(st) { return st && st.seats ? st.seats[String(T.idx)] : null; }
function bjRender() {
    const st = T.state; if (!st || T.game !== 'blackjack') return;
    const cfg = st.cfg || {};
    $('bj-phase').textContent = phaseLabel(st.phase) + (st.closing ? ' · table en fermeture' : '');
    $('bj-phase').classList.toggle('hot', st.phase === 'players' && !!(st.turn && st.turn.seat === T.idx));
    if (BJ.cardRound !== st.round) { BJ.cardRound = st.round; SEEN.clear(); }
    $('bj-dealer').innerHTML = (st.dealer.cards || []).map((c, j) => cardHtml(c, `d${j}`)).join('');
    $('bj-dtot').textContent = st.dealer.cards && st.dealer.cards.length ? st.dealer.total : '';
    let html = '';
    for (let i = 1; i <= (cfg.maxPlayers || 4); i++) {
        const s = st.seats[String(i)];
        if (!s) { html += `<div class="seat empty">Place ${i} libre</div>`; continue; }
        const turn = st.turn && st.turn.seat === i;
        const hands = (s.hands || []).map((h, hi) => `<div class="hand"><div class="cards">${h.cards.map((c, j) => cardHtml(c, `p${i}:${hi}:${j}:${c.r}${c.s}`)).join('')}</div>
            <span class="ht">${h.bj ? 'Blackjack !' : h.total}${h.soft && h.total < 21 ? ' (souple)' : ''} · ${fmt(h.bet)}${h.doubled ? ' ×2' : ''}</span>
            ${h.result ? `<span class="res ${h.result}">${({ blackjack: 'BLACKJACK', win: 'GAGNÉ', push: 'ÉGALITÉ', lose: 'PERDU', surrender: 'ABANDON' })[h.result]}${h.payout ? ` +${fmt(h.payout)}` : ''}</span>` : ''}
            ${turn && st.turn.hand === hi + 1 ? ' ◀' : ''}</div>`).join('');
        html += `<div class="seat ${i === T.idx ? 'me' : ''} ${turn ? 'turn' : ''}"><div class="nm"><span>${esc(s.name)}${s.left ? ' (parti)' : ''}</span>
            <span>${st.phase === 'betting' ? (s.bet ? `${fmt(s.bet)} ${s.ready ? '✔' : ''}` : '—') : s.insurance ? `🛡 ${fmt(s.insurance)}` : ''}</span></div>${hands}</div>`;
    }
    $('bj-seats').innerHTML = html;
    const me = bjMySeat(st);
    const betting = st.phase === 'betting';
    $('bj-betctl').classList.toggle('hidden', !betting);
    if (betting) {
        if (BJ.lastRound !== st.round) { BJ.lastRound = st.round; BJ.pending = me && me.bet ? me.bet : (BJ.last || cfg.minBet || 0); }
        const inp = $('bj-amount');
        if (document.activeElement !== inp) inp.value = BJ.pending;
        inp.min = cfg.minBet || 1; inp.max = cfg.maxBet || '';
        $('bj-placed').textContent = me && me.bet ? `Misé : ${fmt(me.bet)} jetons` : `Mise libre de ${fmt(cfg.minBet)} à ${fmt(cfg.maxBet)}`;
        $('bj-ready').textContent = me && me.ready ? 'Prêt ✔' : 'Prêt';
        $('bj-ready').classList.toggle('on', !!(me && me.ready));
        $('bj-ready').disabled = !(me && me.bet);
        $('bj-rules').textContent = `Blackjack payé ${cfg.blackjackPays === 1.5 ? '3:2' : cfg.blackjackPays === 1.2 ? '6:5' : `${cfg.blackjackPays}×`} · `
            + `croupier ${cfg.dealerHitsSoft17 ? 'tire sur 17 souple' : 'reste sur 17'} · ${cfg.decks} jeu(x)${cfg.allowInsurance !== false ? ' · assurance 2:1' : ''}${cfg.allowSurrender !== false ? ' · abandon (moitié rendue)' : ''}`
            + `${cfg.autoStart ? ' · départ à la fin du compte à rebours (ou quand tous sont prêts)' : ' · départ quand tout le monde est prêt'}`;
        chipRow($('bj-chiprow'), cfg.maxBet, (v) => { BJ.chip = v; BJ.pending = Math.min(cfg.maxBet, BJ.pending + v); $('bj-amount').value = BJ.pending; }, null);
    }
    // Assurance (le croupier montre un As)
    const insOpen = st.phase === 'insurance' && me && me.hands && !me.insDecided;
    $('bj-ins').classList.toggle('hidden', !insOpen);
    if (insOpen) {
        const cost = Math.floor((me.hands[0] || {}).bet / 2);
        $('bj-insq').textContent = `Le croupier montre un As : t'assurer pour ${fmt(cost)} jetons ? (payé 2:1 s'il a blackjack)`;
    }
    // Actions : seulement à son tour
    const myTurn = st.phase === 'players' && st.turn && st.turn.seat === T.idx && me && me.hands;
    const h = myTurn ? me.hands[st.turn.hand - 1] : null;
    BJ.turn = !!h;
    $('bj-acts').classList.toggle('hidden', !myTurn);
    if (h) {
        const vals = h.cards.map((c) => (c.r === 'A' ? 11 : ['J', 'Q', 'K'].includes(c.r) ? 10 : Number(c.r)));
        const enable = (a, on) => { document.querySelector(`[data-bja="${a}"]`).disabled = !on; };
        enable('hit', true); enable('stand', true);
        enable('double', cfg.allowDouble && h.cards.length === 2 && !h.doubled && (!h.split || cfg.doubleAfterSplit) && (cfg.doubleOn !== '9-11' || (h.total >= 9 && h.total <= 11)));
        enable('split', cfg.allowSplit && h.cards.length === 2 && vals[0] === vals[1] && me.hands.length < (cfg.maxHands || 2));
        enable('surrender', cfg.allowSurrender !== false && h.cards.length === 2 && !h.acted && !h.split && me.hands.length === 1);
    }
    // Résultat de la manche
    if (st.phase === 'payout' && me && me.hands && BJ.resultShown !== st.round) {
        BJ.resultShown = st.round;
        let bet = 0, won = 0;
        me.hands.forEach((x) => { bet += x.bet; won += x.payout || 0; });
        const net = won - bet;
        banner('bj-banner', net > 0 ? `Gagné ! +${fmt(net)} jetons` : net === 0 ? 'Égalité : mise rendue' : `Perdu ${fmt(-net)} jetons`, net > 0 ? 'win' : net < 0 ? 'lose' : '');
        refreshChips();
    }
}
$('bj-clear').addEventListener('click', () => { BJ.pending = 0; $('bj-amount').value = 0; });
$('bj-amount').addEventListener('input', (e) => { BJ.pending = Math.max(0, Math.floor(Number(e.target.value) || 0)); });
$('bj-amount').addEventListener('keydown', (e) => { if (e.key === 'Enter') $('bj-place').click(); e.stopPropagation(); });
$('bj-place').addEventListener('click', async () => {
    BJ.pending = Math.max(0, Math.floor(Number($('bj-amount').value) || 0));
    const r = await post('bjAction', { action: 'bet', amount: BJ.pending });
    if (!r.ok) toast(r.msg, 'error'); else { BJ.last = BJ.pending; toast(BJ.pending ? `Mise de ${fmt(BJ.pending)} jetons posée.` : 'Mise retirée.', 'success'); }
    refreshChips();
});
document.querySelectorAll('[data-bji]').forEach((b) => b.addEventListener('click', async () => {
    const r = await post('bjAction', { action: 'insurance', take: b.dataset.bji === '1' });
    if (!r.ok) toast(r.msg, 'error'); refreshChips();
}));
$('bj-ready').addEventListener('click', async () => { const r = await post('bjAction', { action: 'ready' }); if (!r.ok) toast(r.msg, 'error'); });
document.querySelectorAll('[data-bja]').forEach((b) => b.addEventListener('click', async () => {
    document.querySelectorAll('[data-bja]').forEach((x) => { x.disabled = true; });
    const r = await post('bjAction', { action: b.dataset.bja });
    if (!r.ok) toast(r.msg, 'error');
    refreshChips(); bjRender();
}));

/* ------------------------------------------------------------------ roulette */
const RED = new Set([1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]);
const EU_ORDER = [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26];
const US_ORDER = [37, 27, 10, 25, 29, 12, 8, 19, 31, 18, 6, 21, 33, 16, 4, 23, 35, 14, 2, 0, 28, 9, 26, 30, 11, 7, 20, 32, 17, 5, 22, 34, 15, 3, 24, 36, 13, 1];
const lbl = (p) => (p === 37 ? '00' : String(p));
const colorOf = (p) => (p === 0 || p === 37 ? 'green' : RED.has(p) ? 'red' : 'black');
const RL = { chip: 100, mode: 'straight', pick: null, rot: 0, anim: null, lastSpin: -1, resultShown: -1 };
const MODES = [['straight', 'Plein (35:1)'], ['split', 'Cheval (17:1)'], ['street', 'Transversale (11:1)'], ['corner', 'Carré (8:1)'], ['sixline', 'Sixain (5:1)']];

function rlMine(st) { return (st.bets || []).find((b) => b.src === T.me); }

function rlBuildMat(variant) {
    const m = $('rl-mat');
    let h = '';
    if (variant === 'us') {
        h += '<div class="cell zero" data-n="37" style="grid-column:1;grid-row:1">00</div><div class="cell zero" data-n="0" style="grid-column:1;grid-row:2/4">0</div>';
    } else h += '<div class="cell zero" data-n="0" style="grid-column:1;grid-row:1/4">0</div>';
    for (let n = 1; n <= 36; n++) {
        const row = 3 - ((n - 1) % 3), col = 2 + Math.floor((n - 1) / 3);
        h += `<div class="cell c-${RED.has(n) ? 'red' : 'black'}" data-n="${n}" style="grid-column:${col};grid-row:${row}">${n}</div>`;
    }
    [3, 2, 1].forEach((k, i) => { h += `<div class="cell out" data-o="column:${k}" style="grid-column:14;grid-row:${i + 1}">2:1</div>`; });
    ['1re 12', '2e 12', '3e 12'].forEach((t, i) => { h += `<div class="cell out" data-o="dozen:${i + 1}" style="grid-column:${2 + i * 4}/${6 + i * 4};grid-row:4">${t}</div>`; });
    [['low', '1-18'], ['even', 'Pair'], ['red', '◆ Rouge'], ['black', '◆ Noir'], ['odd', 'Impair'], ['high', '19-36']].forEach(([k, t], i) => {
        h += `<div class="cell out ${k === 'red' ? 'c-red' : k === 'black' ? 'c-black' : ''}" data-o="${k}" style="grid-column:${2 + i * 2}/${4 + i * 2};grid-row:5">${t}</div>`;
    });
    m.innerHTML = h;
    m.dataset.variant = variant;
    m.querySelectorAll('[data-n]').forEach((c) => c.addEventListener('click', () => rlClickNumber(Number(c.dataset.n))));
    m.querySelectorAll('[data-o]').forEach((c) => c.addEventListener('click', () => {
        const [kind, n] = c.dataset.o.split(':');
        rlBet({ kind, n: n ? Number(n) : undefined });
    }));
}

function rlClickNumber(n) {
    const mode = RL.mode;
    if (mode === 'straight') return rlBet({ kind: 'straight', numbers: [n] });
    if (mode === 'split') {
        if (RL.pick === null) { RL.pick = n; return rlRender(); }
        const a = RL.pick; RL.pick = null;
        if (a === n) return rlRender();
        return rlBet({ kind: 'split', numbers: [a, n] });
    }
    if (n === 0 || n === 37) return toast('Choisis un numéro de 1 à 36 pour cette mise.', 'error');
    const base = 3 * Math.floor((n - 1) / 3) + 1;
    if (mode === 'street') return rlBet({ kind: 'street', numbers: [base, base + 1, base + 2] });
    if (mode === 'sixline') {
        if (base > 31) return toast('Sixain : choisis une ligne de 1 à 33.', 'error');
        return rlBet({ kind: 'sixline', numbers: [base, base + 1, base + 2, base + 3, base + 4, base + 5] });
    }
    if (mode === 'corner') {
        if ((n - 1) % 3 === 2 || n > 32) return toast('Carré : clique le plus petit des 4 numéros (pas dans la rangée du haut ni après 32).', 'error');
        return rlBet({ kind: 'corner', numbers: [n, n + 1, n + 3, n + 4] });
    }
}

async function rlBet(bet) {
    const st = T.state;
    if (!st || st.phase !== 'betting') return toast('Les mises sont fermées.', 'error');
    const r = await post('rlAction', { action: 'bet', bet, amount: RL.chip });
    if (!r.ok) toast(r.msg, 'error');
    refreshChips();
}

function rlRender() {
    const st = T.state; if (!st || T.game !== 'roulette') return;
    const cfg = st.cfg || {};
    if ($('rl-mat').dataset.variant !== cfg.variant) rlBuildMat(cfg.variant);
    $('rl-title').textContent = `Roulette ${cfg.variant === 'us' ? 'américaine' : 'européenne'}`;
    $('rl-phase').textContent = phaseLabel(st.phase);
    $('rl-modes').innerHTML = MODES.map(([k, t]) => `<button class="btn ${RL.mode === k ? 'on' : ''}" data-mode="${k}">${t}</button>`).join('')
        + '<span class="hint" style="align-self:center">Extérieur (douzaines, colonnes, chances simples) : clic sur la case.</span>';
    $('rl-modes').querySelectorAll('[data-mode]').forEach((b) => b.addEventListener('click', () => { RL.mode = b.dataset.mode; RL.pick = null; rlRender(); }));
    chipRow($('rl-chiprow'), cfg.maxBet, (v) => { RL.chip = v; rlRender(); }, RL.chip);
    const mine = rlMine(st) || { list: [], total: 0 };
    // Jetons posés sur le tapis
    document.querySelectorAll('#rl-mat .cell').forEach((c) => { c.classList.remove('pick', 'win'); const s = c.querySelector('.stake'); if (s) s.remove(); });
    if (RL.pick !== null) { const c = document.querySelector(`#rl-mat [data-n="${RL.pick}"]`); if (c) c.classList.add('pick'); }
    mine.list.forEach((b) => {
        let cell;
        if (b.kind === 'straight') cell = document.querySelector(`#rl-mat [data-n="${b.numbers[0]}"]`);
        else if (['column', 'dozen'].includes(b.kind)) {
            const k = b.kind === 'column' ? b.numbers[0] : Math.ceil(b.numbers[0] / 12);
            cell = document.querySelector(`#rl-mat [data-o="${b.kind}:${k}"]`);
        } else if (['red', 'black', 'even', 'odd', 'low', 'high'].includes(b.kind)) cell = document.querySelector(`#rl-mat [data-o="${b.kind}"]`);
        else cell = document.querySelector(`#rl-mat [data-n="${b.numbers[0]}"]`);
        if (cell) { const s = document.createElement('span'); s.className = 'stake'; s.textContent = fmt(b.amount); cell.appendChild(s); }
    });
    if (st.result !== undefined && st.result !== null && st.phase === 'result') {
        const c = document.querySelector(`#rl-mat [data-n="${st.result}"]`); if (c) c.classList.add('win');
    }
    $('rl-total').textContent = fmt(mine.total);
    // gain possible maximum (sur la meilleure case)
    let best = 0;
    for (let p = 0; p <= 37; p++) {
        let w = 0;
        mine.list.forEach((b) => { if (b.numbers.includes(p)) w += b.amount * (b.pays + 1); });
        best = Math.max(best, w);
    }
    $('rl-pot').textContent = fmt(best);
    const open = st.phase === 'betting';
    $('rl-list').innerHTML = mine.list.map((b) => `<span>${esc(b.label)} · <b>${fmt(b.amount)}</b> → ${fmt(b.amount * (b.pays + 1))}${b.won !== undefined && b.won !== null && st.phase === 'result' ? (b.won ? ' ✔' : ' ✘') : ''}${open ? `<i data-unbet="${esc(b.key)}">✕</i>` : ''}</span>`).join('')
        || '<span class="hint">Choisis un jeton puis clique sur le tapis.</span>';
    $('rl-list').querySelectorAll('[data-unbet]').forEach((x) => x.addEventListener('click', async () => {
        const r = await post('rlAction', { action: 'unbet', key: x.dataset.unbet }); if (!r.ok) toast(r.msg, 'error'); refreshChips();
    }));
    $('rl-clear').disabled = !open || !mine.total;
    $('rl-hist').innerHTML = (st.history || []).map((p) => `<span class="c-${colorOf(p)}">${lbl(p)}</span>`).join('');
    $('rl-players').innerHTML = Object.entries(st.seats || {}).map(([i, s]) => `<div><span>Place ${i} · ${esc(s.name)}</span><b>${fmt(s.total)}</b></div>`).join('');
    if (st.phase === 'result' && RL.resultShown !== st.spin && mine.total) {
        RL.resultShown = st.spin;
        const won = mine.list.reduce((a, b) => a + (b.won || 0), 0);
        const net = won - mine.total;
        banner('rl-banner', `${lbl(st.result)} ${({ red: 'rouge', black: 'noir', green: 'vert' })[colorOf(st.result)]} · ${net > 0 ? `+${fmt(net)} jetons` : net === 0 ? 'mise rendue' : `${fmt(net)} jetons`}`, net > 0 ? 'win' : net < 0 ? 'lose' : '');
        refreshChips();
    }
    if (st.phase === 'betting') RL.ball = null;
    if (!RL.anim) drawRoulette(cfg.variant, RL.rot, RL.ball);
}
$('rl-clear').addEventListener('click', async () => { const r = await post('rlAction', { action: 'clear' }); if (!r.ok) toast(r.msg, 'error'); refreshChips(); });

function drawRoulette(variant, rot, ball) {
    const cv = $('rl-wheel'), g = cv.getContext('2d');
    const order = variant === 'us' ? US_ORDER : EU_ORDER;
    const n = order.length, R = cv.width / 2, seg = (Math.PI * 2) / n;
    g.clearRect(0, 0, cv.width, cv.height);
    g.save(); g.translate(R, R);
    // anneau extérieur néon
    const ring = g.createLinearGradient(-R, -R, R, R); ring.addColorStop(0, '#00e5ff'); ring.addColorStop(.5, '#8b5cff'); ring.addColorStop(1, '#ff2bd6');
    g.beginPath(); g.arc(0, 0, R - 6, 0, Math.PI * 2); g.lineWidth = 8; g.strokeStyle = ring; g.shadowColor = '#00e5ff'; g.shadowBlur = 24; g.stroke(); g.shadowBlur = 0;
    g.beginPath(); g.arc(0, 0, R - 12, 0, Math.PI * 2); g.fillStyle = '#070a1a'; g.fill();
    g.save(); g.rotate(rot);
    order.forEach((p, i) => {
        const a0 = -Math.PI / 2 + i * seg - seg / 2;
        const col = colorOf(p);
        const grd = g.createRadialGradient(0, 0, R * .45, 0, 0, R - 26);
        if (col === 'red') { grd.addColorStop(0, '#7a0a22'); grd.addColorStop(1, '#ff2d55'); }
        else if (col === 'black') { grd.addColorStop(0, '#0b0d1c'); grd.addColorStop(1, '#2a2f52'); }
        else { grd.addColorStop(0, '#006b44'); grd.addColorStop(1, '#2bffa8'); }
        g.beginPath(); g.moveTo(0, 0); g.arc(0, 0, R - 26, a0, a0 + seg); g.closePath(); g.fillStyle = grd; g.fill();
        g.strokeStyle = 'rgba(0,229,255,.35)'; g.lineWidth = 1.5; g.stroke();
        g.save(); g.rotate(a0 + seg / 2 + Math.PI / 2); g.fillStyle = col === 'green' ? '#04140c' : '#fff';
        g.font = `700 ${Math.round(R * .075)}px Orbitron, Arial`; g.textAlign = 'center'; g.fillText(lbl(p), 0, -(R - 46)); g.restore();
    });
    // moyeu
    const hub = g.createRadialGradient(0, 0, 4, 0, 0, R * .42); hub.addColorStop(0, '#2a2f6a'); hub.addColorStop(1, '#090c20');
    g.beginPath(); g.arc(0, 0, R * .42, 0, Math.PI * 2); g.fillStyle = hub; g.fill(); g.lineWidth = 3; g.strokeStyle = '#00e5ff'; g.shadowColor = '#00e5ff'; g.shadowBlur = 14; g.stroke(); g.shadowBlur = 0;
    for (let k = 0; k < 4; k++) { g.save(); g.rotate(k * Math.PI / 2); g.beginPath(); g.moveTo(0, -R * .38); g.lineTo(R * .05, 0); g.lineTo(0, R * .05); g.lineTo(-R * .05, 0); g.closePath(); g.fillStyle = 'rgba(255,211,107,.85)'; g.fill(); g.restore(); }
    g.restore();
    // bille (angle et rayon à l'écran)
    if (ball) {
        const bx = Math.cos(ball.a) * ball.r, by = Math.sin(ball.a) * ball.r;
        g.beginPath(); g.arc(bx, by, R * .035, 0, Math.PI * 2); g.fillStyle = '#fff'; g.shadowColor = '#fff'; g.shadowBlur = 18; g.fill(); g.shadowBlur = 0;
    }
    g.restore();
    // repère
    g.beginPath(); g.moveTo(R - 14, 4); g.lineTo(R + 14, 4); g.lineTo(R, 26); g.closePath(); g.fillStyle = '#ffd36b'; g.shadowColor = '#ffd36b'; g.shadowBlur = 12; g.fill(); g.shadowBlur = 0;
}

function spinRoulette(result, duration, variant) {
    const order = variant === 'us' ? US_ORDER : EU_ORDER;
    const idx = order.indexOf(result);
    const seg = (Math.PI * 2) / order.length;
    const start = RL.rot % (Math.PI * 2);
    const final = Math.PI * 2 * 6 - idx * seg;     // case tirée amenée sous le repère du haut
    const R = $('rl-wheel').width / 2;
    const t0 = performance.now();
    cancelAnimationFrame(RL.anim);
    const step = (t) => {
        const k = Math.min(1, (t - t0) / duration);
        const e = 1 - Math.pow(1 - k, 3);
        RL.rot = start + (final - start) * e;
        // la bille tourne en sens inverse, ralentit, descend vers les cases et s'arrête en haut
        const be = 1 - Math.pow(1 - k, 2.2);
        const a = -Math.PI / 2 - (1 - be) * Math.PI * 2 * 9;
        const r = (R - 18) - (R * .2) * Math.min(1, Math.max(0, (k - .55) / .45));
        drawRoulette(variant, RL.rot, { a, r });
        if (k < 1) RL.anim = requestAnimationFrame(step); else { RL.anim = null; RL.ball = { a: -Math.PI / 2, r }; }
    };
    RL.anim = requestAnimationFrame(step);
}

/* ------------------------------------------------------------------ roue de la fortune */
const WH = { rot: 0, anim: null, wheel: null };
function drawWheel(w, rot, t) {
    const cv = $('wh-canvas'), g = cv.getContext('2d');
    const segs = w.segments || [], n = Math.max(1, segs.length), R = cv.width / 2, seg = (Math.PI * 2) / n;
    g.clearRect(0, 0, cv.width, cv.height);
    g.save(); g.translate(R, R);
    // anneau néon + LED qui défilent
    const ring = g.createLinearGradient(-R, -R, R, R); ring.addColorStop(0, '#00e5ff'); ring.addColorStop(.5, '#8b5cff'); ring.addColorStop(1, '#ff2bd6');
    g.beginPath(); g.arc(0, 0, R - 14, 0, Math.PI * 2); g.lineWidth = 22; g.strokeStyle = '#090c20'; g.stroke();
    g.lineWidth = 6; g.strokeStyle = ring; g.shadowColor = '#00e5ff'; g.shadowBlur = 30; g.stroke(); g.shadowBlur = 0;
    const leds = 48, phase = Math.floor((t || 0) / 90);
    for (let k = 0; k < leds; k++) {
        const a = k / leds * Math.PI * 2;
        const on = (k + phase) % 3 === 0;
        g.beginPath(); g.arc(Math.cos(a) * (R - 14), Math.sin(a) * (R - 14), 5, 0, Math.PI * 2);
        g.fillStyle = on ? '#ffffff' : 'rgba(255,255,255,.18)'; if (on) { g.shadowColor = '#00e5ff'; g.shadowBlur = 14; } g.fill(); g.shadowBlur = 0;
    }
    g.save(); g.rotate(rot);
    segs.forEach((s, i) => {
        const a0 = -Math.PI / 2 + i * seg - seg / 2;
        const grd = g.createRadialGradient(0, 0, R * .12, 0, 0, R - 30);
        grd.addColorStop(0, 'rgba(0,0,0,.55)'); grd.addColorStop(.35, s.color || '#222'); grd.addColorStop(1, s.color || '#222');
        g.beginPath(); g.moveTo(0, 0); g.arc(0, 0, R - 30, a0, a0 + seg); g.closePath(); g.fillStyle = grd; g.fill();
        g.strokeStyle = 'rgba(255,255,255,.55)'; g.lineWidth = 3; g.stroke();
        // texte toujours lisible : retourné quand le segment passe sur la moitié gauche de l'écran
        const mid = a0 + seg / 2;
        const flip = Math.cos(mid + rot) < 0;
        g.save(); g.rotate(mid + (flip ? Math.PI : 0)); g.fillStyle = s.text || '#fff'; g.shadowColor = 'rgba(0,0,0,.8)'; g.shadowBlur = 6;
        g.font = `700 ${n > 14 ? Math.round(R * .045) : Math.round(R * .058)}px Orbitron, Arial`; g.textBaseline = 'middle';
        g.textAlign = flip ? 'left' : 'right';
        g.fillText(`${s.label}`.slice(0, 18), flip ? -(R - 50) : R - 50, 0);
        if (s.icon) { g.font = `${Math.round(R * .07)}px Arial`; g.textAlign = 'center'; g.fillText(s.icon, flip ? -R * .32 : R * .32, 0); }
        g.restore();
    });
    g.restore();
    const hub = g.createRadialGradient(0, 0, 6, 0, 0, R * .16); hub.addColorStop(0, '#3b2f8a'); hub.addColorStop(1, '#0a0c22');
    g.beginPath(); g.arc(0, 0, R * .16, 0, Math.PI * 2); g.fillStyle = hub; g.fill(); g.lineWidth = 5; g.strokeStyle = '#ffd36b'; g.shadowColor = '#ffd36b'; g.shadowBlur = 20; g.stroke(); g.shadowBlur = 0;
    g.fillStyle = '#ffd36b'; g.font = `900 ${Math.round(R * .06)}px Orbitron, Arial`; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText('ELYZEA', 0, 0);
    g.restore();
}
function spinWheel(w, idx, duration) {
    WH.wheel = w;
    $('wheel').classList.remove('hidden');
    $('wh-result').classList.add('hidden');
    $('wh-name').textContent = w.name || '';
    const n = Math.max(1, (w.segments || []).length), seg = (Math.PI * 2) / n;
    const start = WH.rot % (Math.PI * 2);
    const final = Math.PI * 2 * 6 - (idx - 1) * seg;
    const t0 = performance.now() + 1200;    // départ quand le bras du personnage lance la roue
    cancelAnimationFrame(WH.anim);
    const step = (t) => {
        const k = Math.max(0, Math.min(1, (t - t0) / (duration - 1200)));
        const e = 1 - Math.pow(1 - k, 3);
        WH.rot = start + (final - start) * e;
        drawWheel(w, WH.rot, t);
        if (k < 1) WH.anim = requestAnimationFrame(step); else WH.anim = null;
    };
    WH.anim = requestAnimationFrame(step);
}

/* ------------------------------------------------------------------ messages du jeu */
window.addEventListener('message', (ev) => {
    const m = ev.data || {};
    switch (m.action) {
        case 'cashier':
            CA.id = m.id; CA.info = m.info; CA.mode = 'buy'; CA.pending = false;
            $('cashier').classList.toggle('hidden', !m.show); caRender(); break;
        case 'seat':
            T.game = m.game; T.id = m.id; T.idx = m.idx; T.me = m.me; T.state = null; T.deadline = 0;
            $('bj').classList.toggle('hidden', m.game !== 'blackjack');
            $('rl').classList.toggle('hidden', m.game !== 'roulette');
            $('bj-title').textContent = m.name || 'Blackjack';
            if (m.game === 'roulette') $('rl-title').textContent = m.name || 'Roulette';
            BJ.lastRound = -1; myChips = null; refreshChips();
            break;
        case 'unseat':
            T.game = null; T.state = null; $('bj').classList.add('hidden'); $('rl').classList.add('hidden'); break;
        case 'bjState': case 'rlState':
            if (m.id !== T.id) break;
            T.state = m.state; T.me = m.me; T.idx = m.idx;
            T.deadline = m.state.remaining !== undefined && m.state.remaining !== null ? Date.now() + m.state.remaining * 1000 : 0;
            // durée totale du compte à rebours (anneau) : retenue au début de chaque phase
            if (T.deadline && (T.phaseKey !== `${m.state.phase}:${m.state.round ?? m.state.spin}:${m.state.turn ? `${m.state.turn.seat}-${m.state.turn.hand}` : ''}`)) {
                T.phaseKey = `${m.state.phase}:${m.state.round ?? m.state.spin}:${m.state.turn ? `${m.state.turn.seat}-${m.state.turn.hand}` : ''}`;
                T.total = Math.max(1, m.state.remaining);
            } else if (!T.deadline) T.phaseKey = null;
            if (m.action === 'bjState') bjRender(); else rlRender();
            break;
        case 'rlSpin':
            if (m.id === T.id) spinRoulette(m.result, m.duration, m.variant); break;
        case 'wheelSpin': spinWheel(m.wheel, m.idx, m.duration); break;
        case 'wheelResult':
            $('wh-result').innerHTML = `${esc(m.label)}${m.prize ? `<small>Tu gagnes ${esc(m.prize)}</small>` : '<small>Pas de gain cette fois</small>'}`;
            $('wh-result').classList.toggle('win', !!m.prize);
            $('wh-result').classList.remove('hidden'); break;
        case 'wheelHide': $('wheel').classList.add('hidden'); break;
        default: break;
    }
});

document.querySelectorAll('[data-close]').forEach((b) => b.addEventListener('click', () => { $('cashier').classList.add('hidden'); post('close'); }));
document.addEventListener('keydown', (e) => {
    if (T.game === 'blackjack' && BJ.turn && document.activeElement !== $('bj-amount')) {
        const a = ({ t: 'hit', r: 'stand', d: 'double', s: 'split', a: 'surrender' })[e.key.toLowerCase()];
        const btn = a && document.querySelector(`[data-bja="${a}"]`);
        if (btn && !btn.disabled) { btn.click(); return; }
    }
    if (e.key !== 'Escape') return;
    if (!$('cashier').classList.contains('hidden')) { $('cashier').classList.add('hidden'); post('close'); return; }
    if (T.game) post('close');
});
