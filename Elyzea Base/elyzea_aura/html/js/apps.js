'use strict';
/* =========================================================
   APPLICATIONS DE BASE
   ========================================================= */

/* ---------- Téléphone ---------- */
Views.phone = async ({ tab = 'recents', number = '' } = {}) => {
  const tabs = tabsHtml([['recents', t('Récents')], ['contacts', t('Contacts')], ['keypad', t('Clavier')]], tab, 'data-tab');
  const wireTabs = () => $$('[data-tab]', appView).forEach(b => b.onclick = () => { setParams({ tab: b.dataset.tab }); Views.phone({ tab: b.dataset.tab }); });

  if (tab === 'keypad') {
    let value = number;
    frame({ title: t('Téléphone'), tabs, body: `<div class="dial">
      <div class="dial__display" id="dial-display"></div><div class="dial__name" id="dial-name"></div>
      <div class="dial__grid">${[['1', ''], ['2', 'ABC'], ['3', 'DEF'], ['4', 'GHI'], ['5', 'JKL'], ['6', 'MNO'], ['7', 'PQRS'], ['8', 'TUV'], ['9', 'WXYZ'], ['*', ''], ['0', '+'], ['#', '']]
        .map(([d, l]) => `<button class="key" data-key="${d}">${d}<small>${l || '&nbsp;'}</small></button>`).join('')}</div>
      <div class="dial__actions"><span></span>
        <button class="call-btn" id="dial-call" aria-label="${t('Appeler')}">${icon('phone')}</button>
        <button class="icon-btn icon-btn--ghost" id="dial-del" aria-label="${t('Effacer')}">${icon('back')}</button></div></div>` });
    const refresh = () => {
      $('#dial-display').textContent = value;
      $('#dial-name').textContent = S.contacts.find(c => c.number === value)?.name || '';
    };
    refresh();
    $$('[data-key]', appView).forEach(b => b.onclick = () => {
      if (value.length >= 14) return;
      Sound.tap(b.dataset.key); value += b.dataset.key;
      if (/^\d{3}$/.test(value) && /-/.test(S.profile?.number || '')) value += '-';
      refresh();
    });
    $('#dial-del').onclick = () => { value = value.replace(/-?.$/, ''); refresh(); };
    $('#dial-call').onclick = () => value && startCall(value);
    wireTabs(); return;
  }
  if (tab === 'contacts') { renderContacts({ tabs, inPhone: true }); return; }

  frame({ title: t('Téléphone'), tabs, body: loading() });
  wireTabs();
  const res = await api('getCalls');
  if (S.currentApp !== 'phone') return;
  const calls = res.calls || [];
  $('.app__body', appView).innerHTML = calls.length ? `<div class="list">${calls.map(c => {
    const missed = !c.outgoing && c.status !== 'answered';
    const label = c.status === 'answered' ? `${c.outgoing ? t('Sortant') : t('Entrant')}, ${duration(c.duration)}`
      : c.outgoing ? t('Sans réponse') : c.status === 'declined' ? t('Refusé') : t('Manqué');
    return `<button class="row" data-call="${esc(c.number)}">${avatar(nameFor(c.number), c.number)}
      <div class="row__main"><div class="row__title">${esc(nameFor(c.number))}</div>
      <div class="row__sub ${missed ? 'row__sub--missed' : ''}" style="display:flex;gap:5px;align-items:center">
      <span style="width:14px;height:14px;display:inline-block">${icon(c.outgoing ? 'callOut' : 'callIn')}</span>${label}</div></div>
      <span class="row__aside">${timeAgo(c.ts)}</span></button>`;
  }).join('')}</div>` : empty(t('Aucun appel'), t('Les appels passés et reçus apparaîtront ici.'));
  $$('[data-call]', appView).forEach(b => b.onclick = () => startCall(b.dataset.call));
};

/* ---------- Contacts ---------- */
async function loadContacts() {
  const res = await api('getContacts');
  S.contacts = res.contacts || [];
  return S.contacts;
}
function renderContacts({ tabs = '', inPhone = false, filter = '' } = {}) {
  const list = S.contacts.filter(c => !filter || c.name.toLowerCase().includes(filter.toLowerCase()) || c.number.includes(filter));
  const favs = list.filter(c => c.favorite);
  const row = (c) => `<button class="row" data-contact="${c.id}">${avatar(c.name, c.number)}
    <div class="row__main"><div class="row__title">${esc(c.name)}</div><div class="row__sub">${esc(c.number)}</div></div>
    ${c.favorite ? `<span style="width:16px;color:var(--ambre)">${icon('star')}</span>` : ''}</button>`;
  const me = S.settings.cardName || S.profile.name;
  frame({
    title: inPhone ? t('Téléphone') : t('Contacts'), tabs,
    action: `<button class="icon-btn icon-btn--accent" data-add aria-label="${t('Ajouter un contact')}">${icon('plus')}</button>`,
    body: `<input class="search" placeholder="${t('Rechercher un nom ou un numéro')}" value="${esc(filter)}" id="c-search">
      ${filter ? '' : `<button class="row list" id="my-card" style="margin-bottom:12px">${avatar(me, S.profile.number)}
        <div class="row__main"><div class="row__title">${esc(me)}</div><div class="row__sub">${t('Ma fiche')} · ${esc(S.profile.number)}</div></div>
        ${S.profile.auraDrop ? `<span class="chip chip--accent">AuraDrop</span>` : ''}</button>`}
      ${!S.contacts.length ? empty(t('Répertoire vide'), t('Ajoutez vos proches ou recevez leur fiche avec AuraDrop.'), `<button class="btn" data-add>${t('Ajouter un contact')}</button>`) : ''}
      ${favs.length ? `<p class="section-label">${t('Favoris')}</p><div class="list">${favs.map(row).join('')}</div>` : ''}
      ${list.length ? `<p class="section-label">${t('Tous')}</p><div class="list">${list.map(row).join('')}</div>` : ''}`
  });
  const search = $('#c-search');
  search.oninput = () => {
    renderContacts({ tabs, inPhone, filter: search.value });
    const sEl = $('#c-search'); sEl.focus(); sEl.setSelectionRange(sEl.value.length, sEl.value.length);
  };
  $('#my-card')?.addEventListener('click', () => S.profile.auraDrop ? openAuraDrop() : openApp('settings'));
  $$('[data-add]', appView).forEach(b => b.onclick = () => contactSheet());
  $$('[data-contact]', appView).forEach(b => b.onclick = () => contactDetail(S.contacts.find(c => c.id == b.dataset.contact)));
  $$('[data-tab]', appView).forEach(b => b.onclick = () => { setParams({ tab: b.dataset.tab }); Views.phone({ tab: b.dataset.tab }); });
}
Views.contacts = async () => {
  frame({ title: t('Contacts'), body: loading() });
  await loadContacts();
  if (S.currentApp === 'contacts') renderContacts();
};
function contactDetail(c) {
  if (!c) return;
  openSheet('', `<div style="display:flex;flex-direction:column;align-items:center;gap:8px;margin-bottom:18px">${avatar(c.name, c.number, 'avatar--lg')}
      <h2 class="sheet__title" style="margin:6px 0 0">${esc(c.name)}</h2><p class="row__sub" style="font-size:15px">${esc(c.number)}</p></div>
    <div class="form">
      <div class="grid-2"><button class="btn" data-a="call">${icon('phone')}${t('Appeler')}</button>
        <button class="btn btn--ghost" data-a="msg">${icon('messages')}${t('Écrire')}</button></div>
      ${bankOn() ? `<button class="btn btn--ghost btn--block" data-a="pay">${icon('card')}${t('Envoyer de l\'argent')}</button>` : ''}
      <div class="grid-2"><button class="btn btn--ghost" data-a="edit">${t('Modifier')}</button><button class="btn btn--danger" data-a="del">${t('Supprimer')}</button></div></div>`, (sh) => {
    sh.querySelector('[data-a="call"]').onclick = () => { closeSheet(); startCall(c.number); };
    sh.querySelector('[data-a="msg"]').onclick = () => { closeSheet(true); openApp('messages', { number: c.number }); };
    sh.querySelector('[data-a="pay"]')?.addEventListener('click', () => { closeSheet(true); openApp('bank'); setTimeout(() => transferSheet(c.number), 350); });
    sh.querySelector('[data-a="edit"]').onclick = () => contactSheet(c);
    sh.querySelector('[data-a="del"]').onclick = () => confirmSheet(t('Supprimer ce contact ?'), t('{name} sera retiré de votre répertoire.', { name: esc(c.name) }), t('Supprimer'), async () => {
      await api('deleteContact', { id: c.id }); await loadContacts(); refreshCurrent();
    });
  });
}
function contactSheet(c = {}, prefillNumber = '') {
  openSheet(c.id ? t('Modifier le contact') : t('Nouveau contact'), `<div class="form">
    <input class="field" id="f-name" placeholder="${t('Nom')}" maxlength="50" value="${esc(c.name || '')}">
    <input class="field" id="f-num" placeholder="${t('Numéro')}" maxlength="20" value="${esc(c.number || prefillNumber)}">
    <button class="row" id="f-fav" style="padding:6px"><span class="row__main row__title row__title--light">${t('Ajouter aux favoris')}</span><span class="toggle ${c.favorite ? 'on' : ''}"></span></button>
    <p class="error-text" id="f-err"></p>
    <button class="btn btn--block" id="f-save">${t('Enregistrer')}</button></div>`, (sh) => {
    let fav = !!c.favorite;
    sh.querySelector('#f-fav').onclick = (e) => { fav = !fav; e.currentTarget.querySelector('.toggle').classList.toggle('on', fav); };
    sh.querySelector('#f-save').onclick = async () => {
      const res = await api('saveContact', { id: c.id, name: $('#f-name').value, number: $('#f-num').value, favorite: fav });
      if (!res.ok) { $('#f-err').textContent = t(res.error || 'Enregistrement impossible.'); return; }
      closeSheet(); await loadContacts(); refreshCurrent();
    };
  });
}

/* ---------- Messages ---------- */
const GEO = /^%%GPS:(-?[\d.]+),(-?[\d.]+)\|(.*)$/;
const CARD = /^%%CARD:([^|]+)\|(.*)$/;
Views.messages = async ({ number } = {}) => {
  if (number) return renderThread(number);
  S.thread = null;
  frame({ title: t('Messages'), action: `<button class="icon-btn icon-btn--accent" data-new aria-label="${t('Nouveau message')}">${icon('edit')}</button>`, body: loading() });
  $('[data-new]', appView).onclick = newMessageSheet;
  const res = await api('getConversations');
  if (S.currentApp !== 'messages' || S.thread) return;
  const convs = res.conversations || [];
  S.unread = convs.reduce((a, c) => a + c.unread, 0);
  $('.app__body', appView).innerHTML = convs.length ? `<div class="list">${convs.map(c => `<button class="row" data-conv="${esc(c.number)}">${avatar(nameFor(c.number), c.number)}
      <div class="row__main"><div class="row__title">${esc(nameFor(c.number))}</div>
      <div class="row__sub">${GEO.test(c.last) ? t('Position partagée') : CARD.test(c.last) ? t('Fiche contact') : esc(c.last)}</div></div>
      <div class="row__aside">${timeAgo(c.ts)}${c.unread ? `<br><span class="pill">${c.unread}</span>` : ''}</div></button>`).join('')}</div>`
    : empty(t('Aucune conversation'), t('Écrivez à un contact ou à un numéro pour commencer.'), `<button class="btn" data-new2>${t('Nouveau message')}</button>`);
  $('[data-new2]', appView)?.addEventListener('click', newMessageSheet);
  $$('[data-conv]', appView).forEach(b => b.onclick = () => openApp('messages', { number: b.dataset.conv }));
};
function newMessageSheet() {
  openSheet(t('Nouveau message'), `<div class="form">
    <input class="field" id="nm-num" placeholder="${t('Numéro ou nom du contact')}" list="nm-list">
    <datalist id="nm-list">${S.contacts.map(c => `<option value="${esc(c.number)}">${esc(c.name)}</option>`).join('')}</datalist>
    <button class="btn btn--block" id="nm-go">${t('Ouvrir la conversation')}</button></div>`, (sh) => {
    sh.querySelector('#nm-go').onclick = () => {
      const v = $('#nm-num').value.trim();
      const n = S.contacts.find(c => c.name.toLowerCase() === v.toLowerCase())?.number || v;
      if (n) { closeSheet(true); openApp('messages', { number: n }); }
    };
  });
}
async function renderThread(number) {
  S.thread = number;
  const known = S.contacts.some(c => c.number === number);
  frame({
    title: esc(nameFor(number)), small: true,
    action: `${!known ? `<button class="icon-btn" data-save aria-label="${t('Enregistrer le contact')}">${icon('plus')}</button>` : ''}
      <button class="icon-btn" data-call aria-label="${t('Appeler')}">${icon('phone')}</button>
      <button class="icon-btn" data-more aria-label="${t('Plus')}">${icon('sparkle')}</button>`,
    body: `<div class="thread" id="thread">${loading()}</div>`,
    foot: `<div class="composer">
      <button class="icon-btn" data-geo aria-label="${t('Partager ma position')}">${icon('pin')}</button>
      <textarea class="field" id="msg-input" rows="1" maxlength="500" placeholder="${t('Message')}"></textarea>
      <button class="icon-btn icon-btn--accent" data-send aria-label="${t('Envoyer')}">${icon('send')}</button></div>`
  });
  $('[data-call]', appView).onclick = () => startCall(number);
  $('[data-save]', appView)?.addEventListener('click', () => contactSheet({}, number));
  const input = $('#msg-input');
  const send = async (text) => {
    text = text.trim(); if (!text) return;
    const res = await api('sendMessage', { number, message: text });
    if (!res.ok) { notify({ app: 'messages', title: t('Message non envoyé'), text: t(res.error || 'Réessayez dans un instant.') }); return; }
    appendBubble(res.message);
  };
  $('[data-more]', appView).onclick = () => openSheet(esc(nameFor(number)), `<div class="list">
    <button class="row" data-m="card"><span class="chip-ic" style="--c:#2FC9D9">${icon('user')}</span><span class="row__main row__title row__title--light">${t('Envoyer ma fiche contact')}</span></button>
    ${bankOn() ? `<button class="row" data-m="pay"><span class="chip-ic" style="--c:#3FBF8E">${icon('card')}</span><span class="row__main row__title row__title--light">${t('Envoyer de l\'argent')}</span></button>` : ''}
    <button class="row" data-m="del"><span class="chip-ic" style="--c:#FF6B7A">${icon('trash')}</span><span class="row__main row__title row__title--light">${t('Supprimer la conversation')}</span></button></div>`, (sh) => {
    $('[data-m="card"]', sh).onclick = () => { closeSheet(); send(`%%CARD:${S.settings.cardName || S.profile.name}|${S.profile.number}`); };
    $('[data-m="pay"]', sh)?.addEventListener('click', () => { closeSheet(true); transferSheet(number); });
    $('[data-m="del"]', sh).onclick = () => confirmSheet(t('Supprimer la conversation ?'), t('Tous les messages échangés avec ce numéro seront effacés.'), t('Supprimer'), async () => {
      await api('deleteConversation', { number }); back();
    });
  });
  input.oninput = () => { input.style.height = 'auto'; input.style.height = input.scrollHeight + 'px'; };
  input.onkeydown = (e) => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); send(input.value); input.value = ''; input.oninput(); } };
  $('[data-send]', appView).onclick = () => { send(input.value); input.value = ''; input.oninput(); input.focus(); };
  $('[data-geo]', appView).onclick = async () => {
    const loc = await post('getLocation');
    if (loc && loc.x !== undefined) send(`%%GPS:${loc.x},${loc.y}|${[loc.street, loc.zone].filter(Boolean).join(', ')}`);
  };
  const res = await api('getMessages', { number });
  if (S.thread !== number) return;
  const th = $('#thread'); th.innerHTML = '';
  let lastTs = 0;
  (res.messages || []).forEach(m => { appendBubble(m, lastTs); lastTs = m.ts; });
  if (!res.messages?.length) th.innerHTML = `<p class="bubble-time">${t('Début de la conversation avec {name}', { name: esc(nameFor(number)) })}</p>`;
  api('getConversations').then(r => { S.unread = (r.conversations || []).reduce((a, c) => a + c.unread, 0); });
}
function appendBubble(m, prevTs) {
  const th = $('#thread'); if (!th) return;
  $('.spinner', th)?.remove();
  if (prevTs === 0 || (prevTs && m.ts - prevTs > 900)) th.insertAdjacentHTML('beforeend', `<p class="bubble-time">${timeAgo(m.ts)}</p>`);
  const g = GEO.exec(m.message), c = CARD.exec(m.message);
  const cls = `bubble ${m.mine ? 'bubble--out' : 'bubble--in'}`;
  if (g) {
    th.insertAdjacentHTML('beforeend', `<div class="${cls} bubble--geo"><div class="geo-map"></div>
      <span>${esc(g[3] || t('Position partagée'))}</span><button data-wp="${g[1]},${g[2]}">${t('Définir l\'itinéraire')}</button></div>`);
    th.lastElementChild.querySelector('[data-wp]').onclick = () => {
      post('setWaypoint', { x: +g[1], y: +g[2] }); notify({ app: 'maps', title: t('Itinéraire défini'), text: g[3] || t('Point GPS ajouté') });
    };
  } else if (c) {
    const known = S.contacts.some(x => x.number === c[2]);
    th.insertAdjacentHTML('beforeend', `<div class="${cls} bubble--card"><div style="display:flex;gap:10px;align-items:center">${avatar(c[1], c[2])}
      <div><b>${esc(c[1])}</b><br><span>${esc(c[2])}</span></div></div>
      ${!m.mine && !known ? `<button data-addcard>${t('Ajouter aux contacts')}</button>` : ''}</div>`);
    th.lastElementChild.querySelector('[data-addcard]')?.addEventListener('click', async (e) => {
      await api('saveContact', { name: c[1], number: c[2] }); await loadContacts();
      e.target.remove(); notify({ app: 'contacts', title: t('Contact enregistré'), text: c[1] });
    });
  } else {
    th.insertAdjacentHTML('beforeend', `<div class="${cls}">${esc(m.message)}</div>`);
  }
  const body = $('.app__body', appView); body.scrollTop = body.scrollHeight;
}

/* ---------- Banque ---------- */
// Libellé d'opération : "555-1234 (motif)" -> "Inès Morel (motif)" si le numéro est un contact
function txLabel(label) {
  const str = String(label || ''), first = str.split(' ')[0];
  return nameFor(first) + str.slice(first.length);
}
function sparkline(history, balance) {
  const pts = [balance];
  let b = balance;
  history.slice(0, 14).forEach(h => { b -= h.amount; pts.push(b); });
  pts.reverse();
  if (pts.length < 2) pts.unshift(balance);
  const min = Math.min(...pts), max = Math.max(...pts), span = max - min || 1;
  const xy = pts.map((v, i) => [(i / (pts.length - 1)) * 300, 56 - ((v - min) / span) * 48]);
  const line = xy.map((p, i) => (i ? 'L' : 'M') + p[0].toFixed(1) + ' ' + p[1].toFixed(1)).join(' ');
  return `<svg class="spark" viewBox="0 0 300 64" preserveAspectRatio="none" aria-hidden="true"><defs><linearGradient id="sparkFill" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="var(--accent)" stop-opacity=".35"/><stop offset="1" stop-color="var(--accent)" stop-opacity="0"/></linearGradient></defs>
    <path class="area" d="${line} L300 64 L0 64 Z"/><path class="line" d="${line}"/></svg>`;
}
function countUp(el, to) {
  if (!el) return;
  const from = 0, start = performance.now(), dur = 700;
  const step = (now) => {
    const p = Math.min(1, (now - start) / dur), e = 1 - Math.pow(1 - p, 3);
    el.textContent = money(from + (to - from) * e);
    if (p < 1) requestAnimationFrame(step);
  };
  requestAnimationFrame(step);
}
Views.bank = async () => {
  frame({ title: t('Banque'), body: loading() });
  const res = await api('getBank');
  if (S.currentApp !== 'bank') return;
  if (!res.ok) { $('.app__body', appView).innerHTML = empty(t('Banque indisponible'), t('Le service bancaire est désactivé sur ce serveur.')); return; }
  S.profile.bank = res.balance; S.bankPending = res.pending || 0;
  const hist = res.history || [];
  const monthIn = hist.filter(h => h.amount > 0).reduce((a, h) => a + h.amount, 0);
  const monthOut = hist.filter(h => h.amount < 0).reduce((a, h) => a - h.amount, 0);
  $('.app__body', appView).innerHTML = `
    <div class="bank-card">
      <div class="bank-card__top"><span class="bank-card__brand">Elyzea Banque</span><span class="bank-card__chip"></span></div>
      <span class="bank-card__label">${t('Solde disponible')}</span>
      <span class="bank-card__balance" id="bank-balance">${money(res.balance)}</span>
      <span class="bank-card__number">${esc(S.profile.number)}</span></div>
    ${sparkline(hist, res.balance)}
    <div class="grid-2" style="margin-top:4px">
      <div class="widget" style="min-height:0"><span class="widget__label">${t('Entrées récentes')}</span><span class="widget__value amount--in" style="font-size:17px">+${money(monthIn)}</span></div>
      <div class="widget" style="min-height:0"><span class="widget__label">${t('Sorties récentes')}</span><span class="widget__value" style="font-size:17px">−${money(monthOut)}</span></div></div>
    <div class="quick">
      <button data-q="send"><span class="q-ic">${icon('arrowUp')}</span>${t('Virer')}</button>
      <button data-q="request"><span class="q-ic">${icon('arrowDown')}</span>${t('Demander')}</button>
      <button data-q="inbox"><span class="q-ic">${icon('inbox')}</span>${t('Demandes')}${S.bankPending ? `<span class="badge">${S.bankPending}</span>` : ''}</button></div>
    <p class="section-label">${t('Opérations récentes')}</p>
    ${hist.length ? `<div class="list">${hist.map(h => `<div class="row"><span class="tx-ic ${h.amount > 0 ? 'in' : ''}">${icon(h.amount > 0 ? 'arrowDown' : 'arrowUp')}</span>
      <div class="row__main"><div class="row__title">${esc(txLabel(h.label))}</div>
      <div class="row__sub">${h.amount > 0 ? t('Virement reçu') : t('Virement envoyé')}, ${timeAgo(h.ts)}</div></div>
      <span class="${h.amount > 0 ? 'amount--in' : 'amount--out'}">${h.amount > 0 ? '+' : '−'}${money(Math.abs(h.amount))}</span></div>`).join('')}</div>`
      : empty(t('Aucune opération'), t('Vos virements envoyés et reçus apparaîtront ici.'))}`;
  countUp($('#bank-balance'), res.balance);
  $('[data-q="send"]', appView).onclick = () => transferSheet();
  $('[data-q="request"]', appView).onclick = requestSheet;
  $('[data-q="inbox"]', appView).onclick = requestsSheet;
};
const contactOptions = () => S.contacts.map(c => `<option value="${esc(c.number)}">${esc(c.name)}</option>`).join('');
function transferSheet(prefill = '') {
  openSheet(t('Virement'), `<div class="form">
    <input class="field" id="t-num" placeholder="${t('Numéro du destinataire')}" list="t-list" value="${esc(prefill)}">
    <datalist id="t-list">${contactOptions()}</datalist>
    <input class="field" id="t-amount" type="number" min="1" placeholder="${t('Montant en $')}">
    <input class="field" id="t-label" maxlength="40" placeholder="${t('Motif (facultatif)')}">
    <p class="row__sub" style="padding:0 6px">${t('Solde disponible')} : ${money(S.profile.bank)}</p>
    <p class="error-text" id="t-err"></p>
    <button class="btn btn--block" id="t-go">${t('Envoyer le virement')}</button></div>`, (sh) => {
    sh.querySelector('#t-go').onclick = async (e) => {
      const amount = $('#t-amount', sh).value;
      e.currentTarget.disabled = true;
      const r = await api('transfer', { number: $('#t-num', sh).value.trim(), amount, label: $('#t-label', sh).value });
      if (!r.ok) { $('#t-err', sh).textContent = t(r.error || 'Virement refusé.'); e.currentTarget.disabled = false; return; }
      S.profile.bank = r.balance;
      closeSheet(); notify({ app: 'bank', title: t('Virement envoyé'), text: t('{amount} transférés', { amount: money(amount) }) });
      if (S.currentApp === 'bank') Views.bank();
    };
  });
}
function requestSheet() {
  openSheet(t('Demander de l\'argent'), `<div class="form">
    <input class="field" id="r-num" placeholder="${t('Numéro de la personne')}" list="r-list"><datalist id="r-list">${contactOptions()}</datalist>
    <input class="field" id="r-amount" type="number" min="1" placeholder="${t('Montant en $')}">
    <input class="field" id="r-reason" maxlength="60" placeholder="${t('Motif (facultatif)')}">
    <p class="error-text" id="r-err"></p>
    <button class="btn btn--block" id="r-go">${t('Envoyer la demande')}</button></div>`, (sh) => {
    $('#r-go', sh).onclick = async () => {
      const r = await api('requestMoney', { number: $('#r-num', sh).value.trim(), amount: $('#r-amount', sh).value, reason: $('#r-reason', sh).value });
      if (!r.ok) { $('#r-err', sh).textContent = t(r.error || 'Demande impossible.'); return; }
      closeSheet(); notify({ app: 'bank', title: t('Demande envoyée'), text: t('Vous serez prévenu dès qu\'elle sera payée.') });
    };
  });
}
async function requestsSheet() {
  const sh = openSheet(t('Demandes de paiement'), `<div id="req-list">${loading()}</div>`);
  const load = async () => {
    const r = await api('getRequests');
    const reqs = r.requests || [];
    const status = { pending: t('En attente'), paid: t('Payée'), declined: t('Refusée') };
    $('#req-list', sh).innerHTML = reqs.length ? `<div class="list">${reqs.map(q => `<div class="row">
      <span class="tx-ic ${q.incoming ? '' : 'in'}">${icon(q.incoming ? 'arrowUp' : 'arrowDown')}</span>
      <div class="row__main"><div class="row__title">${money(q.amount)} ${q.incoming ? t('pour') : t('de')} ${esc(nameFor(q.incoming ? q.from_number : q.to_number))}</div>
      <div class="row__sub">${esc(q.reason || '')}${q.reason ? ', ' : ''}${status[q.status]}, ${timeAgo(q.ts)}</div></div>
      ${q.incoming && q.status === 'pending' ? `<div class="req-actions"><button class="chip" data-ans="${q.id}" data-acc="0" aria-label="${t('Refuser')}">${t('Refuser')}</button><button class="chip chip--accent" data-ans="${q.id}" data-acc="1">${t('Payer')}</button></div>` : ''}</div>`).join('')}</div>`
      : `<p class="sheet__text" style="text-align:center">${t('Aucune demande pour le moment.')}</p>`;
    $$('[data-ans]', sh).forEach(b => b.onclick = async () => {
      const res = await api('answerRequest', { id: +b.dataset.ans, accept: b.dataset.acc === '1' });
      if (!res.ok) { notify({ app: 'bank', title: t('Paiement impossible'), text: t(res.error || 'Réessayez dans un instant.') }); return; }
      if (res.balance !== undefined) S.profile.bank = res.balance;
      load(); if (S.currentApp === 'bank') Views.bank();
    });
  };
  load();
}

/* ---------- Notes ---------- */
Views.notes = async ({ id } = {}) => {
  if (id !== undefined) return noteEditor(id);
  frame({ title: t('Notes'), action: `<button class="icon-btn icon-btn--accent" data-new aria-label="${t('Nouvelle note')}">${icon('plus')}</button>`, body: loading() });
  $('[data-new]', appView).onclick = () => openApp('notes', { id: null });
  const res = await api('getNotes');
  if (S.currentApp !== 'notes') return;
  S.notes = res.notes || [];
  $('.app__body', appView).innerHTML = S.notes.length ? `<div class="list">${S.notes.map(n => `<button class="row" data-note="${n.id}">
    <div class="row__main"><div class="row__title">${esc(n.title)}</div><div class="row__sub">${timeAgo(n.ts)}, ${esc(n.content.slice(0, 60))}</div></div></button>`).join('')}</div>`
    : empty(t('Aucune note'), t('Gardez une adresse, une liste ou un plan sous la main.'), `<button class="btn" data-new2>${t('Écrire une note')}</button>`);
  $('[data-new2]', appView)?.addEventListener('click', () => openApp('notes', { id: null }));
  $$('[data-note]', appView).forEach(b => b.onclick = () => openApp('notes', { id: +b.dataset.note }));
};
function noteEditor(id) {
  const n = S.notes.find(x => x.id === id) || { title: '', content: '' };
  let noteId = n.id || null, timer;
  frame({ title: '', small: true,
    action: noteId ? `<button class="icon-btn" data-del aria-label="${t('Supprimer')}">${icon('trash')}</button>` : '',
    body: `<div class="note-editor"><input class="field field--title" id="n-title" maxlength="80" placeholder="${t('Titre')}" value="${esc(n.title)}">
      <textarea class="field" id="n-body" placeholder="${t('Commencez à écrire…')}">${esc(n.content)}</textarea></div>` });
  const save = async () => {
    const r = await api('saveNote', { id: noteId, title: $('#n-title')?.value, content: $('#n-body')?.value });
    if (r.ok) noteId = r.id;
  };
  const queue = () => { clearTimeout(timer); timer = setTimeout(save, 600); };
  $('#n-title').oninput = queue; $('#n-body').oninput = queue;
  $('[data-back]', appView).onclick = async () => { clearTimeout(timer); if ($('#n-title').value || $('#n-body').value) await save(); back(); };
  $('[data-del]', appView)?.addEventListener('click', () => confirmSheet(t('Supprimer la note ?'), t('Cette action est définitive.'), t('Supprimer'), async () => {
    clearTimeout(timer); await api('deleteNote', { id: noteId }); back();
  }));
  $('#n-body').focus();
}

/* ---------- Plans ---------- */
Views.maps = async () => {
  frame({ title: t('Plans'), body: loading() });
  const loc = await post('getLocation');
  if (S.currentApp !== 'maps') return;
  const places = S.profile?.places || [];
  $('.app__body', appView).innerHTML = `
    <div class="post" style="display:flex;flex-direction:column;gap:10px">
      <div class="geo-map" style="height:130px"></div>
      <div><div class="row__title">${esc(loc?.street || t('Position inconnue'))}</div>
      <div class="row__sub">${esc([loc?.cross, loc?.zone].filter(Boolean).join(', '))}</div></div>
      <button class="btn btn--ghost btn--block" data-share>${icon('send')}${t('Envoyer ma position')}</button></div>
    <p class="section-label">${t('Destinations')}</p>
    <div class="list">${places.map(p => `<button class="row" data-place="${p.id}"><span class="chip-ic" style="--c:#3FBF8E">${icon('pin')}</span>
      <div class="row__main"><div class="row__title row__title--light">${esc(p.label)}</div></div><span class="row__chev">${icon('chev')}</span></button>`).join('')}</div>`;
  $$('[data-place]', appView).forEach(b => b.onclick = () => {
    post('setWaypoint', { place: +b.dataset.place });
    notify({ app: 'maps', title: t('Itinéraire défini'), text: b.textContent.trim() });
  });
  $('[data-share]', appView).onclick = () => openSheet(t('Envoyer ma position'), `<div class="form">
    <input class="field" id="s-num" placeholder="${t('Numéro')}" list="s-list"><datalist id="s-list">${contactOptions()}</datalist>
    <button class="btn btn--block" id="s-go">${t('Envoyer')}</button></div>`, (sh) => {
    sh.querySelector('#s-go').onclick = async () => {
      const n = $('#s-num').value.trim(); if (!n || !loc) return;
      await api('sendMessage', { number: n, message: `%%GPS:${loc.x},${loc.y}|${[loc.street, loc.zone].filter(Boolean).join(', ')}` });
      closeSheet(); notify({ app: 'messages', title: t('Position envoyée'), text: nameFor(n) });
    };
  });
};

/* ---------- Urgences ---------- */
Views.alert = () => {
  const services = S.profile?.services || [];
  let selected = services[0]?.id;
  frame({ title: t('Urgences'), body: `
    <div class="services">${services.map(s => `<button class="service ${s.id === selected ? 'selected' : ''}" data-svc="${s.id}" style="--svc:${s.color}">
      <span class="service__dot">${icon(s.icon)}</span><span class="service__name">${esc(t(s.label))}</span></button>`).join('')}</div>
    <p class="section-label">${t('Décrivez la situation')}</p>
    <div class="form"><textarea class="field" id="al-msg" rows="4" maxlength="200" placeholder="${t('Ex : accident sur l\'autoroute, deux blessés')}"></textarea>
    <p class="row__sub row__sub--wrap" style="padding:0 6px">${t('Votre position et votre numéro sont transmis automatiquement.')}</p>
    <button class="btn btn--block" id="al-go">${t('Envoyer l\'alerte')}</button></div>` });
  $$('[data-svc]', appView).forEach(b => b.onclick = () => { selected = b.dataset.svc; $$('[data-svc]', appView).forEach(x => x.classList.toggle('selected', x === b)); });
  $('#al-go').onclick = async (e) => {
    e.currentTarget.disabled = true;
    const r = await api('sendAlert', { service: selected, message: $('#al-msg').value });
    const svc = t(services.find(s => s.id === selected)?.label || '');
    notify({ app: 'alert', title: r.ok ? t('Alerte envoyée') : t('Échec de l\'envoi'),
      text: r.ok ? (r.count ? t('{n} agent(s) {svc} prévenu(s)', { n: r.count, svc }) : t('Aucun agent {svc} en service pour le moment', { svc })) : t('Réessayez dans un instant.') });
    $('#al-msg').value = ''; e.currentTarget.disabled = false;
  };
};

/* ---------- Calculatrice ---------- */
Views.calc = () => {
  let expr = '', value = '0', fresh = false;
  frame({ title: t('Calcul'), body: '' });
  const body = $('.app__body', appView); body.style.padding = '0';
  body.innerHTML = `<div class="calc"><div class="calc__screen"><div class="calc__expr" id="cx"></div><div class="calc__value" id="cv">0</div></div>
    <div class="calc__grid">${['C', '±', '%', '÷', '7', '8', '9', '×', '4', '5', '6', '−', '1', '2', '3', '+', '0', ',', '='].map(k => {
      const cls = '÷×−+='.includes(k) ? 'op' : 'C±%'.includes(k) ? 'fn' : k === '0' ? 'wide' : '';
      return `<button class="${cls}" data-k="${k}">${k}</button>`;
    }).join('')}</div></div>`;
  const show = () => { $('#cv').textContent = value === 'Erreur' ? t('Erreur') : value.replace('.', ','); $('#cx').textContent = expr; };
  const compute = (e) => {
    try {
      const js = e.replace(/×/g, '*').replace(/÷/g, '/').replace(/−/g, '-').replace(/,/g, '.');
      if (!/^[\d.+\-*/() ]+$/.test(js)) return 'Erreur';
      const r = Function(`"use strict";return (${js})`)();
      return Number.isFinite(r) ? String(+r.toFixed(8)) : 'Erreur';
    } catch { return 'Erreur'; }
  };
  $$('[data-k]', appView).forEach(b => b.onclick = () => {
    const k = b.dataset.k;
    if (/\d/.test(k)) { value = (fresh || value === '0') ? k : value + k; fresh = false; }
    else if (k === ',') { if (fresh) { value = '0'; fresh = false; } if (!value.includes('.')) value += '.'; }
    else if (k === 'C') { value = '0'; expr = ''; }
    else if (k === '±') { value = value.startsWith('-') ? value.slice(1) : '-' + value; }
    else if (k === '%') { value = String(+value / 100); }
    else if (k === '=') { if (!expr) return; const full = expr + ' ' + value; value = compute(full.replace(/\s/g, '')); expr = full + ' ='; fresh = true; }
    else { if (expr.endsWith('=')) expr = ''; expr = ((expr ? expr + ' ' : '') + value + ' ' + k).replace(/\s+/g, ' '); value = '0'; fresh = false; }
    if (value === 'Erreur') fresh = true;
    show();
  });
};

/* ---------- Annonces ---------- */
Views.ads = async () => {
  frame({ title: t('Annonces'), action: `<button class="icon-btn icon-btn--accent" data-new aria-label="${t('Publier une annonce')}">${icon('plus')}</button>`, body: loading() });
  $('[data-new]', appView).onclick = () => openSheet(t('Publier une annonce'), `<div class="form">
    <input class="field" id="a-title" maxlength="80" placeholder="${t('Titre')}">
    <textarea class="field" id="a-text" rows="4" maxlength="400" placeholder="${t('Description')}"></textarea>
    <input class="field" id="a-price" type="number" min="0" placeholder="${t('Prix en $ (facultatif)')}">
    <p class="error-text" id="a-err"></p>
    <button class="btn btn--block" id="a-go">${t('Publier l\'annonce')}</button></div>`, (sh) => {
    sh.querySelector('#a-go').onclick = async () => {
      const res = await api('createAd', { title: $('#a-title').value, content: $('#a-text').value, price: $('#a-price').value || null });
      if (!res.ok) { $('#a-err').textContent = t(res.error || 'Publication impossible.'); return; }
      closeSheet(); Views.ads();
    };
  });
  const res = await api('getAds');
  if (S.currentApp !== 'ads') return;
  const ads = res.ads || [];
  $('.app__body', appView).innerHTML = ads.length ? ads.map(a => `<article class="ad">
    <div class="ad__top"><h3 class="ad__title">${esc(a.title)}</h3>${a.price != null ? `<span class="ad__price">${money(a.price)}</span>` : ''}</div>
    <p class="ad__text">${esc(a.content)}</p>
    <div class="ad__foot"><span class="ad__author">${esc(a.author_name)}, ${timeAgo(a.ts)}</span>
    ${a.mine ? `<button class="chip" data-del="${a.id}">${t('Retirer')}</button>` : `<button class="chip" data-msg="${esc(a.number)}">${t('Écrire')}</button><button class="chip chip--accent" data-call="${esc(a.number)}">${t('Appeler')}</button>`}</div></article>`).join('')
    : empty(t('Aucune annonce'), t('Vendez, achetez ou proposez vos services à toute la ville.'));
  $$('[data-msg]', appView).forEach(b => b.onclick = () => openApp('messages', { number: b.dataset.msg }));
  $$('[data-call]', appView).forEach(b => b.onclick = () => startCall(b.dataset.call));
  $$('[data-del]', appView).forEach(b => b.onclick = async () => { await api('deleteAd', { id: +b.dataset.del }); Views.ads(); });
};

/* ---------- Appli (magasin) ---------- */
const STORE = {
  birdy:     { tagline: 'Ce qui se dit en ville, en 280 caractères.', category: 'Réseau social', about: 'Publiez des messages courts, mentionnez vos amis avec @identifiant, re-gazouillez ce qui vous plaît et répondez aux discussions. Les mentions vous envoient une notification.' },
  instapick: { tagline: 'Vos plus belles photos de Los Santos.', category: 'Photo et partage', about: 'Partagez les clichés de votre galerie avec une légende. Touchez deux fois une photo pour l\'aimer, commentez, et retrouvez toutes vos publications sur votre profil.' },
  itoune:    { tagline: 'Collez un lien, la musique part.', category: 'Musique', about: 'Collez un lien YouTube ou Spotify et le morceau se lance sur votre téléphone. Activez le haut-parleur pour que les personnes autour de vous l\'entendent, ou gardez-le pour vous.' },
  carplay:   { tagline: 'Votre voiture, au bout des doigts.', category: 'Auto et dépannage', about: 'Verrouillez, ouvrez les portes et les vitres, allumez les LED, lancez de la musique dans votre voiture et retrouvez-la grâce aux phares et au klaxon, même à distance. Dans le véhicule, la tablette ElyzeaCarPlay s\'ouvre avec sa touche dédiée.' },
  garage:    { tagline: 'Vos véhicules, livrés à la demande.', category: 'Auto et dépannage', about: 'Retrouvez tous vos véhicules : au garage, sortis ou en fourrière. Localisez ceux qui sont en ville, et faites-vous apporter celui de votre choix par un voiturier, qui vous remet les clés en main propre.' },
  helpmecano:{ tagline: 'Un mécanicien vient à vous, où que vous soyez.', category: 'Auto et dépannage', about: 'Panne, accident ou voiture sale : une dépanneuse part du garage le plus proche et vous rejoint. Le mécanicien répare, nettoie ou remet votre véhicule sur ses roues sous vos yeux, puis repart. Suivez son arrivée en direct sur le GPS.' },
  livrezy:   { tagline: 'Vos courses livrées où que vous soyez.', category: 'Livraison', about: 'Repas, snacks, boissons : commandez depuis votre téléphone, un livreur part du commerce le plus proche. Suivez-le en direct sur le GPS jusqu\'à ce qu\'il vous remette votre commande en main propre.' },
  etincelle: { tagline: 'Faites des rencontres à Los Santos.', category: 'Rencontres', about: 'Créez votre profil avec vos photos, glissez à droite quand quelqu\'un vous plaît. Si c\'est réciproque, c\'est une étincelle : discutez dans une messagerie privée, sans partager votre numéro.' },
};
async function setInstalled(id, on) {
  const list = installed().filter(x => x !== id);
  if (on) list.push(id);
  await saveSettings({ installed: list });
  if (!on && id === 'itoune') Music.stop();
}
const storeTile = (id, size = 52) => `<span style="flex:none;display:block;width:${size}px;height:${size}px">${solidTile(id, size)}</span>`;
const storeButton = (id) => isInstalled(id)
  ? `<button class="get-btn get-btn--open" data-launch="${id}">${t('Ouvrir')}</button>`
  : `<button class="get-btn" data-get="${id}">${t('Obtenir')}</button>`;
function wireStoreButtons(root, after) {
  $$('[data-launch]', root).forEach(b => b.onclick = (e) => { e.stopPropagation(); closeSheet(true); openApp(b.dataset.launch); });
  $$('[data-get]', root).forEach(b => b.onclick = (e) => { e.stopPropagation(); download(b, b.dataset.get, after); });
}
function download(btn, id, after) {
  if (btn.classList.contains('loading')) return;
  btn.classList.add('loading'); btn.innerHTML = '<span class="ring"></span>';
  btn.setAttribute('aria-label', t('Téléchargement en cours'));
  const ring = btn.firstChild, start = performance.now(), total = 1700;
  const step = (now) => {
    const p = Math.min(1, (now - start) / total);
    ring.style.setProperty('--p', p * 360 + 'deg');
    if (p < 1) return requestAnimationFrame(step);
    setInstalled(id, true).then(() => {
      S.freshApp = id;
      notify({ app: id, title: t('{app} installée', { app: APPS[id].label }), text: t('Elle vous attend sur l\'écran d\'accueil.') });
      after?.();
    });
  };
  requestAnimationFrame(step);
}
Views.store = ({ detail } = {}) => {
  const ids = Object.keys(STORE);
  const featured = ids.find(id => !isInstalled(id)) || ids[0];
  const ic = APP_ICONS[featured];
  frame({ title: t('Appli'), body: `
    <article class="feature" style="--c1:${ic.c1};--c2:${ic.c2}" data-detail="${featured}">
      <div class="feature__art">${storeTile(featured, 72)}</div>
      <div class="feature__text"><p class="feature__kicker">${isInstalled(featured) ? t('Déjà sur votre téléphone') : t('À découvrir')}</p>
        <h2 class="feature__name">${APPS[featured].label}</h2><p class="feature__tagline">${t(STORE[featured].tagline)}</p></div>
      <div class="feature__cta">${storeButton(featured)}</div></article>
    <p class="section-label">${t('Toutes les applications')}</p>
    <div class="list">${ids.map(id => `<div class="row" data-detail="${id}" role="button" tabindex="0" style="cursor:pointer">${storeTile(id)}
      <div class="row__main"><div class="row__title">${APPS[id].label}</div><div class="row__sub">${t(STORE[id].category)}</div></div>${storeButton(id)}</div>`).join('')}</div>
    <p class="row__sub row__sub--wrap" style="text-align:center;margin:18px 10px 0">${t('Les applications installées apparaissent sur l\'écran d\'accueil.')}</p>` });
  const rerender = () => { if (S.currentApp === 'store') Views.store(); };
  wireStoreButtons(appView, rerender);
  $$('[data-detail]', appView).forEach(el => el.onclick = () => storeDetail(el.dataset.detail, rerender));
  if (detail) storeDetail(detail, rerender);
};
function storeDetail(id, after) {
  const d = STORE[id];
  const draw = (sh) => {
    sh.innerHTML = `<div class="store-detail__head">${storeTile(id, 78)}
        <div><h2 class="sheet__title" style="margin:0">${APPS[id].label}</h2><p class="row__sub">${t(d.category)}</p><div style="margin-top:10px">${storeButton(id)}</div></div></div>
      <p class="store-detail__tagline">${t(d.tagline)}</p><p class="store-detail__about">${t(d.about)}</p>
      ${isInstalled(id) ? `<button class="btn btn--danger btn--block" data-uninstall>${t('Désinstaller')}</button>` : ''}`;
    wireStoreButtons(sh, () => { draw(sh); after?.(); });
    sh.querySelector('[data-uninstall]')?.addEventListener('click', async () => {
      await setInstalled(id, false);
      notify({ app: 'store', title: t('{app} supprimée', { app: APPS[id].label }), text: t('Vos données restent sauvegardées.') });
      draw(sh); after?.();
    });
  };
  openSheet('', '', draw);
}
