import { describe, expect, it } from 'vitest';
import { normalizeCode, tebexSignature, verifyTebexSignature } from '../src/security.js';
import { validateReward } from '../src/services/rewardTypes.js';

describe('signature des webhooks Tebex', () => {
  const body = '{"id":"abc","type":"payment.completed"}';
  it('accepte la bonne signature (HMAC-SHA256 du SHA-256 du corps)', () => {
    expect(verifyTebexSignature(body, tebexSignature(body, 's3cret-s3cret-s3cret'), 's3cret-s3cret-s3cret')).toBe(true);
  });
  it('refuse un corps modifié, un mauvais secret, une signature absente ou mal formée', () => {
    const sig = tebexSignature(body, 's3cret-s3cret-s3cret');
    expect(verifyTebexSignature(body + ' ', sig, 's3cret-s3cret-s3cret')).toBe(false);
    expect(verifyTebexSignature(body, sig, 'autre-secret-autre')).toBe(false);
    expect(verifyTebexSignature(body, undefined, 's3cret-s3cret-s3cret')).toBe(false);
    expect(verifyTebexSignature(body, 'pas-hex', 's3cret-s3cret-s3cret')).toBe(false);
  });
});

describe('validation des récompenses', () => {
  it('accepte les paramètres valides', () => {
    expect(validateReward('vehicle', { model: 'sultan', garage: 'pillbox' }).type).toBe('vehicle');
    expect(validateReward('item', { name: 'phone', count: 2 }).params).toEqual({ name: 'phone', count: 2 });
  });
  it('refuse les types inconnus, les champs en trop et les commandes libres', () => {
    expect(() => validateReward('sql', {})).toThrow();
    expect(() => validateReward('item', { name: 'phone', count: 0 })).toThrow();
    expect(() => validateReward('group', { name: 'vip; quit' })).toThrow();
    expect(() => validateReward('command', { name: 'ok', raw: 'quit' })).toThrow();
  });
  it('normalise les codes de liaison', () => { expect(normalizeCode(' ab-cd 23ef ')).toBe('ABCD23EF'); });
});
