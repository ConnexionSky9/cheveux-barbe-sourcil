// Petits outils cryptographiques (Node natif).
import { createHash, createHmac, randomBytes, randomInt, randomUUID, timingSafeEqual } from 'node:crypto';

export const sha256 = (v: string | Buffer): string => createHash('sha256').update(v).digest('hex');
export const randomToken = (bytes = 32): string => randomBytes(bytes).toString('hex');
export const uuid = (): string => randomUUID();

/** Comparaison en temps constant de deux chaînes. */
export function safeEqual(a: string, b: string): boolean {
  const ba = Buffer.from(a, 'utf8');
  const bb = Buffer.from(b, 'utf8');
  if (ba.length !== bb.length) return false;
  return timingSafeEqual(ba, bb);
}

/** Code de liaison lisible (sans 0/O/1/I), 8 caractères. */
const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
export function linkCode(length = 8): string {
  let out = '';
  for (let i = 0; i < length; i++) out += ALPHABET[randomInt(ALPHABET.length)];
  return out;
}
export const normalizeCode = (c: string): string => c.toUpperCase().replace(/[^A-Z0-9]/g, '');

/**
 * Signature des webhooks Tebex : HMAC-SHA256( clé = secret du webhook, données = SHA-256 hex du corps brut ).
 * Le corps doit être le corps BRUT reçu (avant tout JSON.parse).
 */
export function tebexSignature(rawBody: Buffer | string, secret: string): string {
  const bodyHash = createHash('sha256').update(rawBody).digest('hex');
  return createHmac('sha256', secret).update(bodyHash).digest('hex');
}
export function verifyTebexSignature(rawBody: Buffer | string, header: string | undefined, secret: string): boolean {
  if (!header || !/^[a-f0-9]{64}$/i.test(header.trim())) return false;
  return safeEqual(tebexSignature(rawBody, secret), header.trim().toLowerCase());
}
