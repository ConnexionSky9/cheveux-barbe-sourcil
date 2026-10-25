// Appels à l'API : même origine, cookies HttpOnly, jeton CSRF en en-tête pour les modifications.
export class ApiError extends Error {
  constructor(public status: number, message: string, public code = 'error', public fields?: { path: string; message: string }[]) { super(message); }
}

let userCsrf: string | null = null;
let adminCsrf: string | null = null;
export const setUserCsrf = (t: string | null) => { userCsrf = t; };
export const setAdminCsrf = (t: string | null) => { adminCsrf = t; };

async function call<T>(method: string, url: string, body?: unknown): Promise<T> {
  const headers: Record<string, string> = { Accept: 'application/json' };
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  const csrf = url.startsWith('/api/admin') ? adminCsrf : userCsrf;
  if (method !== 'GET' && csrf) headers['X-CSRF-Token'] = csrf;
  let res: Response;
  try {
    res = await fetch(url, { method, headers, credentials: 'same-origin', body: body === undefined ? undefined : JSON.stringify(body) });
  } catch {
    throw new ApiError(0, 'Connexion au serveur impossible. Vérifiez votre connexion internet.', 'network');
  }
  const data = res.status === 204 ? null : await res.json().catch(() => null);
  if (!res.ok) throw new ApiError(res.status, data?.error ?? 'Erreur inattendue.', data?.code, data?.fields);
  return data as T;
}

export const api = {
  get: <T>(url: string) => call<T>('GET', url),
  post: <T>(url: string, body?: unknown) => call<T>('POST', url, body ?? {}),
  patch: <T>(url: string, body: unknown) => call<T>('PATCH', url, body),
  put: <T>(url: string, body: unknown) => call<T>('PUT', url, body),
  del: <T>(url: string) => call<T>('DELETE', url),
};

// ---- Types partagés avec l'API ----
export interface Category { id: number; slug: string; name: string; description: string; icon: string; sort: number; active: boolean }
export interface Product {
  id: number; slug: string; name: string; shortDescription: string; description: string; imageUrl: string;
  priceCents: number; currency: string; durationDays: number | null; maxQuantity: number; perks: string[];
  category: { id: number; slug: string; name: string }; featured: boolean; popular: boolean; available: boolean; sort: number;
}
export interface Catalog { categories: Category[]; products: Product[] }
export interface SiteConfig { serverName: string; currency: string; discordUrl: string | null; supportEmail: string | null }
export interface User { id: number; displayName: string; cfxId: string }
export interface HistoryItem { name: string; quantity: number; unitPriceCents: number; delivery: 'delivered' | 'pending' | 'failed' | 'cancelled' | 'none'; expiresAt: string | null }
export interface HistoryOrder { ref: string; status: string; totalCents: number; currency: string; createdAt: string; paidAt: string | null; source: string; items: HistoryItem[] }

export function money(cents: number, currency = 'EUR'): string {
  return new Intl.NumberFormat('fr-FR', { style: 'currency', currency }).format(cents / 100);
}
export function duration(days: number | null): string {
  if (!days) return 'Permanent';
  if (days % 30 === 0) return `${days / 30} mois`;
  return `${days} jour${days > 1 ? 's' : ''}`;
}
export const dateFr = (d: string | Date | null) => (d ? new Date(d).toLocaleString('fr-FR', { dateStyle: 'medium', timeStyle: 'short' }) : '—');

export const ORDER_STATUS: Record<string, { label: string; tone: string }> = {
  pending: { label: 'En attente de paiement', tone: 'badge-amber' },
  paid: { label: 'Payée', tone: 'badge-green' },
  failed: { label: 'Paiement refusé', tone: 'badge-red' },
  cancelled: { label: 'Annulée', tone: 'badge-muted' },
  refunded: { label: 'Remboursée', tone: 'badge-blue' },
  chargeback: { label: 'Litige bancaire', tone: 'badge-red' },
};
export const DELIVERY_STATUS: Record<string, { label: string; tone: string }> = {
  delivered: { label: 'Livré en jeu', tone: 'badge-green' },
  pending: { label: 'Livraison à la prochaine connexion', tone: 'badge-amber' },
  failed: { label: 'Livraison en échec — contactez le support', tone: 'badge-red' },
  cancelled: { label: 'Annulé', tone: 'badge-muted' },
  none: { label: '—', tone: 'badge-muted' },
};
