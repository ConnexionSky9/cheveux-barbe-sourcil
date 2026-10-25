// Panel d'administration : chaque action est vérifiée côté serveur (session, rôle, CSRF).
// Les liens masqués selon le rôle ne sont qu'un confort d'affichage, pas une protection.
import { createContext, useContext, useEffect, useState, type FormEvent } from 'react';
import { Link, NavLink, Navigate, Route, Routes } from 'react-router-dom';
import { api, ApiError, setAdminCsrf } from '../api';
import { Icon } from '../components/Icon';
import { Loading, Toasts } from '../components/ui';
import { Categories, Dashboard, Deliveries, Logs, OrderDetail, Orders, Webhooks } from './pages';
import { Admins } from './Admins';
import { ProductEdit, Products } from './Products';

export type Role = 'owner' | 'admin' | 'support';
export interface AdminUser { id: number; username: string; role: Role }
const Ctx = createContext<AdminUser | null>(null);
export const useAdmin = () => useContext(Ctx)!;
export const can = (a: AdminUser, min: Role) => ({ support: 1, admin: 2, owner: 3 })[a.role] >= ({ support: 1, admin: 2, owner: 3 })[min];

function Login({ onDone }: { onDone: (a: AdminUser) => void }) {
  const [username, setU] = useState('');
  const [password, setP] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  async function submit(e: FormEvent) {
    e.preventDefault(); setBusy(true); setError(null);
    try {
      const r = await api.post<{ admin: AdminUser; csrfToken: string }>('/api/admin/login', { username, password });
      setAdminCsrf(r.csrfToken); onDone(r.admin);
    } catch (err) { setError(err instanceof ApiError ? err.message : 'Erreur.'); } finally { setBusy(false); }
  }
  return (
    <div className="admin-login">
      <form className="panel panel-pad" onSubmit={submit}>
        <img src="/images/logo-192.webp" alt="" width={72} height={72} style={{ margin: '0 auto 1rem' }} />
        <h2 style={{ textAlign: 'center' }}>Administration</h2>
        <div className="field"><label htmlFor="u">Identifiant</label><input id="u" className="input" autoComplete="username" value={username} onChange={(e) => setU(e.target.value)} required /></div>
        <div className="field"><label htmlFor="p">Mot de passe</label><input id="p" className="input" type="password" autoComplete="current-password" value={password} onChange={(e) => setP(e.target.value)} required /></div>
        {error && <p className="alert alert-error small" role="alert">{error}</p>}
        <button className="btn btn-primary btn-block" disabled={busy}>{busy ? 'Connexion…' : 'Se connecter'}</button>
        <p className="muted small" style={{ marginTop: '1rem', textAlign: 'center' }}><Link to="/">Retour au site</Link></p>
      </form>
    </div>
  );
}

export default function AdminApp() {
  const [admin, setAdmin] = useState<AdminUser | null | undefined>(undefined);
  useEffect(() => {
    api.get<{ admin: AdminUser; csrfToken: string }>('/api/admin/me')
      .then((r) => { setAdminCsrf(r.csrfToken); setAdmin(r.admin); })
      .catch(() => setAdmin(null));
  }, []);
  if (admin === undefined) return <Loading />;
  if (!admin) return <><Login onDone={setAdmin} /><Toasts /></>;

  async function logout() { await api.post('/api/admin/logout').catch(() => undefined); setAdminCsrf(null); setAdmin(null); }
  const links: [string, string, Role][] = [
    ['', 'Tableau de bord', 'support'], ['produits', 'Produits', 'support'], ['categories', 'Catégories', 'support'], ['commandes', 'Commandes', 'support'],
    ['livraisons', 'Livraisons', 'support'], ['webhooks', 'Notifications Tebex', 'support'], ['journaux', 'Journaux', 'support'], ['administrateurs', 'Administrateurs', 'owner'],
  ];
  return (
    <Ctx.Provider value={admin}>
      <div className="admin">
        <aside className="admin-side">
          <Link to="/" className="brand"><img src="/images/logo-192.webp" alt="" width={36} height={36} /><span><strong>Elyzea</strong><small>Administration</small></span></Link>
          <nav>{links.filter(([, , r]) => can(admin, r)).map(([to, label]) => <NavLink key={to} end to={`/admin/${to}`}>{label}</NavLink>)}</nav>
          <div className="admin-me"><Icon name="user" size={16} /> {admin.username} <span className="badge badge-muted">{admin.role}</span><button className="btn btn-sm btn-ghost" onClick={logout}>Déconnexion</button></div>
        </aside>
        <section className="admin-main">
          <Routes>
            <Route index element={<Dashboard />} />
            <Route path="produits" element={<Products />} />
            <Route path="produits/:id" element={<ProductEdit />} />
            <Route path="categories" element={<Categories />} />
            <Route path="commandes" element={<Orders />} />
            <Route path="commandes/:id" element={<OrderDetail />} />
            <Route path="livraisons" element={<Deliveries />} />
            <Route path="webhooks" element={<Webhooks />} />
            <Route path="journaux" element={<Logs />} />
            <Route path="administrateurs" element={can(admin, 'owner') ? <Admins /> : <Navigate to="/admin" />} />
            <Route path="*" element={<Navigate to="/admin" />} />
          </Routes>
        </section>
        <Toasts />
      </div>
    </Ctx.Provider>
  );
}
