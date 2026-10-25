// Middlewares communs : sessions, CSRF, rôles admin, jeton du serveur de jeu, erreurs.
import type { NextFunction, Request, RequestHandler, Response } from 'express';
import { ZodError } from 'zod';
import type { AppConfig } from '../config.js';
import type { Db } from '../db.js';
import { HttpError, forbidden, unauthorized } from '../errors.js';
import { safeEqual } from '../security.js';
import { getAdmin, hasRole, type Admin, type Role } from '../services/admins.js';
import { COOKIE, readSession, type Session } from '../services/sessions.js';

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request { userSession?: Session | null; adminSession?: Session | null; admin?: Admin | null; rawBody?: Buffer }
  }
}

export type Handler = (req: Request, res: Response) => Promise<unknown>;
/** Enveloppe async : toute erreur part dans le gestionnaire central. */
export const h = (fn: Handler): RequestHandler => (req, res, next) => { fn(req, res).catch(next); };

export const clientIp = (req: Request): string => (req.ip ?? '').replace(/^::ffff:/, '');

export function loadSessions(pool: Db): RequestHandler {
  return (req, _res, next) => {
    Promise.all([
      readSession(pool, 'user', req.cookies?.[COOKIE.user]),
      readSession(pool, 'admin', req.cookies?.[COOKIE.admin]),
    ]).then(([u, a]) => { req.userSession = u; req.adminSession = a; next(); }).catch(next);
  };
}

/** Requêtes qui modifient quelque chose : l'en-tête X-CSRF-Token doit correspondre à la session. */
function csrfOk(req: Request, s: Session): boolean {
  const t = req.get('x-csrf-token');
  return typeof t === 'string' && safeEqual(t, s.csrf);
}

export const requireUser: RequestHandler = (req, _res, next) => {
  const s = req.userSession;
  if (!s?.userId) return next(unauthorized('Connectez-vous avec votre code de liaison.'));
  if (req.method !== 'GET' && !csrfOk(req, s)) return next(forbidden('Session expirée, rechargez la page.'));
  next();
};

export function requireAdmin(pool: Db, min: Role): RequestHandler {
  return (req, _res, next) => {
    const s = req.adminSession;
    if (!s?.adminId) return next(unauthorized('Connexion administrateur requise.'));
    if (req.method !== 'GET' && !csrfOk(req, s)) return next(forbidden('Session expirée, rechargez la page.'));
    getAdmin(pool, s.adminId).then((a) => {
      if (!a || !a.active) return next(unauthorized('Compte administrateur désactivé.'));
      if (!hasRole(a.role, min)) return next(forbidden('Votre rôle ne permet pas cette action.'));
      req.admin = a;
      next();
    }).catch(next);
  };
}

/** API réservée au serveur FiveM : jeton partagé (en-tête Authorization: Bearer) + liste d'IP facultative. */
export function requireGameServer(cfg: AppConfig): RequestHandler {
  return (req, _res, next) => {
    const auth = req.get('authorization') ?? '';
    const token = auth.startsWith('Bearer ') ? auth.slice(7).trim() : '';
    if (!token || !safeEqual(token, cfg.GAME_SERVER_TOKEN)) return next(unauthorized('Jeton du serveur de jeu invalide.'));
    if (cfg.GAME_SERVER_IPS.length && !cfg.GAME_SERVER_IPS.includes(clientIp(req))) return next(forbidden('Adresse du serveur de jeu non autorisée.'));
    next();
  };
}

export function errorHandler(log: (m: string) => void = console.error) {
  return (err: unknown, req: Request, res: Response, _next: NextFunction): void => {
    if (err instanceof HttpError) { res.status(err.status).json({ error: err.message, code: err.code }); return; }
    if (err instanceof ZodError) {
      res.status(400).json({ error: 'Données invalides.', code: 'validation', fields: err.issues.map((i) => ({ path: i.path.join('.'), message: i.message })) });
      return;
    }
    const e = err as { type?: string; status?: number };
    if (e?.type === 'entity.parse.failed' || e?.type === 'entity.too.large') { res.status(e.status ?? 400).json({ error: 'Requête invalide.', code: 'bad_body' }); return; }
    // Erreur inattendue : détail dans les journaux du serveur seulement
    log(`[api] ${req.method} ${req.path} : ${err instanceof Error ? err.stack ?? err.message : String(err)}`);
    res.status(500).json({ error: 'Erreur interne. Réessayez plus tard.', code: 'internal' });
  };
}
