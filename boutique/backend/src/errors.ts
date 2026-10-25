// Erreurs métier : le message est montré à l'utilisateur, jamais les détails techniques.
export class HttpError extends Error {
  constructor(public readonly status: number, message: string, public readonly code = 'error') {
    super(message);
    this.name = 'HttpError';
  }
}

export const badRequest = (m: string, code = 'bad_request') => new HttpError(400, m, code);
export const unauthorized = (m = 'Connexion requise.') => new HttpError(401, m, 'unauthorized');
export const forbidden = (m = 'Accès refusé.') => new HttpError(403, m, 'forbidden');
export const notFound = (m = 'Introuvable.') => new HttpError(404, m, 'not_found');
export const conflict = (m: string, code = 'conflict') => new HttpError(409, m, code);
