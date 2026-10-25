// Parcours complet : liaison, commande, connexion Tebex, paiement confirmé, livraison en jeu, remboursement, expiration.
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { exec, one, rows } from '../src/db.js';
import { sweepExpired } from '../src/services/deliveries.js';
import { completedEvent, game, resetDb, setup, signedWebhook } from './helpers.js';

const CFX = '1234567';
const ctx = setup();
const { app, pool, tebex } = ctx;

async function linkedAgent(cfx = CFX) {
  const code = await game(app).post('/link-code', { cfxId: cfx, name: 'Alex', identifiers: { license: 'license:abc', discord: 'discord:42' } });
  expect(code.status).toBe(200);
  const agent = ctx.agent();
  const res = await agent.post('/api/auth/link').send({ code: code.body.code });
  expect(res.status).toBe(200);
  return { agent, csrf: res.body.csrfToken as string };
}

async function productId(slug: string) { return (await one<{ id: number }>(pool, 'SELECT id FROM products WHERE slug = ?', [slug]))!.id; }

beforeAll(async () => { await resetDb(); });
beforeEach(async () => {
  await resetDb();
  tebex.baskets.clear(); tebex.calls = []; tebex.fail = false;
  await exec(pool, "UPDATE products SET tebex_package_id = 9001 WHERE slug = 'vip-or'");
  await exec(pool, "UPDATE products SET tebex_package_id = 9002 WHERE slug = 'pack-demarrage'");
});
afterAll(async () => { await pool.end(); });

describe('liaison des comptes', () => {
  it('un code n\'est utilisable qu\'une fois et rattache les identifiants relevés par le serveur', async () => {
    const code = await game(app).post('/link-code', { cfxId: CFX, name: 'Alex', identifiers: { license: 'license:abc', evil: 'x' } });
    expect(code.body.code).toMatch(/^[A-Z2-9]{8}$/);
    const a = await ctx.agent().post('/api/auth/link').send({ code: code.body.code });
    expect(a.status).toBe(200);
    expect(a.body.user.cfxId).toBe(CFX);
    const b = await ctx.agent().post('/api/auth/link').send({ code: code.body.code });
    expect(b.status).toBe(400);
    const ids = await rows<{ kind: string }>(pool, 'SELECT kind FROM linked_accounts ORDER BY kind');
    expect(ids.map((i) => i.kind)).toEqual(['fivem', 'license']);
  });
  it('l\'API de jeu refuse un jeton absent ou faux', async () => {
    const { default: request } = await import('supertest');
    expect((await request(app).post('/api/game/link-code').send({ cfxId: CFX })).status).toBe(401);
    expect((await request(app).post('/api/game/link-code').set('Authorization', 'Bearer faux').send({ cfxId: CFX })).status).toBe(401);
  });
  it('sans identifiant Cfx.re, pas de code', async () => {
    expect((await game(app).post('/link-code', { cfxId: 'abc' })).status).toBe(400);
  });
});

describe('commande et paiement', () => {
  it('parcours complet : panier → connexion Cfx.re → paquets ajoutés → paiement confirmé → livraison', async () => {
    const { agent, csrf } = await linkedAgent();
    const vip = await productId('vip-or');
    // Prix envoyé par le navigateur : ignoré
    const co = await agent.post('/api/checkout').set('X-CSRF-Token', csrf).send({ items: [{ productId: vip, quantity: 1, priceCents: 1 }] });
    expect(co.status).toBe(200);
    expect(co.body.redirectUrl).toContain('ident.tebex.test/fivem');
    const order = await one<{ id: number; status: string; total_cents: number; tebex_basket_ident: string }>(pool, 'SELECT * FROM orders WHERE public_ref = ?', [co.body.ref]);
    expect(order!.status).toBe('pending');
    expect(order!.total_cents).toBe(1500);

    // Retour sans connexion Cfx.re → renvoyé vers la connexion
    let cont = await ctx.agent().get(`/api/checkout/${co.body.ref}/continue`);
    expect(cont.status).toBe(303);
    expect(cont.headers.location).toContain('ident.tebex.test');
    // Connexion avec le bon compte → paquets ajoutés une seule fois → paiement Tebex
    tebex.login(order!.tebex_basket_ident, CFX);
    cont = await ctx.agent().get(`/api/checkout/${co.body.ref}/continue`);
    expect(cont.headers.location).toBe(`https://checkout.tebex.test/${order!.tebex_basket_ident}`);
    await ctx.agent().get(`/api/checkout/${co.body.ref}/continue`);
    expect(tebex.calls.filter((c) => c.startsWith('addPackage'))).toEqual(['addPackage:9001x1']);

    // Retour du navigateur sur la page de confirmation : toujours « en attente »
    expect((await ctx.agent().get(`/api/orders/${co.body.ref}/status`)).body.status).toBe('pending');

    // Notification Tebex signée → payée + récompense + tâche de livraison
    const wh = await signedWebhook(app, completedEvent({ id: 'evt-1', tx: 'tbx-1', ref: co.body.ref, cfx: CFX, products: [{ id: 9001 }] }));
    expect(wh.status).toBe(200);
    const paid = await one<{ status: string }>(pool, 'SELECT status FROM orders WHERE id = ?', [order!.id]);
    expect(paid!.status).toBe('paid');
    const rw = await rows<{ type: string; status: string; expires_at: Date | null }>(pool, 'SELECT * FROM rewards');
    expect(rw).toHaveLength(1);
    expect(rw[0]!.type).toBe('group');
    const days = (new Date(rw[0]!.expires_at!).getTime() - Date.now()) / 86_400_000;
    expect(days).toBeGreaterThan(29.9); expect(days).toBeLessThan(30.1);

    // Joueur hors ligne : rien n'est réservé pour lui
    expect((await game(app).post('/deliveries/claim', { cfxIds: ['999'] })).body).toEqual([]);
    // Joueur connecté : la tâche est réservée, exécutée, confirmée
    const claim = await game(app).post('/deliveries/claim', { cfxIds: [CFX] });
    expect(claim.body).toHaveLength(1);
    expect(claim.body[0]).toMatchObject({ action: 'grant', type: 'group', params: { name: 'vip_or' }, recipientCfxId: CFX });
    expect((await game(app).post('/deliveries/claim', { cfxIds: [CFX] })).body).toEqual([]);   // déjà réservée
    const done = await game(app).post(`/deliveries/${claim.body[0].id}/result`, { ok: true, meta: { citizenid: 'ABC123' } });
    expect(done.body.status).toBe('done');
    expect((await one<{ status: string }>(pool, 'SELECT status FROM rewards'))!.status).toBe('delivered');
    // Confirmation répétée (réponse perdue) : sans effet
    expect((await game(app).post(`/deliveries/${claim.body[0].id}/result`, { ok: true })).body.status).toBe('done');

    // Historique et avantages actifs
    const hist = await agent.get('/api/account/orders');
    expect(hist.body[0]).toMatchObject({ status: 'paid', items: [{ name: 'VIP Or', delivery: 'delivered' }] });
    const sum = await game(app).get(`/players/${CFX}/summary`);
    expect(sum.body.entitlements).toMatchObject([{ type: 'group', name: 'vip_or' }]);
  });

  it('notification reçue deux fois (même id, ou nouvel id pour la même transaction) : une seule récompense', async () => {
    const ev = completedEvent({ id: 'evt-dup', tx: 'tbx-dup', cfx: CFX, products: [{ id: 9002, qty: 2 }] });
    expect((await signedWebhook(app, ev)).status).toBe(200);
    expect((await signedWebhook(app, ev)).status).toBe(200);
    expect((await signedWebhook(app, { ...ev, id: 'evt-dup-2' })).status).toBe(200);
    // 2 unités × 2 récompenses (téléphone + bandages)
    expect((await rows(pool, 'SELECT id FROM rewards'))).toHaveLength(4);
    expect((await rows(pool, 'SELECT id FROM delivery_jobs'))).toHaveLength(4);
    expect((await rows(pool, 'SELECT id FROM orders'))).toHaveLength(1);
    // Achat fait directement sur la boutique Tebex : commande créée depuis la notification
    expect((await one<{ source: string }>(pool, 'SELECT source FROM orders'))!.source).toBe('tebex');
  });

  it('signature invalide ou absente : refusée, rien n\'est enregistré', async () => {
    const ev = completedEvent({ id: 'evt-bad', tx: 'tbx-bad', cfx: CFX, products: [{ id: 9001 }] });
    expect((await signedWebhook(app, ev, 'mauvais-secret-mauvais')).status).toBe(401);
    const { default: request } = await import('supertest');
    expect((await request(app).post('/api/webhooks/tebex').set('Content-Type', 'application/json').send(JSON.stringify(ev))).status).toBe(401);
    expect(await rows(pool, 'SELECT id FROM webhook_events')).toHaveLength(0);
    expect(await rows(pool, 'SELECT id FROM orders')).toHaveLength(0);
  });

  it('webhook de validation Tebex : renvoie l\'id', async () => {
    const res = await signedWebhook(app, { id: 'val-123', type: 'validation.webhook', subject: {} });
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ id: 'val-123' });
  });

  it('paiement refusé : commande échouée, aucune récompense', async () => {
    const { agent, csrf } = await linkedAgent();
    const co = await agent.post('/api/checkout').set('X-CSRF-Token', csrf).send({ items: [{ productId: await productId('vip-or'), quantity: 1 }] });
    await signedWebhook(app, { id: 'evt-dec', type: 'payment.declined', subject: { transaction_id: 'tbx-dec', custom: { order_ref: co.body.ref }, status: { description: 'Declined' } } });
    expect((await one<{ status: string }>(pool, 'SELECT status FROM orders'))!.status).toBe('failed');
    expect(await rows(pool, 'SELECT id FROM rewards')).toHaveLength(0);
  });

  it('mauvais compte Cfx.re connecté sur Tebex : paiement bloqué', async () => {
    const { agent, csrf } = await linkedAgent();
    const co = await agent.post('/api/checkout').set('X-CSRF-Token', csrf).send({ items: [{ productId: await productId('vip-or'), quantity: 1 }] });
    const o = await one<{ tebex_basket_ident: string }>(pool, 'SELECT tebex_basket_ident FROM orders');
    tebex.login(o!.tebex_basket_ident, '7777777');
    const cont = await ctx.agent().get(`/api/checkout/${co.body.ref}/continue`);
    expect(cont.headers.location).toContain('/erreur?raison=mauvais-compte');
    expect(tebex.calls.some((c) => c.startsWith('addPackage'))).toBe(false);
  });

  it('produit non relié à Tebex ou inactif : refusé ; Tebex en panne : commande annulée', async () => {
    const { agent, csrf } = await linkedAgent();
    const diamant = await productId('vip-diamant');
    expect((await agent.post('/api/checkout').set('X-CSRF-Token', csrf).send({ items: [{ productId: diamant, quantity: 1 }] })).status).toBe(400);
    tebex.fail = true;
    const r = await agent.post('/api/checkout').set('X-CSRF-Token', csrf).send({ items: [{ productId: await productId('vip-or'), quantity: 1 }] });
    expect(r.status).toBe(502);
    expect((await one<{ status: string }>(pool, 'SELECT status FROM orders'))!.status).toBe('cancelled');
  });

  it('commande sans jeton CSRF : refusée', async () => {
    const { agent } = await linkedAgent();
    expect((await agent.post('/api/checkout').send({ items: [{ productId: await productId('vip-or'), quantity: 1 }] })).status).toBe(403);
  });

  it('commande depuis le jeu : même parcours, compte imposé par le serveur de jeu', async () => {
    const co = await game(app).post('/checkout', { cfxId: CFX, name: 'Alex', items: [{ productId: await productId('pack-demarrage'), quantity: 1 }] });
    expect(co.status).toBe(200);
    expect((await one<{ source: string; cfx_id: string }>(pool, 'SELECT source, cfx_id FROM orders'))).toMatchObject({ source: 'game', cfx_id: CFX });
  });
});

describe('livraison, échecs et révocation', () => {
  it('échecs successifs : nouvel essai différé puis « échouée », relance par un admin', async () => {
    await signedWebhook(app, completedEvent({ id: 'e1', tx: 't1', cfx: CFX, products: [{ id: 9001 }] }));
    for (let i = 1; i <= 8; i++) {
      await exec(pool, 'UPDATE delivery_jobs SET next_attempt_at = UTC_TIMESTAMP()');
      const c = await game(app).post('/deliveries/claim', { cfxIds: [CFX] });
      expect(c.body).toHaveLength(1);
      const r = await game(app).post(`/deliveries/${c.body[0].id}/result`, { ok: false, error: 'Personnage non chargé' });
      expect(r.body.status).toBe(i < 8 ? 'pending' : 'failed');
    }
    const job = await one<{ id: number; status: string; last_error: string }>(pool, 'SELECT * FROM delivery_jobs');
    expect(job).toMatchObject({ status: 'failed', last_error: 'Personnage non chargé' });
    expect((await one<{ status: string }>(pool, 'SELECT status FROM rewards'))!.status).toBe('failed');
    const { retryJob } = await import('../src/services/deliveries.js');
    await retryJob(pool, job!.id);
    expect((await game(app).post('/deliveries/claim', { cfxIds: [CFX] })).body).toHaveLength(1);
  });

  it('tâche réservée sans réponse depuis plus de 5 minutes : de nouveau disponible', async () => {
    await signedWebhook(app, completedEvent({ id: 'e2', tx: 't2', cfx: CFX, products: [{ id: 9001 }] }));
    await game(app).post('/deliveries/claim', { cfxIds: [CFX] });
    await exec(pool, 'UPDATE delivery_jobs SET claimed_at = UTC_TIMESTAMP() - INTERVAL 6 MINUTE');
    expect((await game(app).post('/deliveries/claim', { cfxIds: [CFX] })).body).toHaveLength(1);
  });

  it('remboursement : grade livré retiré, objets non livrés annulés, objets livrés signalés', async () => {
    await signedWebhook(app, completedEvent({ id: 'e3', tx: 't3', cfx: CFX, products: [{ id: 9001 }, { id: 9002 }] }));
    const claim = await game(app).post('/deliveries/claim', { cfxIds: [CFX] });
    // On livre le grade et le téléphone, pas les bandages
    for (const j of claim.body.filter((x: { type: string; params: { name: string } }) => x.type === 'group' || x.params.name === 'phone')) {
      await game(app).post(`/deliveries/${j.id}/result`, { ok: true });
    }
    const left = claim.body.find((x: { params: { name: string } }) => x.params.name === 'bandage');
    await game(app).post(`/deliveries/${left.id}/result`, { ok: false, error: 'inventaire plein' });
    await signedWebhook(app, { id: 'e3-ref', type: 'payment.refunded', subject: { transaction_id: 't3', status: { description: 'Refund' } } });
    expect((await one<{ status: string }>(pool, 'SELECT status FROM orders'))!.status).toBe('refunded');
    const rw = await rows<{ type: string; status: string; params: unknown }>(pool, 'SELECT type, status, params FROM rewards ORDER BY id');
    expect(rw.map((r) => `${r.type}:${r.status}`)).toEqual(['group:revoke_pending', 'item:delivered', 'item:cancelled']);
    const revoke = await game(app).post('/deliveries/claim', { cfxIds: [CFX] });
    expect(revoke.body).toMatchObject([{ action: 'revoke', type: 'group' }]);
    await game(app).post(`/deliveries/${revoke.body[0].id}/result`, { ok: true });
    expect((await one<{ status: string }>(pool, "SELECT status FROM rewards WHERE type = 'group'"))!.status).toBe('revoked');
    const warn = await rows(pool, "SELECT id FROM audit_logs WHERE action = 'payment.refunded' AND level = 'warn'");
    expect(warn).toHaveLength(1);
  });

  it('fin de durée : retrait automatique ; achats successifs : périodes enchaînées', async () => {
    await signedWebhook(app, completedEvent({ id: 'e4', tx: 't4', cfx: CFX, products: [{ id: 9001 }] }));
    await signedWebhook(app, completedEvent({ id: 'e5', tx: 't5', cfx: CFX, products: [{ id: 9001 }] }));
    const exp = await rows<{ expires_at: Date }>(pool, 'SELECT expires_at FROM rewards ORDER BY id');
    const gap = (new Date(exp[1]!.expires_at).getTime() - new Date(exp[0]!.expires_at).getTime()) / 86_400_000;
    expect(Math.round(gap)).toBe(30);
    const c = await game(app).post('/deliveries/claim', { cfxIds: [CFX] });
    for (const j of c.body) await game(app).post(`/deliveries/${j.id}/result`, { ok: true });
    await exec(pool, 'UPDATE rewards SET expires_at = UTC_TIMESTAMP() - INTERVAL 1 MINUTE WHERE id = (SELECT id FROM (SELECT MIN(id) AS id FROM rewards) x)');
    await sweepExpired(pool);
    await sweepExpired(pool);   // sans effet la seconde fois
    const jobs = await rows<{ action: string }>(pool, "SELECT action FROM delivery_jobs WHERE action = 'revoke'");
    expect(jobs).toHaveLength(1);
    // Le second achat reste actif
    expect((await game(app).get(`/players/${CFX}/summary`)).body.entitlements).toHaveLength(1);
  });

  it('cadeau Tebex : la récompense va au destinataire', async () => {
    await signedWebhook(app, completedEvent({ id: 'e6', tx: 't6', cfx: CFX, products: [{ id: 9001, giftTo: '5555' }] }));
    expect((await one<{ recipient_cfx_id: string }>(pool, 'SELECT recipient_cfx_id FROM rewards'))!.recipient_cfx_id).toBe('5555');
  });

  it('paquet Tebex inconnu : commande payée, erreur journalisée, aucune récompense', async () => {
    await signedWebhook(app, completedEvent({ id: 'e7', tx: 't7', cfx: CFX, products: [{ id: 123456 }] }));
    expect((await one<{ status: string }>(pool, 'SELECT status FROM orders'))!.status).toBe('paid');
    expect(await rows(pool, 'SELECT id FROM rewards')).toHaveLength(0);
    expect(await rows(pool, "SELECT id FROM audit_logs WHERE action = 'payment.unknown_package' AND level = 'error'")).toHaveLength(1);
  });
});
