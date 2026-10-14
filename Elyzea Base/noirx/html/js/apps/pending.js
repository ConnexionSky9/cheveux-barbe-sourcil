/* NOIR X — écran affiché pour une application activée dont le module n'est pas encore installé.
 * Dès qu'un fichier html/js/apps/<id>.js enregistre l'application, cet écran n'est plus utilisé. */
(function () {
  NX.registerApp('__pending', {
    pending: true,
    render(body, { meta }) {
      const wrap = document.createElement('div');
      wrap.className = 'empty';
      const icon = NX.icon(meta.id); icon.classList.add('empty__icon');
      const title = document.createElement('div'); title.className = 'empty__title'; title.textContent = 'Réseau indisponible';
      const text = document.createElement('div'); text.className = 'empty__text';
      text.textContent = `Le nœud ${meta.label} n'est pas encore déployé sur ce terminal.`;
      const code = document.createElement('div'); code.className = 'mono';
      code.textContent = `ERR · NODE_${meta.id.toUpperCase()}_OFFLINE`;
      wrap.append(icon, title, text, code);
      body.append(wrap);
    },
  });
})();
