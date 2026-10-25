// Pages d'information : erreur, FAQ, support, pages légales, 404.
// Les pages légales sont des MODÈLES : complétez les mentions entre crochets avant la mise en ligne.
import type { ReactNode } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { Icon } from '../components/Icon';
import { Empty, PageHead } from '../components/ui';
import { useStore } from '../store';

const REASONS: Record<string, string> = {
  'mauvais-compte': 'Vous vous êtes connecté sur Tebex avec un autre compte Cfx.re que celui lié à la boutique. Reconnectez-vous avec le compte FiveM que vous utilisez en jeu, puis relancez la commande depuis le panier.',
  'commande-introuvable': 'Cette commande est introuvable. Relancez votre achat depuis le panier.',
  'commande-terminee': 'Cette commande est déjà terminée ou annulée. Consultez votre historique.',
  'paiement-indisponible': 'Le service de paiement ne répond pas pour le moment. Aucun montant n\'a été prélevé. Réessayez dans quelques minutes.',
};

export function ErrorPage() {
  const [p] = useSearchParams();
  return (
    <div className="container section narrow">
      <Empty icon="x" title="Une erreur est survenue">
        <p>{REASONS[p.get('raison') ?? ''] ?? 'La page demandée n\'a pas pu être affichée.'}</p>
        <div className="row-gap" style={{ justifyContent: 'center' }}><Link to="/panier" className="btn btn-primary">Mon panier</Link><Link to="/support" className="btn">Support</Link></div>
      </Empty>
    </div>
  );
}

export function NotFound() {
  return <div className="container section"><Empty icon="help" title="Page introuvable"><Link to="/" className="btn">Retour à l'accueil</Link></Empty></div>;
}

const FAQ: [string, ReactNode][] = [
  ['Comment mes achats arrivent-ils en jeu ?', 'Après la confirmation du paiement par Tebex, le serveur livre automatiquement chaque produit à votre personnage actif. Si vous n\'êtes pas connecté, la livraison attend votre prochaine connexion.'],
  ['Pourquoi dois-je lier mon compte ?', 'Pour être certain que vos achats arrivent sur votre compte. Le lien se fait avec votre compte Cfx.re (FiveM), jamais avec un simple pseudonyme.'],
  ['Pourquoi Tebex me demande-t-il de me connecter à Cfx.re ?', 'C\'est la règle pour les serveurs FiveM : Tebex vérifie le compte qui reçoit l\'achat. Utilisez le même compte que sur le serveur.'],
  ['Mon paiement est validé mais rien n\'est arrivé.', 'Connectez-vous au serveur avec votre personnage : la livraison se fait dans la minute. Si votre historique indique « échec », contactez le support avec la référence de la commande.'],
  ['Que se passe-t-il à la fin d\'un produit temporaire ?', 'Il est retiré automatiquement à la date indiquée dans votre compte. Racheter le même produit prolonge la durée.'],
  ['Puis-je offrir un produit ?', 'Si l\'option cadeau est activée sur Tebex pour ce produit, la récompense est livrée au compte FiveM désigné lors du paiement.'],
  ['Mes données bancaires sont-elles stockées ?', 'Non. Le paiement est entièrement traité par Tebex. Nous ne recevons qu\'une confirmation de paiement.'],
];

export function Faq() {
  return (
    <>
      <PageHead eyebrow="Aide" title="Questions fréquentes" />
      <div className="container section narrow faq">
        {FAQ.map(([q, a]) => <details key={q} className="panel"><summary>{q}<Icon name="arrow" size={16} /></summary><div className="muted">{a}</div></details>)}
      </div>
    </>
  );
}

export function Support() {
  const { config } = useStore();
  return (
    <>
      <PageHead eyebrow="Aide" title="Support">Un problème avec un achat ? Nous sommes là.</PageHead>
      <div className="container section narrow">
        <div className="panel panel-pad">
          <h3>Avant de nous contacter</h3>
          <ul className="perks"><li>Vérifiez l'état de la commande dans <Link to="/compte">votre historique</Link>.</li><li>Connectez-vous en jeu avec votre personnage : les livraisons en attente arrivent dans la minute.</li><li>Notez la référence de la commande (8 premiers caractères).</li></ul>
          <h3 style={{ marginTop: '1.5rem' }}>Nous contacter</h3>
          <div className="row-gap">
            {config?.discordUrl && <a className="btn btn-primary" href={config.discordUrl} target="_blank" rel="noreferrer">Ticket sur Discord</a>}
            {config?.supportEmail && <a className="btn" href={`mailto:${config.supportEmail}`}>{config.supportEmail}</a>}
            {!config?.discordUrl && !config?.supportEmail && <p className="muted">Le contact du support n'est pas encore configuré (DISCORD_URL / SUPPORT_EMAIL).</p>}
          </div>
          <p className="muted small" style={{ marginTop: '1rem' }}>Pour une question sur le paiement lui-même (reçu, prélèvement), vous pouvez aussi contacter le support de Tebex depuis le reçu reçu par e-mail.</p>
        </div>
      </div>
    </>
  );
}

function Legal({ title, children }: { title: string; children: ReactNode }) {
  return (
    <>
      <PageHead eyebrow="Informations légales" title={title} />
      <div className="container section narrow legal">
        <p className="alert alert-info small">Modèle à compléter et à faire relire : les mentions entre [crochets] dépendent de votre structure (association, entreprise, particulier) et de votre pays.</p>
        {children}
      </div>
    </>
  );
}

export function Cgv() {
  const { config } = useStore();
  const n = config?.serverName ?? 'Elyzea';
  return (
    <Legal title="Conditions générales de vente">
      <h3>1. Objet</h3><p>Les présentes conditions encadrent la vente d'avantages numériques utilisables uniquement sur le serveur de jeu {n} (« le Serveur »), édité par [nom de l'éditeur, statut, adresse, contact].</p>
      <h3>2. Revendeur et paiement</h3><p>Les paiements sont encaissés par Tebex Limited, revendeur officiel (« merchant of record ») des serveurs FiveM. Les conditions de Tebex s'appliquent au paiement. {n} ne collecte ni ne conserve aucune donnée bancaire.</p>
      <h3>3. Produits</h3><p>Les produits sont des avantages numériques en jeu (grades, véhicules virtuels, objets, cosmétiques). Ils n'ont aucune valeur monétaire, ne sont ni échangeables ni convertibles en argent réel. Leur durée est indiquée sur chaque fiche ; « Permanent » signifie : tant que le Serveur et le produit existent.</p>
      <h3>4. Livraison</h3><p>La livraison est automatique après confirmation du paiement par Tebex, sur le compte FiveM (Cfx.re) utilisé lors du paiement, au personnage actif lors de la connexion suivante.</p>
      <h3>5. Droit de rétractation</h3><p>[À adapter selon votre pays : pour un contenu numérique fourni immédiatement, l'acheteur peut renoncer expressément à son droit de rétractation lors de la commande.]</p>
      <h3>6. Sanctions</h3><p>Un achat ne place pas le joueur au-dessus du règlement du Serveur. Une sanction (bannissement compris) n'ouvre pas droit à remboursement.</p>
      <h3>7. Contact</h3><p>[Adresse e-mail de contact, Discord]</p>
    </Legal>
  );
}

export function Refund() {
  return (
    <Legal title="Politique de remboursement">
      <p>Les demandes de remboursement sont étudiées au cas par cas via le support, dans un délai de [14] jours après l'achat, notamment si un produit n'a pas pu être livré.</p>
      <p>Un remboursement entraîne le retrait automatique des avantages retirables (grades, véhicules). Les objets et l'argent virtuels déjà utilisés sont traités manuellement par l'équipe.</p>
      <p>Une opposition bancaire (« chargeback ») entraîne le retrait des avantages et peut entraîner la suspension du compte sur le Serveur.</p>
      <p>Les remboursements sont effectués par Tebex, sur le moyen de paiement utilisé.</p>
    </Legal>
  );
}

export function Privacy() {
  return (
    <Legal title="Politique de confidentialité">
      <h3>Données traitées</h3><p>Identifiant de compte Cfx.re (FiveM), pseudonyme, identifiants de jeu relevés par le serveur lors de la liaison (licence Rockstar, Discord si connecté), historique d'achats et de livraisons, adresse IP des connexions (sécurité).</p>
      <h3>Finalités</h3><p>Associer vos achats à votre compte, livrer les produits en jeu, assurer le support, prévenir la fraude.</p>
      <h3>Paiement</h3><p>Les données de paiement sont traitées exclusivement par Tebex, selon sa propre politique de confidentialité.</p>
      <h3>Cookies</h3><p>Un cookie de session strictement nécessaire (connexion). Le panier est conservé dans votre navigateur (stockage local). Aucun cookie publicitaire.</p>
      <h3>Durée et droits</h3><p>[Durées de conservation.] Vous pouvez demander l'accès ou la suppression de vos données : [contact]. Les données nécessaires aux obligations comptables sont conservées par Tebex.</p>
    </Legal>
  );
}
