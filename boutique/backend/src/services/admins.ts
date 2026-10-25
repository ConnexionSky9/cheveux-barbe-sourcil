// Comptes administrateurs : mots de passe bcrypt, verrouillage après échecs répétés, rôles.
import bcrypt from 'bcryptjs';
import type { Conn, Db } from '../db.js';
import { exec, one, rows } from '../db.js';
import { badRequest, conflict, notFound } from '../errors.js';

export type Role = 'owner' | 'admin' | 'support';
export interface Admin { id: number; username: string; role: Role; active: number; last_login_at: Date | null; created_at: Date }

/** Ce que chaque rôle peut faire. Vérifié côté serveur sur chaque route. */
export const ROLE_RANK: Record<Role, number> = { support: 1, admin: 2, owner: 3 };
export const hasRole = (role: Role, min: Role): boolean => ROLE_RANK[role] >= ROLE_RANK[min];

const USERNAME = /^[a-zA-Z0-9_.-]{3,32}$/;
const MAX_FAILS = 5;
const LOCK_MINUTES = 15;
// Hachage factice : même durée de vérification quand l'identifiant n'existe pas
const DUMMY_HASH = bcrypt.hashSync('elyzea-dummy-password', 12);

function checkPassword(pw: string): void {
  if (typeof pw !== 'string' || pw.length < 12 || pw.length > 128) throw badRequest('Le mot de passe doit faire entre 12 et 128 caractères.');
}

export async function upsertAdmin(db: Db, username: string, password: string, role: Role): Promise<void> {
  if (!USERNAME.test(username)) throw badRequest('Identifiant invalide (3 à 32 caractères : lettres, chiffres, _ . -).');
  checkPassword(password);
  const hash = await bcrypt.hash(password, 12);
  await exec(db,
    `INSERT INTO admins (username, password_hash, role, active) VALUES (?, ?, ?, 1)
     ON DUPLICATE KEY UPDATE password_hash = VALUES(password_hash), role = VALUES(role), active = 1, failed_attempts = 0, locked_until = NULL`,
    [username, hash, role]);
}

export async function verifyLogin(db: Db, username: string, password: string): Promise<{ ok: true; admin: Admin } | { ok: false; reason: 'invalid' | 'locked' }> {
  const row = await one<Admin & { password_hash: string; failed_attempts: number; locked_until: Date | null }>(db,
    'SELECT * FROM admins WHERE username = ? LIMIT 1', [String(username)]);
  if (!row || !row.active) {
    await bcrypt.compare(String(password), DUMMY_HASH);
    return { ok: false, reason: 'invalid' };
  }
  if (row.locked_until && new Date(row.locked_until).getTime() > Date.now()) return { ok: false, reason: 'locked' };
  const good = await bcrypt.compare(String(password), row.password_hash);
  if (!good) {
    const fails = row.failed_attempts + 1;
    await exec(db, 'UPDATE admins SET failed_attempts = ?, locked_until = ? WHERE id = ?',
      [fails >= MAX_FAILS ? 0 : fails, fails >= MAX_FAILS ? new Date(Date.now() + LOCK_MINUTES * 60_000) : null, row.id]);
    return { ok: false, reason: fails >= MAX_FAILS ? 'locked' : 'invalid' };
  }
  await exec(db, 'UPDATE admins SET failed_attempts = 0, locked_until = NULL, last_login_at = UTC_TIMESTAMP() WHERE id = ?', [row.id]);
  return { ok: true, admin: { id: row.id, username: row.username, role: row.role, active: row.active, last_login_at: row.last_login_at, created_at: row.created_at } };
}

export const getAdmin = (db: Conn, id: number) =>
  one<Admin>(db, 'SELECT id, username, role, active, last_login_at, created_at FROM admins WHERE id = ?', [id]);

export const listAdmins = (db: Conn) =>
  rows<Admin>(db, 'SELECT id, username, role, active, last_login_at, created_at FROM admins ORDER BY id');

export async function updateAdmin(db: Db, actorId: number, id: number, patch: { role?: Role; active?: boolean; password?: string }): Promise<void> {
  const target = await getAdmin(db, id);
  if (!target) throw notFound('Administrateur introuvable.');
  const demoting = (patch.role && patch.role !== 'owner') || patch.active === false;
  if (target.role === 'owner' && demoting) {
    const owners = await one<{ n: number }>(db, "SELECT COUNT(*) AS n FROM admins WHERE role = 'owner' AND active = 1");
    if ((owners?.n ?? 0) <= 1) throw conflict('Impossible : il doit rester au moins un propriétaire actif.');
  }
  if (id === actorId && patch.active === false) throw conflict('Vous ne pouvez pas désactiver votre propre compte.');
  if (patch.role) await exec(db, 'UPDATE admins SET role = ? WHERE id = ?', [patch.role, id]);
  if (patch.active !== undefined) {
    await exec(db, 'UPDATE admins SET active = ? WHERE id = ?', [patch.active ? 1 : 0, id]);
    if (!patch.active) await exec(db, 'DELETE FROM sessions WHERE admin_id = ?', [id]);
  }
  if (patch.password) {
    checkPassword(patch.password);
    await exec(db, 'UPDATE admins SET password_hash = ?, failed_attempts = 0, locked_until = NULL WHERE id = ?', [await bcrypt.hash(patch.password, 12), id]);
    await exec(db, 'DELETE FROM sessions WHERE admin_id = ?', [id]);
  }
}
