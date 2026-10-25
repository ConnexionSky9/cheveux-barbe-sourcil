import { Link } from 'react-router-dom';
import { Icon } from '../components/Icon';
import { ErrorBox, Loading, ProductCard } from '../components/ui';
import { useStore } from '../store';

const ADVANTAGES = [
  { icon: 'bolt', title: 'Livraison automatique', text: 'Votre achat arrive en jeu dès que le paiement est confirmé par Tebex, ou à votre prochaine connexion.' },
  { icon: 'shield', title: 'Paiement sécurisé', text: 'Tebex, revendeur officiel FiveM, traite le paiement. Nous ne voyons jamais vos données bancaires.' },
  { icon: 'user', title: 'Lié à votre compte FiveM', text: 'Vos achats sont rattachés à votre compte Cfx.re : pas de confusion de pseudonyme.' },
  { icon: 'help', title: 'Support réactif', text: 'Un souci de livraison ? L\'équipe retrouve votre commande en quelques secondes.' },
];

export default function Home() {
  const { catalog, catalogError, reloadCatalog, config } = useStore();
  const name = config?.serverName ?? 'Elyzea';
  const featured = catalog?.products.filter((p) => p.featured).slice(0, 3) ?? [];
  const popular = catalog?.products.filter((p) => p.popular).slice(0, 4) ?? [];

  return (
    <>
      <section className="hero">
        <div className="hero-bg" aria-hidden="true" />
        <div className="container hero-inner">
          <img className="hero-logo" src="/images/logo.webp" alt={`Logo ${name}`} width={300} height={300} />
          <div>
            <div className="eyebrow">Boutique officielle</div>
            <h1>Soutenez <span className="gold">{name}</span>,<br />vivez votre RP en grand.</h1>
            <p className="lead">Grades VIP, véhicules, packs et cosmétiques. Chaque achat aide à faire vivre le serveur et arrive directement en jeu.</p>
            <div className="hero-actions">
              <Link to="/boutique" className="btn btn-primary">Voir les produits <Icon name="arrow" size={18} /></Link>
              <Link to="/connexion" className="btn">Lier mon compte</Link>
            </div>
            <div className="hero-sides">
              <span className="badge badge-blue">Légal</span><span className="badge badge-red">Illégal</span><span className="muted small">Deux camps, une seule ville.</span>
            </div>
          </div>
        </div>
      </section>

      {catalogError && <div className="container section"><ErrorBox message={catalogError} onRetry={reloadCatalog} /></div>}
      {!catalog && !catalogError && <Loading />}

      {featured.length > 0 && (
        <section className="container section">
          <div className="section-head"><div><div className="eyebrow">À la une</div><h2>Offres mises en avant</h2></div><Link to="/boutique" className="btn btn-sm">Tout voir</Link></div>
          <div className="product-grid">{featured.map((p) => <ProductCard key={p.id} p={p} />)}</div>
        </section>
      )}

      {catalog && catalog.categories.length > 0 && (
        <section className="container section">
          <div className="section-head"><div><div className="eyebrow">Catalogue</div><h2>Catégories</h2></div></div>
          <div className="cat-grid">
            {catalog.categories.map((c) => (
              <Link key={c.id} to={`/boutique?categorie=${c.slug}`} className="cat-card panel">
                <Icon name={c.icon} size={28} /><strong>{c.name}</strong><span className="muted small">{c.description}</span>
              </Link>
            ))}
          </div>
        </section>
      )}

      {popular.length > 0 && (
        <section className="container section">
          <div className="section-head"><div><div className="eyebrow">Les joueurs adorent</div><h2>Produits populaires</h2></div></div>
          <div className="product-grid">{popular.map((p) => <ProductCard key={p.id} p={p} />)}</div>
        </section>
      )}

      <section className="container section">
        <div className="section-head"><div><div className="eyebrow">Pourquoi ici</div><h2>Les avantages de la boutique</h2></div></div>
        <div className="adv-grid">
          {ADVANTAGES.map((a) => <div key={a.title} className="panel panel-pad adv"><Icon name={a.icon} size={26} /><h3>{a.title}</h3><p className="muted small">{a.text}</p></div>)}
        </div>
      </section>
    </>
  );
}
