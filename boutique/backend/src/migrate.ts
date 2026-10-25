// Applique les migrations SQL (database/migrations/NNN_nom.sql) dans l'ordre, une seule fois chacune.
import { readdirSync, readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import mysql from 'mysql2/promise';

export const MIGRATIONS_DIR = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..', 'database', 'migrations');

export async function migrate(databaseUrl: string, log: (m: string) => void = console.log): Promise<string[]> {
  const conn = await mysql.createConnection({ uri: databaseUrl, multipleStatements: true, timezone: 'Z', charset: 'utf8mb4' });
  try {
    await conn.query(`CREATE TABLE IF NOT EXISTS schema_migrations (
      version VARCHAR(128) NOT NULL PRIMARY KEY,
      applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`);
    const [done] = await conn.query<mysql.RowDataPacket[]>('SELECT version FROM schema_migrations');
    const applied = new Set(done.map((r) => String(r.version)));
    const files = readdirSync(MIGRATIONS_DIR).filter((f) => /^\d+_.+\.sql$/.test(f)).sort();
    const ran: string[] = [];
    for (const file of files) {
      if (applied.has(file)) continue;
      log(`→ migration ${file}`);
      await conn.query(readFileSync(join(MIGRATIONS_DIR, file), 'utf8'));
      await conn.query('INSERT INTO schema_migrations (version) VALUES (?)', [file]);
      ran.push(file);
    }
    if (!ran.length) log('Base de données à jour.');
    return ran;
  } finally {
    await conn.end();
  }
}
