// Pont sécurisé entre l'interface et le processus principal.
// L'interface n'a accès ni à Node.js ni au disque : uniquement aux fonctions listées ici.
const { contextBridge, ipcRenderer, webUtils } = require('electron');

const call = (channel) => (...args) => ipcRenderer.invoke(channel, ...args);
const CHANNELS = [
  'app:info', 'app:events',
  'dialog:pickDir', 'dialog:pickFiles', 'dialog:openProject', 'dialog:confirm',
  'project:create', 'project:open', 'project:save', 'project:autosave', 'project:recover', 'project:close',
  'project:duplicate', 'project:rename', 'project:delete', 'project:saveTemplate', 'project:templates',
  'recent:list', 'recent:remove',
  'import:inspect', 'import:add',
  'texture:fromAsset', 'texture:blank', 'texture:load', 'texture:save', 'texture:decodeFile', 'texture:decodeAsset', 'texture:export', 'texture:delete',
  'model:load', 'model:saveWork', 'asset:remove',
  'catalog:info', 'catalog:scan', 'catalog:query', 'catalog:thumb', 'catalog:create', 'ytd:list', 'texture:fromYtd',
  'export:validate', 'export:run', 'export:cancel',
  'tools:detect', 'config:get', 'config:set', 'config:openFile',
  'shell:openPath', 'shell:openExternal', 'docs:read',
];

contextBridge.exposeInMainWorld('fcs', {
  ...Object.fromEntries(CHANNELS.map((c) => [c.replace(/:(\w)/g, (_, l) => l.toUpperCase()).replace(/^(\w)/, (l) => l), call(c)])),
  /** Chemin réel d'un fichier déposé depuis l'explorateur Windows. */
  pathForFile: (file) => webUtils.getPathForFile(file),
  on: (event, fn) => {
    const allowed = ['export:progress', 'menu', 'app:event'];
    if (!allowed.includes(event)) return () => {};
    const h = (_e, ...args) => fn(...args);
    ipcRenderer.on(event, h);
    return () => ipcRenderer.removeListener(event, h);
  },
});
