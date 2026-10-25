// Client de l'API Headless de Tebex (https://headless.tebex.io).
// Chemins et champs vérifiés sur le client officiel communautaire « tebex_headless » (npm) :
//   GET  /api/accounts/{token}/categories?includePackages=1
//   POST /api/accounts/{token}/baskets                 { complete_url, cancel_url, custom, complete_auto_redirect }
//   GET  /api/accounts/{token}/baskets/{ident}
//   GET  /api/accounts/{token}/baskets/{ident}/auth?returnUrl=...   → [{ name, url }]
//   POST /api/baskets/{ident}/packages                 { package_id, quantity }
// La clé privée (facultative) n'est utilisée que côté serveur, en authentification Basic.

export interface TebexPackage { id: number; name: string; description?: string; base_price: number; total_price: number; currency: string; image: string | null; type?: string; category?: { id: number; name: string } }
export interface TebexCategory { id: number; name: string; packages: TebexPackage[] | null }
export interface TebexBasket {
  ident: string; complete: boolean; username_id: number | string | null; username: string | null;
  total_price: number; currency: string; packages: { id: number; name: string; in_basket: { quantity: number; price: number } }[];
  links: { checkout: string; payment?: string }; custom: Record<string, unknown> | null;
}
export interface TebexAuthLink { name: string; url: string }

export interface TebexClient {
  listCategories(): Promise<TebexCategory[]>;
  createBasket(input: { completeUrl: string; cancelUrl: string; custom: Record<string, string>; ip?: string }): Promise<TebexBasket>;
  getBasket(ident: string): Promise<TebexBasket>;
  getAuthLinks(ident: string, returnUrl: string): Promise<TebexAuthLink[]>;
  addPackage(ident: string, packageId: number, quantity: number): Promise<TebexBasket>;
}

export class TebexError extends Error {
  constructor(public readonly status: number, public readonly body: unknown) {
    super(`Tebex a répondu ${status}`);
    this.name = 'TebexError';
  }
}

const BASE_URL = 'https://headless.tebex.io';

export class HttpTebexClient implements TebexClient {
  constructor(private readonly token: string, private readonly privateKey = '', private readonly timeoutMs = 10_000) {}

  private async call<T>(method: string, path: string, opts: { query?: Record<string, string>; body?: unknown } = {}): Promise<T> {
    const url = new URL(BASE_URL + path);
    for (const [k, v] of Object.entries(opts.query ?? {})) url.searchParams.set(k, v);
    const headers: Record<string, string> = { Accept: 'application/json', 'Content-Type': 'application/json' };
    if (this.privateKey) headers.Authorization = `Basic ${Buffer.from(`${this.token}:${this.privateKey}`).toString('base64')}`;
    const res = await fetch(url, { method, headers, body: opts.body === undefined ? undefined : JSON.stringify(opts.body), signal: AbortSignal.timeout(this.timeoutMs) });
    const text = await res.text();
    let data: unknown = undefined;
    try { data = text ? JSON.parse(text) : undefined; } catch { data = text; }
    if (!res.ok) throw new TebexError(res.status, data);
    return data as T;
  }
  private acct(): string { return `/api/accounts/${encodeURIComponent(this.token)}`; }

  async listCategories(): Promise<TebexCategory[]> {
    return (await this.call<{ data: TebexCategory[] }>('GET', `${this.acct()}/categories`, { query: { includePackages: '1' } })).data;
  }
  async createBasket(i: { completeUrl: string; cancelUrl: string; custom: Record<string, string>; ip?: string }): Promise<TebexBasket> {
    return (await this.call<{ data: TebexBasket }>('POST', `${this.acct()}/baskets`, {
      query: i.ip ? { ip_address: i.ip } : {},
      body: { complete_url: i.completeUrl, cancel_url: i.cancelUrl, custom: i.custom, complete_auto_redirect: true },
    })).data;
  }
  async getBasket(ident: string): Promise<TebexBasket> {
    return (await this.call<{ data: TebexBasket }>('GET', `${this.acct()}/baskets/${encodeURIComponent(ident)}`)).data;
  }
  async getAuthLinks(ident: string, returnUrl: string): Promise<TebexAuthLink[]> {
    const r = await this.call<TebexAuthLink[] | { data: TebexAuthLink[] }>('GET', `${this.acct()}/baskets/${encodeURIComponent(ident)}/auth`, { query: { returnUrl } });
    return Array.isArray(r) ? r : r.data;
  }
  async addPackage(ident: string, packageId: number, quantity: number): Promise<TebexBasket> {
    return (await this.call<{ data: TebexBasket }>('POST', `/api/baskets/${encodeURIComponent(ident)}/packages`, { body: { package_id: packageId, quantity } })).data;
  }
}

export const toCents = (amount: number | string | null | undefined): number => Math.round(Number(amount ?? 0) * 100);
