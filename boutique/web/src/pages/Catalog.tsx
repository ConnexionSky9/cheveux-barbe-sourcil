import { useMemo, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { Icon } from '../components/Icon';
import { Empty, ErrorBox, Loading, PageHead, ProductCard } from '../components/ui';
import { useStore } from '../store';

export default function Catalog() {
  const { catalog, catalogError, reloadCatalog } = useStore();
  const [params, setParams] = useSearchParams();
  const [search, setSearch] = useState('');
  const current = params.get('categorie') ?? '';
  const list = useMemo(() => {
    const q = search.trim().toLowerCase();
    return (catalog?.products ?? []).filter((p) => (!current || p.category.slug === current) && (!q || `${p.name} ${p.shortDescription}`.toLowerCase().includes(q)));
  }, [catalog, current, search]);

  return (
    <>
      <PageHead eyebrow="Catalogue" title="La boutique">Tous les produits sont livrés automatiquement en jeu après confirmation du paiement.</PageHead>
      <div className="container section">
        <div className="toolbar">
          <div className="chips" role="tablist" aria-label="Catégories">
            <button role="tab" aria-selected={!current} className={`chip ${!current ? 'on' : ''}`} onClick={() => setParams({})}>Tout</button>
            {catalog?.categories.map((c) => (
              <button key={c.id} role="tab" aria-selected={current === c.slug} className={`chip ${current === c.slug ? 'on' : ''}`} onClick={() => setParams({ categorie: c.slug })}>
                <Icon name={c.icon} size={16} />{c.name}
              </button>
            ))}
          </div>
          <input className="input search" type="search" placeholder="Rechercher…" value={search} onChange={(e) => setSearch(e.target.value)} aria-label="Rechercher un produit" />
        </div>
        {catalogError && <ErrorBox message={catalogError} onRetry={reloadCatalog} />}
        {!catalog && !catalogError && <Loading />}
        {catalog && list.length === 0 && <Empty title="Aucun produit ici pour le moment">Revenez bientôt : de nouveaux produits arrivent régulièrement.</Empty>}
        {list.length > 0 && <div className="product-grid">{list.map((p) => <ProductCard key={p.id} p={p} />)}</div>}
      </div>
    </>
  );
}
