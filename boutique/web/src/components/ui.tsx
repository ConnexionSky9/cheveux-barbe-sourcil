import type { ReactNode } from 'react';
import { Link } from 'react-router-dom';
import { duration, money, type Product } from '../api';
import { useStore } from '../store';
import { Icon } from './Icon';

export function Loading({ label = 'Chargement…' }: { label?: string }) {
  return <div className="empty" role="status"><div className="spinner" style={{ margin: '0 auto 1rem' }} />{label}</div>;
}

export function Empty({ icon = 'package', title, children }: { icon?: string; title: string; children?: ReactNode }) {
  return <div className="empty"><div className="icon"><Icon name={icon} size={36} /></div><h3>{title}</h3>{children}</div>;
}

export function ErrorBox({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return (
    <div className="alert alert-error" role="alert" style={{ display: 'flex', gap: '1rem', alignItems: 'center', justifyContent: 'space-between' }}>
      <span>{message}</span>
      {onRetry && <button className="btn btn-sm" onClick={onRetry}><Icon name="refresh" size={16} />Réessayer</button>}
    </div>
  );
}

export function PriceTag({ p }: { p: Product }) {
  return <span className="price">{money(p.priceCents, p.currency)}{p.durationDays ? <small>/ {duration(p.durationDays)}</small> : null}</span>;
}

export function ProductCard({ p }: { p: Product }) {
  const { addToCart, notify } = useStore();
  return (
    <article className="product-card">
      <Link to={`/produit/${p.slug}`} className="media" aria-label={p.name}>
        <img src={p.imageUrl || '/images/logo-192.webp'} alt="" loading="lazy" decoding="async" width={400} height={250} />
      </Link>
      <div className="tags">
        {p.popular && <span className="badge">Populaire</span>}
        {p.durationDays ? <span className="badge badge-blue"><Icon name="clock" size={12} />{duration(p.durationDays)}</span> : <span className="badge badge-muted">Permanent</span>}
      </div>
      <div className="body">
        <span className="eyebrow" style={{ fontSize: '.7rem' }}>{p.category.name}</span>
        <h3 className="title"><Link to={`/produit/${p.slug}`} style={{ color: 'inherit' }}>{p.name}</Link></h3>
        <p className="muted small" style={{ margin: 0 }}>{p.shortDescription}</p>
        {p.perks.length > 0 && <ul className="perks small">{p.perks.slice(0, 3).map((k) => <li key={k}>{k}</li>)}</ul>}
        <div className="foot">
          <PriceTag p={p} />
          {p.available
            ? <button className="btn btn-primary btn-sm" onClick={() => { addToCart(p.id); notify(`« ${p.name} » ajouté au panier.`, 'success'); }}><Icon name="cart" size={16} />Ajouter</button>
            : <span className="badge badge-muted">Indisponible</span>}
        </div>
      </div>
    </article>
  );
}

export function Toasts() {
  const { toasts } = useStore();
  return <div className="toasts" aria-live="polite">{toasts.map((t) => <div key={t.id} className={`toast ${t.kind}`}>{t.text}</div>)}</div>;
}

export function PageHead({ eyebrow, title, children }: { eyebrow?: string; title: string; children?: ReactNode }) {
  return (
    <header className="page-head container">
      {eyebrow && <div className="eyebrow">{eyebrow}</div>}
      <h1>{title}</h1>
      {children && <p className="muted lead">{children}</p>}
    </header>
  );
}
