// Catalogue : une seule source pour le site, la boutique en jeu et le panel.
import type { Conn } from '../db.js';
import { json, rows, one } from '../db.js';

export interface CategoryDto { id: number; slug: string; name: string; description: string; icon: string; sort: number; active: boolean }
export interface ProductDto {
  id: number; slug: string; name: string; shortDescription: string; description: string; imageUrl: string;
  priceCents: number; currency: string; durationDays: number | null; maxQuantity: number; perks: string[];
  category: { id: number; slug: string; name: string };
  featured: boolean; popular: boolean; available: boolean; sort: number;
}
export interface AdminProductDto extends ProductDto { active: boolean; tebexPackageId: number | null; rewards: { id: number; type: string; params: Record<string, unknown>; sort: number }[] }

type ProductRow = {
  id: number; slug: string; name: string; short_description: string; description: string; image_url: string; price_cents: number; currency: string;
  duration_days: number | null; max_quantity: number; perks: unknown; featured: number; popular: number; active: number; sort: number;
  tebex_package_id: number | string | null; category_id: number; category_slug: string; category_name: string; category_active: number;
};

const BASE = `SELECT p.*, c.slug AS category_slug, c.name AS category_name, c.active AS category_active
              FROM products p JOIN categories c ON c.id = p.category_id`;

function toDto(r: ProductRow): ProductDto {
  return {
    id: r.id, slug: r.slug, name: r.name, shortDescription: r.short_description, description: r.description, imageUrl: r.image_url,
    priceCents: r.price_cents, currency: r.currency, durationDays: r.duration_days, maxQuantity: r.max_quantity,
    perks: json<string[]>(r.perks, []),
    category: { id: r.category_id, slug: r.category_slug, name: r.category_name },
    featured: !!r.featured, popular: !!r.popular, sort: r.sort,
    // Achetable seulement si actif ET relié à un paquet Tebex
    available: !!r.active && !!r.category_active && r.tebex_package_id !== null,
  };
}

const catDto = (c: { id: number; slug: string; name: string; description: string; icon: string; sort: number; active: number }): CategoryDto =>
  ({ id: c.id, slug: c.slug, name: c.name, description: c.description, icon: c.icon, sort: c.sort, active: !!c.active });

export async function publicCategories(db: Conn): Promise<CategoryDto[]> {
  return (await rows<{ id: number; slug: string; name: string; description: string; icon: string; sort: number; active: number }>(db,
    'SELECT * FROM categories WHERE active = 1 ORDER BY sort, id')).map(catDto);
}

export async function publicProducts(db: Conn, categorySlug?: string): Promise<ProductDto[]> {
  const params: unknown[] = [];
  let where = 'WHERE p.active = 1 AND c.active = 1';
  if (categorySlug) { where += ' AND c.slug = ?'; params.push(categorySlug); }
  return (await rows<ProductRow>(db, `${BASE} ${where} ORDER BY c.sort, p.sort, p.id`, params)).map(toDto);
}

export async function publicProduct(db: Conn, slug: string): Promise<ProductDto | null> {
  const r = await one<ProductRow>(db, `${BASE} WHERE p.slug = ? AND p.active = 1 AND c.active = 1`, [slug]);
  return r ? toDto(r) : null;
}

export async function publicCatalog(db: Conn): Promise<{ categories: CategoryDto[]; products: ProductDto[] }> {
  const [categories, products] = await Promise.all([publicCategories(db), publicProducts(db)]);
  return { categories, products };
}

// ---- Administration ----
export async function adminCategories(db: Conn): Promise<(CategoryDto & { productCount: number })[]> {
  const list = await rows<{ id: number; slug: string; name: string; description: string; icon: string; sort: number; active: number; n: number }>(db,
    'SELECT c.*, (SELECT COUNT(*) FROM products p WHERE p.category_id = c.id) AS n FROM categories c ORDER BY c.sort, c.id');
  return list.map((c) => ({ ...catDto(c), productCount: Number(c.n) }));
}

export async function adminProducts(db: Conn, id?: number): Promise<AdminProductDto[]> {
  const list = await rows<ProductRow>(db, `${BASE} ${id ? 'WHERE p.id = ?' : ''} ORDER BY c.sort, p.sort, p.id`, id ? [id] : []);
  if (!list.length) return [];
  const rewards = await rows<{ id: number; product_id: number; type: string; params: unknown; sort: number }>(db,
    `SELECT * FROM product_rewards WHERE product_id IN (${list.map(() => '?').join(',')}) ORDER BY sort, id`, list.map((p) => p.id));
  return list.map((r) => ({
    ...toDto(r), active: !!r.active, tebexPackageId: r.tebex_package_id === null ? null : Number(r.tebex_package_id),
    rewards: rewards.filter((w) => w.product_id === r.id).map((w) => ({ id: w.id, type: w.type, params: json<Record<string, unknown>>(w.params, {}), sort: w.sort })),
  }));
}
