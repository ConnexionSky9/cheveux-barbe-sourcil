// Analyse des modèles 3D intermédiaires (OBJ, glTF / GLB, FBX) avant affichage.
// Ces analyses ne prétendent pas valider un vêtement GTA V : elles vérifient que le
// fichier est lisible et signalent les problèmes qui empêcheront un bon aperçu.
// Module PUR (tampons en entrée).

const issue = (level, message) => ({ level, message });

/** OBJ (texte) : sommets, UV, normales, faces, groupes, matériaux, références MTL. */
export function inspectObj(text) {
  const st = { vertices: 0, uvs: 0, normals: 0, faces: 0, triangles: 0, objects: [], materials: new Set(), mtllibs: [], badFaces: 0, nan: 0 };
  const lines = String(text).split(/\r?\n/);
  for (const raw of lines) {
    const line = raw.trim();
    if (!line || line[0] === '#') continue;
    const sp = line.indexOf(' ');
    const kw = sp < 0 ? line : line.slice(0, sp), rest = sp < 0 ? '' : line.slice(sp + 1).trim();
    switch (kw) {
      case 'v': st.vertices++; if (rest.split(/\s+/).slice(0, 3).some((n) => !Number.isFinite(Number(n)))) st.nan++; break;
      case 'vt': st.uvs++; break;
      case 'vn': st.normals++; break;
      case 'o': case 'g': st.objects.push(rest || '(sans nom)'); break;
      case 'usemtl': st.materials.add(rest); break;
      case 'mtllib': st.mtllibs.push(rest); break;
      case 'f': {
        const refs = rest.split(/\s+/);
        st.faces++;
        st.triangles += Math.max(0, refs.length - 2);
        if (refs.length < 3) { st.badFaces++; break; }
        for (const r of refs) {
          const [vi, ti, ni] = r.split('/').map((x) => (x === '' || x === undefined ? null : Number(x)));
          const ok = (i, n) => i === null || (Number.isInteger(i) && i !== 0 && Math.abs(i) <= n);
          // Les index négatifs sont relatifs : on vérifie au moins la borne par rapport au total actuel
          if (!ok(vi, st.vertices) || vi === null || !ok(ti, st.uvs) || !ok(ni, st.normals)) { st.badFaces++; break; }
        }
        break;
      }
      default: break;
    }
  }
  const issues = [];
  if (!st.vertices || !st.faces) issues.push(issue('error', 'Aucune géométrie (sommets / faces) dans ce fichier OBJ.'));
  if (st.badFaces) issues.push(issue('error', `${st.badFaces} face(s) invalide(s) (index hors limites ou moins de 3 sommets).`));
  if (st.nan) issues.push(issue('error', `${st.nan} sommet(s) avec des coordonnées invalides.`));
  if (!st.uvs) issues.push(issue('warning', 'Aucune coordonnée UV : aucune texture ne pourra être appliquée correctement.'));
  if (!st.normals) issues.push(issue('info', 'Pas de normales : elles seront calculées pour l\'aperçu.'));
  if (st.mtllibs.length) issues.push(issue('info', `Fichier(s) de matériaux référencé(s) : ${st.mtllibs.join(', ')} (à importer à côté du modèle).`));
  return { format: 'obj', ...st, materials: [...st.materials], skinned: false, issues };
}

/** glTF 2.0 (JSON ou GLB binaire). */
export function inspectGltf(buf) {
  const u8 = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
  const issues = [];
  let json, binLength = 0, format = 'gltf';
  try {
    if (u8[0] === 0x67 && u8[1] === 0x6c && u8[2] === 0x54 && u8[3] === 0x46) {
      format = 'glb';
      const dv = new DataView(u8.buffer, u8.byteOffset, u8.byteLength);
      const version = dv.getUint32(4, true), total = dv.getUint32(8, true);
      if (version !== 2) return { format, issues: [issue('error', `GLB version ${version} non prise en charge (glTF 2.0 requis).`)] };
      if (total > u8.length) return { format, issues: [issue('error', 'Fichier GLB tronqué.')] };
      let o = 12;
      while (o + 8 <= total) {
        const len = dv.getUint32(o, true), type = dv.getUint32(o + 4, true);
        if (o + 8 + len > total) return { format, issues: [issue('error', 'Bloc GLB tronqué.')] };
        if (type === 0x4e4f534a) json = JSON.parse(new TextDecoder().decode(u8.subarray(o + 8, o + 8 + len)));
        else if (type === 0x004e4942) binLength = len;
        o += 8 + len;
      }
      if (!json) return { format, issues: [issue('error', 'Bloc JSON manquant dans le GLB.')] };
    } else {
      json = JSON.parse(new TextDecoder().decode(u8));
    }
  } catch (e) {
    return { format, issues: [issue('error', `glTF illisible : ${e.message}`)] };
  }
  const ver = String(json.asset?.version ?? '');
  if (!ver.startsWith('2')) issues.push(issue('error', `glTF version « ${ver || '?'} » non prise en charge (2.0 requis).`));
  const meshes = json.meshes || [];
  let triangles = 0, hasUv = false, hasNormals = false, primitives = 0;
  for (const m of meshes) for (const p of m.primitives || []) {
    primitives++;
    if (p.attributes?.TEXCOORD_0 !== undefined) hasUv = true;
    if (p.attributes?.NORMAL !== undefined) hasNormals = true;
    const acc = json.accessors?.[p.indices ?? p.attributes?.POSITION];
    if (acc && (p.mode === undefined || p.mode === 4)) triangles += Math.floor(acc.count / (p.indices !== undefined ? 3 : 3));
  }
  const external = [];
  for (const b of json.buffers || []) if (b.uri && !b.uri.startsWith('data:')) external.push(b.uri);
  for (const im of json.images || []) if (im.uri && !im.uri.startsWith('data:')) external.push(im.uri);
  if (format === 'glb' && json.buffers?.[0] && !json.buffers[0].uri && json.buffers[0].byteLength > binLength) {
    issues.push(issue('error', 'Données binaires GLB incomplètes.'));
  }
  if (!meshes.length) issues.push(issue('error', 'Aucun maillage dans ce fichier.'));
  if (meshes.length && !hasUv) issues.push(issue('warning', 'Aucune coordonnée UV : les textures ne pourront pas être appliquées.'));
  if (meshes.length && !hasNormals) issues.push(issue('info', 'Pas de normales : elles seront calculées pour l\'aperçu.'));
  if (external.length) issues.push(issue('info', `Fichiers externes requis : ${external.join(', ')} (laissez-les à côté du modèle).`));
  const skinned = (json.skins || []).length > 0;
  if (skinned) issues.push(issue('info', `Squelette présent (${json.skins.length} skin) : affiché sans animation.`));
  return { format, meshes: meshes.length, primitives, triangles, materials: (json.materials || []).map((m, i) => m.name || `Matériau ${i + 1}`),
    textures: (json.images || []).length, hasUv, hasNormals, skinned, externalFiles: external, issues };
}

/** FBX : seule la version est lue ici ; le contenu est chargé par le visualiseur (prise en charge partielle). */
export function inspectFbx(buf) {
  const u8 = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
  const head = new TextDecoder('latin1').decode(u8.subarray(0, 32));
  const issues = [issue('warning', 'FBX : lecture par le visualiseur Three.js, prise en charge partielle (FBX 7.x). Préférez glTF / GLB si l\'aperçu échoue.')];
  if (head.startsWith('Kaydara FBX Binary')) {
    const version = new DataView(u8.buffer, u8.byteOffset, u8.byteLength).getUint32(23, true);
    if (version < 7000) issues.push(issue('error', `FBX ${version} trop ancien (7000 minimum).`));
    return { format: 'fbx', binary: true, version, issues };
  }
  const m = /FBXVersion:\s*(\d+)/.exec(new TextDecoder('latin1').decode(u8.subarray(0, 4096)));
  return { format: 'fbx', binary: false, version: m ? Number(m[1]) : null, issues };
}
