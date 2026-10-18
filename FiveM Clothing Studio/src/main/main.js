// Processus principal Electron : fenêtre, menu, journaux, configuration.
import { app, BrowserWindow, Menu, dialog, shell } from 'electron';
import path from 'node:path';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import { Logger } from '../core/logger.js';
import { loadConfig } from '../core/config.js';
import { registerIpc } from './ipc.js';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '../..');

// Dossier de données isolé possible (tests automatisés, version portable)
if (process.env.FCS_USER_DATA) app.setPath('userData', process.env.FCS_USER_DATA);

const ctx = {
  root: ROOT,
  userData: () => app.getPath('userData'),
  logger: null,
  config: null,
  configFile: null,
  window: null,
  appVersion: app.getVersion(),
};

function buildMenu(win) {
  const send = (cmd) => () => win.webContents.send('menu', cmd);
  const template = [
    { label: 'Fichier', submenu: [
      { label: 'Nouveau projet…', accelerator: 'CmdOrCtrl+N', registerAccelerator: false, click: send('new') },
      { label: 'Ouvrir un projet…', accelerator: 'CmdOrCtrl+O', registerAccelerator: false, click: send('open') },
      { label: 'Enregistrer', accelerator: 'CmdOrCtrl+S', registerAccelerator: false, click: send('save') },
      { label: 'Importer des fichiers…', accelerator: 'CmdOrCtrl+I', registerAccelerator: false, click: send('import') },
      { type: 'separator' },
      { label: 'Exporter pour FiveM…', accelerator: 'CmdOrCtrl+E', registerAccelerator: false, click: send('export') },
      { type: 'separator' },
      { label: 'Fermer le projet', click: send('close') },
      { role: 'quit', label: 'Quitter' },
    ] },
    { label: 'Édition', submenu: [
      { label: 'Annuler', accelerator: 'CmdOrCtrl+Z', registerAccelerator: false, click: send('undo') },
      { label: 'Rétablir', accelerator: 'CmdOrCtrl+Y', registerAccelerator: false, click: send('redo') },
      { type: 'separator' },
      { role: 'cut', label: 'Couper' }, { role: 'copy', label: 'Copier' }, { role: 'paste', label: 'Coller' },
    ] },
    { label: 'Affichage', submenu: [
      { label: 'Panneau de gauche', accelerator: 'CmdOrCtrl+1', registerAccelerator: false, click: send('toggle-left') },
      { label: 'Panneau de droite', accelerator: 'CmdOrCtrl+2', registerAccelerator: false, click: send('toggle-right') },
      { type: 'separator' },
      { role: 'resetZoom', label: 'Zoom de l\'interface 100 %' }, { role: 'zoomIn', label: 'Agrandir l\'interface' }, { role: 'zoomOut', label: 'Réduire l\'interface' },
      { role: 'togglefullscreen', label: 'Plein écran' },
      { type: 'separator' },
      { role: 'toggleDevTools', label: 'Outils de développement' },
    ] },
    { label: 'Aide', submenu: [
      { label: 'Guide utilisateur', accelerator: 'F1', registerAccelerator: false, click: send('help') },
      { label: 'Outils et dépendances', click: send('tools') },
      { label: 'Ouvrir le dossier des journaux', click: () => shell.openPath(path.join(ctx.userData(), 'logs')) },
      { label: 'À propos', click: () => dialog.showMessageBox(win, { type: 'info', title: ctx.config.appName,
        message: `${ctx.config.appName} ${ctx.appVersion}`, detail: 'Éditeur de vêtements pour FiveM.\nLicence MIT. Voir README.md pour les limites connues.' }) },
    ] },
  ];
  Menu.setApplicationMenu(Menu.buildFromTemplate(template));
}

function createWindow() {
  const win = new BrowserWindow({
    width: 1600, height: 960, minWidth: 1024, minHeight: 680,
    backgroundColor: '#14161b', show: false,
    title: ctx.config.appName,
    webPreferences: {
      preload: path.join(HERE, 'preload.cjs'),
      contextIsolation: true, sandbox: true, nodeIntegration: false, spellcheck: false,
    },
  });
  ctx.window = win;
  buildMenu(win);
  win.once('ready-to-show', () => win.show());
  // Aucune navigation hors de l'application ; les liens s'ouvrent dans le navigateur
  win.webContents.setWindowOpenHandler(({ url }) => { if (/^https:\/\//.test(url)) shell.openExternal(url); return { action: 'deny' }; });
  win.webContents.on('will-navigate', (e) => e.preventDefault());
  win.webContents.on('render-process-gone', (_e, d) => ctx.logger.error('Processus d\'affichage arrêté', d));
  win.on('close', (e) => {
    if (ctx.allowClose) return;
    e.preventDefault();
    win.webContents.send('menu', 'quit-request');   // l'interface propose d'enregistrer puis appelle project:close
    setTimeout(() => { if (!win.isDestroyed() && !ctx.allowClose) { ctx.allowClose = true; win.close(); } }, 15000);
  });
  win.loadFile(path.join(ROOT, 'src/renderer/index.html'));
  return win;
}

app.whenReady().then(() => {
  const logsDir = path.join(ctx.userData(), 'logs');
  ctx.logger = new Logger(logsDir, { echo: !app.isPackaged && process.env.FCS_QUIET !== '1' });
  ctx.configFile = path.join(ctx.userData(), 'config.json');
  ctx.config = loadConfig(ctx.configFile, ctx.logger);
  ctx.logger.info(`Démarrage ${ctx.config.appName} ${ctx.appVersion} (${process.platform} ${process.arch}, Electron ${process.versions.electron})`);
  fs.mkdirSync(path.join(ctx.userData(), 'templates'), { recursive: true });
  registerIpc(ctx);
  createWindow();
});

process.on('uncaughtException', (e) => { ctx.logger?.error('Exception non gérée', e); });
process.on('unhandledRejection', (e) => { ctx.logger?.error('Promesse rejetée non gérée', e); });
app.on('window-all-closed', () => app.quit());
