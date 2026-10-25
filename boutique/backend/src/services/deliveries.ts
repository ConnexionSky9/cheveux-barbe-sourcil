// File de livraison lue par le serveur FiveM.
// · Le serveur de jeu « réserve » les tâches des joueurs connectés, les exécute, puis rend compte.
// · Une tâche réservée sans réponse depuis 5 minutes redevient disponible.
// · Échec : nouvel essai plus tard (attente croissante), puis « échouée » après N essais (visible dans le panel).
// · Le serveur de jeu garde aussi la liste des tâches déjà exécutées : une même tâche n'est jamais exécutée deux fois.
import type { Db } from '../db.js';
import { exec, json, one, rows, tx } from '../db.js';
import { conflict, notFound } from '../errors.js';
import { audit } from './audit.js';

const STALE_MINUTES = 5;

export interface ClaimedJob {
  id: number; action: 'grant' | 'revoke'; rewardId: number; type: string; params: Record<string, unknown>;
  recipientCfxId: string; expiresAt: Date | null; productName: string; orderRef: string; deliveryMeta: Record<string, unknown> | null;
}

export async function claimJobs(pool: Db, cfxIds: string[], server: string, limit = 50): Promise<ClaimedJob[]> {
  const ids = [...new Set(cfxIds.filter((x) => /^\d{1,20}$/.test(x)))].slice(0, 256);
  if (!ids.length) return [];
  return tx(pool, async (c) => {
    await exec(c, `UPDATE delivery_jobs SET status = 'pending' WHERE status = 'claimed' AND claimed_at < UTC_TIMESTAMP() - INTERVAL ${STALE_MINUTES} MINUTE`);
    const picked = await rows<{ id: number }>(c,
      `SELECT id FROM delivery_jobs WHERE status = 'pending' AND next_attempt_at <= UTC_TIMESTAMP()
       AND recipient_cfx_id IN (${ids.map(() => '?').join(',')}) ORDER BY id LIMIT ? FOR UPDATE SKIP LOCKED`, [...ids, limit]);
    if (!picked.length) return [];
    const jobIds = picked.map((p) => p.id);
    await exec(c, `UPDATE delivery_jobs SET status = 'claimed', claimed_at = UTC_TIMESTAMP(), claimed_by = ?, attempts = attempts + 1 WHERE id IN (${jobIds.map(() => '?').join(',')})`,
      [server.slice(0, 64), ...jobIds]);
    const list = await rows<{ id: number; action: 'grant' | 'revoke'; reward_id: number; type: string; params: unknown; recipient_cfx_id: string; expires_at: Date | null; name_snapshot: string; public_ref: string; delivery_meta: unknown }>(c,
      `SELECT j.id, j.action, j.reward_id, r.type, r.params, j.recipient_cfx_id, r.expires_at, oi.name_snapshot, o.public_ref, r.delivery_meta
       FROM delivery_jobs j JOIN rewards r ON r.id = j.reward_id JOIN order_items oi ON oi.id = r.order_item_id JOIN orders o ON o.id = oi.order_id
       WHERE j.id IN (${jobIds.map(() => '?').join(',')}) ORDER BY j.id`, jobIds);
    return list.map((j) => ({
      id: j.id, action: j.action, rewardId: j.reward_id, type: j.type, params: json<Record<string, unknown>>(j.params, {}),
      recipientCfxId: j.recipient_cfx_id, expiresAt: j.expires_at, productName: j.name_snapshot, orderRef: j.public_ref,
      deliveryMeta: json<Record<string, unknown> | null>(j.delivery_meta, null),
    }));
  });
}

export async function reportJob(pool: Db, jobId: number, result: { ok: boolean; error?: string; meta?: Record<string, unknown> }, server: string, maxAttempts: number): Promise<{ status: string }> {
  return tx(pool, async (c) => {
    const j = await one<{ id: number; reward_id: number; action: 'grant' | 'revoke'; status: string; attempts: number; recipient_cfx_id: string }>(c,
      'SELECT * FROM delivery_jobs WHERE id = ? FOR UPDATE', [jobId]);
    if (!j) throw notFound('Tâche introuvable.');
    if (j.status === 'done' || j.status === 'cancelled') return { status: j.status };
    if (j.status !== 'claimed') throw conflict('Tâche non réservée.');
    if (result.ok) {
      await exec(c, "UPDATE delivery_jobs SET status = 'done', done_at = UTC_TIMESTAMP(), last_error = NULL WHERE id = ?", [j.id]);
      if (j.action === 'grant') {
        await exec(c, "UPDATE rewards SET status = 'delivered', delivered_at = UTC_TIMESTAMP(), delivery_meta = ? WHERE id = ? AND status IN ('pending','failed')",
          [result.meta ? JSON.stringify(result.meta) : null, j.reward_id]);
      } else {
        await exec(c, "UPDATE rewards SET status = 'revoked', revoked_at = UTC_TIMESTAMP() WHERE id = ?", [j.reward_id]);
      }
      await audit(c, { actorType: 'game', actorId: server, action: `delivery.${j.action}`, target: `job:${j.id}`, details: { reward: j.reward_id, cfx: j.recipient_cfx_id } });
      return { status: 'done' };
    }
    const error = String(result.error ?? 'Erreur inconnue').slice(0, 500);
    if (j.attempts >= maxAttempts) {
      await exec(c, "UPDATE delivery_jobs SET status = 'failed', last_error = ? WHERE id = ?", [error, j.id]);
      if (j.action === 'grant') await exec(c, "UPDATE rewards SET status = 'failed' WHERE id = ? AND status = 'pending'", [j.reward_id]);
      await audit(c, { level: 'error', actorType: 'game', actorId: server, action: `delivery.${j.action}_failed`, target: `job:${j.id}`, details: { error, attempts: j.attempts } });
      return { status: 'failed' };
    }
    const waitMin = Math.min(60, 2 ** j.attempts);
    await exec(c, `UPDATE delivery_jobs SET status = 'pending', last_error = ?, next_attempt_at = UTC_TIMESTAMP() + INTERVAL ? MINUTE WHERE id = ?`, [error, waitMin, j.id]);
    await audit(c, { level: 'warn', actorType: 'game', actorId: server, action: `delivery.${j.action}_retry`, target: `job:${j.id}`, details: { error, attempts: j.attempts, nextInMinutes: waitMin } });
    return { status: 'pending' };
  });
}

/** Avantages actifs d'un joueur (grades / avantages) : réappliqués par le serveur de jeu à chaque connexion. */
export async function activeEntitlements(db: Db, cfxId: string): Promise<{ type: string; name: string; expiresAt: Date | null; product: string }[]> {
  const list = await rows<{ type: string; params: unknown; expires_at: Date | null; name_snapshot: string }>(db,
    `SELECT r.type, r.params, r.expires_at, oi.name_snapshot FROM rewards r JOIN order_items oi ON oi.id = r.order_item_id
     WHERE r.recipient_cfx_id = ? AND r.type IN ('group','perk') AND r.status = 'delivered'
     AND (r.expires_at IS NULL OR r.expires_at > UTC_TIMESTAMP())`, [cfxId]);
  return list.map((r) => ({ type: r.type, name: String(json<Record<string, unknown>>(r.params, {}).name ?? ''), expiresAt: r.expires_at, product: r.name_snapshot }));
}

/** Fin de durée : les récompenses expirées passent en « à retirer » (tâche de retrait pour le serveur de jeu). */
export async function sweepExpired(pool: Db): Promise<number> {
  const due = await rows<{ id: number; status: string; recipient_cfx_id: string }>(pool,
    "SELECT id, status, recipient_cfx_id FROM rewards WHERE status IN ('delivered','pending') AND expires_at IS NOT NULL AND expires_at <= UTC_TIMESTAMP() LIMIT 500");
  for (const r of due) {
    await tx(pool, async (c) => {
      if (r.status === 'delivered') {
        const u = await exec(c, "UPDATE rewards SET status = 'revoke_pending' WHERE id = ? AND status = 'delivered'", [r.id]);
        if (u.affectedRows) await exec(c, "INSERT IGNORE INTO delivery_jobs (reward_id, action, recipient_cfx_id) VALUES (?, 'revoke', ?)", [r.id, r.recipient_cfx_id]);
      } else {
        // Jamais livrée (joueur non revenu) et période terminée : annulée
        const u = await exec(c, "UPDATE rewards SET status = 'cancelled' WHERE id = ? AND status = 'pending'", [r.id]);
        if (u.affectedRows) {
          await exec(c, "UPDATE delivery_jobs SET status = 'cancelled' WHERE reward_id = ? AND action = 'grant' AND status <> 'done'", [r.id]);
          await audit(c, { level: 'warn', actorType: 'system', action: 'reward.expired_undelivered', target: `reward:${r.id}` });
        }
      }
    });
  }
  return due.length;
}

// ---- Administration ----
export async function retryJob(pool: Db, jobId: number): Promise<void> {
  await tx(pool, async (c) => {
    const j = await one<{ id: number; reward_id: number; action: string; status: string }>(c, 'SELECT * FROM delivery_jobs WHERE id = ? FOR UPDATE', [jobId]);
    if (!j) throw notFound('Tâche introuvable.');
    if (j.status !== 'failed') throw conflict('Seule une tâche échouée peut être relancée.');
    await exec(c, "UPDATE delivery_jobs SET status = 'pending', attempts = 0, next_attempt_at = UTC_TIMESTAMP(), last_error = NULL WHERE id = ?", [j.id]);
    if (j.action === 'grant') await exec(c, "UPDATE rewards SET status = 'pending' WHERE id = ? AND status = 'failed'", [j.reward_id]);
  });
}

export async function cancelJob(pool: Db, jobId: number): Promise<void> {
  await tx(pool, async (c) => {
    const j = await one<{ id: number; reward_id: number; action: string; status: string }>(c, 'SELECT * FROM delivery_jobs WHERE id = ? FOR UPDATE', [jobId]);
    if (!j) throw notFound('Tâche introuvable.');
    if (!['pending', 'failed'].includes(j.status)) throw conflict('Cette tâche ne peut plus être annulée.');
    await exec(c, "UPDATE delivery_jobs SET status = 'cancelled' WHERE id = ?", [j.id]);
    if (j.action === 'grant') await exec(c, "UPDATE rewards SET status = 'cancelled' WHERE id = ? AND status IN ('pending','failed')", [j.reward_id]);
    // Retrait annulé par un admin : la récompense est gardée sans limite de durée
    else await exec(c, "UPDATE rewards SET status = 'delivered', expires_at = NULL WHERE id = ? AND status = 'revoke_pending'", [j.reward_id]);
  });
}
