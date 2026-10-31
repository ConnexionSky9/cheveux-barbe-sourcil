#!/usr/bin/env node
/* =========================================================
   BUILDER STUDIO - GÉNÉRATEUR DU KIT ARCHITECTURAL (ubk_*)
   Produit les SOURCES des modèles du kit, prêtes pour Blender + Sollumz :
     <sortie>/source/obj/ubk_<module>_<matériau>.obj  (+ .mtl)
     <sortie>/source/textures/ubk_<matériau>.png      (textures procédurales 512x512)
     <sortie>/source/ubk_kit.ytyp.xml                  (archétypes, XML CodeWalker)
     <sortie>/builder_studio_kit/fxmanifest.lua         (ressource à remplir avec stream/)
   Les dimensions viennent de shared/kits.lua (mêmes valeurs que le jeu).
   Ce script NE produit PAS de .ydr / .ytd / .ybn binaires : la conversion se fait
   dans Blender avec Sollumz (voir tools/README.md).

   Utilisation :
     node tools/kit_generator.js <sortie> [--materials beton,brique] [--scale brique=1.5] [--rotate bois=90] [--size 512]
   ========================================================= */
'use strict';
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

// ---------------------------------------------------------
//  Lecture des modules et matériaux depuis shared/kits.lua
// ---------------------------------------------------------
const kitsLua = fs.readFileSync(path.join(__dirname, '..', 'shared', 'kits.lua'), 'utf8');
function parseModules(src) {
    const block = src.slice(src.indexOf('BKits.ubkModules = {'), src.indexOf('BKits.glassThickness'));
    const out = {};
    let current = null;
    for (const line of block.split('\n')) {
        const head = line.match(/^\s{4}(\w+)\s*=\s*\{/);
        if (head) { current = head[1]; out[current] = []; }
        const re = /\{\s*s\s*=\s*'(\w+)',\s*x\s*=\s*([\d.]+),\s*y\s*=\s*([\d.]+),\s*z\s*=\s*([\d.]+)\s*\}/g;
        let m;
        while (current && (m = re.exec(line))) out[current].push({ s: m[1], x: +m[2], y: +m[3], z: +m[4] });
    }
    return out;
}
function parseMaterials(src) {
    const out = [];
    const re = /\{\s*id\s*=\s*'(\w+)',\s*label\s*=\s*'([^']+)',\s*kind\s*=\s*'(\w+)',\s*color\s*=\s*'(#[0-9a-fA-F]{6})'\s*\}/g;
    let m;
    while ((m = re.exec(src))) out.push({ id: m[1], label: m[2], kind: m[3], color: m[4] });
    return out;
}
const MODULES = parseModules(kitsLua);
const MATERIALS = parseMaterials(kitsLua);
const GLASS_T = +(kitsLua.match(/BKits\.glassThickness\s*=\s*([\d.]+)/) || [0, 0.03])[1];
const GLASS_MODULES = new Set(['wall', 'floor', 'door']);

// ---------------------------------------------------------
//  Arguments
// ---------------------------------------------------------
const args = process.argv.slice(2);
if (!args[0] || args[0].startsWith('--')) {
    console.log('Utilisation : node tools/kit_generator.js <dossier_sortie> [--materials a,b] [--scale mat=m] [--rotate mat=deg] [--size 512]');
    process.exit(1);
}
const OUT = path.resolve(args[0]);
const opt = { materials: null, scale: {}, rotate: {}, size: 512 };
for (let i = 1; i < args.length; i++) {
    const a = args[i], v = args[i + 1];
    if (a === '--materials') { opt.materials = new Set(v.split(',')); i++; }
    else if (a === '--scale' || a === '--rotate') { for (const kv of v.split(',')) { const [k, n] = kv.split('='); opt[a.slice(2)][k] = +n; } i++; }
    else if (a === '--size') { opt.size = Math.max(64, Math.min(2048, +v)); i++; }
}
// Taille couverte par une répétition de texture (mètres) : « répétition / échelle »
const DEFAULT_SCALE = { brique: 1.0, pierre: 2.0, bois: 2.0, carrelage: 1.0, marbre: 2.0, asphalte: 4.0, sable: 4.0, herbe: 4.0, terre: 4.0, roche: 4.0 };
const texScale = (mat) => opt.scale[mat] || DEFAULT_SCALE[mat] || 2.0;
const texRot = (mat) => ((opt.rotate[mat] || 0) * Math.PI) / 180;

// ---------------------------------------------------------
//  PNG (zlib natif de Node)
// ---------------------------------------------------------
const CRC = new Int32Array(256).map((_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c; });
function crc32(buf) { let c = -1; for (const b of buf) c = CRC[(c ^ b) & 255] ^ (c >>> 8); return (c ^ -1) >>> 0; }
function chunk(type, data) {
    const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
    const td = Buffer.concat([Buffer.from(type), data]);
    const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td));
    return Buffer.concat([len, td, crc]);
}
function png(w, h, rgba) {
    const raw = Buffer.alloc((w * 4 + 1) * h);
    for (let y = 0; y < h; y++) { raw[y * (w * 4 + 1)] = 0; rgba.copy(raw, y * (w * 4 + 1) + 1, y * w * 4, (y + 1) * w * 4); }
    const ihdr = Buffer.alloc(13);
    ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 6; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
    return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]);
}

// ---------------------------------------------------------
//  Textures procédurales (raccordables : bruit périodique)
// ---------------------------------------------------------
function rng(seed) { let s = seed >>> 0 || 1; return () => ((s = (s * 1664525 + 1013904223) >>> 0) / 4294967296); }
function periodicNoise(N, cells, seed) {
    const r = rng(seed);
    const g = Array.from({ length: cells * cells }, () => r());
    const at = (i, j) => g[((j % cells + cells) % cells) * cells + ((i % cells + cells) % cells)];
    return (x, y) => {
        const fx = (x / N) * cells, fy = (y / N) * cells;
        const x0 = Math.floor(fx), y0 = Math.floor(fy), tx = fx - x0, ty = fy - y0;
        const sx = tx * tx * (3 - 2 * tx), sy = ty * ty * (3 - 2 * ty);
        const a = at(x0, y0) * (1 - sx) + at(x0 + 1, y0) * sx;
        const b = at(x0, y0 + 1) * (1 - sx) + at(x0 + 1, y0 + 1) * sx;
        return a * (1 - sy) + b * sy;
    };
}
function fbm(N, seed, octaves = 4) {
    const layers = Array.from({ length: octaves }, (_, o) => periodicNoise(N, 4 << o, seed + o * 97));
    return (x, y) => { let v = 0, a = 0.5, t = 0; for (const l of layers) { v += l(x, y) * a; t += a; a *= 0.5; } return v / t; };
}
const hex = (c) => [parseInt(c.slice(1, 3), 16), parseInt(c.slice(3, 5), 16), parseInt(c.slice(5, 7), 16)];
const clamp = (v) => Math.max(0, Math.min(255, Math.round(v)));

function texture(mat, N) {
    const base = hex(mat.color);
    const buf = Buffer.alloc(N * N * 4);
    const n1 = fbm(N, mat.id.length * 31 + 7), n2 = fbm(N, mat.id.length * 17 + 3, 2), brushN = periodicNoise(N, 64, 5);
    const put = (x, y, rgb, a = 255) => { const i = (y * N + x) * 4; buf[i] = clamp(rgb[0]); buf[i + 1] = clamp(rgb[1]); buf[i + 2] = clamp(rgb[2]); buf[i + 3] = a; };
    const shade = (k) => base.map((c) => c * k);
    for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
        const n = n1(x, y), m = n2(x, y);
        let c = shade(0.85 + n * 0.3), a = 255;
        switch (mat.id) {
            case 'beton': c = shade(0.88 + n * 0.25); break;
            case 'beton_brut': c = shade(0.75 + n * 0.45 - (m > 0.82 ? 0.25 : 0)); break;
            case 'beton_cire': c = shade(0.95 + n * 0.1); break;
            case 'brique': {
                const rowH = N / 8, row = Math.floor(y / rowH), bw = N / 4, off = row % 2 ? bw / 2 : 0;
                const mortar = y % rowH < 3 || (x + off) % bw < 3;
                c = mortar ? [190, 185, 175].map((v) => v * (0.9 + n * 0.15)) : shade(0.8 + n * 0.4 + ((Math.floor((x + off) / bw) * 7 + row * 3) % 5) * 0.03);
                break;
            }
            case 'pierre': {
                const bw = N / 3, bh = N / 4, row = Math.floor(y / bh), off = row % 2 ? bw / 2 : 0;
                const joint = y % bh < 4 || (x + off) % bw < 4;
                c = joint ? shade(0.55) : shade(0.8 + n * 0.4 + m * 0.1);
                break;
            }
            case 'bois': {
                const plank = Math.floor(y / (N / 6));
                const grain = Math.sin((x / N) * Math.PI * 2 * 3 + n * 9 + plank * 1.7) * 0.5 + 0.5;
                c = y % (N / 6) < 2 ? shade(0.5) : shade(0.75 + grain * 0.3 + m * 0.1);
                break;
            }
            case 'metal': case 'acier': case 'aluminium': {
                const brush = brushN(x * 0.05, y) * 0.15;
                c = shade(0.85 + brush + n * 0.08); break;
            }
            case 'verre_clair': c = base; a = 70; break;
            case 'verre_teinte': c = base; a = 150; break;
            case 'verre_opaque': c = shade(0.95 + n * 0.08); a = 225; break;
            case 'carrelage': {
                const t = N / 4, joint = x % t < 2 || y % t < 2;
                c = joint ? [170, 168, 160] : shade(0.95 + n * 0.08); break;
            }
            case 'marbre': {
                const vein = Math.abs(Math.sin((x + y) / N * Math.PI * 4 + n * 10));
                c = shade(0.92 + (vein < 0.06 ? -0.35 : 0) + m * 0.06); break;
            }
            case 'platre': c = shade(0.95 + n * 0.07); break;
            case 'asphalte': c = shade(0.8 + n * 0.3 + (m > 0.7 ? 0.25 : 0)); break;
            case 'sable': c = shade(0.88 + n * 0.2 + (m > 0.75 ? 0.08 : 0)); break;
            case 'herbe': c = [base[0] * (0.7 + m * 0.5), base[1] * (0.75 + n * 0.45), base[2] * (0.7 + n * 0.3)]; break;
            case 'terre': c = shade(0.75 + n * 0.45); break;
            case 'roche': c = shade(0.65 + n * 0.6 - (m > 0.8 ? 0.2 : 0)); break;
        }
        put(x, y, c, a);
    }
    return png(N, N, buf);
}

// ---------------------------------------------------------
//  Géométrie : boîte, origine au centre de la face du bas
//  OBJ écrit en « Y vers le haut » (convention OBJ) : (x, z, -y)
//  -> l'import par défaut de Blender redonne Z vers le haut (comme GTA).
// ---------------------------------------------------------
function boxObj(name, mat, dx, dy, dz) {
    const x0 = -dx / 2, x1 = dx / 2, y0 = -dy / 2, y1 = dy / 2, z0 = 0, z1 = dz;
    const s = texScale(mat.id), rot = texRot(mat.id), cr = Math.cos(rot), sr = Math.sin(rot);
    const uv = (u, v) => { const a = u / s, b = v / s; return [a * cr - b * sr, a * sr + b * cr]; };
    // chaque face : 4 coins (sens anti-horaire vu de l'extérieur), normale, axes UV en mètres
    const faces = [
        { n: [0, 0, 1], p: [[x0, y0, z1], [x1, y0, z1], [x1, y1, z1], [x0, y1, z1]], u: (p) => uv(p[0], p[1]) },
        { n: [0, 0, -1], p: [[x0, y1, z0], [x1, y1, z0], [x1, y0, z0], [x0, y0, z0]], u: (p) => uv(p[0], -p[1]) },
        { n: [0, -1, 0], p: [[x0, y0, z0], [x1, y0, z0], [x1, y0, z1], [x0, y0, z1]], u: (p) => uv(p[0], p[2]) },
        { n: [0, 1, 0], p: [[x1, y1, z0], [x0, y1, z0], [x0, y1, z1], [x1, y1, z1]], u: (p) => uv(-p[0], p[2]) },
        { n: [1, 0, 0], p: [[x1, y0, z0], [x1, y1, z0], [x1, y1, z1], [x1, y0, z1]], u: (p) => uv(p[1], p[2]) },
        { n: [-1, 0, 0], p: [[x0, y1, z0], [x0, y0, z0], [x0, y0, z1], [x0, y1, z1]], u: (p) => uv(-p[1], p[2]) },
    ];
    const L = [`# Builder Studio - ${name} (${dx} x ${dy} x ${dz} m, origine : centre du bas)`, `mtllib ${name}.mtl`, `o ${name}`];
    faces.forEach((f) => f.p.forEach((p) => L.push(`v ${p[0].toFixed(4)} ${p[2].toFixed(4)} ${(-p[1]).toFixed(4)}`)));
    faces.forEach((f) => f.p.forEach((p) => { const t = f.u(p); L.push(`vt ${t[0].toFixed(4)} ${t[1].toFixed(4)}`); }));
    faces.forEach((f) => L.push(`vn ${f.n[0]} ${f.n[2]} ${-f.n[1]}`));
    L.push(`usemtl ubk_${mat.id}`, 's off');
    faces.forEach((f, i) => {
        const b = i * 4 + 1, n = i + 1;
        L.push(`f ${b}/${b}/${n} ${b + 1}/${b + 1}/${n} ${b + 2}/${b + 2}/${n} ${b + 3}/${b + 3}/${n}`);
    });
    return L.join('\n') + '\n';
}
function mtl(mat) {
    const [r, g, b] = hex(mat.color).map((v) => (v / 255).toFixed(3));
    const glass = mat.kind === 'glass';
    return [`newmtl ubk_${mat.id}`, `Kd ${r} ${g} ${b}`, 'Ka 0 0 0', `Ks ${glass ? '0.9 0.9 0.9' : '0.1 0.1 0.1'}`, `Ns ${glass ? 200 : 20}`,
        `d ${glass ? (mat.id === 'verre_clair' ? 0.3 : mat.id === 'verre_teinte' ? 0.6 : 0.88) : 1}`, 'illum 2', `map_Kd ../textures/ubk_${mat.id}.png`, ''].join('\n');
}

// ---------------------------------------------------------
//  Archétypes (XML CodeWalker)
// ---------------------------------------------------------
function archetypeXml(name, dx, dy, dz) {
    const r = Math.sqrt((dx / 2) ** 2 + (dy / 2) ** 2 + (dz / 2) ** 2);
    const f = (v) => v.toFixed(6);
    return `    <Item type="CBaseArchetypeDef">
      <lodDist value="300.000000" />
      <flags value="0" />
      <specialAttribute value="0" />
      <bbMin x="${f(-dx / 2)}" y="${f(-dy / 2)}" z="0.000000" />
      <bbMax x="${f(dx / 2)}" y="${f(dy / 2)}" z="${f(dz)}" />
      <bsCentre x="0.000000" y="0.000000" z="${f(dz / 2)}" />
      <bsRadius value="${f(r)}" />
      <hdTextureDist value="40.000000" />
      <name>${name}</name>
      <textureDictionary>ubk_textures</textureDictionary>
      <clipDictionary />
      <drawableDictionary />
      <physicsDictionary />
      <assetType>ASSET_TYPE_DRAWABLE</assetType>
      <assetName>${name}</assetName>
      <extensions />
    </Item>`;
}

// ---------------------------------------------------------
//  Génération
// ---------------------------------------------------------
const objDir = path.join(OUT, 'source', 'obj'), texDir = path.join(OUT, 'source', 'textures'), resDir = path.join(OUT, 'builder_studio_kit');
for (const d of [objDir, texDir, path.join(resDir, 'stream')]) fs.mkdirSync(d, { recursive: true });

const ALU = MATERIALS.find((m) => m.id === 'aluminium');
const models = new Map();
for (const mat of MATERIALS) {
    if (opt.materials && !opt.materials.has(mat.id)) continue;
    fs.writeFileSync(path.join(texDir, `ubk_${mat.id}.png`), texture(mat, opt.size));
    for (const [type, list] of Object.entries(MODULES)) {
        let m2 = mat;
        const glass = mat.kind === 'glass';
        if (glass && !GLASS_MODULES.has(type)) m2 = ALU;         // même règle que BKits.modules
        for (const mod of list) {
            const name = `ubk_${mod.s}_${m2.id}`;
            if (models.has(name)) continue;
            const dy = glass && m2 === mat && (type === 'wall' || type === 'door') ? GLASS_T : mod.y;
            models.set(name, { mat: m2, dx: mod.x, dy, dz: mod.z });
        }
    }
}
// texture de chaque matériau réellement utilisé (ex. alu des montants d'une verrière filtrée)
for (const m of new Set([...models.values()].map((x) => x.mat))) {
    const f = path.join(texDir, `ubk_${m.id}.png`);
    if (!fs.existsSync(f)) fs.writeFileSync(f, texture(m, opt.size));
}
for (const [name, m] of models) {
    fs.writeFileSync(path.join(objDir, name + '.obj'), boxObj(name, m.mat, m.dx, m.dy, m.dz));
    fs.writeFileSync(path.join(objDir, name + '.mtl'), mtl(m.mat));
}
const ytyp = `<?xml version="1.0" encoding="UTF-8"?>
<CMapTypes>
  <extensions />
  <archetypes>
${[...models].map(([n, m]) => archetypeXml(n, m.dx, m.dy, m.dz)).join('\n')}
  </archetypes>
  <name>ubk_kit</name>
  <dependencies />
  <compositeEntityTypes />
</CMapTypes>
`;
fs.writeFileSync(path.join(OUT, 'source', 'ubk_kit.ytyp.xml'), ytyp);
fs.writeFileSync(path.join(resDir, 'fxmanifest.lua'), `fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'builder_studio_kit'
description 'Kit architectural de Builder Studio (modèles ubk_*)'
version '1.0.0'
this_is_a_map 'yes'

-- stream/ doit contenir : les .ydr (un par modèle), les .ybn (collisions) si séparées,
-- ubk_textures.ytd et ubk_kit.ytyp (converti depuis source/ubk_kit.ytyp.xml avec CodeWalker)
data_file 'DLC_ITYP_REQUEST' 'stream/ubk_kit.ytyp'
`);
fs.writeFileSync(path.join(OUT, 'models.txt'), [...models.keys()].join('\n') + '\n');
console.log(`Kit généré dans ${OUT}`);
console.log(`  ${models.size} modèles (OBJ + MTL) · ${fs.readdirSync(texDir).length} textures · source/ubk_kit.ytyp.xml · builder_studio_kit/fxmanifest.lua`);
console.log('  Étape suivante : tools/README.md (Blender + Sollumz -> .ydr / .ytd / .ybn, CodeWalker -> .ytyp)');
