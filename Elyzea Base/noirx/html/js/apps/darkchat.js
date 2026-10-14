/* NOIR X — Dark Chat : conversations privées et de groupe, invitations, éphémères, lectures. */
(function () {
  'use strict';
  const h = NX.h;
  let stack = null, offs = [];
  let openConv = null; // conversation actuellement affichée

  /* ── Liste des conversations ────────────────────────────────── */
  function renderList(body, params) {
    body.append(h('div', { class: 'gl-head' }, NX.ident.switcher(),
      NX.ui.button(null, 'ghost', () => openNew(), 'plus')));
    const host = h('div', {});
    body.append(host);

    function load() {
      host.textContent = '';
      host.append(NX.ui.loader());
      NX.rpc('chat.list', { identity: NX.ident.id() }).then(res => {
        host.textContent = '';
        if (!res.ok) { host.append(NX.ui.empty('darkchat', 'Indisponible', res.message)); return; }
        const invites = res.conversations.filter(c => c.status === 'invited');
        const convs = res.conversations.filter(c => c.status === 'active');

        if (invites.length) {
          host.append(NX.ui.label('Invitations'));
          const card = h('div', { class: 'card' });
          invites.forEach(c => card.append(h('div', { class: 'lrow lrow--static' },
            NX.icon('users', 'lrow__ic'),
            h('span', { class: 'lrow__main' }, h('span', { class: 'lrow__title', text: c.title }), h('span', { class: 'lrow__sub', text: 'invitation au groupe' })),
            h('span', { class: 'lrow__side' },
              h('button', { class: 'icon-btn icon-btn--ok', on: { click: () => invite(c.id, true, load) } }, NX.icon('check')),
              h('button', { class: 'icon-btn', on: { click: () => invite(c.id, false, load) } }, NX.icon('close'))))));
          host.append(card);
        }

        let totalUnread = 0;
        if (!convs.length) {
          host.append(NX.ui.empty('darkchat', 'Aucune conversation', 'Démarre une discussion privée ou crée un groupe.'));
        } else {
          const card = h('div', { class: 'card' });
          convs.forEach(c => {
            totalUnread += c.unread || 0;
            card.append(NX.ui.row({
              lead: c.kind === 'group' ? NX.icon('users', 'lrow__ic lrow__ic--round') : NX.ui.avatar(c.title, { small: true }),
              title: (c.favorite ? '★ ' : '') + c.title,
              sub: (c.preview ? (c.previewMine ? 'Toi : ' : '') + c.preview : (c.ephemeral ? 'messages éphémères' : 'aucun message')),
              meta: c.lastAt ? NX.ui.ago(c.lastAt) : '',
              badge: c.unread || 0,
              onClick: () => stack.push(c.title, (b) => renderConv(b, c.id, c.title), { flush: true }),
            }));
          });
          host.append(card);
        }
        NX.badge('darkchat', totalUnread);
        NX.applyIcons(host);
      });
    }

    const off1 = NX.on('chat:message', () => { if (stack.depth() === 1) load(); });
    const off2 = NX.on('chat:invite', load);
    const off3 = NX.on('identity:changed', () => stack.refresh());
    const off4 = NX.on('chat:removed', load);
    load();

    if (params && params.dm) {
      NX.rpc('chat.dm', { identity: NX.ident.id(), target: params.dm, handle: params.handle }).then(res => {
        if (res.ok) stack.push(params.handle || 'Conversation', (b) => renderConv(b, res.conversation, params.handle), { flush: true });
        else NX.fail(res);
      });
    }
    return () => { off1(); off2(); off3(); off4(); };
  }

  function invite(conversation, accept, done) {
    NX.rpc('chat.respond', { identity: NX.ident.id(), conversation, accept }).then(res => {
      if (!res.ok) return NX.fail(res);
      NX.sound(accept ? 'win' : 'tap');
      done();
    });
  }

  function openNew() {
    NX.ui.sheet({
      title: 'Nouvelle conversation',
      content: h('div', { class: 'card' },
        NX.ui.row({ lead: NX.icon('user', 'lrow__ic'), title: 'Message privé', sub: 'À partir d\'un pseudo', onClick: () => { NX.ui.closeTopSheet(); newDm(); } }),
        NX.ui.row({ lead: NX.icon('users', 'lrow__ic'), title: 'Créer un groupe', sub: 'Invite plusieurs contacts', onClick: () => { NX.ui.closeTopSheet(); newGroup(); } })),
    });
  }

  function newDm() {
    NX.ui.prompt('Message privé', { placeholder: 'pseudo exact', maxLength: 20, confirmLabel: 'Ouvrir' }).then(handle => {
      if (!handle) return;
      NX.rpc('chat.dm', { identity: NX.ident.id(), handle }).then(res => {
        if (!res.ok) return NX.fail(res);
        stack.push(handle, (b) => renderConv(b, res.conversation, handle), { flush: true });
      });
    });
  }

  function newGroup() {
    NX.ui.prompt('Créer un groupe', { placeholder: 'nom du groupe', maxLength: 32, confirmLabel: 'Créer' }).then(name => {
      if (!name) return;
      NX.rpc('chat.group', { identity: NX.ident.id(), name }).then(res => {
        if (!res.ok) return NX.fail(res);
        NX.sound('win');
        stack.push(name, (b) => renderConv(b, res.conversation, name), { flush: true });
      });
    });
  }

  /* ── Conversation ───────────────────────────────────────────── */
  function renderConv(body, convId, title) {
    let info = null, oldestId = null, loadingMore = false, hasMore = false, peerRead = null;
    const seen = new Set();
    openConv = convId;
    const thread = h('div', { class: 'thread' });
    const input = NX.ui.input({ placeholder: 'Message chiffré…', maxLength: 500 });
    const sendBtn = h('button', { class: 'composer__send' }, NX.icon('send'));
    body.append(h('div', { class: 'chat' }, thread, h('div', { class: 'composer' }, input, sendBtn)));

    function scroll() { requestAnimationFrame(() => { thread.scrollTop = thread.scrollHeight; }); }

    function msgEl(m) {
      const mine = info && m.sender === info.myId;
      const el = h('div', { class: 'msg ' + (mine ? 'msg--me' : 'msg--them'), dataset: { id: m.id } },
        (!mine && info && info.kind === 'group') ? h('span', { class: 'msg__who', text: m.handle }) : null,
        h('span', { class: 'msg__text', text: m.body }),
        h('span', { class: 'msg__time' }, m.expiresAt ? NX.icon('clock', 'msg__eph') : null, document.createTextNode(NX.ui.clock(m.at))));
      return el;
    }

    function append(m, prepend) {
      if (seen.has(m.id)) return;
      seen.add(m.id);
      const el = msgEl(m);
      if (prepend) thread.insertBefore(el, thread.firstChild.classList && thread.firstChild.classList.contains('loadmore') ? thread.children[1] : thread.firstChild);
      else thread.append(el);
      NX.applyIcons(el);
      updateReadMark();
    }

    function updateReadMark() {
      thread.querySelectorAll('.msg__read').forEach(e => e.remove());
      if (!info || info.kind !== 'dm' || peerRead == null) return;
      let last = null;
      thread.querySelectorAll('.msg--me').forEach(e => { if (Number(e.dataset.id) <= peerRead) last = e; });
      if (last) last.append(h('span', { class: 'msg__read', text: 'lu' }));
    }

    function header() {
      NX.setTitle(info.title);
      NX.setAction('more', () => openInfo(convId, info, () => stack.pop()));
    }

    function loadInitial() {
      thread.append(NX.ui.loader());
      NX.rpc('chat.history', { identity: NX.ident.id(), conversation: convId }).then(res => {
        thread.textContent = '';
        if (!res.ok) { thread.append(NX.ui.empty('darkchat', 'Accès refusé', res.message)); return; }
        info = { myId: NX.ident.id(), kind: res.conversation.kind, title: res.conversation.title, role: res.conversation.role,
          ephemeral: res.conversation.ephemeral, peer: res.conversation.peer, favorite: res.conversation.favorite };
        hasMore = res.hasMore; peerRead = res.peerRead;
        header();
        if (res.messages.length) oldestId = res.messages[0].id;
        if (hasMore) thread.append(loadMoreBtn());
        if (!res.messages.length) thread.append(h('div', { class: 'thread__empty', text: info.ephemeral ? 'Messages éphémères activés.' : 'Début de la conversation.' }));
        res.messages.forEach(m => append(m));
        NX.applyIcons(thread);
        scroll();
      });
    }

    function loadMoreBtn() {
      const b = h('button', { class: 'loadmore', text: 'Messages précédents', on: { click: () => loadMore(b) } });
      return b;
    }

    function loadMore(btn) {
      if (loadingMore || !oldestId) return;
      loadingMore = true; btn.textContent = '…';
      NX.rpc('chat.history', { identity: NX.ident.id(), conversation: convId, before: oldestId }).then(res => {
        loadingMore = false;
        if (!res.ok || !res.messages.length) { btn.remove(); return; }
        oldestId = res.messages[0].id;
        const prevH = thread.scrollHeight;
        res.messages.reverse().forEach(m => append(m, true));
        if (!res.hasMore) btn.remove(); else btn.textContent = 'Messages précédents';
        thread.scrollTop = thread.scrollHeight - prevH;
      });
    }

    function send() {
      const text = input.value.trim();
      if (!text) return;
      input.value = '';
      NX.rpc('chat.send', { identity: NX.ident.id(), conversation: convId, body: text }).then(res => {
        if (!res.ok) { NX.fail(res); return; }
        NX.sound('send');
        append(res.message);
        scroll();
      });
    }
    sendBtn.addEventListener('click', () => send());
    input.addEventListener('keydown', e => { if (e.key === 'Enter') { e.preventDefault(); send(); } });

    const offMsg = NX.on('chat:message', p => {
      if (p.conversation !== convId) return;
      append(p.message); scroll();
      NX.rpc('chat.history', { identity: NX.ident.id(), conversation: convId }).catch(() => {});
    });
    const offRead = NX.on('chat:read', p => { if (p.conversation === convId) { peerRead = p.last; updateReadMark(); } });
    const offSet = NX.on('chat:settings', p => { if (p.conversation === convId && info) info.ephemeral = p.ephemeral; });
    const offKick = NX.on('chat:removed', p => { if (p.conversation === convId) { NX.notify('Dark Chat', 'Tu as été retiré de cette conversation.'); stack.pop(); } });

    loadInitial();
    return () => { openConv = null; offMsg(); offRead(); offSet(); offKick(); };
  }

  /* ── Infos / gestion de la conversation ─────────────────────── */
  function openInfo(convId, info, onLeave) {
    NX.rpc('chat.members', { identity: NX.ident.id(), conversation: convId }).then(res => {
      if (!res.ok) return NX.fail(res);
      const isGroup = res.kind === 'group';
      const myRole = (res.members.find(m => m.me) || {}).role;
      const canManage = myRole === 'owner' || myRole === 'admin';
      const content = h('div', {});

      // Éphémères
      const ephRow = h('div', { class: 'card card--pad' },
        h('div', { class: 'field-label', text: 'Messages éphémères' }),
        NX.ui.chips(res.ephemeralOptions.map(s => [s, s === 0 ? 'Off' : NX.ui.duration(s)]), res.ephemeral, sec => {
          if (isGroup && !canManage) { NX.notify('Dark Chat', 'Réservé aux responsables.', 'error'); return; }
          NX.rpc('chat.settings', { identity: NX.ident.id(), conversation: convId, ephemeral: sec }).then(r => {
            if (!r.ok) return NX.fail(r);
            NX.notify('Dark Chat', sec ? `Messages effacés après ${NX.ui.duration(sec)}.` : 'Éphémères désactivés.');
          });
        }),
        h('div', { class: 'hint', text: 'S\'applique aux nouveaux messages.' }));
      content.append(ephRow);

      // Favori
      content.append(h('div', { class: 'card' }, NX.ui.row({
        lead: NX.icon('star', 'lrow__ic'), title: info.favorite ? 'Retirer des favoris' : 'Mettre en favori',
        onClick: () => NX.rpc('chat.settings', { identity: NX.ident.id(), conversation: convId, favorite: !info.favorite }).then(r => { if (r.ok) { info.favorite = !info.favorite; NX.sound('tap'); NX.ui.closeTopSheet(); } }),
      })));

      if (isGroup) {
        content.append(NX.ui.label(`Membres · ${res.members.length}/${res.max}`));
        const card = h('div', { class: 'card' });
        res.members.forEach(m => {
          const canKick = canManage && !m.me && (myRole === 'owner' || m.role === 'member') && m.role !== 'owner';
          card.append(h('div', { class: 'lrow lrow--static' },
            NX.ui.avatar(m.handle, { small: true }),
            h('span', { class: 'lrow__main' },
              h('span', { class: 'lrow__title', text: m.handle + (m.me ? ' (toi)' : '') }),
              h('span', { class: 'lrow__sub', text: m.status === 'invited' ? 'invité' : ({ owner: 'fondateur', admin: 'admin', member: 'membre' }[m.role]) })),
            canKick ? h('button', { class: 'icon-btn', on: { click: () => kick(convId, m, () => openInfoRefresh(convId, info, onLeave)) } }, NX.icon('close')) : null));
        });
        content.append(card);
        if (canManage) content.append(h('div', { class: 'stack-gap' }, NX.ui.button('Inviter un contact', 'ghost', () => inviteToGroup(convId), 'plus')));
      }

      content.append(h('div', { class: 'stack-gap' },
        NX.ui.button(isGroup ? 'Quitter le groupe' : 'Masquer la conversation', 'danger', () => leave(convId, onLeave))));

      NX.ui.sheet({ title: isGroup ? 'Groupe' : 'Conversation', content });
    });
  }
  function openInfoRefresh(convId, info, onLeave) { NX.ui.closeTopSheet(); openInfo(convId, info, onLeave); }

  function kick(convId, m, done) {
    NX.ui.confirm('Retirer le membre', `Retirer ${m.handle} du groupe ?`, 'Retirer', true).then(ok => {
      if (!ok) return;
      NX.rpc('chat.kick', { identity: NX.ident.id(), conversation: convId, target: m.id }).then(r => { if (!r.ok) return NX.fail(r); NX.sound('tap'); done(); });
    });
  }

  function inviteToGroup(convId) {
    NX.ui.prompt('Inviter au groupe', { placeholder: 'pseudo exact', maxLength: 20, confirmLabel: 'Inviter' }).then(handle => {
      if (!handle) return;
      NX.rpc('chat.invite', { identity: NX.ident.id(), conversation: convId, handle }).then(r => {
        if (!r.ok) return NX.fail(r);
        NX.sound('send'); NX.notify('Dark Chat', r.message || 'Invitation transmise.');
      });
    });
  }

  function leave(convId, onLeave) {
    NX.ui.confirm('Confirmer', 'Quitter cette conversation ?', 'Quitter', true).then(ok => {
      if (!ok) return;
      NX.rpc('chat.leave', { identity: NX.ident.id(), conversation: convId }).then(r => {
        if (!r.ok) return NX.fail(r);
        NX.sound('close'); NX.ui.closeSheets(); onLeave && onLeave();
      });
    });
  }

  NX.registerApp('darkchat', {
    title: 'Dark Chat',
    render(body, { params }) {
      NX.ident.ensure(body, () => {
        body.textContent = '';
        stack = NX.ui.stack(body, 'Dark Chat');
        stack.push('Dark Chat', (b) => renderList(b, params));
      });
    },
    onBack() { return stack ? stack.pop() : false; },
    destroy() { if (stack) stack.destroy(); stack = null; openConv = null; offs.forEach(o => o()); offs = []; },
  });

  // Notification hors application
  NX.on('chat:message', p => {
    if (NX.currentApp() === 'darkchat' && openConv === p.conversation) return;
    NX.notify(p.title || 'Dark Chat', p.message.body);
    const cur = NX.state.badges['darkchat'] || 0;
    if (NX.currentApp() !== 'darkchat') NX.badge('darkchat', cur + 1);
  });
})();
