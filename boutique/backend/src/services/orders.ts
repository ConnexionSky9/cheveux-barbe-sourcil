// Passage en caisse : commande « en attente » + panier Tebex.
// Le paiement n'est JAMAIS considéré comme réussi ici : seule la notification Tebex signée
// (services/payments.ts) fait passer une commande à « payée » et déclenche les récompenses.
import type { Db } from '../db.js';
import { exec, one, rows, tx } from '../db.js';
import { HttpError, badRequest, notFound } from '../errors.js';
import { uuid } from '../security.js';
import { audit } from './audit.js';
import type { TebexClient } from './tebex.js';

export interface CheckoutDeps { pool: Db; tebex: TebexClient; publicUrl: string; currency: string }
export interface CheckoutItem { productId: number; quantity: number }

export const REF = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

type OrderRow = { id: number; public_ref: string; user_id: number | null; cfx_id: string | null; source: string; status: string; tebex_basket_ident: string | null; packages_added: number };

/** Choisit le lien de connexion FiveM (Cfx.re) parmi ceux proposés par Tebex. */
function pickAuth(links: { name: string; url: string }[]): string | null {
  const fivem = links.find((l) => /fivem|cfx/i.test(l.name));
  return (fivem ?? links[0])?.url ?? null;
}

export async function createCheckout(d: CheckoutDeps, input: { source: 'web' | 'game'; userId: number | null; cfxId: string; items: CheckoutItem[]; ip?: string }): Promise<{ ref: string; redirectUrl: string }> {
  const items = input.items;
  if (!Array.isArray(items) || items.length < 1 || items.length > 10) throw badRequest('Panier vide ou trop grand (10 produits maximum).');
  const seen = new Set<number>();
  for (const it of items) {
    if (!Number.isInteger(it.productId) || !Number.isInteger(it.quantity) || it.quantity < 1 || it.quantity > 99) throw badRequest('Quantité invalide.');
    if (seen.has(it.productId)) throw badRequest('Produit en double dans le panier.');
    seen.add(it.productId);
  }
  // Prix, disponibilité et paquets Tebex lus en base : rien ne vient du navigateur ni de la NUI
  const products = await rows<{ id: number; name: string; price_cents: number; currency: string; max_quantity: number; tebex_package_id: number | null }>(d.pool,
    `SELECT p.id, p.name, p.price_cents, p.currency, p.max_quantity, p.tebex_package_id
     FROM products p JOIN categories c ON c.id = p.category_id
     WHERE p.active = 1 AND c.active = 1 AND p.tebex_package_id IS NOT NULL AND p.id IN (${items.map(() => '?').join(',')})`,
    items.map((i) => i.productId));
  const byId = new Map(products.map((p) => [p.id, p]));
  let total = 0;
  for (const it of items) {
    const p = byId.get(it.productId);
    if (!p) throw badRequest('Un produit du panier n\'est plus disponible.', 'unavailable');
    if (it.quantity > p.max_quantity) throw badRequest(`« ${p.name} » : ${p.max_quantity} maximum par commande.`);
    total += p.price_cents * it.quantity;
  }

  const ref = uuid();
  const orderId = await tx(d.pool, async (c) => {
    const r = await exec(c, 'INSERT INTO orders (public_ref, user_id, cfx_id, source, status, total_cents, currency) VALUES (?, ?, ?, ?, \'pending\', ?, ?)',
      [ref, input.userId, input.cfxId, input.source, total, d.currency]);
    for (const it of items) {
      const p = byId.get(it.productId)!;
      await exec(c, 'INSERT INTO order_items (order_id, product_id, tebex_package_id, name_snapshot, quantity, unit_price_cents, recipient_cfx_id) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [r.insertId, p.id, p.tebex_package_id, p.name, it.quantity, p.price_cents, input.cfxId]);
    }
    return r.insertId;
  });

  try {
    const basket = await d.tebex.createBasket({
      completeUrl: `${d.publicUrl}/commande/${ref}`,
      cancelUrl: `${d.publicUrl}/panier?annule=${ref}`,
      custom: { order_ref: ref },
      ip: input.ip,
    });
    await exec(d.pool, 'UPDATE orders SET tebex_basket_ident = ? WHERE id = ?', [basket.ident, orderId]);
    const links = await d.tebex.getAuthLinks(basket.ident, `${d.publicUrl}/api/checkout/${ref}/continue`);
    const auth = pickAuth(links);
    return { ref, redirectUrl: auth ?? `${d.publicUrl}/api/checkout/${ref}/continue` };
  } catch (err) {
    await exec(d.pool, 'UPDATE orders SET status = \'cancelled\' WHERE id = ? AND status = \'pending\'', [orderId]);
    await audit(d.pool, { level: 'error', actorType: 'system', action: 'tebex.basket_failed', target: ref, details: { error: err instanceof Error ? err.message : String(err) } });
    throw new HttpError(502, 'Le service de paiement ne répond pas. Réessayez dans quelques minutes.', 'payment_unavailable');
  }
}

export type ContinueResult = { redirect: string } | { error: 'not_found' | 'closed' | 'account_mismatch' | 'payment_unavailable' };

/** Retour de la connexion Cfx.re sur Tebex : vérifie le compte, ajoute les paquets, envoie vers le paiement Tebex. */
export async function continueCheckout(d: CheckoutDeps, ref: string): Promise<ContinueResult> {
  if (!REF.test(ref)) return { error: 'not_found' };
  const order = await one<OrderRow>(d.pool, 'SELECT * FROM orders WHERE public_ref = ?', [ref]);
  if (!order || !order.tebex_basket_ident) return { error: 'not_found' };
  if (order.status !== 'pending') return { error: 'closed' };
  try {
    const basket = await d.tebex.getBasket(order.tebex_basket_ident);
    if (basket.complete) return { error: 'closed' };
    if (basket.username_id === null || basket.username_id === undefined || basket.username_id === '') {
      const auth = pickAuth(await d.tebex.getAuthLinks(basket.ident, `${d.publicUrl}/api/checkout/${ref}/continue`));
      return auth ? { redirect: auth } : { error: 'payment_unavailable' };
    }
    // Le compte Cfx.re connecté sur Tebex doit être celui du joueur (site lié ou serveur de jeu)
    if (order.cfx_id && String(basket.username_id) !== order.cfx_id) {
      await audit(d.pool, { level: 'warn', actorType: 'system', action: 'checkout.account_mismatch', target: ref, details: { expected: order.cfx_id, got: String(basket.username_id) } });
      return { error: 'account_mismatch' };
    }
    // Ajout des paquets une seule fois, même si la page est rechargée
    const lock = await exec(d.pool, 'UPDATE orders SET packages_added = 1 WHERE id = ? AND packages_added = 0', [order.id]);
    if (lock.affectedRows === 1) {
      try {
        const items = await rows<{ tebex_package_id: number; quantity: number }>(d.pool, 'SELECT tebex_package_id, quantity FROM order_items WHERE order_id = ?', [order.id]);
        for (const it of items) await d.tebex.addPackage(basket.ident, Number(it.tebex_package_id), it.quantity);
      } catch (err) {
        await exec(d.pool, 'UPDATE orders SET packages_added = 0 WHERE id = ?', [order.id]);
        throw err;
      }
    }
    const fresh = await d.tebex.getBasket(basket.ident);
    return { redirect: fresh.links.checkout };
  } catch (err) {
    await audit(d.pool, { level: 'error', actorType: 'system', action: 'tebex.continue_failed', target: ref, details: { error: err instanceof Error ? err.message : String(err) } });
    return { error: 'payment_unavailable' };
  }
}

/** Statut public d'une commande (page de confirmation) : aucune donnée personnelle. */
export async function orderStatus(pool: Db, ref: string): Promise<{ ref: string; status: string; items: { name: string; quantity: number }[]; deliveries: { pending: number; delivered: number; failed: number } }> {
  if (!REF.test(ref)) throw notFound('Commande introuvable.');
  const o = await one<{ id: number; status: string }>(pool, 'SELECT id, status FROM orders WHERE public_ref = ?', [ref]);
  if (!o) throw notFound('Commande introuvable.');
  const items = await rows<{ name_snapshot: string; quantity: number }>(pool, 'SELECT name_snapshot, quantity FROM order_items WHERE order_id = ?', [o.id]);
  const st = await rows<{ status: string; n: number }>(pool,
    'SELECT r.status, COUNT(*) AS n FROM rewards r JOIN order_items oi ON oi.id = r.order_item_id WHERE oi.order_id = ? GROUP BY r.status', [o.id]);
  const count = (s: string[]) => st.filter((x) => s.includes(x.status)).reduce((a, x) => a + Number(x.n), 0);
  return { ref, status: o.status, items: items.map((i) => ({ name: i.name_snapshot, quantity: i.quantity })),
    deliveries: { pending: count(['pending']), delivered: count(['delivered', 'revoke_pending', 'revoked']), failed: count(['failed']) } };
}

/** Historique d'un joueur (compte web ou jeu), avec l'état de livraison de chaque ligne. */
export async function historyFor(pool: Db, cfxId: string): Promise<unknown[]> {
  const orders = await rows<{ id: number; public_ref: string; status: string; total_cents: number; currency: string; created_at: Date; paid_at: Date | null; source: string }>(pool,
    `SELECT id, public_ref, status, total_cents, currency, created_at, paid_at, source FROM orders
     WHERE cfx_id = ? AND status <> 'cancelled' AND NOT (status = 'pending' AND created_at < UTC_TIMESTAMP() - INTERVAL 2 DAY)
     ORDER BY created_at DESC LIMIT 100`, [cfxId]);
  if (!orders.length) return [];
  const items = await rows<{ id: number; order_id: number; name_snapshot: string; quantity: number; unit_price_cents: number }>(pool,
    `SELECT id, order_id, name_snapshot, quantity, unit_price_cents FROM order_items WHERE order_id IN (${orders.map(() => '?').join(',')})`, orders.map((o) => o.id));
  const rewards = items.length ? await rows<{ order_item_id: number; status: string; expires_at: Date | null }>(pool,
    `SELECT order_item_id, status, expires_at FROM rewards WHERE order_item_id IN (${items.map(() => '?').join(',')})`, items.map((i) => i.id)) : [];
  return orders.map((o) => ({
    ref: o.public_ref, status: o.status, totalCents: o.total_cents, currency: o.currency, createdAt: o.created_at, paidAt: o.paid_at, source: o.source,
    items: items.filter((i) => i.order_id === o.id).map((i) => {
      const rs = rewards.filter((r) => r.order_item_id === i.id);
      const delivery = !rs.length ? 'none' : rs.every((r) => ['delivered', 'revoked', 'revoke_pending'].includes(r.status)) ? 'delivered'
        : rs.some((r) => r.status === 'failed') ? 'failed' : rs.every((r) => r.status === 'cancelled') ? 'cancelled' : 'pending';
      const exp = rs.map((r) => r.expires_at).filter((x): x is Date => !!x).sort((a, b) => +b - +a)[0] ?? null;
      return { name: i.name_snapshot, quantity: i.quantity, unitPriceCents: i.unit_price_cents, delivery, expiresAt: exp };
    }),
  }));
}
