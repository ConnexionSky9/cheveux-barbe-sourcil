import { useState, type FormEvent } from 'react';
import { api, ApiError, dateFr } from '../api';
import { ErrorBox, Loading } from '../components/ui';
import { useStore } from '../store';
import { useAdmin, type Role } from './AdminApp';
import { useFetch } from './hooks';

interface A { id: number; username: string; role: Role; active: number; last_login_at: string | null; created_at: string }

export function Admins() {
  const me = useAdmin();
  const { notify } = useStore();
  const { data, error, reload } = useFetch<A[]>('/api/admin/admins');
  const [form, setForm] = useState({ username: '', password: '', role: 'support' as Role });
  const [err, setErr] = useState<string | null>(null);
  async function create(e: FormEvent) {
    e.preventDefault(); setErr(null);
    try { await api.post('/api/admin/admins', form); notify('Administrateur créé.', 'success'); setForm({ username: '', password: '', role: 'support' }); reload(); }
    catch (x) { setErr(x instanceof ApiError ? x.message : 'Erreur.'); }
  }
  async function patch(id: number, body: Record<string, unknown>) {
    try { await api.patch(`/api/admin/admins/${id}`, body); notify('Modifié.', 'success'); reload(); } catch (x) { notify(x instanceof ApiError ? x.message : 'Erreur', 'error'); }
  }
  async function resetPassword(id: number) {
    const pw = window.prompt('Nouveau mot de passe (12 caractères minimum) :');
    if (pw) await patch(id, { password: pw });
  }
  if (error) return <ErrorBox message={error} onRetry={reload} />;
  if (!data) return <Loading />;
  return (
    <>
      <div className="admin-head"><h1>Administrateurs</h1></div>
      <p className="muted small">Rôles : <strong>support</strong> (lecture seule), <strong>admin</strong> (catalogue, livraisons), <strong>owner</strong> (tout, y compris cette page).</p>
      <div className="panel table-wrap"><table className="table">
        <thead><tr><th>Identifiant</th><th>Rôle</th><th>État</th><th>Dernière connexion</th><th /></tr></thead>
        <tbody>{data.map((a) => (
          <tr key={a.id}><td>{a.username}{a.id === me.id && <span className="badge badge-muted" style={{ marginLeft: 8 }}>vous</span>}</td>
            <td><select className="input" value={a.role} onChange={(e) => patch(a.id, { role: e.target.value })}><option value="support">support</option><option value="admin">admin</option><option value="owner">owner</option></select></td>
            <td>{a.active ? <span className="badge badge-green">actif</span> : <span className="badge badge-muted">désactivé</span>}</td><td>{dateFr(a.last_login_at)}</td>
            <td className="row-gap"><button className="btn btn-sm" onClick={() => resetPassword(a.id)}>Mot de passe</button>{a.id !== me.id && <button className="btn btn-sm btn-ghost" onClick={() => patch(a.id, { active: !a.active })}>{a.active ? 'Désactiver' : 'Réactiver'}</button>}</td></tr>
        ))}</tbody>
      </table></div>
      <form className="panel panel-pad grid-2" style={{ marginTop: '1.5rem' }} onSubmit={create}>
        <h3 className="span-2">Ajouter un administrateur</h3>
        <div className="field"><label>Identifiant</label><input className="input" value={form.username} onChange={(e) => setForm({ ...form, username: e.target.value })} pattern="[a-zA-Z0-9_.\-]{3,32}" required /></div>
        <div className="field"><label>Rôle</label><select className="input" value={form.role} onChange={(e) => setForm({ ...form, role: e.target.value as Role })}><option value="support">support</option><option value="admin">admin</option><option value="owner">owner</option></select></div>
        <div className="field span-2"><label>Mot de passe (12 caractères minimum)</label><input className="input" type="password" autoComplete="new-password" minLength={12} value={form.password} onChange={(e) => setForm({ ...form, password: e.target.value })} required /></div>
        {err && <p className="alert alert-error small span-2">{err}</p>}
        <div className="span-2"><button className="btn btn-primary btn-sm">Créer</button></div>
      </form>
    </>
  );
}
