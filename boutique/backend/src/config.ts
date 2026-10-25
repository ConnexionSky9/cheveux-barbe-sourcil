// Configuration lue dans les variables d'environnement (fichier .env en local).
// Aucune valeur secrète n'a de valeur par défaut : le serveur refuse de démarrer sans.
import { readFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { z } from 'zod';

/** Charge un fichier .env simple (CLE=valeur) sans dépendance externe. */
function loadDotEnv(file: string): void {
  if (!existsSync(file)) return;
  for (const raw of readFileSync(file, 'utf8').split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    const eq = line.indexOf('=');
    if (eq < 1) continue;
    const key = line.slice(0, eq).trim();
    let value = line.slice(eq + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) value = value.slice(1, -1);
    if (process.env[key] === undefined) process.env[key] = value;
  }
}
loadDotEnv(resolve(process.cwd(), '.env'));
loadDotEnv(resolve(process.cwd(), '..', '.env'));

const bool = z.enum(['true', 'false', '1', '0']).transform((v) => v === 'true' || v === '1');
const list = z.string().default('').transform((v) => v.split(',').map((s) => s.trim()).filter(Boolean));

const schema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  PORT: z.coerce.number().int().min(1).max(65535).default(3000),
  PUBLIC_URL: z.string().url().transform((v) => v.replace(/\/+$/, '')),
  DATABASE_URL: z.string().min(1),
  TRUST_PROXY: z.coerce.number().int().min(0).max(5).default(0),
  COOKIE_SECURE: bool.default(true),

  SERVER_NAME: z.string().min(1).default('Elyzea'),
  CURRENCY: z.string().length(3).default('EUR'),
  DISCORD_URL: z.string().default(''),
  SUPPORT_EMAIL: z.string().default(''),

  // Tebex (Headless API + webhooks)
  TEBEX_PUBLIC_TOKEN: z.string().min(1),
  TEBEX_PRIVATE_KEY: z.string().default(''),
  TEBEX_WEBHOOK_SECRET: z.string().min(16),
  TEBEX_WEBHOOK_IPS: list,

  // Serveur de jeu FiveM ↔ API (jeton partagé, jamais envoyé aux joueurs)
  GAME_SERVER_TOKEN: z.string().min(32),
  GAME_SERVER_IPS: list,

  DELIVERY_MAX_ATTEMPTS: z.coerce.number().int().min(1).max(50).default(8),
  WEB_DIST: z.string().default('../web/dist'),
});

export type AppConfig = z.infer<typeof schema>;

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  const parsed = schema.safeParse(env);
  if (!parsed.success) {
    const lines = parsed.error.issues.map((i) => `  - ${i.path.join('.')} : ${i.message}`);
    throw new Error(`Configuration invalide (.env) :\n${lines.join('\n')}`);
  }
  return parsed.data;
}
