// Accès MySQL / MariaDB (mysql2, requêtes préparées uniquement).
import mysql from 'mysql2/promise';
import type { Pool, PoolConnection, ResultSetHeader, RowDataPacket } from 'mysql2/promise';

export type Db = Pool;
export type Conn = Pool | PoolConnection;
export type Row = RowDataPacket;

export function createPool(url: string): Pool {
  return mysql.createPool({
    uri: url,
    connectionLimit: 10,
    waitForConnections: true,
    timezone: 'Z',             // toutes les dates en UTC
    dateStrings: false,
    supportBigNumbers: true,
    bigNumberStrings: false,
    charset: 'utf8mb4',
  });
}

export async function rows<T = Row>(db: Conn, sql: string, params: unknown[] = []): Promise<T[]> {
  const [r] = await db.query<RowDataPacket[]>(sql, params);
  return r as unknown as T[];
}

export async function one<T = Row>(db: Conn, sql: string, params: unknown[] = []): Promise<T | null> {
  const r = await rows<T>(db, sql, params);
  return r[0] ?? null;
}

export async function exec(db: Conn, sql: string, params: unknown[] = []): Promise<ResultSetHeader> {
  const [r] = await db.query<ResultSetHeader>(sql, params);
  return r;
}

/** Exécute fn dans une transaction (COMMIT si tout va bien, ROLLBACK sinon). */
export async function tx<T>(pool: Pool, fn: (conn: PoolConnection) => Promise<T>): Promise<T> {
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const out = await fn(conn);
    await conn.commit();
    return out;
  } catch (err) {
    await conn.rollback().catch(() => undefined);
    throw err;
  } finally {
    conn.release();
  }
}

/** Les colonnes JSON arrivent déjà décodées avec mysql2 sous MySQL, en texte sous MariaDB. */
export function json<T>(v: unknown, fallback: T): T {
  if (v === null || v === undefined) return fallback;
  if (typeof v === 'string') {
    try { return JSON.parse(v) as T; } catch { return fallback; }
  }
  return v as T;
}
