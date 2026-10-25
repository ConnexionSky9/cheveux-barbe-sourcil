// Sessions côté serveur : le navigateur ne reçoit qu'un jeton aléatoire (cookie HttpOnly),
// la base ne garde que son hachage. Chaque session a son propre jeton anti-CSRF.
import type { Conn } from '../db.js';
import { exec, one } from '../db.js';
import { randomToken, sha256 } from '../security.js';

export type SessionKind = 'user' | 'admin';
export interface Session { kind: SessionKind; userId: number | null; adminId: number | null; csrf: string; tokenHash: string }

export const SESSION_TTL: Record<SessionKind, number> = { user: 7 * 24 * 3600_000, admin: 8 * 3600_000 };
export const COOKIE: Record<SessionKind, string> = { user: 'eb_session', admin: 'eb_admin' };

export async function createSession(db: Conn, kind: SessionKind, ownerId: number, ip: string | null): Promise<{ token: string; csrf: string; expires: Date }> {
  const token = randomToken(32);
  const csrf = randomToken(32);
  const expires = new Date(Date.now() + SESSION_TTL[kind]);
  await exec(db,
    'INSERT INTO sessions (token_hash, kind, user_id, admin_id, csrf_token, ip, expires_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
    [sha256(token), kind, kind === 'user' ? ownerId : null, kind === 'admin' ? ownerId : null, csrf, ip, expires]);
  return { token, csrf, expires };
}

export async function readSession(db: Conn, kind: SessionKind, token: string | undefined): Promise<Session | null> {
  if (!token || !/^[a-f0-9]{64}$/.test(token)) return null;
  const r = await one<{ token_hash: string; user_id: number | null; admin_id: number | null; csrf_token: string }>(db,
    'SELECT token_hash, user_id, admin_id, csrf_token FROM sessions WHERE token_hash = ? AND kind = ? AND expires_at > UTC_TIMESTAMP()',
    [sha256(token), kind]);
  if (!r) return null;
  return { kind, userId: r.user_id, adminId: r.admin_id, csrf: r.csrf_token, tokenHash: r.token_hash };
}

export const destroySession = (db: Conn, tokenHash: string) => exec(db, 'DELETE FROM sessions WHERE token_hash = ?', [tokenHash]);
export const purgeExpiredSessions = (db: Conn) => exec(db, 'DELETE FROM sessions WHERE expires_at <= UTC_TIMESTAMP()');
