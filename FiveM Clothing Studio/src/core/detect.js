// Détection du format RÉEL d'un fichier par sa signature (jamais par la seule extension).
// Module PUR.

const startsWith = (u8, bytes, off = 0) => bytes.every((b, i) => u8[off + i] === b);
const ascii = (u8, off, len) => String.fromCharCode(...u8.subarray(off, off + len));

/**
 * Renvoie { format, family, ext, mismatch } :
 *  family : 'image' | 'model' | 'gta' | 'archive' | 'unknown'
 *  mismatch : l'extension ne correspond pas au contenu.
 */
export function sniff(buf, extHint = '') {
  const u8 = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
  const ext = String(extHint).toLowerCase().replace(/^.*\./, '');
  let format = 'unknown', family = 'unknown';
  if (startsWith(u8, [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) { format = 'png'; family = 'image'; }
  else if (startsWith(u8, [0xff, 0xd8, 0xff])) { format = 'jpeg'; family = 'image'; }
  else if (startsWith(u8, [0x44, 0x44, 0x53, 0x20])) { format = 'dds'; family = 'image'; }
  else if (startsWith(u8, [0x52, 0x53, 0x43, 0x37])) { format = 'rsc7'; family = 'gta'; }           // RSC7 : ressource GTA V (ydd, ytd, ymt…)
  else if (startsWith(u8, [0x50, 0x53, 0x49, 0x4e])) { format = 'pso'; family = 'gta'; }            // PSIN : métadonnées PSO
  else if (startsWith(u8, [0x67, 0x6c, 0x54, 0x46])) { format = 'glb'; family = 'model'; }          // glTF binaire
  else if (u8.length > 20 && ascii(u8, 0, 18) === 'Kaydara FBX Binary') { format = 'fbx'; family = 'model'; }
  else if (startsWith(u8, [0x50, 0x4b, 0x03, 0x04])) { format = 'zip'; family = 'archive'; }
  else {
    const head = ascii(u8, 0, Math.min(u8.length, 2048));
    const text = !/[\u0000-\u0008\u000e-\u001f]/.test(head.replace(/[\r\n\t]/g, ''));
    if (text && /^\s*\{/.test(head) && /"asset"\s*:/.test(head)) { format = 'gltf'; family = 'model'; }
    else if (text && /^\s*;\s*FBX/.test(head)) { format = 'fbx'; family = 'model'; }
    else if (text && /^\s*(#.*\r?\n\s*)*(v|vt|vn|o|g|mtllib|f|s|usemtl)\s/m.test(head) && ext === 'obj') { format = 'obj'; family = 'model'; }
    else if (text && ext === 'mtl') { format = 'mtl'; family = 'model'; }
    else if (text && /^\s*<\?xml|^\s*<\w+/.test(head)) { format = 'xml'; family = 'gta'; }
    else if (['tga', 'icb', 'vda', 'vst'].includes(ext) && looksLikeTga(u8)) { format = 'tga'; family = 'image'; }
  }
  const expected = { jpg: 'jpeg', jpeg: 'jpeg', png: 'png', dds: 'dds', tga: 'tga', obj: 'obj', mtl: 'mtl', gltf: 'gltf', glb: 'glb', fbx: 'fbx',
    ydd: 'rsc7', ytd: 'rsc7', ydr: 'rsc7', yft: 'rsc7', ymt: ['rsc7', 'pso', 'xml'], meta: 'xml', xml: 'xml', zip: 'zip' }[ext];
  const mismatch = expected !== undefined && !(Array.isArray(expected) ? expected.includes(format) : expected === format);
  return { format, family, ext, mismatch };
}

function looksLikeTga(u8) {
  if (u8.length < 18) return false;
  const type = u8[2], w = u8[12] | (u8[13] << 8), h = u8[14] | (u8[15] << 8), bpp = u8[16];
  return [1, 2, 3, 9, 10, 11].includes(type) && w > 0 && h > 0 && [8, 15, 16, 24, 32].includes(bpp) && u8[1] <= 1;
}
