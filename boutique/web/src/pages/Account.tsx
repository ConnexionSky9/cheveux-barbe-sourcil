import { useEffect, useState } from 'react';
import { Link, Navigate } from 'react-router-dom';
import { api, ApiError, dateFr, DELIVERY_STATUS, money, ORDER_STATUS, type HistoryOrder } from '../api';
import { Empty, ErrorBox, Loading, PageHead } from '../components/ui';
import { useStore } from '../store';

interface Entitlement { type: string; name: string; expiresAt: string | null; product: string }

export default function Account() {
  const { user, sessionReady, setSession, notify } = useStore();
  const [orders, setOrders] = useState<HistoryOrder[] | null>(null);
  const [ents, setEnts] = useState<Entitlement[]>([]);
  const [error, setError] = useState<string | null>(null);

  const load = () => {
    setError(null);
    Promise.all([api.get<HistoryOrder[]>('/api/account/orders'), api.get<Entitlement[]>('/api/account/entitlements')])
      .then(([o, e]) => { setOrders(o); setEnts(e); })
      .catch((e: ApiError) => setError(e.message));
  };
  useEffect(() => { if (user) load(); }, [user]);

  if (!sessionReady) return <Loading />;
  if (!user) return <Navigate to="/connexion?retour=/compte" replace />;

  async function logout() {
    await api.post('/api/auth/logout').catch(() => undefined);
    setSession(null, null);
    notify('Déconnecté.', 'info');
  }

  return (
    <>
      <PageHead eyebrow="Mon compte" title={user.displayName}>Compte FiveM lié : <code>fivem:{user.cfxId}</code></PageHead>
      <div className="container section">
        <div className="row-gap" style={{ marginBottom: '1.5rem' }}><Link to="/boutique" className="btn btn-sm">Boutique</Link><button className="btn btn-sm btn-ghost" onClick={logout}>Se déconnecter</button></div>
        <h2>Avantages actifs</h2>
        {ents.length === 0 ? <p className="muted">Aucun grade ou avantage actif.</p> : (
          <div className="ent-grid">{ents.map((e, i) => (
            <div key={i} className="panel panel-pad"><strong>{e.product}</strong><div className="muted small">{e.expiresAt ? `Jusqu'au ${dateFr(e.expiresAt)}` : 'Permanent'}</div></div>
          ))}</div>
        )}
        <h2 style={{ marginTop: '2.5rem' }}>Historique des achats</h2>
        {error && <ErrorBox message={error} onRetry={load} />}
        {!orders && !error && <Loading />}
        {orders && orders.length === 0 && <Empty icon="cart" title="Aucun achat pour le moment"><Link to="/boutique" className="btn btn-primary">Découvrir la boutique</Link></Empty>}
        {orders && orders.length > 0 && (
          <div className="orders">
            {orders.map((o) => (
              <article key={o.ref} className="panel panel-pad order">
                <header>
                  <div><strong>{dateFr(o.createdAt)}</strong><div className="muted small">Réf. {o.ref.slice(0, 8)}</div></div>
                  <span className={`badge ${ORDER_STATUS[o.status]?.tone ?? 'badge-muted'}`}>{ORDER_STATUS[o.status]?.label ?? o.status}</span>
                  <strong className="price-sm">{money(o.totalCents, o.currency)}</strong>
                </header>
                <ul>{o.items.map((i, k) => (
                  <li key={k}>
                    <span>{i.quantity} × {i.name}{i.expiresAt ? <span className="muted small"> — jusqu'au {dateFr(i.expiresAt)}</span> : null}</span>
                    {o.status === 'paid' && <span className={`badge ${DELIVERY_STATUS[i.delivery]?.tone}`}>{DELIVERY_STATUS[i.delivery]?.label}</span>}
                  </li>
                ))}</ul>
                {o.status === 'pending' && <Link to={`/commande/${o.ref}`} className="small">Suivre cette commande</Link>}
              </article>
            ))}
          </div>
        )}
      </div>
    </>
  );
}
