import { useEffect, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { api, ApiError, duration, type Product } from '../api';
import { Icon } from '../components/Icon';
import { Empty, ErrorBox, Loading, PriceTag } from '../components/ui';
import { useStore } from '../store';

export default function ProductPage() {
  const { slug = '' } = useParams();
  const { addToCart, notify } = useStore();
  const nav = useNavigate();
  const [p, setP] = useState<Product | null>(null);
  const [error, setError] = useState<ApiError | null>(null);
  const [qty, setQty] = useState(1);

  useEffect(() => {
    setP(null); setError(null);
    api.get<Product>(`/api/products/${encodeURIComponent(slug)}`).then(setP).catch((e: ApiError) => setError(e));
  }, [slug]);

  if (error?.status === 404) return <div className="container section"><Empty title="Produit introuvable"><Link to="/boutique" className="btn">Retour à la boutique</Link></Empty></div>;
  if (error) return <div className="container section"><ErrorBox message={error.message} /></div>;
  if (!p) return <Loading />;

  return (
    <div className="container section product-page">
      <Link to={`/boutique?categorie=${p.category.slug}`} className="back"><Icon name="back" size={16} />{p.category.name}</Link>
      <div className="product-layout">
        <div className="product-visual panel"><img src={p.imageUrl || '/images/logo.webp'} alt={p.name} width={800} height={500} /></div>
        <div className="product-info">
          <div className="eyebrow">{p.category.name}</div>
          <h1>{p.name}</h1>
          <div className="row-gap">
            {p.durationDays ? <span className="badge badge-blue"><Icon name="clock" size={12} />Durée : {duration(p.durationDays)}</span> : <span className="badge">Permanent</span>}
            {p.available ? <span className="badge badge-green">Disponible</span> : <span className="badge badge-muted">Indisponible</span>}
          </div>
          <PriceTag p={p} />
          <p className="lead">{p.shortDescription}</p>
          {p.description.split(/\n{2,}/).map((para, i) => <p key={i} className="muted">{para}</p>)}
          {p.perks.length > 0 && (<><h3>Ce que vous obtenez</h3><ul className="perks">{p.perks.map((k) => <li key={k}>{k}</li>)}</ul></>)}
          {p.durationDays && <p className="alert alert-info small" style={{ marginTop: '1rem' }}>Produit temporaire : il est retiré automatiquement {duration(p.durationDays)} après l'achat. Un nouvel achat prolonge la durée.</p>}
          {p.available ? (
            <div className="buy-row">
              {p.maxQuantity > 1 && (
                <label className="qty">Quantité
                  <select className="input" value={qty} onChange={(e) => setQty(Number(e.target.value))}>
                    {Array.from({ length: p.maxQuantity }, (_, i) => i + 1).map((n) => <option key={n} value={n}>{n}</option>)}
                  </select>
                </label>
              )}
              <button className="btn btn-primary" onClick={() => { addToCart(p.id, qty); notify('Ajouté au panier.', 'success'); }}><Icon name="cart" size={18} />Ajouter au panier</button>
              <button className="btn" onClick={() => { addToCart(p.id, qty); nav('/panier'); }}>Acheter maintenant</button>
            </div>
          ) : <p className="alert">Ce produit n'est pas disponible à l'achat pour le moment.</p>}
          <p className="muted small"><Icon name="lock" size={14} /> Paiement sécurisé par Tebex. Livraison en jeu après confirmation du paiement.</p>
        </div>
      </div>
    </div>
  );
}
