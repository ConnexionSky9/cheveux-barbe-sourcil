import { StrictMode, Suspense, lazy } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter, Route, Routes } from 'react-router-dom';
import '../../shared/theme.css';
import './site.css';
import { Layout } from './components/Layout';
import { Loading } from './components/ui';
import Account from './pages/Account';
import Cart from './pages/Cart';
import Catalog from './pages/Catalog';
import Home from './pages/Home';
import { Cgv, ErrorPage, Faq, NotFound, Privacy, Refund, Support } from './pages/Info';
import Login from './pages/Login';
import OrderConfirm from './pages/OrderConfirm';
import ProductPage from './pages/ProductPage';
import { StoreProvider } from './store';

// Le panel n'est chargé que pour les administrateurs (code séparé)
const AdminApp = lazy(() => import('./admin/AdminApp'));

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <StoreProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/admin/*" element={<Suspense fallback={<Loading />}><AdminApp /></Suspense>} />
          <Route element={<Layout />}>
            <Route index element={<Home />} />
            <Route path="boutique" element={<Catalog />} />
            <Route path="produit/:slug" element={<ProductPage />} />
            <Route path="panier" element={<Cart />} />
            <Route path="connexion" element={<Login />} />
            <Route path="compte" element={<Account />} />
            <Route path="commande/:ref" element={<OrderConfirm />} />
            <Route path="erreur" element={<ErrorPage />} />
            <Route path="faq" element={<Faq />} />
            <Route path="support" element={<Support />} />
            <Route path="cgv" element={<Cgv />} />
            <Route path="remboursement" element={<Refund />} />
            <Route path="confidentialite" element={<Privacy />} />
            <Route path="*" element={<NotFound />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </StoreProvider>
  </StrictMode>,
);
