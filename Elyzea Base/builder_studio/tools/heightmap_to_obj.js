#!/usr/bin/env node
/* =========================================================
   BUILDER STUDIO - HEIGHTMAP -> MAILLAGE OBJ (îles, terrains)
   Entrées acceptées :
     - le JSON « Exporter la heightmap » de l'inspecteur d'un terrain
       { cols, rows, cell, base, heights[], origin, heading }
     - une image PGM 8 bits (P5) en niveaux de gris : --cell <m> --height <m>
   Sortie : OBJ lissé (sommets aux coins des cases), avec UV et bord qui
   descend jusqu'au niveau de base. À importer dans Blender, convertir avec
   Sollumz en Drawable (.ydr) + collision (.ybn), puis placer avec un .ymap.

   node tools/heightmap_to_obj.js terrain.json terrain.obj [--subdiv 2] [--uv 8]
   node tools/heightmap_to_obj.js ile.pgm ile.obj --cell 4 --height 40 [--base 0]
   ========================================================= */
'use strict';
const fs = require('fs');
const [, , input, output, ...rest] = process.argv;
if (!input || !output) { console.log('Utilisation : node tools/heightmap_to_obj.js <terrain.json | carte.pgm> <sortie.obj> [--subdiv n] [--uv m] [--cell m --height m --base m]'); process.exit(1); }
const opt = { subdiv: 1, uv: 8, cell: 4, height: 30, base: 0 };
for (let i = 0; i < rest.length; i += 2) opt[rest[i].replace(/^--/, '')] = +rest[i + 1];

let cols, rows, cell, base, H;
if (input.toLowerCase().endsWith('.pgm')) {
    const buf = fs.readFileSync(input);
    const header = buf.toString('latin1', 0, 64).replace(/#[^\n]*\n/g, '').match(/^P5\s+(\d+)\s+(\d+)\s+(\d+)\s/);
    if (!header) throw new Error('PGM P5 8 bits attendu');
    cols = +header[1]; rows = +header[2];
    const max = +header[3];
    const start = buf.length - cols * rows;
    cell = opt.cell; base = opt.base;
    H = (i, j) => base + (buf[start + j * cols + i] / max) * opt.height;
} else {
    const d = JSON.parse(fs.readFileSync(input, 'utf8'));
    cols = d.cols; rows = d.rows; cell = d.cell; base = d.base || 0;
    H = (i, j) => (d.heights[j * cols + i] ?? 0);
}
// hauteur aux coins = moyenne des cases voisines (relief lissé)
const corner = (ci, cj) => {
    let s = 0, n = 0;
    for (const [i, j] of [[ci - 1, cj - 1], [ci, cj - 1], [ci - 1, cj], [ci, cj]]) {
        if (i >= 0 && j >= 0 && i < cols && j < rows) { s += H(i, j); n++; }
    }
    return n ? s / n : base;
};
const sd = Math.max(1, Math.floor(opt.subdiv));
const nx = cols * sd, ny = rows * sd, step = cell / sd;
const hAt = (x, y) => { // interpolation bilinéaire des coins
    const fx = x / sd, fy = y / sd, i = Math.floor(fx), j = Math.floor(fy), tx = fx - i, ty = fy - j;
    const a = corner(i, j), b = corner(Math.min(i + 1, cols), j), c = corner(i, Math.min(j + 1, rows)), e = corner(Math.min(i + 1, cols), Math.min(j + 1, rows));
    return (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + e * tx) * ty;
};
const L = ['# Builder Studio - terrain (OBJ Y vers le haut ; import Blender par défaut = Z vers le haut)', 'o terrain'];
const idx = (x, y) => y * (nx + 1) + x + 1;
for (let y = 0; y <= ny; y++) for (let x = 0; x <= nx; x++) {
    const X = x * step, Y = y * step, Z = hAt(x, y);
    L.push(`v ${X.toFixed(3)} ${Z.toFixed(3)} ${(-Y).toFixed(3)}`);
}
for (let y = 0; y <= ny; y++) for (let x = 0; x <= nx; x++) L.push(`vt ${(x * step / opt.uv).toFixed(4)} ${(y * step / opt.uv).toFixed(4)}`);
for (let y = 0; y < ny; y++) for (let x = 0; x < nx; x++) {
    const a = idx(x, y), b = idx(x + 1, y), c = idx(x + 1, y + 1), d = idx(x, y + 1);
    L.push(`f ${a}/${a} ${b}/${b} ${c}/${c}`, `f ${a}/${a} ${c}/${c} ${d}/${d}`);
}
// bord : jupe verticale jusqu'au niveau de base (pas de trou sous l'île)
const nTop = (nx + 1) * (ny + 1);
const ring = [];
for (let x = 0; x <= nx; x++) ring.push([x, 0]);
for (let y = 1; y <= ny; y++) ring.push([nx, y]);
for (let x = nx - 1; x >= 0; x--) ring.push([x, ny]);
for (let y = ny - 1; y >= 1; y--) ring.push([0, y]);
ring.forEach(([x, y]) => L.push(`v ${(x * step).toFixed(3)} ${base.toFixed(3)} ${(-y * step).toFixed(3)}`));
L.push('vt 0 0');
const vtB = nTop + 1;
for (let k = 0; k < ring.length; k++) {
    const [x1, y1] = ring[k], [x2, y2] = ring[(k + 1) % ring.length];
    const t1 = idx(x1, y1), t2 = idx(x2, y2), b1 = nTop + k + 1, b2 = nTop + ((k + 1) % ring.length) + 1;
    L.push(`f ${t1}/${vtB} ${b1}/${vtB} ${b2}/${vtB}`, `f ${t1}/${vtB} ${b2}/${vtB} ${t2}/${vtB}`);
}
fs.writeFileSync(output, L.join('\n') + '\n');
console.log(`OBJ écrit : ${output} (${nx} x ${ny} quadrillage, ${(cols * cell).toFixed(0)} x ${(rows * cell).toFixed(0)} m, ${nTop + ring.length} sommets)`);
