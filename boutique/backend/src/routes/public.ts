// Routes publiques et compte joueur (site web).
import { Router } from 'express';
import type { Request, Response } from 'express';
import rateLimit from 'express-rate-limit';
import { z } from 'zod';
import type { AppConfig } from '../config.js';
import type { Db } from '../db.js';
import { badRequest, notFound } from '../errors.js';
import { clientIp, h, requireUser } from '../http/middleware.js';
import { audit } from '../services/audit.js';
import { publicCatalog, publicCategories, publicProduct, publicProducts } from '../services/catalog.js';
import { activeEntitlements } from '../services/deliveries.js';
import { getUser, redeemLinkCode } from '../services/linking.js';
import { continueCheckout, createCheckout, historyFor, orderStatus } from '../services/orders.js';
import { COOKIE, SESSION_TTL, createSession, destroySession } from '../services/sessions.js';
import type { TebexClient } from '../services/tebex.js';

const ERROR_PAGES: Record<string, string> = {
  not_found: 'commande-introuvable', closed: 'commande-terminee', account_mismatch: 'mauvais-compte', payment_unavailable: 'paiement-indisponible',
};

export function publicRoutes(pool: Db, cfg: AppConfig, tebex: TebexClient): Router {
  const r = Router();
  const deps = { pool, tebex, publicUrl: cfg.PUBLIC_URL, currency: cfg.CURRENCY };
  const cookieOpts = (maxAge: number) => ({ httpOnly: true, secure: cfg.COOKIE_SECURE, sameSite: 'lax' as const, path: '/', maxAge });

  const linkLimiter = rateLimit({ windowMs: 15 * 60_000, limit: 10, standardHeaders: 'draft-7', legacyHeaders: false, message: { error: 'Trop de tentatives. Réessayez dans 15 minutes.', code: 'rate_limited' } });
  const checkoutLimiter = rateLimit({ windowMs: 10 * 60_000, limit: 20, standardHeaders: 'draft-7', legacyHeaders: false, message: { error: 'Trop de commandes en peu de temps.', code: 'rate_limited' } });

  r.get('/health', h(async (_q, s) => s.json({ ok: true })));

  r.get('/config', h(async (_q, s) => s.json({
    serverName: cfg.SERVER_NAME, currency: cfg.CURRENCY, discordUrl: cfg.DISCORD_URL || null, supportEmail: cfg.SUPPORT_EMAIL || null,
  })));

  // ---- Catalogue ----
  r.get('/catalog', h(async (_q, s) => { s.set('Cache-Control', 'public, max-age=30'); s.json(await publicCatalog(pool)); }));
  r.get('/categories', h(async (_q, s) => s.json(await publicCategories(pool))));
  r.get('/products', h(async (q, s) => {
    const cat = typeof q.query.category === 'string' && /^[a-z0-9-]{1,48}$/.test(q.query.category) ? q.query.category : undefined;
    s.json(await publicProducts(pool, cat));
  }));
  r.get('/products/:slug', h(async (q, s) => {
    const slug = String(q.params.slug);
    if (!/^[a-z0-9-]{1,64}$/.test(slug)) throw notFound('Produit introuvable.');
    const p = await publicProduct(pool, slug);
    if (!p) throw notFound('Produit introuvable.');
    s.json(p);
  }));

  // ---- Session / liaison ----
  r.get('/session', h(async (q, s) => {
    const sess = q.userSession;
    const user = sess?.userId ? await getUser(pool, sess.userId) : null;
    s.json({ user: user ? { id: user.id, displayName: user.display_name, cfxId: user.cfx_id } : null, csrfToken: user ? sess!.csrf : null });
  }));

  r.post('/auth/link', linkLimiter, h(async (q: Request, s: Response) => {
    const body = z.object({ code: z.string().min(4).max(16) }).parse(q.body);
    const user = await redeemLinkCode(pool, body.code);
    if (!user) {
      await audit(pool, { level: 'warn', actorType: 'user', action: 'auth.link_failed', ip: clientIp(q) });
      throw badRequest('Code invalide ou expiré. Générez-en un nouveau en jeu avec /boutique_lier.', 'invalid_code');
    }
    if (q.userSession) await destroySession(pool, q.userSession.tokenHash);
    const sess = await createSession(pool, 'user', user.id, clientIp(q));
    s.cookie(COOKIE.user, sess.token, cookieOpts(SESSION_TTL.user));
    await audit(pool, { actorType: 'user', actorId: user.id, action: 'auth.linked', target: `cfx:${user.cfxId}`, ip: clientIp(q) });
    s.json({ user: { id: user.id, displayName: user.displayName, cfxId: user.cfxId }, csrfToken: sess.csrf });
  }));

  r.post('/auth/logout', requireUser, h(async (q, s) => {
    await destroySession(pool, q.userSession!.tokenHash);
    s.clearCookie(COOKIE.user, { path: '/' });
    s.json({ ok: true });
  }));

  // ---- Compte ----
  r.get('/account/orders', requireUser, h(async (q, s) => {
    const u = await getUser(pool, q.userSession!.userId!);
    if (!u) throw notFound();
    s.json(await historyFor(pool, u.cfx_id));
  }));
  r.get('/account/entitlements', requireUser, h(async (q, s) => {
    const u = await getUser(pool, q.userSession!.userId!);
    if (!u) throw notFound();
    s.json(await activeEntitlements(pool, u.cfx_id));
  }));

  // ---- Commande ----
  r.post('/checkout', checkoutLimiter, requireUser, h(async (q, s) => {
    const body = z.object({ items: z.array(z.object({ productId: z.number().int().positive(), quantity: z.number().int().min(1).max(99) })).min(1).max(10) }).parse(q.body);
    const u = await getUser(pool, q.userSession!.userId!);
    if (!u) throw notFound();
    const out = await createCheckout(deps, { source: 'web', userId: u.id, cfxId: u.cfx_id, items: body.items, ip: clientIp(q) });
    await audit(pool, { actorType: 'user', actorId: u.id, action: 'checkout.created', target: out.ref, ip: clientIp(q) });
    s.json(out);
  }));

  // Retour de la connexion Cfx.re (Tebex) : redirection du navigateur
  r.get('/checkout/:ref/continue', h(async (q, s) => {
    const result = await continueCheckout(deps, String(q.params.ref));
    if ('redirect' in result) return s.redirect(303, result.redirect);
    s.redirect(303, `${cfg.PUBLIC_URL}/erreur?raison=${ERROR_PAGES[result.error] ?? 'inconnue'}`);
  }));

  // Statut affiché sur la page de confirmation (référence = jeton non devinable)
  r.get('/orders/:ref/status', h(async (q, s) => { s.set('Cache-Control', 'no-store'); s.json(await orderStatus(pool, String(q.params.ref))); }));

  return r;
}
