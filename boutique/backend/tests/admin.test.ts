import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { one } from '../src/db.js';
import { upsertAdmin } from '../src/services/admins.js';
import { resetDb, setup } from './helpers.js';

const ctx = setup();
const { pool } = ctx;

async function login(username: string, password = 'mot-de-passe-solide-123', app = ctx) {
  const agent = app.agent();
  const r = await agent.post('/api/admin/login').send({ username, password });
  return { agent, r, csrf: r.body.csrfToken as string };
}

beforeAll(async () => {
  await resetDb();
  await upsertAdmin(pool, 'patron', 'mot-de-passe-solide-123', 'owner');
  await upsertAdmin(pool, 'modo', 'mot-de-passe-solide-123', 'support');
  await upsertAdmin(pool, 'gerant', 'mot-de-passe-solide-123', 'admin');
});
afterAll(async () => { await pool.end(); });

describe('panel d\'administration', () => {
  it('sans session : 401 sur toutes les routes sensibles', async () => {
    const a = ctx.agent();
    for (const p of ['/api/admin/stats', '/api/admin/products', '/api/admin/orders', '/api/admin/admins', '/api/admin/logs']) {
      expect((await a.get(p)).status).toBe(401);
    }
  });

  it('mauvais mot de passe puis verrouillage après 5 échecs', async () => {
    await upsertAdmin(pool, 'cible', 'mot-de-passe-solide-123', 'support');
    for (let i = 0; i < 4; i++) expect((await login('cible', 'faux-mot-de-passe')).r.body.code).toBe('invalid');
    expect((await login('cible', 'faux-mot-de-passe')).r.body.code).toBe('locked');
    expect((await login('cible')).r.body.code).toBe('locked');
  });

  it('rôles : le support lit mais ne modifie pas ; seul le propriétaire gère les admins', async () => {
    const support = await login('modo');
    expect(support.r.status).toBe(200);
    expect((await support.agent.get('/api/admin/products')).status).toBe(200);
    const pid = (await one<{ id: number }>(pool, "SELECT id FROM products WHERE slug = 'vip-or'"))!.id;
    expect((await support.agent.put(`/api/admin/products/${pid}/rewards`).set('X-CSRF-Token', support.csrf).send({ rewards: [] })).status).toBe(403);
    const gerant = await login('gerant');
    expect((await gerant.agent.get('/api/admin/admins')).status).toBe(403);
  });

  it('modification sans jeton CSRF : refusée ; avec : acceptée et journalisée', async () => {
    const { agent, csrf } = await login('gerant');
    const p = (await agent.get('/api/admin/products')).body.products.find((x: { slug: string }) => x.slug === 'vip-or');
    const body = { ...p, categoryId: p.category.id, priceCents: 1999, tebexPackageId: 4242 };
    expect((await agent.patch(`/api/admin/products/${p.id}`).send(body)).status).toBe(403);
    expect((await agent.patch(`/api/admin/products/${p.id}`).set('X-CSRF-Token', csrf).send(body)).status).toBe(200);
    expect((await one<{ price_cents: number }>(pool, 'SELECT price_cents FROM products WHERE id = ?', [p.id]))!.price_cents).toBe(1999);
    expect((await one<{ n: number }>(pool, "SELECT COUNT(*) AS n FROM audit_logs WHERE action = 'product.update'"))!.n).toBe(1);
    // Le produit est maintenant achetable sur le site
    expect((await ctx.agent().get('/api/products/vip-or')).body.available).toBe(true);
  });

  it('récompenses validées côté serveur', async () => {
    const { agent, csrf } = await login('gerant');
    const pid = (await one<{ id: number }>(pool, "SELECT id FROM products WHERE slug = 'vip-or'"))!.id;
    const bad = await agent.put(`/api/admin/products/${pid}/rewards`).set('X-CSRF-Token', csrf).send({ rewards: [{ type: 'command', params: { name: 'x', raw: 'quit' } }] });
    expect(bad.status).toBe(400);
    const ok = await agent.put(`/api/admin/products/${pid}/rewards`).set('X-CSRF-Token', csrf).send({ rewards: [{ type: 'vehicle', params: { model: 'sultan' } }, { type: 'group', params: { name: 'vip_or' } }] });
    expect(ok.status).toBe(200);
    expect((await agent.get(`/api/admin/products/${pid}`)).body.rewards.map((r: { type: string }) => r.type)).toEqual(['vehicle', 'group']);
  });

  it('le dernier propriétaire ne peut pas être rétrogradé', async () => {
    // Nouvelle instance : la limite de 10 connexions / 15 min par adresse est déjà atteinte dans ce fichier
    const fresh = setup();
    const { agent, csrf } = await login('patron', undefined, fresh);
    const me = (await agent.get('/api/admin/me')).body.admin;
    expect((await agent.patch(`/api/admin/admins/${me.id}`).set('X-CSRF-Token', csrf).send({ role: 'admin' })).status).toBe(409);
    await fresh.pool.end();
  });

  it('limite de tentatives de connexion par adresse', async () => {
    const r = await ctx.agent().post('/api/admin/login').send({ username: 'x', password: 'y' });
    expect(r.status).toBe(429);
  });

  it('le catalogue public ne contient ni récompenses ni identifiants Tebex', async () => {
    const res = await ctx.agent().get('/api/catalog');
    const p = res.body.products[0];
    expect(p).not.toHaveProperty('rewards');
    expect(p).not.toHaveProperty('tebexPackageId');
  });
});
