// Panel d'administration. Chaque route vérifie la session admin, le rôle et (pour les modifications) le jeton CSRF.
// Rôles : support = lecture ; admin = catalogue, livraisons ; owner = tout + gestion des administrateurs.
import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { z } from 'zod';
import type { AppConfig } from '../config.js';
import type { Db } from '../db.js';
import { exec, json, one, rows, tx } from '../db.js';
import { badRequest, conflict, notFound } from '../errors.js';
import { clientIp, h, requireAdmin } from '../http/middleware.js';
import { listAdmins, updateAdmin, upsertAdmin, verifyLogin } from '../services/admins.js';
import { audit } from '../services/audit.js';
import { adminCategories, adminProducts } from '../services/catalog.js';
import { cancelJob, retryJob } from '../services/deliveries.js';
import { REWARD_TYPES, validateReward } from '../services/rewardTypes.js';
import { COOKIE, SESSION_TTL, createSession, destroySession } from '../services/sessions.js';
import { toCents, type TebexClient } from '../services/tebex.js';

const slug = (max: number) => z.string().regex(new RegExp(`^[a-z0-9-]{2,${max}}$`), 'minuscules, chiffres et tirets');
const imageUrl = z.string().max(255).refine((v) => v === '' || v.startsWith('/') || /^https:\/\/[^\s"'<>]+$/.test(v), 'URL https:// ou chemin /images/...');

const categoryInput = z.object({
  slug: slug(48), name: z.string().trim().min(2).max(64), description: z.string().max(255).default(''),
  icon: z.string().regex(/^[a-z-]{2,32}$/).default('star'), sort: z.number().int().min(-9999).max(9999).default(0), active: z.boolean().default(true),
});
const productInput = z.object({
  slug: slug(64), categoryId: z.number().int().positive(), name: z.string().trim().min(2).max(80),
  shortDescription: z.string().max(160).default(''), description: z.string().max(5000).default(''), imageUrl: imageUrl.default(''),
  priceCents: z.number().int().min(0).max(10_000_000), currency: z.string().regex(/^[A-Z]{3}$/).default('EUR'),
  durationDays: z.number().int().min(1).max(3650).nullable().default(null), maxQuantity: z.number().int().min(1).max(99).default(1),
  perks: z.array(z.string().trim().min(1).max(120)).max(12).default([]),
  tebexPackageId: z.number().int().positive().nullable().default(null),
  featured: z.boolean().default(false), popular: z.boolean().default(false), active: z.boolean().default(true), sort: z.number().int().min(-9999).max(9999).default(0),
});
const idParam = (v: unknown): number => { const n = Number(v); if (!Number.isInteger(n) || n < 1) throw badRequest('Identifiant invalide.'); return n; };

export function adminRoutes(pool: Db, cfg: AppConfig, tebex: TebexClient): Router {
  const r = Router();
  const support = requireAdmin(pool, 'support');
  const admin = requireAdmin(pool, 'admin');
  const owner = requireAdmin(pool, 'owner');
  const log = (q: Parameters<typeof clientIp>[0], action: string, target: string | null, details?: Record<string, unknown>) =>
    audit(pool, { actorType: 'admin', actorId: q.admin?.id ?? null, action, target, details: details ?? null, ip: clientIp(q) });

  // ---- Connexion ----
  const loginLimiter = rateLimit({ windowMs: 15 * 60_000, limit: 10, standardHeaders: 'draft-7', legacyHeaders: false, message: { error: 'Trop de tentatives. Réessayez dans 15 minutes.', code: 'rate_limited' } });
  r.post('/login', loginLimiter, h(async (q, s) => {
    const body = z.object({ username: z.string().max(32), password: z.string().max(128) }).parse(q.body);
    const res = await verifyLogin(pool, body.username, body.password);
    if (!res.ok) {
      await audit(pool, { level: 'warn', actorType: 'admin', action: 'admin.login_failed', target: body.username.slice(0, 32), ip: clientIp(q) });
      throw badRequest(res.reason === 'locked' ? 'Compte verrouillé 15 minutes après plusieurs échecs.' : 'Identifiant ou mot de passe incorrect.', res.reason);
    }
    if (q.adminSession) await destroySession(pool, q.adminSession.tokenHash);
    const sess = await createSession(pool, 'admin', res.admin.id, clientIp(q));
    s.cookie(COOKIE.admin, sess.token, { httpOnly: true, secure: cfg.COOKIE_SECURE, sameSite: 'strict', path: '/', maxAge: SESSION_TTL.admin });
    await audit(pool, { actorType: 'admin', actorId: res.admin.id, action: 'admin.login', ip: clientIp(q) });
    s.json({ admin: { id: res.admin.id, username: res.admin.username, role: res.admin.role }, csrfToken: sess.csrf });
  }));
  r.post('/logout', support, h(async (q, s) => {
    await destroySession(pool, q.adminSession!.tokenHash);
    s.clearCookie(COOKIE.admin, { path: '/' });
    s.json({ ok: true });
  }));
  r.get('/me', support, h(async (q, s) => s.json({ admin: { id: q.admin!.id, username: q.admin!.username, role: q.admin!.role }, csrfToken: q.adminSession!.csrf })));

  // ---- Tableau de bord ----
  r.get('/stats', support, h(async (_q, s) => {
    const [o, d, w, e] = await Promise.all([
      one<{ paid: number; pending: number; revenue: number | null; month: number | null }>(pool,
        `SELECT SUM(status='paid') AS paid, SUM(status='pending') AS pending, SUM(CASE WHEN status='paid' THEN total_cents END) AS revenue,
         SUM(CASE WHEN status='paid' AND paid_at >= UTC_TIMESTAMP() - INTERVAL 30 DAY THEN total_cents END) AS month FROM orders`),
      rows<{ status: string; n: number }>(pool, 'SELECT status, COUNT(*) AS n FROM delivery_jobs GROUP BY status'),
      one<{ n: number }>(pool, "SELECT COUNT(*) AS n FROM webhook_events WHERE status = 'error'"),
      one<{ n: number }>(pool, "SELECT COUNT(*) AS n FROM audit_logs WHERE level = 'error' AND created_at >= UTC_TIMESTAMP() - INTERVAL 7 DAY"),
    ]);
    s.json({
      orders: { paid: Number(o?.paid ?? 0), pending: Number(o?.pending ?? 0), revenueCents: Number(o?.revenue ?? 0), last30DaysCents: Number(o?.month ?? 0) },
      deliveries: Object.fromEntries(d.map((x) => [x.status, Number(x.n)])),
      webhookErrors: Number(w?.n ?? 0), errorsLast7Days: Number(e?.n ?? 0), currency: cfg.CURRENCY,
    });
  }));

  // ---- Catégories ----
  r.get('/categories', support, h(async (_q, s) => s.json(await adminCategories(pool))));
  r.post('/categories', admin, h(async (q, s) => {
    const c = categoryInput.parse(q.body);
    try {
      const res = await exec(pool, 'INSERT INTO categories (slug, name, description, icon, sort, active) VALUES (?, ?, ?, ?, ?, ?)', [c.slug, c.name, c.description, c.icon, c.sort, c.active ? 1 : 0]);
      await log(q, 'category.create', `category:${res.insertId}`, { slug: c.slug });
      s.status(201).json({ id: res.insertId });
    } catch (err) { if ((err as { code?: string }).code === 'ER_DUP_ENTRY') throw conflict('Ce lien (slug) existe déjà.'); throw err; }
  }));
  r.patch('/categories/:id', admin, h(async (q, s) => {
    const id = idParam(q.params.id);
    const c = categoryInput.parse(q.body);
    const res = await exec(pool, 'UPDATE categories SET slug = ?, name = ?, description = ?, icon = ?, sort = ?, active = ? WHERE id = ?', [c.slug, c.name, c.description, c.icon, c.sort, c.active ? 1 : 0, id]).catch((err) => {
      if ((err as { code?: string }).code === 'ER_DUP_ENTRY') throw conflict('Ce lien (slug) existe déjà.'); throw err;
    });
    if (!res.affectedRows) throw notFound('Catégorie introuvable.');
    await log(q, 'category.update', `category:${id}`, { active: c.active });
    s.json({ ok: true });
  }));
  r.delete('/categories/:id', admin, h(async (q, s) => {
    const id = idParam(q.params.id);
    const n = await one<{ n: number }>(pool, 'SELECT COUNT(*) AS n FROM products WHERE category_id = ?', [id]);
    if (Number(n?.n ?? 0) > 0) throw conflict('Catégorie non vide : désactivez-la ou déplacez ses produits.');
    const res = await exec(pool, 'DELETE FROM categories WHERE id = ?', [id]);
    if (!res.affectedRows) throw notFound('Catégorie introuvable.');
    await log(q, 'category.delete', `category:${id}`);
    s.json({ ok: true });
  }));

  // ---- Produits ----
  r.get('/products', support, h(async (_q, s) => s.json({ products: await adminProducts(pool), rewardTypes: REWARD_TYPES })));
  r.get('/products/:id', support, h(async (q, s) => {
    const p = (await adminProducts(pool, idParam(q.params.id)))[0];
    if (!p) throw notFound('Produit introuvable.');
    s.json(p);
  }));
  const saveProduct = async (p: z.infer<typeof productInput>, id?: number): Promise<number> => {
    const cat = await one(pool, 'SELECT id FROM categories WHERE id = ?', [p.categoryId]);
    if (!cat) throw badRequest('Catégorie inconnue.');
    const values = [p.slug, p.categoryId, p.name, p.shortDescription, p.description, p.imageUrl, p.priceCents, p.currency, p.durationDays, p.maxQuantity,
      JSON.stringify(p.perks), p.tebexPackageId, p.featured ? 1 : 0, p.popular ? 1 : 0, p.active ? 1 : 0, p.sort];
    try {
      if (id) {
        const res = await exec(pool, `UPDATE products SET slug=?, category_id=?, name=?, short_description=?, description=?, image_url=?, price_cents=?, currency=?,
          duration_days=?, max_quantity=?, perks=?, tebex_package_id=?, featured=?, popular=?, active=?, sort=? WHERE id = ?`, [...values, id]);
        if (!res.affectedRows) throw notFound('Produit introuvable.');
        return id;
      }
      const res = await exec(pool, `INSERT INTO products (slug, category_id, name, short_description, description, image_url, price_cents, currency,
        duration_days, max_quantity, perks, tebex_package_id, featured, popular, active, sort) VALUES (${values.map(() => '?').join(',')})`, values);
      return res.insertId;
    } catch (err) {
      if ((err as { code?: string }).code === 'ER_DUP_ENTRY') throw conflict('Lien (slug) ou paquet Tebex déjà utilisé par un autre produit.');
      throw err;
    }
  };
  r.post('/products', admin, h(async (q, s) => {
    const p = productInput.parse(q.body);
    const id = await saveProduct(p);
    await log(q, 'product.create', `product:${id}`, { slug: p.slug, priceCents: p.priceCents, tebexPackageId: p.tebexPackageId });
    s.status(201).json({ id });
  }));
  r.patch('/products/:id', admin, h(async (q, s) => {
    const id = idParam(q.params.id);
    const before = (await adminProducts(pool, id))[0];
    if (!before) throw notFound('Produit introuvable.');
    const p = productInput.parse(q.body);
    await saveProduct(p, id);
    await log(q, 'product.update', `product:${id}`, {
      priceCents: before.priceCents !== p.priceCents ? [before.priceCents, p.priceCents] : undefined,
      active: before.active !== p.active ? p.active : undefined,
      tebexPackageId: before.tebexPackageId !== p.tebexPackageId ? [before.tebexPackageId, p.tebexPackageId] : undefined,
    });
    s.json({ ok: true });
  }));
  // Récompenses du produit : remplacées en bloc (les achats passés gardent leur copie figée)
  r.put('/products/:id/rewards', admin, h(async (q, s) => {
    const id = idParam(q.params.id);
    const body = z.object({ rewards: z.array(z.object({ type: z.string(), params: z.record(z.string(), z.unknown()) })).max(20) }).parse(q.body);
    let clean: { type: string; params: Record<string, unknown> }[];
    try { clean = body.rewards.map((w) => validateReward(w.type, w.params)); } catch (err) { throw badRequest(err instanceof Error ? err.message : 'Récompense invalide.'); }
    await tx(pool, async (c) => {
      const p = await one(c, 'SELECT id FROM products WHERE id = ? FOR UPDATE', [id]);
      if (!p) throw notFound('Produit introuvable.');
      await exec(c, 'DELETE FROM product_rewards WHERE product_id = ?', [id]);
      for (const [i, w] of clean.entries()) await exec(c, 'INSERT INTO product_rewards (product_id, type, params, sort) VALUES (?, ?, ?, ?)', [id, w.type, JSON.stringify(w.params), i]);
    });
    await log(q, 'product.rewards', `product:${id}`, { rewards: clean });
    s.json({ ok: true });
  }));

  // ---- Tebex ----
  r.get('/tebex/packages', admin, h(async (_q, s) => {
    const cats = await tebex.listCategories();
    const mapped = await rows<{ id: number; name: string; tebex_package_id: number }>(pool, 'SELECT id, name, tebex_package_id FROM products WHERE tebex_package_id IS NOT NULL');
    const byPkg = new Map(mapped.map((m) => [Number(m.tebex_package_id), m]));
    s.json(cats.flatMap((c) => (c.packages ?? []).map((p) => ({
      id: p.id, name: p.name, category: c.name, priceCents: toCents(p.total_price ?? p.base_price), currency: p.currency, type: p.type ?? null,
      product: byPkg.get(Number(p.id)) ? { id: byPkg.get(Number(p.id))!.id, name: byPkg.get(Number(p.id))!.name } : null,
    }))));
  }));
  // Aligne les prix affichés sur ceux de Tebex (le prix payé est toujours celui de Tebex)
  r.post('/tebex/sync-prices', admin, h(async (q, s) => {
    const cats = await tebex.listCategories();
    let updated = 0;
    for (const p of cats.flatMap((c) => c.packages ?? [])) {
      const res = await exec(pool, 'UPDATE products SET price_cents = ?, currency = ? WHERE tebex_package_id = ? AND (price_cents <> ? OR currency <> ?)',
        [toCents(p.total_price ?? p.base_price), p.currency, p.id, toCents(p.total_price ?? p.base_price), p.currency]);
      updated += res.affectedRows;
    }
    await log(q, 'tebex.sync_prices', null, { updated });
    s.json({ updated });
  }));

  // ---- Commandes ----
  r.get('/orders', support, h(async (q, s) => {
    const status = typeof q.query.status === 'string' && /^[a-z]{4,12}$/.test(q.query.status) ? q.query.status : null;
    const search = typeof q.query.q === 'string' ? q.query.q.trim().slice(0, 64) : '';
    const page = Math.max(1, Math.min(1000, Number(q.query.page) || 1));
    const where: string[] = []; const params: unknown[] = [];
    if (status) { where.push('o.status = ?'); params.push(status); }
    if (search) { where.push('(o.public_ref = ? OR o.tebex_transaction_id = ? OR o.cfx_id = ? OR u.display_name LIKE ?)'); params.push(search, search, search, `%${search.replace(/[%_]/g, '')}%`); }
    const list = await rows(pool,
      `SELECT o.id, o.public_ref, o.status, o.source, o.cfx_id, o.tebex_transaction_id, o.total_cents, o.currency, o.created_at, o.paid_at, u.display_name
       FROM orders o LEFT JOIN users u ON u.id = o.user_id ${where.length ? 'WHERE ' + where.join(' AND ') : ''}
       ORDER BY o.id DESC LIMIT 50 OFFSET ?`, [...params, (page - 1) * 50]);
    s.json({ page, orders: list });
  }));
  r.get('/orders/:id', support, h(async (q, s) => {
    const id = idParam(q.params.id);
    const order = await one(pool, 'SELECT o.*, u.display_name FROM orders o LEFT JOIN users u ON u.id = o.user_id WHERE o.id = ?', [id]);
    if (!order) throw notFound('Commande introuvable.');
    const [items, transactions, rewardsList] = await Promise.all([
      rows(pool, 'SELECT * FROM order_items WHERE order_id = ?', [id]),
      rows(pool, 'SELECT * FROM transactions WHERE order_id = ? ORDER BY id', [id]),
      rows<{ params: unknown; delivery_meta: unknown }>(pool,
        `SELECT r.*, (SELECT JSON_ARRAYAGG(JSON_OBJECT('id', j.id, 'action', j.action, 'status', j.status, 'attempts', j.attempts, 'lastError', j.last_error))
                      FROM delivery_jobs j WHERE j.reward_id = r.id) AS jobs
         FROM rewards r JOIN order_items oi ON oi.id = r.order_item_id WHERE oi.order_id = ? ORDER BY r.id`, [id]),
    ]);
    s.json({ order, items, transactions, rewards: rewardsList.map((x) => ({ ...x, params: json(x.params, {}), delivery_meta: json(x.delivery_meta, null), jobs: json((x as Record<string, unknown>).jobs, []) })) });
  }));

  // ---- Livraisons ----
  r.get('/deliveries', support, h(async (q, s) => {
    const status = typeof q.query.status === 'string' && ['pending', 'claimed', 'done', 'failed', 'cancelled'].includes(q.query.status) ? q.query.status : null;
    s.json(await rows(pool,
      `SELECT j.id, j.action, j.status, j.attempts, j.last_error, j.recipient_cfx_id, j.created_at, j.next_attempt_at, j.done_at, j.claimed_by,
              r.type, r.params, oi.name_snapshot, o.public_ref, o.id AS order_id
       FROM delivery_jobs j JOIN rewards r ON r.id = j.reward_id JOIN order_items oi ON oi.id = r.order_item_id JOIN orders o ON o.id = oi.order_id
       ${status ? 'WHERE j.status = ?' : ''} ORDER BY j.id DESC LIMIT 200`, status ? [status] : []));
  }));
  r.post('/deliveries/:id/retry', admin, h(async (q, s) => { const id = idParam(q.params.id); await retryJob(pool, id); await log(q, 'delivery.retry', `job:${id}`); s.json({ ok: true }); }));
  r.post('/deliveries/:id/cancel', admin, h(async (q, s) => { const id = idParam(q.params.id); await cancelJob(pool, id); await log(q, 'delivery.cancel', `job:${id}`); s.json({ ok: true }); }));

  // ---- Webhooks et journaux ----
  r.get('/webhooks', support, h(async (q, s) => {
    const status = typeof q.query.status === 'string' && ['received', 'processed', 'ignored', 'error'].includes(q.query.status) ? q.query.status : null;
    s.json(await rows(pool, `SELECT id, tebex_id, type, status, error, received_at, processed_at FROM webhook_events ${status ? 'WHERE status = ?' : ''} ORDER BY id DESC LIMIT 200`, status ? [status] : []));
  }));
  r.get('/logs', support, h(async (q, s) => {
    const level = typeof q.query.level === 'string' && ['info', 'warn', 'error'].includes(q.query.level) ? q.query.level : null;
    const list = await rows<{ details: unknown }>(pool, `SELECT * FROM audit_logs ${level ? 'WHERE level = ?' : ''} ORDER BY id DESC LIMIT 300`, level ? [level] : []);
    s.json(list.map((l) => ({ ...l, details: json(l.details, null) })));
  }));

  // ---- Administrateurs (propriétaire uniquement) ----
  r.get('/admins', owner, h(async (_q, s) => s.json(await listAdmins(pool))));
  r.post('/admins', owner, h(async (q, s) => {
    const b = z.object({ username: z.string(), password: z.string(), role: z.enum(['owner', 'admin', 'support']) }).parse(q.body);
    const exists = await one(pool, 'SELECT id FROM admins WHERE username = ?', [b.username]);
    if (exists) throw conflict('Cet identifiant existe déjà.');
    await upsertAdmin(pool, b.username, b.password, b.role);
    await log(q, 'admin.create', b.username, { role: b.role });
    s.status(201).json({ ok: true });
  }));
  r.patch('/admins/:id', owner, h(async (q, s) => {
    const id = idParam(q.params.id);
    const b = z.object({ role: z.enum(['owner', 'admin', 'support']).optional(), active: z.boolean().optional(), password: z.string().optional() }).parse(q.body);
    await updateAdmin(pool, q.admin!.id, id, b);
    await log(q, 'admin.update', `admin:${id}`, { role: b.role, active: b.active, passwordChanged: !!b.password });
    s.json({ ok: true });
  }));

  return r;
}
