// Réception des notifications Tebex. Ordre des contrôles :
// 1. adresse IP (si TEBEX_WEBHOOK_IPS est renseigné), 2. signature X-Signature sur le corps BRUT,
// 3. traitement idempotent (services/payments.ts). Un retour du navigateur n'est jamais une preuve de paiement.
import express, { Router } from 'express';
import type { AppConfig } from '../config.js';
import type { Db } from '../db.js';
import { clientIp, h } from '../http/middleware.js';
import { audit } from '../services/audit.js';
import { handleTebexWebhook } from '../services/payments.js';
import { verifyTebexSignature } from '../security.js';

export function webhookRoutes(pool: Db, cfg: AppConfig): Router {
  const r = Router();
  r.post('/tebex', express.raw({ type: '*/*', limit: '512kb' }), h(async (q, s) => {
    const ip = clientIp(q);
    if (cfg.TEBEX_WEBHOOK_IPS.length && !cfg.TEBEX_WEBHOOK_IPS.includes(ip)) {
      await audit(pool, { level: 'warn', actorType: 'webhook', action: 'webhook.bad_ip', ip });
      return s.status(403).json({ error: 'forbidden' });
    }
    const raw = Buffer.isBuffer(q.body) ? q.body : Buffer.alloc(0);
    if (!verifyTebexSignature(raw, q.get('x-signature'), cfg.TEBEX_WEBHOOK_SECRET)) {
      await audit(pool, { level: 'warn', actorType: 'webhook', action: 'webhook.bad_signature', ip });
      return s.status(401).json({ error: 'invalid signature' });
    }
    let payload: unknown;
    try { payload = JSON.parse(raw.toString('utf8')); } catch { return s.status(400).json({ error: 'invalid json' }); }
    const result = await handleTebexWebhook(pool, payload);
    s.status(result.httpStatus).json(result.body);
  }));
  return r;
}
