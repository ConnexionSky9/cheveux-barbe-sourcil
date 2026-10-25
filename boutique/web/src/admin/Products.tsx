import { useEffect, useState, type FormEvent } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { api, ApiError, duration, money, type Category, type Product } from '../api';
import { ErrorBox, Loading } from '../components/ui';
import { useStore } from '../store';
import { can, useAdmin } from './AdminApp';
import { useFetch } from './hooks';

interface Reward { type: string; params: Record<string, unknown> }
interface AdminProduct extends Product { active: boolean; tebexPackageId: number | null; rewards: (Reward & { id: number })[] }
interface TebexPkg { id: number; name: string; category: string; priceCents: number; currency: string; type: string | null; product: { id: number; name: string } | null }

export function Products() {
  const me = useAdmin();
  const { data, error, reload } = useFetch<{ products: AdminProduct[] }>('/api/admin/products');
  const { notify } = useStore();
  const [syncing, setSyncing] = useState(false);
  async function sync() {
    setSyncing(true);
    try { const r = await api.post<{ updated: number }>('/api/admin/tebex/sync-prices'); notify(`${r.updated} prix mis à jour depuis Tebex.`, 'success'); reload(); }
    catch (e) { notify(e instanceof ApiError ? e.message : 'Erreur', 'error'); } finally { setSyncing(false); }
  }
  return (
    <>
      <div className="admin-head"><h1>Produits</h1>{can(me, 'admin') && <div className="row-gap"><button className="btn btn-sm" disabled={syncing} onClick={sync}>{syncing ? 'Synchronisation…' : 'Prix depuis Tebex'}</button><Link className="btn btn-primary btn-sm" to="/admin/produits/nouveau">Nouveau produit</Link></div>}</div>
      {error && <ErrorBox message={error} onRetry={reload} />}
      {!data && !error && <Loading />}
      {data && (
        <div className="panel table-wrap">
          <table className="table">
            <thead><tr><th>Produit</th><th>Catégorie</th><th>Prix</th><th>Durée</th><th>Paquet Tebex</th><th>Récompenses</th><th>État</th></tr></thead>
            <tbody>{data.products.map((p) => (
              <tr key={p.id}>
                <td><Link to={`/admin/produits/${p.id}`}><strong>{p.name}</strong></Link><div className="muted small">/{p.slug}</div></td>
                <td>{p.category.name}</td><td>{money(p.priceCents, p.currency)}</td><td>{duration(p.durationDays)}</td>
                <td>{p.tebexPackageId ?? <span className="badge badge-amber">non relié</span>}</td>
                <td>{p.rewards.length ? p.rewards.map((r) => r.type).join(', ') : <span className="badge badge-red">aucune</span>}</td>
                <td>{p.active ? (p.available ? <span className="badge badge-green">en vente</span> : <span className="badge badge-amber">visible, non achetable</span>) : <span className="badge badge-muted">désactivé</span>}</td>
              </tr>
            ))}</tbody>
          </table>
        </div>
      )}
    </>
  );
}

const EMPTY = { slug: '', categoryId: 0, name: '', shortDescription: '', description: '', imageUrl: '', priceCents: 0, currency: 'EUR', durationDays: null as number | null, maxQuantity: 1, perks: [] as string[], tebexPackageId: null as number | null, featured: false, popular: false, active: true, sort: 0 };
const REWARD_HELP: Record<string, { fields: [string, string, 'text' | 'number'][]; help: string }> = {
  group: { fields: [['name', 'Nom du grade (ex. vip_or)', 'text']], help: 'Donne le groupe ACE « group.<nom> » en jeu tant que l\'achat est actif. Vos scripts peuvent tester IsPlayerAceAllowed ou exports.server_shop:HasPerk.' },
  perk: { fields: [['name', 'Nom de l\'avantage', 'text']], help: 'Avantage nommé, lisible par vos scripts : exports.server_shop:HasPerk(source, nom).' },
  vehicle: { fields: [['model', 'Modèle (nom de spawn)', 'text'], ['garage', 'Garage (facultatif)', 'text']], help: 'Ajouté au garage du personnage actif (table configurable dans config.lua).' },
  item: { fields: [['name', 'Nom de l\'objet', 'text'], ['count', 'Quantité', 'number']], help: 'Ajouté à l\'inventaire du personnage actif.' },
  money: { fields: [['account', 'Compte (bank, cash…)', 'text'], ['amount', 'Montant', 'number']], help: 'Argent en jeu. Vérifiez que la vente de monnaie est autorisée par les règles Cfx.re.' },
  command: { fields: [['name', 'Nom de la commande prédéfinie', 'text']], help: 'Exécute une commande définie dans server_shop/config.lua › Config.Commands (jamais de texte libre).' },
};

export function ProductEdit() {
  const { id = '' } = useParams();
  const isNew = id === 'nouveau';
  const me = useAdmin();
  const nav = useNavigate();
  const { notify } = useStore();
  const editable = can(me, 'admin');
  const cats = useFetch<(Category & { productCount: number })[]>('/api/admin/categories');
  const prod = useFetch<AdminProduct>(isNew ? null : `/api/admin/products/${id}`);
  const [form, setForm] = useState(EMPTY);
  const [perksText, setPerksText] = useState('');
  const [rewards, setRewards] = useState<Reward[]>([]);
  const [pkgs, setPkgs] = useState<TebexPkg[] | null>(null);
  const [pkgError, setPkgError] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    const p = prod.data;
    if (!p) return;
    setForm({ slug: p.slug, categoryId: p.category.id, name: p.name, shortDescription: p.shortDescription, description: p.description, imageUrl: p.imageUrl, priceCents: p.priceCents, currency: p.currency, durationDays: p.durationDays, maxQuantity: p.maxQuantity, perks: p.perks, tebexPackageId: p.tebexPackageId, featured: p.featured, popular: p.popular, active: p.active, sort: p.sort });
    setPerksText(p.perks.join('\n'));
    setRewards(p.rewards.map((r) => ({ type: r.type, params: r.params })));
  }, [prod.data]);
  useEffect(() => { if (isNew && cats.data?.[0] && !form.categoryId) setForm((f) => ({ ...f, categoryId: cats.data![0]!.id })); }, [isNew, cats.data, form.categoryId]);

  const set = <K extends keyof typeof EMPTY>(k: K, v: (typeof EMPTY)[K]) => setForm((f) => ({ ...f, [k]: v }));

  async function save(e: FormEvent) {
    e.preventDefault(); setBusy(true); setError(null);
    const body = { ...form, perks: perksText.split('\n').map((s) => s.trim()).filter(Boolean) };
    try {
      let pid = Number(id);
      if (isNew) pid = (await api.post<{ id: number }>('/api/admin/products', body)).id;
      else await api.patch(`/api/admin/products/${id}`, body);
      await api.put(`/api/admin/products/${pid}/rewards`, { rewards });
      notify('Produit enregistré.', 'success');
      if (isNew) nav(`/admin/produits/${pid}`, { replace: true }); else prod.reload();
    } catch (err) {
      setError(err instanceof ApiError ? `${err.message}${err.fields ? ' — ' + err.fields.map((f) => `${f.path} : ${f.message}`).join(' ; ') : ''}` : 'Erreur.');
    } finally { setBusy(false); }
  }

  async function loadPackages() {
    setPkgError(null);
    try { setPkgs(await api.get<TebexPkg[]>('/api/admin/tebex/packages')); } catch (e) { setPkgError(e instanceof ApiError ? e.message : 'Tebex injoignable.'); }
  }

  if (!isNew && prod.error) return <ErrorBox message={prod.error} />;
  if ((!isNew && !prod.data) || !cats.data) return <Loading />;

  return (
    <form onSubmit={save}>
      <div className="admin-head"><h1>{isNew ? 'Nouveau produit' : form.name}</h1><Link to="/admin/produits" className="btn btn-sm">Retour</Link></div>
      {!editable && <p className="alert alert-info small">Lecture seule : votre rôle ne permet pas de modifier les produits.</p>}
      <fieldset disabled={!editable} className="admin-form">
        <div className="panel panel-pad grid-2">
          <div className="field"><label>Nom</label><input className="input" value={form.name} onChange={(e) => set('name', e.target.value)} required maxLength={80} /></div>
          <div className="field"><label>Lien (slug)</label><input className="input" value={form.slug} onChange={(e) => set('slug', e.target.value.toLowerCase())} pattern="[a-z0-9-]{2,64}" required /></div>
          <div className="field"><label>Catégorie</label><select className="input" value={form.categoryId} onChange={(e) => set('categoryId', Number(e.target.value))}>{cats.data.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}</select></div>
          <div className="field"><label>Image (chemin /images/... ou URL https)</label><input className="input" value={form.imageUrl} onChange={(e) => set('imageUrl', e.target.value)} /></div>
          <div className="field"><label>Prix affiché (centimes)</label><input className="input" type="number" min={0} value={form.priceCents} onChange={(e) => set('priceCents', Number(e.target.value))} /><span className="muted small">{money(form.priceCents, form.currency)} — le prix réellement payé est celui de Tebex.</span></div>
          <div className="field"><label>Durée (jours, vide = permanent)</label><input className="input" type="number" min={1} value={form.durationDays ?? ''} onChange={(e) => set('durationDays', e.target.value ? Number(e.target.value) : null)} /></div>
          <div className="field"><label>Quantité max. par commande</label><input className="input" type="number" min={1} max={99} value={form.maxQuantity} onChange={(e) => set('maxQuantity', Number(e.target.value))} /></div>
          <div className="field"><label>Ordre d'affichage</label><input className="input" type="number" value={form.sort} onChange={(e) => set('sort', Number(e.target.value))} /></div>
          <div className="field span-2"><label>Accroche</label><input className="input" value={form.shortDescription} onChange={(e) => set('shortDescription', e.target.value)} maxLength={160} /></div>
          <div className="field span-2"><label>Description (paragraphes séparés par une ligne vide)</label><textarea className="input" value={form.description} onChange={(e) => set('description', e.target.value)} maxLength={5000} /></div>
          <div className="field span-2"><label>Avantages affichés (un par ligne)</label><textarea className="input" value={perksText} onChange={(e) => setPerksText(e.target.value)} /></div>
          <div className="row-gap span-2">
            <label className="check"><input type="checkbox" checked={form.active} onChange={(e) => set('active', e.target.checked)} />Actif</label>
            <label className="check"><input type="checkbox" checked={form.featured} onChange={(e) => set('featured', e.target.checked)} />Mis en avant</label>
            <label className="check"><input type="checkbox" checked={form.popular} onChange={(e) => set('popular', e.target.checked)} />Populaire</label>
          </div>
        </div>

        <div className="panel panel-pad" style={{ marginTop: '1rem' }}>
          <h3>Paquet Tebex</h3>
          <p className="muted small">Sans paquet Tebex, le produit est visible mais pas achetable. Créez le paquet dans votre panneau Tebex (même prix), puis reliez-le ici.</p>
          <div className="row-gap">
            <input className="input" style={{ maxWidth: 220 }} type="number" placeholder="ID du paquet" value={form.tebexPackageId ?? ''} onChange={(e) => set('tebexPackageId', e.target.value ? Number(e.target.value) : null)} />
            <button type="button" className="btn btn-sm" onClick={loadPackages}>Lister mes paquets Tebex</button>
          </div>
          {pkgError && <p className="alert alert-error small">{pkgError}</p>}
          {pkgs && (
            <div className="table-wrap" style={{ marginTop: '.8rem' }}><table className="table"><tbody>{pkgs.map((p) => (
              <tr key={p.id}><td>{p.id}</td><td>{p.name}<div className="muted small">{p.category}{p.type === 'subscription' ? ' · abonnement (non pris en charge)' : ''}</div></td><td>{money(p.priceCents, p.currency)}</td>
                <td>{p.product ? <span className="muted small">relié à « {p.product.name} »</span> : <button type="button" className="btn btn-sm" onClick={() => { set('tebexPackageId', p.id); set('priceCents', p.priceCents); set('currency', p.currency); }}>Choisir</button>}</td></tr>
            ))}</tbody></table></div>
          )}
        </div>

        <div className="panel panel-pad" style={{ marginTop: '1rem' }}>
          <h3>Ce que le produit donne en jeu</h3>
          {rewards.length === 0 && <p className="alert alert-error small">Aucune récompense : un achat de ce produit ne livrerait rien en jeu.</p>}
          {rewards.map((r, i) => (
            <div key={i} className="reward-row">
              <select className="input" value={r.type} onChange={(e) => setRewards((rs) => rs.map((x, k) => (k === i ? { type: e.target.value, params: {} } : x)))}>
                {Object.keys(REWARD_HELP).map((t) => <option key={t} value={t}>{t}</option>)}
              </select>
              {REWARD_HELP[r.type]?.fields.map(([key, label, kind]) => (
                <input key={key} className="input" placeholder={label} type={kind} value={String(r.params[key] ?? '')}
                  onChange={(e) => setRewards((rs) => rs.map((x, k) => {
                    if (k !== i) return x;
                    const params = { ...x.params };
                    if (e.target.value === '') delete params[key]; else params[key] = kind === 'number' ? Number(e.target.value) : e.target.value;
                    return { ...x, params };
                  }))} />
              ))}
              <button type="button" className="btn btn-sm btn-danger" onClick={() => setRewards((rs) => rs.filter((_, k) => k !== i))}>Retirer</button>
              <p className="muted small span-all">{REWARD_HELP[r.type]?.help}</p>
            </div>
          ))}
          <button type="button" className="btn btn-sm" onClick={() => setRewards((rs) => [...rs, { type: 'item', params: { count: 1 } }])}>Ajouter une récompense</button>
        </div>
        {error && <p className="alert alert-error" role="alert" style={{ marginTop: '1rem' }}>{error}</p>}
        {editable && <div className="row-gap" style={{ marginTop: '1rem' }}><button className="btn btn-primary" disabled={busy}>{busy ? 'Enregistrement…' : 'Enregistrer'}</button></div>}
      </fieldset>
    </form>
  );
}
