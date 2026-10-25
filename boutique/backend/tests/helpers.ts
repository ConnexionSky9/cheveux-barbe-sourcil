// Outils de test : base MariaDB/MySQL réelle (TEST_DATABASE_URL), faux client Tebex en mémoire.
import mysql from 'mysql2/promise';
import request from 'supertest';
import { loadConfig, type AppConfig } from '../src/config.js';
import { createPool, type Db } from '../src/db.js';
import { createApp } from '../src/http/app.js';
import { migrate } from '../src/migrate.js';
import { tebexSignature } from '../src/security.js';
import type { TebexAuthLink, TebexBasket, TebexCategory, TebexClient } from '../src/services/tebex.js';

export const TEST_DB = process.env.TEST_DATABASE_URL ?? 'mysql://boutique:boutique@127.0.0.1:3306/boutique_test';
export const WEBHOOK_SECRET = 'secret-de-test-webhook-0123456789';
export const GAME_TOKEN = 'jeton-serveur-de-jeu-de-test-0123456789abcdef';

export function testConfig(over: Record<string, string> = {}): AppConfig {
  return loadConfig({
    NODE_ENV: 'test', PUBLIC_URL: 'https://boutique.test', DATABASE_URL: TEST_DB, COOKIE_SECURE: 'false',
    TEBEX_PUBLIC_TOKEN: 'public-token', TEBEX_WEBHOOK_SECRET: WEBHOOK_SECRET, GAME_SERVER_TOKEN: GAME_TOKEN, WEB_DIST: '/nonexistent', ...over,
  });
}

/** Repart d'une base vide puis applique toutes les migrations. */
export async function resetDb(): Promise<void> {
  const conn = await mysql.createConnection({ uri: TEST_DB, multipleStatements: true });
  const [tables] = await conn.query<mysql.RowDataPacket[]>('SELECT table_name AS t FROM information_schema.tables WHERE table_schema = DATABASE()');
  await conn.query('SET FOREIGN_KEY_CHECKS = 0');
  for (const t of tables) await conn.query(`DROP TABLE IF EXISTS \`${t.t}\``);
  await conn.query('SET FOREIGN_KEY_CHECKS = 1');
  await conn.end();
  await migrate(TEST_DB, () => undefined);
}

/** Faux Tebex : reproduit le comportement utile (panier, connexion Cfx.re, paquets). Utilisé seulement par les tests. */
export class FakeTebex implements TebexClient {
  baskets = new Map<string, TebexBasket>();
  calls: string[] = [];
  fail = false;
  categories: TebexCategory[] = [];
  private n = 0;
  async listCategories() { return this.categories; }
  async createBasket(i: { completeUrl: string; cancelUrl: string; custom: Record<string, string> }) {
    this.calls.push('createBasket');
    if (this.fail) throw new Error('Tebex indisponible');
    const ident = `basket-${++this.n}`;
    const b: TebexBasket = { ident, complete: false, username_id: null, username: null, total_price: 0, currency: 'EUR', packages: [], links: { checkout: `https://checkout.tebex.test/${ident}` }, custom: i.custom };
    this.baskets.set(ident, b);
    return b;
  }
  async getBasket(ident: string) { const b = this.baskets.get(ident); if (!b) throw new Error('panier inconnu'); return structuredClone(b); }
  async getAuthLinks(ident: string, returnUrl: string): Promise<TebexAuthLink[]> {
    this.calls.push('getAuthLinks');
    return [{ name: 'FiveM', url: `https://ident.tebex.test/fivem?basket=${ident}&return=${encodeURIComponent(returnUrl)}` }];
  }
  async addPackage(ident: string, packageId: number, quantity: number) {
    this.calls.push(`addPackage:${packageId}x${quantity}`);
    const b = this.baskets.get(ident)!;
    b.packages.push({ id: packageId, name: `pkg ${packageId}`, in_basket: { quantity, price: 0 } });
    return structuredClone(b);
  }
  /** Simule la connexion Cfx.re du joueur sur Tebex. */
  login(ident: string, cfxId: string) { const b = this.baskets.get(ident)!; b.username_id = cfxId; b.username = `joueur${cfxId}`; }
}

export function setup(over: Record<string, string> = {}) {
  const cfg = testConfig(over);
  const pool: Db = createPool(cfg.DATABASE_URL);
  const tebex = new FakeTebex();
  const errors: string[] = [];
  const app = createApp({ pool, cfg, tebex, log: (m) => errors.push(m) });
  return { cfg, pool, tebex, app, errors, agent: () => request.agent(app) };
}

export function signedWebhook(app: Parameters<typeof request>[0], payload: unknown, secret = WEBHOOK_SECRET) {
  const raw = JSON.stringify(payload);
  return request(app).post('/api/webhooks/tebex').set('Content-Type', 'application/json').set('X-Signature', tebexSignature(raw, secret)).send(raw);
}

export const game = (app: Parameters<typeof request>[0]) => ({
  post: (path: string, body: unknown) => request(app).post(`/api/game${path}`).set('Authorization', `Bearer ${GAME_TOKEN}`).set('X-Server-Name', 'test').send(body as object),
  get: (path: string) => request(app).get(`/api/game${path}`).set('Authorization', `Bearer ${GAME_TOKEN}`),
});

/** Corps d'un webhook payment.completed au format Tebex. */
export function completedEvent(o: { id: string; tx: string; ref?: string; cfx: string; products: { id: number; qty?: number; giftTo?: string }[] }) {
  return {
    id: o.id, type: 'payment.completed', date: new Date().toISOString(),
    subject: {
      transaction_id: o.tx, status: { id: 1, description: 'Complete' }, price: { amount: 15, currency: 'EUR' }, price_paid: { amount: 15, currency: 'EUR' },
      customer: { first_name: 'Test', email: 'test@example.com', username: { id: o.cfx, username: `joueur${o.cfx}` } },
      products: o.products.map((p) => ({ id: p.id, name: `Paquet ${p.id}`, quantity: p.qty ?? 1, paid_price: { amount: 15 * (p.qty ?? 1), currency: 'EUR' },
        username: p.giftTo ? { id: p.giftTo, username: `joueur${p.giftTo}` } : { id: o.cfx, username: `joueur${o.cfx}` } })),
      custom: o.ref ? { order_ref: o.ref } : {},
    },
  };
}
