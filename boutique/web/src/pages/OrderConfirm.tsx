// Page de retour après Tebex. Elle n'affiche « payée » que si l'API l'a confirmé (notification Tebex reçue).
import { useEffect, useRef, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { api, ApiError, ORDER_STATUS } from '../api';
import { Icon } from '../components/Icon';
import { ErrorBox, Loading, PageHead } from '../components/ui';
import { useStore } from '../store';

interface Status { ref: string; status: string; items: { name: string; quantity: number }[]; deliveries: { pending: number; delivered: number; failed: number } }

export default function OrderConfirm() {
  const { ref = '' } = useParams();
  const { clearCart } = useStore();
  const [s, setS] = useState<Status | null>(null);
  const [error, setError] = useState<string | null>(null);
  const tries = useRef(0);

  useEffect(() => {
    let timer: number | undefined;
    let stopped = false;
    const poll = () => {
      api.get<Status>(`/api/orders/${encodeURIComponent(ref)}/status`).then((r) => {
        if (stopped) return;
        setS(r);
        if (r.status === 'paid' && sessionStorage.getItem('elyzea-derniere-commande') === ref) { clearCart(); sessionStorage.removeItem('elyzea-derniere-commande'); }
        // Tant que la confirmation n'est pas arrivée (ou que la livraison est en cours), on revérifie, de moins en moins souvent
        const waiting = r.status === 'pending' || (r.status === 'paid' && r.deliveries.pending > 0);
        if (waiting && tries.current < 60) { tries.current++; timer = window.setTimeout(poll, Math.min(15000, 3000 + tries.current * 500)); }
      }).catch((e: ApiError) => !stopped && setError(e.message));
    };
    poll();
    return () => { stopped = true; window.clearTimeout(timer); };
  }, [ref, clearCart]);

  if (error) return <div className="container section"><ErrorBox message={error} /></div>;
  if (!s) return <Loading label="Vérification de votre commande…" />;
  const st = ORDER_STATUS[s.status];

  return (
    <>
      <PageHead eyebrow="Commande" title={s.status === 'paid' ? 'Merci pour votre soutien !' : s.status === 'pending' ? 'Paiement en cours de confirmation' : 'Commande non aboutie'} />
      <div className="container section narrow">
        <div className="panel panel-pad">
          <div className="row-gap"><span className={`badge ${st?.tone ?? 'badge-muted'}`}>{st?.label ?? s.status}</span><span className="muted small">Réf. {s.ref.slice(0, 8)}</span></div>
          <ul className="perks" style={{ margin: '1rem 0' }}>{s.items.map((i, k) => <li key={k}>{i.quantity} × {i.name}</li>)}</ul>
          {s.status === 'pending' && (
            <p className="alert alert-info"><Icon name="clock" size={16} /> Nous attendons la confirmation officielle de Tebex. Cela prend généralement moins d'une minute ;
              cette page se met à jour toute seule. Si vous avez annulé le paiement, aucun montant n'a été prélevé.</p>
          )}
          {s.status === 'paid' && (
            <p className="alert alert-success">
              Paiement confirmé. {s.deliveries.pending > 0
                ? `${s.deliveries.pending} récompense(s) seront livrées en jeu dès que vous serez connecté(e) avec votre personnage.`
                : s.deliveries.delivered > 0 ? 'Tout a été livré en jeu.' : 'Vos avantages sont en cours de préparation.'}
              {s.deliveries.failed > 0 && ' Une livraison a échoué : contactez le support avec la référence ci-dessus.'}
            </p>
          )}
          {['failed', 'cancelled'].includes(s.status) && <p className="alert alert-error">Le paiement n'a pas abouti. Aucun produit n'a été attribué.</p>}
          <div className="row-gap" style={{ marginTop: '1rem' }}><Link to="/compte" className="btn btn-primary">Mon historique</Link><Link to="/boutique" className="btn">Continuer mes achats</Link></div>
        </div>
      </div>
    </>
  );
}
