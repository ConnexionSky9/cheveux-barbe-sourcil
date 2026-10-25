// Journal des actions sensibles et des erreurs (table audit_logs). Ne jamais y mettre de secret.
import type { Conn } from '../db.js';
import { exec } from '../db.js';

export type ActorType = 'admin' | 'user' | 'game' | 'webhook' | 'system';
export type Level = 'info' | 'warn' | 'error';

export interface AuditEntry {
  level?: Level;
  actorType: ActorType;
  actorId?: string | number | null;
  action: string;
  target?: string | null;
  details?: Record<string, unknown> | null;
  ip?: string | null;
}

export async function audit(db: Conn, e: AuditEntry): Promise<void> {
  try {
    await exec(db,
      'INSERT INTO audit_logs (level, actor_type, actor_id, action, target, details, ip) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [e.level ?? 'info', e.actorType, e.actorId == null ? null : String(e.actorId), e.action.slice(0, 64),
        e.target == null ? null : String(e.target).slice(0, 96), e.details ? JSON.stringify(e.details) : null, e.ip ?? null]);
  } catch (err) {
    // Le journal ne doit jamais faire échouer l'action elle-même
    console.error('[audit] écriture impossible :', err instanceof Error ? err.message : err);
  }
}
