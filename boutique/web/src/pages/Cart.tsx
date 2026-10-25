import { useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { api, ApiError, duration, money } from '../api';
import { Icon } from '../components/Icon';
import { Empty, Loading, PageHead } from '../components/ui';
import { useStore } from '../store';

export default function Cart() {
  const { cart, catalog, setQuantity, removeFromCart, user, sessionReady, config, notify } = useStore();
  const [params] = useSearchParams();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [accepted, setAccepted] = useState(false);
  if (!catalog) return <Loading />;

  const lines = cart.map((l) => ({ ...l, p: catalog.products.find((x) => x.id === l.productId) })).filter((l) => l.p);
  const total = lines.reduce((a, l) => a + l.p!.priceCents * l.quantity, 0);
  const currency = config?.currency ?? 'EUR';

  async function checkout() {
    setBusy(true); setError(null);
    try {
      const r = await api.post<{ ref: string; redirectUrl: string }>('/api/checkout', { items: lines.map((l) => ({ productId: l.productId, quantity: l.quantity })) });
      // Le panier est conservé : il ne sera vidé qu'une fois le paiement confirmé (page de commande)
      sessionStorage.setItem('elyzea-derniere-commande', r.ref);
      window.location.assign(r.redirectUrl);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Erreur inattendue.');
      setBusy(false);
      if (e instanceof ApiError && e.code === 'unavailable') notify('Un produit n\'est plus disponible : panier mis à jour.', 'error');
    }
  }

  return (
    <>
      <PageHead eyebrow="Commande" title="Votre panier" />
      <div className="container section">
        {params.get('annule') && <p className="alert" role="status">Paiement annulé : aucun montant n'a été prélevé. Votre panier est toujours là.</p>}
        {lines.length === 0 ? (
          <Empty icon="cart" title="Votre panier est vide"><Link to="/boutique" className="btn btn-primary">Découvrir la boutique</Link></Empty>
        ) : (
          <div className="cart-layout">
            <div className="panel">
              {lines.map((l) => (
                <div key={l.productId} className="cart-line">
                  <img src={l.p!.imageUrl || '/images/logo-192.webp'} alt="" width={120} height={75} />
                  <div className="grow">
                    <Link to={`/produit/${l.p!.slug}`}><strong>{l.p!.name}</strong></Link>
                    <div className="muted small">{l.p!.category.name} · {duration(l.p!.durationDays)}</div>
                  </div>
                  {l.p!.maxQuantity > 1 ? (
                    <select className="input qty-select" aria-label="Quantité" value={l.quantity} onChange={(e) => setQuantity(l.productId, Number(e.target.value))}>
                      {Array.from({ length: l.p!.maxQuantity }, (_, i) => i + 1).map((n) => <option key={n}>{n}</option>)}
                    </select>
                  ) : <span className="muted small">×1</span>}
                  <span className="price-sm">{money(l.p!.priceCents * l.quantity, l.p!.currency)}</span>
                  <button className="btn btn-ghost btn-sm" aria-label={`Retirer ${l.p!.name}`} onClick={() => removeFromCart(l.productId)}><Icon name="trash" size={16} /></button>
                </div>
              ))}
            </div>
            <aside className="panel panel-pad summary">
              <h3>Récapitulatif</h3>
              <div className="sum-row"><span>Total indicatif</span><strong className="price">{money(total, currency)}</strong></div>
              <p className="muted small">Le montant final (taxes selon votre pays) est affiché par Tebex avant le paiement.</p>
              {!sessionReady ? <Loading /> : !user ? (
                <>
                  <p className="alert alert-info small">Liez d'abord votre compte FiveM pour que vos achats arrivent sur le bon personnage.</p>
                  <Link to="/connexion?retour=/panier" className="btn btn-primary btn-block">Se connecter</Link>
                </>
              ) : (
                <>
                  <p className="small">Connecté : <strong>{user.displayName}</strong></p>
                  <label className="check small" style={{ marginBottom: '1rem' }}>
                    <input type="checkbox" checked={accepted} onChange={(e) => setAccepted(e.target.checked)} />
                    <span>J'accepte les <Link to="/cgv">conditions générales de vente</Link> et la <Link to="/remboursement">politique de remboursement</Link>.</span>
                  </label>
                  <button className="btn btn-primary btn-block" disabled={busy || !accepted} onClick={checkout}>{busy ? 'Redirection…' : 'Payer avec Tebex'}</button>
                  <p className="muted small" style={{ marginTop: '.8rem' }}>Étapes : connexion à votre compte Cfx.re sur Tebex, puis paiement. Utilisez le même compte FiveM qu'en jeu.</p>
                </>
              )}
              {error && <p className="alert alert-error small" role="alert">{error}</p>}
            </aside>
          </div>
        )}
      </div>
    </>
  );
}
