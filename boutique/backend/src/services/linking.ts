// Liaison compte web ↔ compte FiveM.
// 1. En jeu, le joueur tape /boutique_lier : le SERVEUR FiveM (jeton secret) demande un code à l'API,
//    avec l'identifiant Cfx.re et les identifiants du joueur relevés par le serveur lui-même.
// 2. Sur le site, le joueur saisit ce code (valable 10 min, usage unique) : son compte web est créé / connecté
//    et rattaché à cet identifiant Cfx.re. Le navigateur ne fournit jamais lui-même d'identifiant.
import type { Conn, Db } from '../db.js';
import { exec, one, tx } from '../db.js';
import { badRequest } from '../errors.js';
import { linkCode, normalizeCode, sha256 } from '../security.js';

export const CFX_ID = /^\d{1,20}$/;
const KINDS = new Set(['fivem', 'license', 'license2', 'discord', 'steam', 'xbl', 'live']);
const CODE_TTL_MS = 10 * 60_000;

export interface GameIdentity { cfxId: string; name: string; identifiers: Record<string, string> }

export function cleanIdentity(input: { cfxId?: unknown; name?: unknown; identifiers?: unknown }): GameIdentity {
  const cfxId = String(input.cfxId ?? '');
  if (!CFX_ID.test(cfxId)) throw badRequest('Identifiant Cfx.re manquant : le joueur doit être connecté à son compte FiveM.', 'no_cfx');
  const name = String(input.name ?? 'Joueur').replace(/[\u0000-\u001f<>]/g, '').trim().slice(0, 64) || 'Joueur';
  const identifiers: Record<string, string> = {};
  if (input.identifiers && typeof input.identifiers === 'object') {
    for (const [k, v] of Object.entries(input.identifiers as Record<string, unknown>)) {
      if (KINDS.has(k) && typeof v === 'string' && /^[a-zA-Z0-9:._-]{1,96}$/.test(v)) identifiers[k] = v;
    }
  }
  identifiers.fivem = `fivem:${cfxId}`;
  return { cfxId, name, identifiers };
}

export async function createLinkCode(db: Conn, id: GameIdentity): Promise<{ code: string; expiresAt: Date }> {
  await exec(db, 'DELETE FROM link_codes WHERE cfx_id = ? OR expires_at < UTC_TIMESTAMP()', [id.cfxId]);
  const code = linkCode(8);
  const expiresAt = new Date(Date.now() + CODE_TTL_MS);
  await exec(db, 'INSERT INTO link_codes (code_hash, cfx_id, display_name, identifiers, expires_at) VALUES (?, ?, ?, ?, ?)',
    [sha256(code), id.cfxId, id.name, JSON.stringify(id.identifiers), expiresAt]);
  return { code, expiresAt };
}

/** Utilise un code : renvoie l'utilisateur (créé si besoin) ou null si le code est faux / expiré / déjà utilisé. */
export async function redeemLinkCode(pool: Db, rawCode: string): Promise<{ id: number; cfxId: string; displayName: string } | null> {
  const code = normalizeCode(String(rawCode ?? ''));
  if (code.length !== 8) return null;
  return tx(pool, async (c) => {
    const row = await one<{ cfx_id: string; display_name: string; identifiers: unknown }>(c,
      'SELECT cfx_id, display_name, identifiers FROM link_codes WHERE code_hash = ? AND used_at IS NULL AND expires_at > UTC_TIMESTAMP() FOR UPDATE',
      [sha256(code)]);
    if (!row) return null;
    await exec(c, 'UPDATE link_codes SET used_at = UTC_TIMESTAMP() WHERE code_hash = ?', [sha256(code)]);
    await exec(c,
      `INSERT INTO users (cfx_id, display_name, last_login_at) VALUES (?, ?, UTC_TIMESTAMP())
       ON DUPLICATE KEY UPDATE display_name = VALUES(display_name), last_login_at = UTC_TIMESTAMP()`,
      [row.cfx_id, row.display_name]);
    const user = await one<{ id: number }>(c, 'SELECT id FROM users WHERE cfx_id = ?', [row.cfx_id]);
    if (!user) throw new Error('Utilisateur non créé');
    const ids = typeof row.identifiers === 'string' ? JSON.parse(row.identifiers) as Record<string, string> : row.identifiers as Record<string, string>;
    for (const [kind, value] of Object.entries(ids ?? {})) {
      await exec(c, 'INSERT INTO linked_accounts (user_id, kind, value) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE user_id = VALUES(user_id)', [user.id, kind, value]);
    }
    // Les commandes déjà payées avec ce compte Cfx.re apparaissent dans l'historique du compte web
    await exec(c, 'UPDATE orders SET user_id = ? WHERE cfx_id = ? AND user_id IS NULL', [user.id, row.cfx_id]);
    return { id: user.id, cfxId: row.cfx_id, displayName: row.display_name };
  });
}

export const getUser = (db: Conn, id: number) =>
  one<{ id: number; cfx_id: string; display_name: string; created_at: Date }>(db, 'SELECT id, cfx_id, display_name, created_at FROM users WHERE id = ?', [id]);
