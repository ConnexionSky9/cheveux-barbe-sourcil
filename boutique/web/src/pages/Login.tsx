import { useState, type FormEvent } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import { api, ApiError, type User } from '../api';
import { Icon } from '../components/Icon';
import { PageHead } from '../components/ui';
import { useStore } from '../store';

export default function Login() {
  const { user, setSession, notify, config } = useStore();
  const [code, setCode] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const nav = useNavigate();
  const [params] = useSearchParams();
  const back = params.get('retour')?.startsWith('/') ? params.get('retour')! : '/compte';

  async function submit(e: FormEvent) {
    e.preventDefault();
    setBusy(true); setError(null);
    try {
      const r = await api.post<{ user: User; csrfToken: string }>('/api/auth/link', { code });
      setSession(r.user, r.csrfToken);
      notify(`Bienvenue, ${r.user.displayName} !`, 'success');
      nav(back);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Erreur inattendue.');
    } finally { setBusy(false); }
  }

  return (
    <>
      <PageHead eyebrow="Mon compte" title="Lier mon compte FiveM">Vos achats sont rattachés à votre compte Cfx.re. Aucune inscription ni mot de passe.</PageHead>
      <div className="container section login-layout">
        <ol className="steps panel panel-pad">
          <li><span>1</span><div><strong>Connectez-vous au serveur {config?.serverName ?? 'Elyzea'}</strong><p className="muted small">Avec FiveM ouvert sur votre compte Cfx.re.</p></div></li>
          <li><span>2</span><div><strong>Tapez <code>/boutique_lier</code> dans le chat</strong><p className="muted small">Ou ouvrez la boutique en jeu (<code>/boutique</code>) › « Lier mon compte web ». Un code de 8 caractères s'affiche, valable 10 minutes.</p></div></li>
          <li><span>3</span><div><strong>Saisissez le code ici</strong><p className="muted small">Le code ne fonctionne qu'une fois. Ne le communiquez à personne.</p></div></li>
        </ol>
        <form className="panel panel-pad" onSubmit={submit}>
          {user && <p className="alert alert-success small">Déjà connecté : {user.displayName}. <Link to="/compte">Voir mon compte</Link></p>}
          <div className="field">
            <label htmlFor="code">Code de liaison</label>
            <input id="code" className="input code-input" autoComplete="one-time-code" inputMode="text" maxLength={11} placeholder="ABCD 2345"
              value={code} onChange={(e) => setCode(e.target.value.toUpperCase())} required />
          </div>
          {error && <p className="alert alert-error small" role="alert">{error}</p>}
          <button className="btn btn-primary btn-block" disabled={busy || code.replace(/[^A-Z0-9]/gi, '').length !== 8}><Icon name="lock" size={16} />{busy ? 'Vérification…' : 'Lier mon compte'}</button>
        </form>
      </div>
    </>
  );
}
