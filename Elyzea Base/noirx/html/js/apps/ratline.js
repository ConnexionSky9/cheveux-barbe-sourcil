/* NOIR X — Ratline : discuter avec des informateurs PNJ (champs, revendeurs, rumeurs…). */
(function () {
  'use strict';
  const h = NX.h;
  let stack = null;

  function setWaypoint(gps) {
    if (!gps) return;
    NX.post('waypoint', { x: gps.x, y: gps.y });
    NX.notify('Ratline', 'Position marquée sur ton GPS.');
  }

  function gpsButton(intelId, gps) {
    return h('button', { class: 'bubble__action', on: { click: () => {
      NX.sound('tap');
      if (gps) return setWaypoint(gps);
      NX.rpc('ratline.gps', { intel: intelId }).then(res => res.ok ? setWaypoint(res.gps) : NX.fail(res));
    } } }, NX.icon('gps'), h('span', { text: 'Placer le GPS' }));
  }

  /* ── Liste des informateurs ─────────────────────────────────── */
  function renderList(body) {
    body.append(NX.ui.loader());
    NX.rpc('ratline.list').then(res => {
      body.textContent = '';
      if (!res.ok) { body.append(NX.ui.empty('ratline', 'Réseau indisponible', res.message)); return; }
      if (!res.informants.length) {
        body.append(NX.ui.empty('ratline', 'Aucun informateur', 'Personne ne parle pour l\'instant. Repasse plus tard.'));
        return;
      }
      const list = h('div', { class: 'card' });
      res.informants.forEach(inf => list.append(NX.ui.row({
        lead: NX.ui.avatar(inf.name, { npc: true }),
        title: inf.name,
        sub: inf.last ? (inf.last.mine ? 'Toi : ' : '') + inf.last.body : inf.tagline,
        meta: inf.last ? NX.ui.ago(inf.last.at) : '',
        onClick: () => stack.push(inf.name, (b) => renderChat(b, inf.id), { flush: true }),
      })));
      body.append(list);
      NX.applyIcons(body);
    });
  }

  /* ── Conversation ───────────────────────────────────────────── */
  function renderChat(body, informantId) {
    let data = null;
    let busy = false;
    const thread = h('div', { class: 'thread' });
    const topics = h('div', { class: 'topics' });
    const input = NX.ui.input({ placeholder: 'Demande-lui quelque chose…', maxLength: 160 });
    const sendBtn = h('button', { class: 'composer__send', attrs: { 'aria-label': 'Envoyer' } }, NX.icon('send'));
    const composer = h('div', { class: 'composer' }, input, sendBtn);
    body.append(h('div', { class: 'chat' }, thread, topics, composer));

    function scroll() { requestAnimationFrame(() => { thread.scrollTop = thread.scrollHeight; }); }

    function bubble(mine, text, extra) {
      const b = h('div', { class: 'bubble ' + (mine ? 'bubble--me' : 'bubble--them') }, h('div', { class: 'bubble__text', text }), extra || null);
      thread.append(b);
      NX.applyIcons(b);
      scroll();
      return b;
    }

    function typing() {
      const t = h('div', { class: 'bubble bubble--them bubble--typing' }, h('span'), h('span'), h('span'));
      thread.append(t);
      scroll();
      return t;
    }

    function priceLabel(t) {
      if (t.purchased) return 'payé';
      if (!t.price) return 'gratuit';
      return `${NX.money(t.price)} ${t.currency === 'dirty' ? 'sale' : 'propre'}`;
    }

    function topicChip(t, cls) {
      return h('button', { class: 'topic' + (cls ? ' ' + cls : '') + (t.purchased ? ' is-bought' : ''), on: { click: () => ask(t) } },
        h('span', { class: 'topic__cat', text: t.categoryLabel }),
        h('span', { class: 'topic__title', text: t.title }),
        h('span', { class: 'topic__price', text: priceLabel(t) }));
    }

    function renderTopics() {
      topics.textContent = '';
      if (!data.topics.length) { topics.append(h('div', { class: 'hint', text: 'Il n\'a rien à vendre pour le moment.' })); return; }
      data.topics.forEach(t => topics.append(topicChip(t)));
    }

    async function ask(t) {
      if (busy) return;
      NX.sound('tap');
      if (!t.purchased && t.price > 0) {
        const ok = await NX.ui.confirm(t.title,
          `Il demande ${NX.money(t.price)} en argent ${t.currency === 'dirty' ? 'sale' : 'propre'}. Fiabilité annoncée : ${t.reliability}.`, 'Payer');
        if (!ok) return;
      }
      busy = true;
      bubble(true, t.title);
      const res = await NX.rpc('ratline.ask', { informant: informantId, intel: t.id });
      if (!res.ok) { busy = false; bubble(false, res.message || 'Pas maintenant.'); return; }
      NX.sound('send');
      const dots = typing();
      setTimeout(() => {
        dots.remove();
        bubble(false, res.answer, res.gps ? gpsButton(res.intel, res.gps) : null);
        NX.sound('notify');
        t.purchased = true;
        renderTopics();
        busy = false;
      }, res.delay || 900);
    }

    async function say() {
      const text = input.value.trim();
      if (!text || busy) return;
      busy = true;
      input.value = '';
      bubble(true, text);
      const res = await NX.rpc('ratline.say', { informant: informantId, text });
      if (!res.ok) { busy = false; bubble(false, res.message || '…'); return; }
      const dots = typing();
      setTimeout(() => {
        dots.remove();
        const sug = res.suggestions && res.suggestions.length
          ? h('div', { class: 'bubble__suggest' }, ...res.suggestions.map(t => {
            const local = data.topics.find(x => x.id === t.id) || t;
            return topicChip(local, 'topic--inline');
          }))
          : null;
        bubble(false, res.reply, sug);
        NX.sound('notify');
        busy = false;
      }, res.delay || 800);
    }

    sendBtn.addEventListener('click', () => { NX.sound('tap'); say(); });
    input.addEventListener('keydown', e => { if (e.key === 'Enter') { e.preventDefault(); say(); } });

    thread.append(NX.ui.loader());
    NX.rpc('ratline.open', { informant: informantId }).then(res => {
      thread.textContent = '';
      if (!res.ok) { thread.append(NX.ui.empty('ratline', 'Contact injoignable', res.message)); return; }
      data = res;
      NX.setTitle(res.informant.name);
      thread.append(h('div', { class: 'thread__intro' },
        NX.ui.avatar(res.informant.name, { npc: true }),
        h('div', { class: 'thread__name', text: res.informant.name }),
        h('div', { class: 'thread__tag', text: res.informant.tagline || 'Informateur' })));
      if (!res.history.length && res.informant.greeting) bubble(false, res.informant.greeting);
      res.history.forEach(m => bubble(m.mine, m.body, !m.mine && m.gps && m.intel ? gpsButton(m.intel) : null));
      renderTopics();
      NX.applyIcons(body);
      scroll();
    });
  }

  NX.registerApp('ratline', {
    title: 'Ratline',
    render(body) {
      stack = NX.ui.stack(body, 'Ratline');
      stack.push('Ratline', renderList);
    },
    onBack() { return stack ? stack.pop() : false; },
    destroy() { if (stack) stack.destroy(); stack = null; },
  });
})();
