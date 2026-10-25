// Traitement des notifications (webhooks) Tebex, déjà authentifiées par leur signature (routes/webhook.ts).
// · Chaque événement porte un id unique : il n'est traité qu'une fois (table webhook_events).
// · Une commande n'est payée QUE sur « payment.completed » ; les récompenses sont créées dans la même transaction.
// · Remboursement / litige perdu : les récompenses retirables sont révoquées, les autres signalées.
import type { PoolConnection } from 'mysql2/promise';
import type { Db } from '../db.js';
import { exec, one, rows, tx } from '../db.js';
import { uuid } from '../security.js';
import { audit } from './audit.js';
import { REVOCABLE, type RewardType } from './rewardTypes.js';
import { toCents } from './tebex.js';

type Obj = Record<string, unknown>;
const obj = (v: unknown): Obj => (v && typeof v === 'object' && !Array.isArray(v) ? (v as Obj) : {});
const str = (v: unknown): string => (v === null || v === undefined ? '' : String(v));
const cfx = (v: unknown): string => { const s = str(v); return /^\d{1,20}$/.test(s) ? s : ''; };

export interface WebhookResult { httpStatus: number; body: unknown; outcome: 'validation' | 'processed' | 'duplicate' | 'ignored' | 'error' }

const HANDLED = new Set(['payment.completed', 'payment.declined', 'payment.refunded', 'payment.dispute.opened', 'payment.dispute.lost', 'payment.dispute.won', 'payment.dispute.closed']);

export async function handleTebexWebhook(pool: Db, payload: unknown): Promise<WebhookResult> {
  const ev = obj(payload);
  const id = str(ev.id).slice(0, 64);
  const type = str(ev.type).slice(0, 64);
  if (!id || !type) return { httpStatus: 400, body: { error: 'payload invalide' }, outcome: 'error' };

  // Validation de l'adresse du webhook (configuration dans le panneau Tebex) : renvoyer l'id
  if (type === 'validation.webhook') return { httpStatus: 200, body: { id }, outcome: 'validation' };

  await exec(pool, 'INSERT IGNORE INTO webhook_events (tebex_id, type, payload) VALUES (?, ?, ?)', [id, type, JSON.stringify(payload)]);
  try {
    const outcome = await tx(pool, async (c) => {
      // Verrou : deux livraisons simultanées du même événement attendent l'une l'autre
      const row = await one<{ id: number; status: string }>(c, 'SELECT id, status FROM webhook_events WHERE tebex_id = ? FOR UPDATE', [id]);
      if (!row) throw new Error('événement non enregistré');
      if (row.status === 'processed' || row.status === 'ignored') return 'duplicate' as const;
      if (!HANDLED.has(type)) {
        await exec(c, "UPDATE webhook_events SET status = 'ignored', processed_at = UTC_TIMESTAMP() WHERE id = ?", [row.id]);
        return 'ignored' as const;
      }
      const subject = obj(ev.subject);
      if (type === 'payment.completed') await onCompleted(c, subject);
      else if (type === 'payment.declined') await onDeclined(c, subject);
      else if (type === 'payment.refunded') await onReversal(c, subject, 'refunded');
      else if (type === 'payment.dispute.lost') await onReversal(c, subject, 'chargeback');
      else await onDisputeInfo(c, subject, type);
      await exec(c, "UPDATE webhook_events SET status = 'processed', error = NULL, processed_at = UTC_TIMESTAMP() WHERE id = ?", [row.id]);
      return 'processed' as const;
    });
    return { httpStatus: 200, body: { ok: true }, outcome };
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    await exec(pool, "UPDATE webhook_events SET status = 'error', error = ? WHERE tebex_id = ?", [msg.slice(0, 500), id]).catch(() => undefined);
    await audit(pool, { level: 'error', actorType: 'webhook', action: 'webhook.failed', target: id, details: { type, error: msg } });
    // Code ≠ 2xx : Tebex renverra la notification plus tard
    return { httpStatus: 500, body: { error: 'traitement impossible' }, outcome: 'error' };
  }
}

async function findOrder(c: PoolConnection, subject: Obj): Promise<{ id: number; public_ref: string; status: string; tebex_transaction_id: string | null; cfx_id: string | null; user_id: number | null } | null> {
  const txId = str(subject.transaction_id);
  if (txId) {
    const byTx = await one<any>(c, 'SELECT * FROM orders WHERE tebex_transaction_id = ? FOR UPDATE', [txId]);
    if (byTx) return byTx;
  }
  const ref = str(obj(subject.custom).order_ref);
  if (ref) {
    const byRef = await one<any>(c, 'SELECT * FROM orders WHERE public_ref = ? FOR UPDATE', [ref]);
    if (byRef && (!byRef.tebex_transaction_id || byRef.tebex_transaction_id === txId)) return byRef;
  }
  return null;
}

async function addTransaction(c: PoolConnection, orderId: number, subject: Obj, type: string): Promise<void> {
  const price = obj(subject.price_paid ?? subject.price);
  await exec(c, 'INSERT INTO transactions (order_id, tebex_transaction_id, event_type, status, amount_cents, currency) VALUES (?, ?, ?, ?, ?, ?)',
    [orderId, str(subject.transaction_id).slice(0, 64) || 'inconnu', type, str(obj(subject.status).description || subject.status).slice(0, 48) || type,
      price.amount === undefined ? null : toCents(price.amount as number), str(price.currency).slice(0, 3) || null]);
}

async function onCompleted(c: PoolConnection, subject: Obj): Promise<void> {
  const txId = str(subject.transaction_id).slice(0, 64);
  if (!txId) throw new Error('transaction_id absent');
  const payer = cfx(obj(obj(subject.customer).username).id);
  let order = await findOrder(c, subject);
  if (order && order.status === 'paid' && order.tebex_transaction_id === txId) return; // déjà fait

  if (!order) {
    // Achat fait directement sur la boutique Tebex (sans passer par notre site) : on le prend en compte aussi
    const ref = uuid();
    const user = payer ? await one<{ id: number }>(c, 'SELECT id FROM users WHERE cfx_id = ?', [payer]) : null;
    const r = await exec(c, "INSERT INTO orders (public_ref, user_id, cfx_id, source, status) VALUES (?, ?, ?, 'tebex', 'pending')", [ref, user?.id ?? null, payer || null]);
    order = { id: r.insertId, public_ref: ref, status: 'pending', tebex_transaction_id: null, cfx_id: payer || null, user_id: user?.id ?? null };
  }
  const price = obj(subject.price_paid ?? subject.price);
  await exec(c,
    `UPDATE orders SET status = 'paid', tebex_transaction_id = ?, paid_at = UTC_TIMESTAMP(), cfx_id = COALESCE(?, cfx_id),
     total_cents = COALESCE(?, total_cents), currency = COALESCE(?, currency) WHERE id = ?`,
    [txId, payer || null, price.amount === undefined ? null : toCents(price.amount as number), str(price.currency).slice(0, 3) || null, order.id]);
  await addTransaction(c, order.id, subject, 'payment.completed');

  // Les produits payés selon Tebex font foi : on remplace les lignes prévues au passage en caisse
  await exec(c, 'DELETE oi FROM order_items oi LEFT JOIN rewards r ON r.order_item_id = oi.id WHERE oi.order_id = ? AND r.id IS NULL', [order.id]);
  const products = Array.isArray(subject.products) ? subject.products.map(obj) : [];
  if (!products.length) await audit(c, { level: 'warn', actorType: 'webhook', action: 'payment.no_products', target: order.public_ref });

  for (const p of products) {
    const packageId = Number(p.id);
    const qty = Math.max(1, Math.min(99, Number(p.quantity ?? 1) || 1));
    const recipient = cfx(obj(p.username).id) || payer;
    const ours = Number.isFinite(packageId)
      ? await one<{ id: number; name: string; duration_days: number | null }>(c, 'SELECT id, name, duration_days FROM products WHERE tebex_package_id = ?', [packageId])
      : null;
    const paid = obj(p.paid_price ?? p.base_price);
    const unit = paid.amount === undefined ? 0 : Math.round(toCents(paid.amount as number) / qty);
    const item = await exec(c,
      'INSERT INTO order_items (order_id, product_id, tebex_package_id, name_snapshot, quantity, unit_price_cents, recipient_cfx_id) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [order.id, ours?.id ?? null, Number.isFinite(packageId) ? packageId : null, (ours?.name ?? str(p.name)).slice(0, 80) || 'Produit', qty, unit, recipient || null]);

    if (!ours) {
      await audit(c, { level: 'error', actorType: 'webhook', action: 'payment.unknown_package', target: order.public_ref, details: { packageId, name: str(p.name) } });
      continue;
    }
    if (!recipient) {
      await audit(c, { level: 'error', actorType: 'webhook', action: 'payment.no_recipient', target: order.public_ref, details: { packageId } });
      continue;
    }
    await createRewards(c, item.insertId, ours, qty, recipient);
  }
  await audit(c, { actorType: 'webhook', action: 'payment.completed', target: order.public_ref, details: { transaction: txId, products: products.length } });
}

/** Une récompense par unité et par récompense du produit, plus une tâche de livraison. Idempotent (clés uniques). */
async function createRewards(c: PoolConnection, orderItemId: number, product: { id: number; duration_days: number | null }, qty: number, recipient: string): Promise<void> {
  const defs = await rows<{ id: number; type: RewardType; params: unknown }>(c, 'SELECT id, type, params FROM product_rewards WHERE product_id = ? ORDER BY sort, id', [product.id]);
  let base = Date.now();
  if (product.duration_days) {
    // Achats successifs d'un produit à durée : les périodes s'enchaînent
    const last = await one<{ e: Date | null }>(c,
      `SELECT MAX(r.expires_at) AS e FROM rewards r JOIN order_items oi ON oi.id = r.order_item_id
       WHERE oi.product_id = ? AND r.recipient_cfx_id = ? AND r.status IN ('pending','delivered') AND r.expires_at > UTC_TIMESTAMP()`,
      [product.id, recipient]);
    if (last?.e) base = Math.max(base, new Date(last.e).getTime());
  }
  for (let u = 0; u < qty; u++) {
    for (const d of defs) {
      const timed = product.duration_days && REVOCABLE.has(d.type);
      const expires = timed ? new Date(base + (u + 1) * product.duration_days! * 86_400_000) : null;
      const params = typeof d.params === 'string' ? d.params : JSON.stringify(d.params);
      const r = await exec(c,
        'INSERT IGNORE INTO rewards (order_item_id, unit_index, reward_def_id, type, params, recipient_cfx_id, expires_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [orderItemId, u, d.id, d.type, params, recipient, expires]);
      if (r.affectedRows === 1) {
        await exec(c, "INSERT IGNORE INTO delivery_jobs (reward_id, action, recipient_cfx_id) VALUES (?, 'grant', ?)", [r.insertId, recipient]);
      }
    }
  }
}

async function onDeclined(c: PoolConnection, subject: Obj): Promise<void> {
  const order = await findOrder(c, subject);
  if (!order) return;
  if (order.status === 'pending') await exec(c, "UPDATE orders SET status = 'failed' WHERE id = ?", [order.id]);
  await addTransaction(c, order.id, subject, 'payment.declined');
}

async function onReversal(c: PoolConnection, subject: Obj, status: 'refunded' | 'chargeback'): Promise<void> {
  const order = await findOrder(c, subject);
  if (!order) {
    await audit(c, { level: 'warn', actorType: 'webhook', action: `payment.${status}_unknown`, target: str(subject.transaction_id).slice(0, 96) });
    return;
  }
  if (order.status === status) return;
  await exec(c, 'UPDATE orders SET status = ? WHERE id = ?', [status, order.id]);
  await addTransaction(c, order.id, subject, status === 'refunded' ? 'payment.refunded' : 'payment.dispute.lost');
  const list = await rows<{ id: number; type: RewardType; status: string; recipient_cfx_id: string }>(c,
    'SELECT r.id, r.type, r.status, r.recipient_cfx_id FROM rewards r JOIN order_items oi ON oi.id = r.order_item_id WHERE oi.order_id = ? FOR UPDATE', [order.id]);
  const manual: number[] = [];
  for (const r of list) {
    if (r.status === 'pending' || r.status === 'failed') {
      await exec(c, "UPDATE rewards SET status = 'cancelled' WHERE id = ?", [r.id]);
      await exec(c, "UPDATE delivery_jobs SET status = 'cancelled' WHERE reward_id = ? AND action = 'grant' AND status IN ('pending','failed')", [r.id]);
    } else if (r.status === 'delivered') {
      if (REVOCABLE.has(r.type)) {
        await exec(c, "UPDATE rewards SET status = 'revoke_pending' WHERE id = ?", [r.id]);
        await exec(c, "INSERT IGNORE INTO delivery_jobs (reward_id, action, recipient_cfx_id) VALUES (?, 'revoke', ?)", [r.id, r.recipient_cfx_id]);
      } else manual.push(r.id);
    }
  }
  await audit(c, { level: manual.length ? 'warn' : 'info', actorType: 'webhook', action: `payment.${status}`, target: order.public_ref,
    details: manual.length ? { message: 'Récompenses non retirables automatiquement (argent, objets, commandes) : à traiter à la main', rewards: manual } : null });
}

async function onDisputeInfo(c: PoolConnection, subject: Obj, type: string): Promise<void> {
  const order = await findOrder(c, subject);
  if (order) await addTransaction(c, order.id, subject, type);
  await audit(c, { level: type === 'payment.dispute.opened' ? 'warn' : 'info', actorType: 'webhook', action: type, target: order?.public_ref ?? str(subject.transaction_id).slice(0, 96) });
}
