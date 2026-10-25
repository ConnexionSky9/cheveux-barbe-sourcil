// API du serveur FiveM (ressource server_shop). Protégée par le jeton GAME_SERVER_TOKEN.
// Le serveur de jeu fournit lui-même l'identifiant Cfx.re du joueur (lu côté serveur FiveM,
// jamais transmis par la NUI ni par le client du joueur).
import { Router } from 'express';
import { z } from 'zod';
import type { AppConfig } from '../config.js';
import type { Db } from '../db.js';
import { h, requireGameServer } from '../http/middleware.js';
import { audit } from '../services/audit.js';
import { publicCatalog } from '../services/catalog.js';
import { activeEntitlements, claimJobs, reportJob } from '../services/deliveries.js';
import { CFX_ID, cleanIdentity, createLinkCode } from '../services/linking.js';
import { createCheckout, historyFor } from '../services/orders.js';
import type { TebexClient } from '../services/tebex.js';
import { badRequest } from '../errors.js';

const identity = z.object({ cfxId: z.string(), name: z.string().max(64).optional(), identifiers: z.record(z.string(), z.string()).optional() });

export function gameRoutes(pool: Db, cfg: AppConfig, tebex: TebexClient): Router {
  const r = Router();
  r.use(requireGameServer(cfg));
  const server = (q: { get(n: string): string | undefined }) => (q.get('x-server-name') ?? 'fivem').slice(0, 64);

  r.get('/catalog', h(async (_q, s) => s.json(await publicCatalog(pool))));

  r.post('/link-code', h(async (q, s) => {
    const id = cleanIdentity(identity.parse(q.body));
    const out = await createLinkCode(pool, id);
    await audit(pool, { actorType: 'game', actorId: server(q), action: 'link.code_created', target: `cfx:${id.cfxId}` });
    s.json({ code: out.code, expiresAt: out.expiresAt, url: `${cfg.PUBLIC_URL}/connexion` });
  }));

  r.post('/checkout', h(async (q, s) => {
    const body = identity.extend({ items: z.array(z.object({ productId: z.number().int().positive(), quantity: z.number().int().min(1).max(99) })).min(1).max(10) }).parse(q.body);
    const id = cleanIdentity(body);
    const user = await pool.query('SELECT id FROM users WHERE cfx_id = ?', [id.cfxId]).then(([rows]) => (rows as { id: number }[])[0] ?? null);
    const out = await createCheckout({ pool, tebex, publicUrl: cfg.PUBLIC_URL, currency: cfg.CURRENCY },
      { source: 'game', userId: user?.id ?? null, cfxId: id.cfxId, items: body.items });
    await audit(pool, { actorType: 'game', actorId: server(q), action: 'checkout.created', target: out.ref, details: { cfx: id.cfxId } });
    s.json(out);
  }));

  r.post('/deliveries/claim', h(async (q, s) => {
    const body = z.object({ cfxIds: z.array(z.string()).max(256) }).parse(q.body);
    s.json(await claimJobs(pool, body.cfxIds, server(q)));
  }));

  r.post('/deliveries/:id/result', h(async (q, s) => {
    const id = Number(q.params.id);
    if (!Number.isInteger(id) || id < 1) throw badRequest('Tâche invalide.');
    const body = z.object({ ok: z.boolean(), error: z.string().max(500).optional(), meta: z.record(z.string(), z.unknown()).optional() }).parse(q.body);
    s.json(await reportJob(pool, id, body, server(q), cfg.DELIVERY_MAX_ATTEMPTS));
  }));

  r.get('/players/:cfxId/summary', h(async (q, s) => {
    const cfxId = String(q.params.cfxId);
    if (!CFX_ID.test(cfxId)) throw badRequest('Identifiant Cfx.re invalide.');
    const [history, entitlements, linked] = await Promise.all([
      historyFor(pool, cfxId), activeEntitlements(pool, cfxId),
      pool.query('SELECT 1 FROM users WHERE cfx_id = ?', [cfxId]).then(([rows]) => (rows as unknown[]).length > 0),
    ]);
    s.json({ history, entitlements, linked });
  }));

  return r;
}
