// Types de récompenses et validation de leurs paramètres (utilisé par le panel et à l'achat).
// L'exécution réelle se fait dans la ressource FiveM (adaptateurs ESX / Elyzea).
import { z } from 'zod';

const ident = (max: number) => z.string().regex(new RegExp(`^[a-zA-Z0-9_]{1,${max}}$`), 'Lettres, chiffres et _ uniquement.');

export const REWARD_SCHEMAS = {
  // Grade (ACE group.<name> appliqué en jeu tant que la récompense est active)
  group: z.object({ name: ident(32) }).strict(),
  // Avantage nommé, lisible par les autres scripts via exports.server_shop:HasPerk(src, name)
  perk: z.object({ name: ident(32) }).strict(),
  // Véhicule ajouté au garage du personnage actif
  vehicle: z.object({ model: ident(32), garage: z.string().max(32).optional() }).strict(),
  // Objet d'inventaire
  item: z.object({ name: ident(48), count: z.number().int().min(1).max(1000) }).strict(),
  // Argent en jeu (vérifiez les règles Cfx.re avant de vendre de la monnaie)
  money: z.object({ account: z.string().regex(/^[a-z_]{2,16}$/), amount: z.number().int().min(1).max(100_000_000) }).strict(),
  // Commande serveur PRÉDÉFINIE dans fivem/server_shop/config.lua › Config.Commands (jamais du texte libre)
  command: z.object({ name: ident(32) }).strict(),
} as const;

export type RewardType = keyof typeof REWARD_SCHEMAS;
export const REWARD_TYPES = Object.keys(REWARD_SCHEMAS) as RewardType[];
/** Types pouvant être retirés (remboursement, fin de durée). Les autres sont journalisés. */
export const REVOCABLE: ReadonlySet<RewardType> = new Set<RewardType>(['group', 'perk', 'vehicle']);

export function validateReward(type: string, params: unknown): { type: RewardType; params: Record<string, unknown> } {
  if (!(type in REWARD_SCHEMAS)) throw new Error(`Type de récompense inconnu : ${type}`);
  const t = type as RewardType;
  const r = REWARD_SCHEMAS[t].safeParse(params);
  if (!r.success) throw new Error(`Paramètres invalides pour « ${t} » : ${r.error.issues.map((i) => `${i.path.join('.') || '•'} ${i.message}`).join(', ')}`);
  return { type: t, params: r.data as Record<string, unknown> };
}
