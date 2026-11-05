'use strict';
/* =========================================================
   TÉLÉPHONE PLIABLE
   · Bouton à gauche du téléphone (ou double-clic sur la charnière) : plier / déplier.
   · Déplié : l'écran de gauche garde l'application ouverte ; l'écran de droite est un bureau
     (heure, solde, numéro, toutes les applications, dernières notifications).
     Une application touchée à droite s'ouvre à gauche : on garde toujours les deux sous les yeux.
   · L'état (plié / déplié) est mémorisé sur ce PC.
   ========================================================= */
const Fold = (() => {
  const s2 = $('#screen2');
  const KEY = 'aura_unfolded';
  const notifs = [];
  let open = false;

  const store = (v) => { try { localStorage.setItem(KEY, v ? '1' : '0'); } catch (e) { /* stockage indisponible */ } };
  const stored = () => { try { return localStorage.getItem(KEY) === '1'; } catch (e) { return false; } };

  // Même thème et même style d'icônes que l'écran principal
  function syncTheme() {
    s2.dataset.theme = screenEl.dataset.theme || 'dark';
    s2.dataset.icons = screenEl.dataset.icons || 'prisme';
  }
  new MutationObserver(syncTheme).observe(screenEl, { attributes: true, attributeFilter: ['data-theme', 'data-icons'] });

  function appList() {
    const store_ = (typeof STORE === 'object' && STORE) ? Object.keys(STORE).filter(isInstalled) : [];
    return DOCK.concat(GRID.filter((id) => id !== 'bank' || bankOn())).concat(['maison']).concat(store_).filter((id, i, a) => APPS[id] && a.indexOf(id) === i && appAllowed(id));
  }

  function render() {
    if (!open) return;
    syncTheme();
    const now = new Date();
    const h = S.gameTime ? S.gameTime.h : now.getHours(), m = S.gameTime ? S.gameTime.m : now.getMinutes();
    const pad = (n) => String(n).padStart(2, '0');
    const locked = S.locked || screenEl.classList.contains('in-setup');
    s2.innerHTML = `<div class="s2__bg"></div><div class="s2">
      <div><div class="s2__clock">${pad(h)}:${pad(m)}</div><div class="s2__date">${esc(now.toLocaleDateString(locale(), { weekday: 'long', day: 'numeric', month: 'long' }))}</div></div>
      ${locked ? `<p class="s2__hint">${t('Déverrouillez le téléphone pour utiliser le second écran.')}</p>` : `
      <div class="s2__row">
        ${bankOn() ? `<button class="s2__w" data-open="bank"><small>${t('Compte courant')}</small><b>${money(S.profile.bank)}</b></button>` : ''}
        <div class="s2__w"><small>${t('Mon numéro')}</small><b>${esc(S.profile?.number || '')}</b></div>
      </div>
      <p class="s2__h">${t('Applications')}</p>
      <div class="s2__apps">${appList().map((id) => `<button class="app-icon ${S.currentApp === id ? 'on' : ''}" data-open="${id}" aria-label="${t(APPS[id].label)}">${appTile(id)}<span>${t(APPS[id].label)}</span></button>`).join('')}</div>
      <p class="s2__h">${t('Notifications')}</p>
      <div class="s2__notifs">${notifs.length ? notifs.map((n) => `<button class="s2__n" ${n.app && APPS[n.app] ? `data-open="${n.app}"` : ''}>${appTile(APPS[n.app] ? n.app : 'system')}<div><b>${esc(n.title || '')}</b><span>${esc(n.text || '')}</span></div></button>`).join('')
        : `<p class="s2__empty">${t('Aucune notification récente.')}</p>`}</div>
      <p class="s2__hint">${t('Touchez une application : elle s\'ouvre sur l\'écran de gauche.')}</p>`}
    </div>`;
  }

  function set(v, save = true) {
    open = !!v && DEV().fold !== false;   // seulement l'ElyAura 5 Fold se déplie
    if (typeof post === 'function' && S.open) post('setFold', { open });   // en jeu : tenu à deux mains une fois déplié
    phoneEl.classList.toggle('unfolded', open);
    s2.setAttribute('aria-hidden', open ? 'false' : 'true');
    $('#fold-btn').setAttribute('aria-label', open ? t('Plier le téléphone') : t('Déplier le téléphone'));
    if (save) store(open);
    if (open) render(); else s2.innerHTML = '';
  }

  $('#fold-btn').addEventListener('click', (e) => { e.stopPropagation(); set(!open); });
  $('.hinge').addEventListener('dblclick', () => set(!open));

  // Les notifications et l'application ouverte s'affichent aussi à droite
  const baseNotify = notify;
  notify = function (raw) {
    try { const d = resolveNotif(raw); if (d && (d.title || d.text)) { notifs.unshift(d); notifs.splice(6); } } catch (e) { /* ignoré */ }
    baseNotify(raw);
    render();
  };
  const baseOpen = openApp;
  openApp = function (...a) { baseOpen(...a); render(); };
  const baseHome = goHome;
  goHome = function (...a) { baseHome(...a); render(); };
  setInterval(() => { if (open) { const c = $('.s2__clock', s2); if (c) render(); } }, 15000);

  set(stored(), false);
  return { set, render, isOpen: () => open };
})();
