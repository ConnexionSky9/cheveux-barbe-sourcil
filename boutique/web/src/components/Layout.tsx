import { useEffect, useState } from 'react';
import { Link, NavLink, Outlet, useLocation } from 'react-router-dom';
import { useStore } from '../store';
import { Icon } from './Icon';
import { Toasts } from './ui';

export function Layout() {
  const { cart, user, config } = useStore();
  const [open, setOpen] = useState(false);
  const loc = useLocation();
  useEffect(() => { setOpen(false); window.scrollTo({ top: 0 }); }, [loc.pathname]);
  const count = cart.reduce((a, l) => a + l.quantity, 0);
  const name = config?.serverName ?? 'Elyzea';

  return (
    <div className="site">
      <a className="skip" href="#contenu">Aller au contenu</a>
      <header className="topbar">
        <div className="container topbar-inner">
          <Link to="/" className="brand" aria-label={`${name} — accueil`}>
            <img src="/images/logo-192.webp" alt="" width={44} height={44} />
            <span><strong>{name}</strong><small>Boutique officielle</small></span>
          </Link>
          <button className="btn btn-ghost nav-toggle" aria-expanded={open} aria-label="Menu" onClick={() => setOpen((o) => !o)}><Icon name="menu" /></button>
          <nav className={`nav ${open ? 'open' : ''}`} aria-label="Navigation principale">
            <NavLink to="/boutique">Boutique</NavLink>
            <NavLink to="/faq">FAQ</NavLink>
            <NavLink to="/support">Support</NavLink>
            <NavLink to={user ? '/compte' : '/connexion'} className="nav-account"><Icon name="user" size={18} />{user ? user.displayName : 'Connexion'}</NavLink>
            <NavLink to="/panier" className="nav-cart" aria-label={`Panier, ${count} article(s)`}><Icon name="cart" size={18} />Panier{count > 0 && <span className="count">{count}</span>}</NavLink>
          </nav>
        </div>
      </header>
      <main id="contenu"><Outlet /></main>
      <footer className="footer">
        <div className="container footer-grid">
          <div>
            <div className="brand"><img src="/images/logo-192.webp" alt="" width={40} height={40} /><span><strong>{name}</strong><small>Serveur GTA RP</small></span></div>
            <p className="muted small" style={{ marginTop: '1rem', maxWidth: 360 }}>
              Paiements traités par Tebex, revendeur officiel pour les serveurs FiveM. Aucune donnée bancaire n'est stockée par {name}.
            </p>
          </div>
          <div><h4>Boutique</h4><Link to="/boutique">Catalogue</Link><Link to="/panier">Panier</Link><Link to="/compte">Mon compte</Link></div>
          <div><h4>Aide</h4><Link to="/faq">FAQ</Link><Link to="/support">Support</Link>{config?.discordUrl && <a href={config.discordUrl} target="_blank" rel="noreferrer">Discord</a>}</div>
          <div><h4>Informations légales</h4><Link to="/cgv">Conditions générales de vente</Link><Link to="/remboursement">Politique de remboursement</Link><Link to="/confidentialite">Confidentialité</Link></div>
        </div>
        <div className="container footer-legal muted small">
          © {new Date().getFullYear()} {name}. Projet non affilié à Rockstar Games ni à Take-Two Interactive. GTA V est une marque de Take-Two Interactive.
        </div>
      </footer>
      <Toasts />
    </div>
  );
}
