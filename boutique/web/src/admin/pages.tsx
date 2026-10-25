import { useState, type FormEvent } from 'react';
import { Link, useParams } from 'react-router-dom';
import { api, ApiError, dateFr, money, ORDER_STATUS, type Category } from '../api';
import { ErrorBox, Loading } from '../components/ui';
import { useStore } from '../store';
import { can, useAdmin } from './AdminApp';
import { useFetch } from './hooks';

type Row = Record<string, unknown>;
const s = (v: unknown) => (v === null || v === undefined ? '—' : String(v));

export function Dashboard() {
  const { data, error, reload } = useFetch<{ orders: { paid: number; pending: number; revenueCents: number; last30DaysCents: number }; deliveries: Record<string, number>; webhookErrors: number; errorsLast7Days: number; currency: string }>('/api/admin/stats');
  if (error) return <ErrorBox message={error} onRetry={reload} />;
  if (!data) return <Loading />;
  const tiles: [string, string, string?][] = [
    ['Commandes payées', String(data.orders.paid)], ['Revenus (30 jours)', money(data.orders.last30DaysCents, data.currency)], ['Revenus (total)', money(data.orders.revenueCents, data.currency)],
    ['En attente de paiement', String(data.orders.pending)], ['Livraisons en attente', String((data.deliveries.pending ?? 0) + (data.deliveries.claimed ?? 0))],
    ['Livraisons échouées', String(data.deliveries.failed ?? 0), data.deliveries.failed ? '/admin/livraisons' : undefined],
    ['Notifications Tebex en erreur', String(data.webhookErrors), data.webhookErrors ? '/admin/webhooks' : undefined], ['Erreurs (7 jours)', String(data.errorsLast7Days), data.errorsLast7Days ? '/admin/journaux' : undefined],
  ];
  return (
    <>
      <div className="admin-head"><h1>Tableau de bord</h1><button className="btn btn-sm" onClick={reload}>Actualiser</button></div>
      <div className="stat-grid">{tiles.map(([label, value, link]) => (
        <div key={label} className={`panel panel-pad stat ${link ? 'warn' : ''}`}><div className="muted small">{label}</div><div className="stat-value">{value}</div>{link && <Link to={link} className="small">Voir</Link>}</div>
      ))}</div>
      <p className="muted small" style={{ marginTop: '1rem' }}>Les revenus affichés sont les montants des notifications Tebex (taxes comprises selon Tebex). Le relevé officiel reste celui du panneau Tebex.</p>
    </>
  );
}

const EMPTY_CAT = { slug: '', name: '', description: '', icon: 'star', sort: 0, active: true };
export function Categories() {
  const me = useAdmin();
  const { notify } = useStore();
  const { data, error, reload } = useFetch<(Category & { productCount: number })[]>('/api/admin/categories');
  const [edit, setEdit] = useState<{ id: number | null; v: typeof EMPTY_CAT } | null>(null);
  const [err, setErr] = useState<string | null>(null);
  async function save(e: FormEvent) {
    e.preventDefault(); if (!edit) return; setErr(null);
    try {
      if (edit.id) await api.patch(`/api/admin/categories/${edit.id}`, edit.v); else await api.post('/api/admin/categories', edit.v);
      notify('Catégorie enregistrée.', 'success'); setEdit(null); reload();
    } catch (x) { setErr(x instanceof ApiError ? x.message : 'Erreur.'); }
  }
  async function remove(id: number) {
    if (!window.confirm('Supprimer cette catégorie vide ?')) return;
    try { await api.del(`/api/admin/categories/${id}`); notify('Catégorie supprimée.', 'success'); reload(); } catch (x) { notify(x instanceof ApiError ? x.message : 'Erreur', 'error'); }
  }
  if (error) return <ErrorBox message={error} onRetry={reload} />;
  if (!data) return <Loading />;
  return (
    <>
      <div className="admin-head"><h1>Catégories</h1>{can(me, 'admin') && <button className="btn btn-primary btn-sm" onClick={() => setEdit({ id: null, v: EMPTY_CAT })}>Nouvelle catégorie</button>}</div>
      {edit && (
        <form className="panel panel-pad grid-2" onSubmit={save} style={{ marginBottom: '1rem' }}>
          <div className="field"><label>Nom</label><input className="input" value={edit.v.name} onChange={(e) => setEdit({ ...edit, v: { ...edit.v, name: e.target.value } })} required /></div>
          <div className="field"><label>Lien (slug)</label><input className="input" value={edit.v.slug} pattern="[a-z0-9-]{2,48}" onChange={(e) => setEdit({ ...edit, v: { ...edit.v, slug: e.target.value.toLowerCase() } })} required /></div>
          <div className="field"><label>Icône</label><select className="input" value={edit.v.icon} onChange={(e) => setEdit({ ...edit, v: { ...edit.v, icon: e.target.value } })}>{['crown', 'car', 'package', 'sparkles', 'star', 'gift', 'bolt', 'shield'].map((i) => <option key={i}>{i}</option>)}</select></div>
          <div className="field"><label>Ordre</label><input className="input" type="number" value={edit.v.sort} onChange={(e) => setEdit({ ...edit, v: { ...edit.v, sort: Number(e.target.value) } })} /></div>
          <div className="field span-2"><label>Description</label><input className="input" value={edit.v.description} maxLength={255} onChange={(e) => setEdit({ ...edit, v: { ...edit.v, description: e.target.value } })} /></div>
          <label className="check"><input type="checkbox" checked={edit.v.active} onChange={(e) => setEdit({ ...edit, v: { ...edit.v, active: e.target.checked } })} />Active</label>
          {err && <p className="alert alert-error small span-2">{err}</p>}
          <div className="row-gap span-2"><button className="btn btn-primary btn-sm">Enregistrer</button><button type="button" className="btn btn-sm" onClick={() => setEdit(null)}>Annuler</button></div>
        </form>
      )}
      <div className="panel table-wrap"><table className="table">
        <thead><tr><th>Nom</th><th>Lien</th><th>Produits</th><th>État</th><th /></tr></thead>
        <tbody>{data.map((c) => (
          <tr key={c.id}><td>{c.name}</td><td>/{c.slug}</td><td>{c.productCount}</td><td>{c.active ? <span className="badge badge-green">active</span> : <span className="badge badge-muted">masquée</span>}</td>
            <td className="row-gap">{can(me, 'admin') && <><button className="btn btn-sm" onClick={() => setEdit({ id: c.id, v: { slug: c.slug, name: c.name, description: c.description, icon: c.icon, sort: c.sort, active: c.active } })}>Modifier</button>
              {c.productCount === 0 && <button className="btn btn-sm btn-danger" onClick={() => remove(c.id)}>Supprimer</button>}</>}</td></tr>
        ))}</tbody>
      </table></div>
    </>
  );
}

export function Orders() {
  const [status, setStatus] = useState('');
  const [q, setQ] = useState('');
  const [query, setQuery] = useState('');
  const [page, setPage] = useState(1);
  const url = `/api/admin/orders?page=${page}${status ? `&status=${status}` : ''}${query ? `&q=${encodeURIComponent(query)}` : ''}`;
  const { data, error, reload } = useFetch<{ page: number; orders: Row[] }>(url);
  return (
    <>
      <div className="admin-head"><h1>Commandes</h1></div>
      <form className="row-gap" style={{ marginBottom: '1rem' }} onSubmit={(e) => { e.preventDefault(); setPage(1); setQuery(q.trim()); }}>
        <select className="input" style={{ maxWidth: 220 }} value={status} onChange={(e) => { setStatus(e.target.value); setPage(1); }}>
          <option value="">Tous les statuts</option>{Object.entries(ORDER_STATUS).map(([k, v]) => <option key={k} value={k}>{v.label}</option>)}
        </select>
        <input className="input" style={{ maxWidth: 340 }} placeholder="Réf., transaction Tebex, id Cfx.re, pseudo" value={q} onChange={(e) => setQ(e.target.value)} />
        <button className="btn btn-sm">Rechercher</button>
      </form>
      {error && <ErrorBox message={error} onRetry={reload} />}
      {!data && !error && <Loading />}
      {data && (
        <>
          <div className="panel table-wrap"><table className="table">
            <thead><tr><th>Date</th><th>Joueur</th><th>Statut</th><th>Total</th><th>Origine</th><th>Transaction Tebex</th></tr></thead>
            <tbody>{data.orders.map((o) => (
              <tr key={String(o.id)}>
                <td><Link to={`/admin/commandes/${s(o.id)}`}>{dateFr(o.created_at as string)}</Link></td>
                <td>{s(o.display_name)}<div className="muted small">{o.cfx_id ? `fivem:${s(o.cfx_id)}` : ''}</div></td>
                <td><span className={`badge ${ORDER_STATUS[String(o.status)]?.tone}`}>{ORDER_STATUS[String(o.status)]?.label}</span></td>
                <td>{money(Number(o.total_cents), String(o.currency))}</td><td>{s(o.source)}</td><td className="small">{s(o.tebex_transaction_id)}</td>
              </tr>
            ))}</tbody>
          </table></div>
          <div className="row-gap" style={{ marginTop: '1rem' }}>
            <button className="btn btn-sm" disabled={page <= 1} onClick={() => setPage(page - 1)}>Précédent</button><span className="muted small">Page {page}</span>
            <button className="btn btn-sm" disabled={data.orders.length < 50} onClick={() => setPage(page + 1)}>Suivant</button>
          </div>
        </>
      )}
    </>
  );
}

export function OrderDetail() {
  const { id = '' } = useParams();
  const me = useAdmin();
  const { notify } = useStore();
  const { data, error, reload } = useFetch<{ order: Row; items: Row[]; transactions: Row[]; rewards: (Row & { jobs: Row[]; params: Row })[] }>(`/api/admin/orders/${id}`);
  async function act(jobId: unknown, action: 'retry' | 'cancel') {
    try { await api.post(`/api/admin/deliveries/${s(jobId)}/${action}`); notify(action === 'retry' ? 'Livraison relancée.' : 'Tâche annulée.', 'success'); reload(); }
    catch (e) { notify(e instanceof ApiError ? e.message : 'Erreur', 'error'); }
  }
  if (error) return <ErrorBox message={error} onRetry={reload} />;
  if (!data) return <Loading />;
  const o = data.order;
  return (
    <>
      <div className="admin-head"><h1>Commande {s(o.public_ref).slice(0, 8)}</h1><Link to="/admin/commandes" className="btn btn-sm">Retour</Link></div>
      <div className="panel panel-pad grid-2">
        <div><div className="muted small">Statut</div><span className={`badge ${ORDER_STATUS[String(o.status)]?.tone}`}>{ORDER_STATUS[String(o.status)]?.label}</span></div>
        <div><div className="muted small">Joueur</div>{s(o.display_name)} — fivem:{s(o.cfx_id)}</div>
        <div><div className="muted small">Créée / payée</div>{dateFr(o.created_at as string)} / {dateFr(o.paid_at as string)}</div>
        <div><div className="muted small">Transaction Tebex</div>{s(o.tebex_transaction_id)}</div>
        <div><div className="muted small">Total</div>{money(Number(o.total_cents), String(o.currency))}</div>
        <div><div className="muted small">Origine</div>{s(o.source)}</div>
      </div>
      <h3 style={{ marginTop: '1.5rem' }}>Lignes</h3>
      <div className="panel table-wrap"><table className="table"><thead><tr><th>Produit</th><th>Qté</th><th>Prix unitaire</th><th>Paquet Tebex</th><th>Destinataire</th></tr></thead>
        <tbody>{data.items.map((i) => <tr key={s(i.id)}><td>{s(i.name_snapshot)}{!i.product_id && <span className="badge badge-red" style={{ marginLeft: 8 }}>paquet non relié</span>}</td><td>{s(i.quantity)}</td><td>{money(Number(i.unit_price_cents), String(o.currency))}</td><td>{s(i.tebex_package_id)}</td><td>{i.recipient_cfx_id ? `fivem:${s(i.recipient_cfx_id)}` : '—'}</td></tr>)}</tbody></table></div>
      <h3 style={{ marginTop: '1.5rem' }}>Récompenses et livraisons</h3>
      <div className="panel table-wrap"><table className="table"><thead><tr><th>Type</th><th>Paramètres</th><th>Statut</th><th>Expire</th><th>Tâches</th></tr></thead>
        <tbody>{data.rewards.map((r) => (
          <tr key={s(r.id)}><td>{s(r.type)}</td><td className="small">{JSON.stringify(r.params)}</td><td>{s(r.status)}</td><td>{dateFr(r.expires_at as string)}</td>
            <td>{(r.jobs ?? []).map((j) => (
              <div key={s(j.id)} className="small">#{s(j.id)} {s(j.action)} · {s(j.status)} · {s(j.attempts)} essai(s){j.lastError ? <div className="muted">{s(j.lastError)}</div> : null}
                {can(me, 'admin') && j.status === 'failed' && <button className="btn btn-sm" onClick={() => act(j.id, 'retry')}>Relancer</button>}
                {can(me, 'admin') && ['pending', 'failed'].includes(String(j.status)) && <button className="btn btn-sm btn-ghost" onClick={() => act(j.id, 'cancel')}>Annuler</button>}
              </div>))}</td></tr>
        ))}</tbody></table></div>
      <h3 style={{ marginTop: '1.5rem' }}>Événements de paiement</h3>
      <div className="panel table-wrap"><table className="table"><thead><tr><th>Date</th><th>Événement</th><th>Statut</th><th>Montant</th></tr></thead>
        <tbody>{data.transactions.map((t) => <tr key={s(t.id)}><td>{dateFr(t.created_at as string)}</td><td>{s(t.event_type)}</td><td>{s(t.status)}</td><td>{t.amount_cents === null ? '—' : money(Number(t.amount_cents), String(t.currency ?? o.currency))}</td></tr>)}</tbody></table></div>
    </>
  );
}

export function Deliveries() {
  const me = useAdmin();
  const { notify } = useStore();
  const [status, setStatus] = useState('failed');
  const { data, error, reload } = useFetch<Row[]>(`/api/admin/deliveries${status ? `?status=${status}` : ''}`);
  async function act(id: unknown, action: 'retry' | 'cancel') {
    if (action === 'cancel' && !window.confirm('Annuler cette tâche ? (une récompense annulée ne sera pas livrée)')) return;
    try { await api.post(`/api/admin/deliveries/${s(id)}/${action}`); notify('Fait.', 'success'); reload(); } catch (e) { notify(e instanceof ApiError ? e.message : 'Erreur', 'error'); }
  }
  return (
    <>
      <div className="admin-head"><h1>Livraisons</h1><div className="row-gap"><select className="input" value={status} onChange={(e) => setStatus(e.target.value)}>
        <option value="">Toutes</option><option value="pending">En attente (joueur hors ligne)</option><option value="claimed">En cours</option><option value="failed">Échouées</option><option value="done">Terminées</option><option value="cancelled">Annulées</option>
      </select><button className="btn btn-sm" onClick={reload}>Actualiser</button></div></div>
      {error && <ErrorBox message={error} onRetry={reload} />}
      {!data && !error && <Loading />}
      {data && data.length === 0 && <p className="muted">Aucune tâche.</p>}
      {data && data.length > 0 && (
        <div className="panel table-wrap"><table className="table">
          <thead><tr><th>#</th><th>Produit</th><th>Action</th><th>Joueur</th><th>État</th><th>Essais</th><th>Dernière erreur</th><th /></tr></thead>
          <tbody>{data.map((j) => (
            <tr key={s(j.id)}><td>{s(j.id)}</td><td><Link to={`/admin/commandes/${s(j.order_id)}`}>{s(j.name_snapshot)}</Link><div className="muted small">{s(j.type)}</div></td><td>{j.action === 'grant' ? 'donner' : 'retirer'}</td>
              <td>fivem:{s(j.recipient_cfx_id)}</td><td>{s(j.status)}</td><td>{s(j.attempts)}</td><td className="small">{s(j.last_error)}</td>
              <td className="row-gap">{can(me, 'admin') && j.status === 'failed' && <button className="btn btn-sm" onClick={() => act(j.id, 'retry')}>Relancer</button>}
                {can(me, 'admin') && ['pending', 'failed'].includes(String(j.status)) && <button className="btn btn-sm btn-ghost" onClick={() => act(j.id, 'cancel')}>Annuler</button>}</td></tr>
          ))}</tbody>
        </table></div>
      )}
    </>
  );
}

export function Webhooks() {
  const [status, setStatus] = useState('');
  const { data, error, reload } = useFetch<Row[]>(`/api/admin/webhooks${status ? `?status=${status}` : ''}`);
  return (
    <>
      <div className="admin-head"><h1>Notifications Tebex</h1><div className="row-gap"><select className="input" value={status} onChange={(e) => setStatus(e.target.value)}><option value="">Toutes</option><option value="error">En erreur</option><option value="processed">Traitées</option><option value="ignored">Ignorées</option></select><button className="btn btn-sm" onClick={reload}>Actualiser</button></div></div>
      <p className="muted small">Une notification en erreur est renvoyée automatiquement par Tebex plus tard ; elle sera retraitée sans doublon.</p>
      {error && <ErrorBox message={error} onRetry={reload} />}
      {!data && !error && <Loading />}
      {data && <div className="panel table-wrap"><table className="table"><thead><tr><th>Reçue</th><th>Type</th><th>Id Tebex</th><th>État</th><th>Erreur</th></tr></thead>
        <tbody>{data.map((w) => <tr key={s(w.id)}><td>{dateFr(w.received_at as string)}</td><td>{s(w.type)}</td><td className="small">{s(w.tebex_id)}</td><td>{s(w.status)}</td><td className="small">{s(w.error)}</td></tr>)}</tbody></table></div>}
    </>
  );
}

export function Logs() {
  const [level, setLevel] = useState('');
  const { data, error, reload } = useFetch<Row[]>(`/api/admin/logs${level ? `?level=${level}` : ''}`);
  return (
    <>
      <div className="admin-head"><h1>Journaux</h1><div className="row-gap"><select className="input" value={level} onChange={(e) => setLevel(e.target.value)}><option value="">Tous</option><option value="error">Erreurs</option><option value="warn">Avertissements</option><option value="info">Informations</option></select><button className="btn btn-sm" onClick={reload}>Actualiser</button></div></div>
      {error && <ErrorBox message={error} onRetry={reload} />}
      {!data && !error && <Loading />}
      {data && <div className="panel table-wrap"><table className="table"><thead><tr><th>Date</th><th>Niveau</th><th>Acteur</th><th>Action</th><th>Cible</th><th>Détails</th></tr></thead>
        <tbody>{data.map((l) => <tr key={s(l.id)}><td className="small">{dateFr(l.created_at as string)}</td><td><span className={`badge ${l.level === 'error' ? 'badge-red' : l.level === 'warn' ? 'badge-amber' : 'badge-muted'}`}>{s(l.level)}</span></td>
          <td className="small">{s(l.actor_type)} {l.actor_id ? `#${s(l.actor_id)}` : ''}</td><td>{s(l.action)}</td><td className="small">{s(l.target)}</td><td className="small mono">{l.details ? JSON.stringify(l.details) : ''}</td></tr>)}</tbody></table></div>}
    </>
  );
}
