// Journal technique : un fichier par jour, lignes JSON lisibles, rotation simple.
import fs from 'node:fs';
import path from 'node:path';

const LEVELS = ['debug', 'info', 'warn', 'error'];

export class Logger {
  constructor(dir, { keepDays = 14, echo = false } = {}) {
    this.dir = dir;
    this.echo = echo;
    this.recent = [];           // derniers événements (écran d'accueil)
    if (dir) {
      fs.mkdirSync(dir, { recursive: true });
      this.#prune(keepDays);
    }
  }

  get file() {
    const d = new Date().toISOString().slice(0, 10);
    return this.dir ? path.join(this.dir, `app-${d}.log`) : null;
  }

  log(level, message, data) {
    if (!LEVELS.includes(level)) level = 'info';
    const entry = { t: new Date().toISOString(), level, message: String(message) };
    if (data !== undefined) entry.data = data instanceof Error ? { error: data.message, stack: data.stack } : data;
    this.recent.push(entry);
    if (this.recent.length > 200) this.recent.shift();
    if (this.file) {
      try { fs.appendFileSync(this.file, JSON.stringify(entry) + '\n', 'utf8'); } catch { /* disque plein : on n'arrête pas l'app */ }
    }
    if (this.echo) console[level === 'debug' ? 'log' : level](`[${level}] ${entry.message}`);
    return entry;
  }
  debug(m, d) { return this.log('debug', m, d); }
  info(m, d) { return this.log('info', m, d); }
  warn(m, d) { return this.log('warn', m, d); }
  error(m, d) { return this.log('error', m, d); }

  #prune(keepDays) {
    const limit = Date.now() - keepDays * 86400000;
    for (const f of fs.readdirSync(this.dir)) {
      if (!/^app-\d{4}-\d{2}-\d{2}\.log$/.test(f)) continue;
      const p = path.join(this.dir, f);
      try { if (fs.statSync(p).mtimeMs < limit) fs.unlinkSync(p); } catch { /* ignoré */ }
    }
  }
}

export const nullLogger = new Logger(null);
