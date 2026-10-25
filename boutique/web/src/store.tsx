// État global du site : configuration, catalogue, session joueur, panier, notifications.
import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import { api, setUserCsrf, type Catalog, type SiteConfig, type User } from './api';

export interface CartLine { productId: number; quantity: number }
interface Toast { id: number; kind: 'success' | 'error' | 'info'; text: string }

interface Store {
  config: SiteConfig | null;
  catalog: Catalog | null;
  catalogError: string | null;
  reloadCatalog: () => void;
  user: User | null;
  sessionReady: boolean;
  setSession: (u: User | null, csrf: string | null) => void;
  cart: CartLine[];
  addToCart: (productId: number, quantity?: number) => void;
  setQuantity: (productId: number, quantity: number) => void;
  removeFromCart: (productId: number) => void;
  clearCart: () => void;
  toasts: Toast[];
  notify: (text: string, kind?: Toast['kind']) => void;
}

const Ctx = createContext<Store | null>(null);
const CART_KEY = 'elyzea-boutique-panier';

function loadCart(): CartLine[] {
  try {
    const raw = JSON.parse(localStorage.getItem(CART_KEY) ?? '[]') as unknown;
    if (!Array.isArray(raw)) return [];
    return raw.filter((l): l is CartLine => Number.isInteger(l?.productId) && Number.isInteger(l?.quantity) && l.quantity > 0).slice(0, 10);
  } catch { return []; }
}

export function StoreProvider({ children }: { children: ReactNode }) {
  const [config, setConfig] = useState<SiteConfig | null>(null);
  const [catalog, setCatalog] = useState<Catalog | null>(null);
  const [catalogError, setCatalogError] = useState<string | null>(null);
  const [user, setUser] = useState<User | null>(null);
  const [sessionReady, setSessionReady] = useState(false);
  const [cart, setCart] = useState<CartLine[]>(loadCart);
  const [toasts, setToasts] = useState<Toast[]>([]);

  const notify = useCallback((text: string, kind: Toast['kind'] = 'info') => {
    const id = Date.now() + Math.random();
    setToasts((t) => [...t.slice(-3), { id, kind, text }]);
    setTimeout(() => setToasts((t) => t.filter((x) => x.id !== id)), 4500);
  }, []);

  const reloadCatalog = useCallback(() => {
    setCatalogError(null);
    api.get<Catalog>('/api/catalog').then(setCatalog).catch((e: Error) => setCatalogError(e.message));
  }, []);

  useEffect(() => {
    api.get<SiteConfig>('/api/config').then(setConfig).catch(() => setConfig({ serverName: 'Elyzea', currency: 'EUR', discordUrl: null, supportEmail: null }));
    reloadCatalog();
    api.get<{ user: User | null; csrfToken: string | null }>('/api/session')
      .then((s) => { setUser(s.user); setUserCsrf(s.csrfToken); })
      .catch(() => undefined)
      .finally(() => setSessionReady(true));
  }, [reloadCatalog]);

  useEffect(() => { try { localStorage.setItem(CART_KEY, JSON.stringify(cart)); } catch { /* navigation privée */ } }, [cart]);

  // Panier : on retire ce qui n'existe plus ou n'est plus achetable dans le catalogue
  useEffect(() => {
    if (!catalog) return;
    setCart((c) => c.filter((l) => catalog.products.some((p) => p.id === l.productId && p.available)));
  }, [catalog]);

  const setSession = useCallback((u: User | null, csrf: string | null) => { setUser(u); setUserCsrf(csrf); }, []);

  const value = useMemo<Store>(() => ({
    config, catalog, catalogError, reloadCatalog, user, sessionReady, setSession, toasts, notify, cart,
    addToCart: (productId, quantity = 1) => setCart((c) => {
      const max = catalog?.products.find((p) => p.id === productId)?.maxQuantity ?? 1;
      const cur = c.find((l) => l.productId === productId);
      if (cur) return c.map((l) => (l.productId === productId ? { ...l, quantity: Math.min(max, l.quantity + quantity) } : l));
      if (c.length >= 10) return c;
      return [...c, { productId, quantity: Math.min(max, quantity) }];
    }),
    setQuantity: (productId, quantity) => setCart((c) => c.map((l) => (l.productId === productId ? { ...l, quantity: Math.max(1, quantity) } : l))),
    removeFromCart: (productId) => setCart((c) => c.filter((l) => l.productId !== productId)),
    clearCart: () => setCart([]),
  }), [config, catalog, catalogError, reloadCatalog, user, sessionReady, setSession, toasts, notify, cart]);

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useStore(): Store {
  const s = useContext(Ctx);
  if (!s) throw new Error('StoreProvider manquant');
  return s;
}
