// Visualiseur 3D (Three.js) : OBJ (+MTL), glTF / GLB, FBX (partiel).
// Les fichiers GTA V (.ydd) ne sont PAS lus ici : ils demandent une conversion externe.
import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { TransformControls } from 'three/addons/controls/TransformControls.js';
import { OBJLoader } from 'three/addons/loaders/OBJLoader.js';
import { MTLLoader } from 'three/addons/loaders/MTLLoader.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { FBXLoader } from 'three/addons/loaders/FBXLoader.js';
import { GLTFExporter } from 'three/addons/exporters/GLTFExporter.js';
import { VertexNormalsHelper } from 'three/addons/helpers/VertexNormalsHelper.js';

export class Viewer {
  constructor(container, { onSelect, onStatus } = {}) {
    this.container = container;
    this.onSelect = onSelect || (() => {});
    this.onStatus = onStatus || (() => {});
    this.renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
    this.renderer.setPixelRatio(Math.min(2, window.devicePixelRatio || 1));
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    container.append(this.renderer.domElement);
    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(0x101217);
    this.camera = new THREE.PerspectiveCamera(40, 1, 0.01, 1000);
    this.controls = new OrbitControls(this.camera, this.renderer.domElement);
    this.controls.enableDamping = true;
    this.hemi = new THREE.HemisphereLight(0xffffff, 0x334455, 1.4);
    this.sun = new THREE.DirectionalLight(0xffffff, 1.6);
    this.sun.position.set(2, 4, 3);
    this.back = new THREE.DirectionalLight(0x99bbff, 0.6);
    this.back.position.set(-3, 2, -3);
    this.grid = new THREE.GridHelper(4, 40, 0x3a4252, 0x252a33);
    this.scene.add(this.hemi, this.sun, this.back, this.grid);
    this.root = new THREE.Group();
    this.scene.add(this.root);
    this.helpers = [];
    this.textures = new Map();     // matériau → THREE.Texture appliquée
    this.models = [];              // { name, object, reference }
    this.selected = null;
    this.transform = new TransformControls(this.camera, this.renderer.domElement);
    this.transform.addEventListener('dragging-changed', (e) => { this.controls.enabled = !e.value; });
    this.scene.add(this.transform.getHelper ? this.transform.getHelper() : this.transform);
    this.raycaster = new THREE.Raycaster();
    this.renderer.domElement.addEventListener('pointerdown', (e) => { this.down = [e.clientX, e.clientY]; });
    this.renderer.domElement.addEventListener('pointerup', (e) => {
      if (!this.down || Math.hypot(e.clientX - this.down[0], e.clientY - this.down[1]) > 4 || this.transform.dragging) return;
      this.pick(e);
    });
    this.ro = new ResizeObserver(() => this.resize());
    this.ro.observe(container);
    this.resize();
    this.resetView();
    this.running = true;
    this.paused = false;
    const loop = () => {
      if (!this.running) return;
      if (!this.paused && this.container.isConnected) { this.controls.update(); this.renderer.render(this.scene, this.camera); }
      this.raf = requestAnimationFrame(loop);
    };
    loop();
  }
  /** Ré-attache le visualiseur dans un nouveau conteneur (changement d'onglet sans tout recharger). */
  attach(container) {
    if (container === this.container) return;
    this.ro.disconnect();
    this.container = container;
    container.append(this.renderer.domElement);
    this.ro.observe(container);
    this.resize();
  }

  resize() {
    const w = this.container.clientWidth || 1, h = this.container.clientHeight || 1;
    this.renderer.setSize(w, h, false);
    this.renderer.domElement.style.width = '100%';
    this.renderer.domElement.style.height = '100%';
    this.camera.aspect = w / h;
    this.camera.updateProjectionMatrix();
  }

  /** Charge un modèle depuis les octets renvoyés par le processus principal. */
  async load({ name, format, data, companions = {} }, { reference = false } = {}) {
    const blobs = new Map();
    for (const [rel, bytes] of Object.entries(companions)) {
      const url = URL.createObjectURL(new Blob([bytes]));
      blobs.set(rel.toLowerCase(), url);
      blobs.set(rel.split('/').pop().toLowerCase(), url);
    }
    const manager = new THREE.LoadingManager();
    const missing = [];
    manager.setURLModifier((url) => {
      if (url.startsWith('blob:') || url.startsWith('data:')) return url;
      const clean = decodeURIComponent(url.replace(/^.*?:\/\/\/?/, '').split(/[?#]/)[0]).replace(/\\/g, '/');
      const hit = blobs.get(clean.toLowerCase()) || blobs.get(clean.split('/').pop().toLowerCase());
      if (!hit) missing.push(clean.split('/').pop());
      return hit || 'data:,';
    });
    let object;
    const buf = data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength);
    try {
      if (format === 'obj') {
        const text = new TextDecoder().decode(data);
        const loader = new OBJLoader(manager);
        const mtlName = /^\s*mtllib\s+(.+?)\s*$/m.exec(text)?.[1];
        if (mtlName && blobs.has(mtlName.toLowerCase())) {
          const mtlText = new TextDecoder().decode(companions[Object.keys(companions).find((k) => k.toLowerCase() === mtlName.toLowerCase())]);
          const mats = new MTLLoader(manager).parse(mtlText, '');
          mats.preload();
          loader.setMaterials(mats);
        } else if (mtlName) missing.push(mtlName);
        object = loader.parse(text);
        object.userData.flipY = true;
      } else if (format === 'gltf' || format === 'glb') {
        const gltf = await new GLTFLoader(manager).parseAsync(format === 'glb' ? buf : new TextDecoder().decode(data), '');
        object = gltf.scene;
        object.userData.flipY = false;
      } else if (format === 'fbx') {
        object = new FBXLoader(manager).parse(buf, '');
        object.userData.flipY = true;
      } else {
        throw new Error(`Format ${format} non affichable en 3D.`);
      }
    } catch (e) {
      throw new Error(`Chargement impossible : ${e.message}`);
    }
    object.name = name;
    const stats = analyse(object);
    // Mise à l'échelle : un modèle exporté en centimètres est ramené à une taille lisible
    if (stats.size.length() > 50) { const k = 2 / stats.size.length(); object.scale.setScalar(k); stats.scaled = k; }
    if (reference) {
      object.traverse((o) => { if (o.isMesh) { o.material = new THREE.MeshStandardMaterial({ color: 0x8a93a3, transparent: true, opacity: 0.35, depthWrite: false }); } });
      object.userData.reference = true;
    }
    this.root.add(object);
    this.models.push({ name, object, reference });
    if (!reference) this.frame(object);
    if (missing.length) stats.issues.push({ level: 'warning', message: `Fichiers non trouvés à côté du modèle : ${[...new Set(missing)].join(', ')}` });
    return stats;
  }

  clear() {
    this.select(null);
    for (const m of this.models) { this.root.remove(m.object); disposeObject(m.object); }
    this.models = [];
    this.clearHelpers();
    for (const t of this.textures.values()) t.dispose();
    this.textures.clear();
  }

  frame(object) {
    const box = new THREE.Box3().setFromObject(object);
    if (box.isEmpty()) return;
    const size = box.getSize(new THREE.Vector3()), center = box.getCenter(new THREE.Vector3());
    this.focus = { center, radius: Math.max(size.x, size.y, size.z) || 1 };
    this.setView('front');
    this.grid.position.y = box.min.y;
  }
  resetView() { this.focus = this.focus || { center: new THREE.Vector3(0, 1, 0), radius: 2 }; this.setView('front'); }
  setView(name) {
    const { center, radius } = this.focus || { center: new THREE.Vector3(0, 1, 0), radius: 2 };
    const d = radius * 1.9;
    const dirs = { front: [0, 0.15, 1], back: [0, 0.15, -1], left: [-1, 0.15, 0], right: [1, 0.15, 0], top: [0, 1, 0.001], three: [0.8, 0.5, 1] };
    const v = new THREE.Vector3(...(dirs[name] || dirs.front)).normalize().multiplyScalar(d);
    this.camera.position.copy(center).add(v);
    this.camera.near = radius / 200; this.camera.far = radius * 200; this.camera.updateProjectionMatrix();
    this.controls.target.copy(center);
    this.controls.update();
  }
  setLight(intensity) { this.sun.intensity = 1.6 * intensity; this.hemi.intensity = 1.4 * intensity; }
  toggleGrid(on) { this.grid.visible = on; }
  setWireframe(on) {
    this.wire = on;
    this.forMeshes((m) => { for (const mat of [].concat(m.material)) mat.wireframe = on; });
  }
  clearHelpers() { for (const hh of this.helpers) { this.scene.remove(hh); hh.dispose?.(); } this.helpers = []; }
  setNormals(on) {
    this.clearHelpers();
    if (!on) return;
    let budget = 60000;
    this.forMeshes((m) => {
      const n = m.geometry.attributes.position?.count || 0;
      if (!m.geometry.attributes.normal || n > budget) return;
      budget -= n;
      const box = new THREE.Box3().setFromObject(m);
      const hh = new VertexNormalsHelper(m, box.getSize(new THREE.Vector3()).length() * 0.02, 0x3ccf8e);
      this.helpers.push(hh); this.scene.add(hh);
    });
  }
  forMeshes(fn, includeReference = false) {
    for (const m of this.models) if (includeReference || !m.reference) m.object.traverse((o) => { if (o.isMesh || o.isSkinnedMesh) fn(o); });
  }

  /** Matériaux du modèle principal (noms uniques). */
  materials() {
    const out = new Map();
    this.forMeshes((m) => { for (const mat of [].concat(m.material)) out.set(mat.name || '(sans nom)', mat); });
    return [...out.keys()];
  }

  /** Applique une image (canvas ou ImageData) comme texture de base d'un matériau. */
  applyTexture(materialName, source) {
    const flipY = this.models.find((m) => !m.reference)?.object.userData.flipY ?? true;
    const old = this.textures.get(materialName);
    let tex;
    if (source instanceof HTMLCanvasElement || source instanceof OffscreenCanvas) {
      tex = old instanceof THREE.CanvasTexture && old.image === source ? old : new THREE.CanvasTexture(source);
    } else {
      tex = new THREE.DataTexture(source.data, source.width, source.height, THREE.RGBAFormat);
      tex.flipY = !flipY; // DataTexture : origine en bas à gauche
    }
    if (tex instanceof THREE.CanvasTexture) tex.flipY = flipY;
    tex.colorSpace = THREE.SRGBColorSpace;
    tex.needsUpdate = true;
    if (old && old !== tex) old.dispose();
    this.textures.set(materialName, tex);
    this.forMeshes((m) => {
      for (const mat of [].concat(m.material)) {
        if ((mat.name || '(sans nom)') !== materialName) continue;
        mat.map = tex;
        if (mat.color) mat.color.set(0xffffff);
        mat.transparent = true; mat.alphaTest = 0.02;
        mat.needsUpdate = true;
      }
    });
  }
  removeTexture(materialName) {
    const t = this.textures.get(materialName);
    if (!t) return;
    this.forMeshes((m) => { for (const mat of [].concat(m.material)) if ((mat.name || '(sans nom)') === materialName) { mat.map = null; mat.needsUpdate = true; } });
    t.dispose(); this.textures.delete(materialName);
  }

  /** Segments UV (0…1) du modèle principal, pour superposer le patron sur la texture. */
  uvSegments(materialName = null, max = 200000) {
    const segs = [];
    let flipY = true;
    this.forMeshes((m) => {
      flipY = this.models.find((x) => !x.reference)?.object.userData.flipY ?? true;
      const g = m.geometry, uv = g.attributes.uv;
      if (!uv) return;
      const groups = g.groups.length ? g.groups : [{ start: 0, count: g.index ? g.index.count : uv.count, materialIndex: 0 }];
      const mats = [].concat(m.material);
      for (const gr of groups) {
        if (materialName && (mats[gr.materialIndex]?.name || '(sans nom)') !== materialName) continue;
        for (let i = gr.start; i + 2 < gr.start + gr.count && segs.length < max; i += 3) {
          const ids = g.index ? [g.index.getX(i), g.index.getX(i + 1), g.index.getX(i + 2)] : [i, i + 1, i + 2];
          for (let k = 0; k < 3; k++) {
            const a = ids[k], b = ids[(k + 1) % 3];
            segs.push([uv.getX(a), uv.getY(a), uv.getX(b), uv.getY(b)]);
          }
        }
      }
    });
    return { segments: segs, flipY };
  }

  pick(e) {
    const r = this.renderer.domElement.getBoundingClientRect();
    const p = new THREE.Vector2(((e.clientX - r.left) / r.width) * 2 - 1, -((e.clientY - r.top) / r.height) * 2 + 1);
    this.raycaster.setFromCamera(p, this.camera);
    const targets = [];
    this.forMeshes((m) => targets.push(m));
    const hit = this.raycaster.intersectObjects(targets, false)[0];
    this.select(hit ? hit.object : null);
  }
  select(obj) {
    this.selected = obj;
    if (obj) this.transform.attach(obj); else this.transform.detach();
    this.onSelect(obj ? { name: obj.name || '(sans nom)', material: [].concat(obj.material).map((m) => m.name).join(', '), vertices: obj.geometry.attributes.position?.count || 0 } : null);
  }
  setTransformMode(mode) { this.transform.setMode(mode); }
  resetTransform() { if (this.selected) { this.selected.position.set(0, 0, 0); this.selected.rotation.set(0, 0, 0); this.selected.scale.set(1, 1, 1); } }

  /** Copie de travail GLB du modèle principal (transformations et textures appliquées incluses). */
  async exportGlb() {
    const main = this.models.find((m) => !m.reference);
    if (!main) throw new Error('Aucun modèle chargé.');
    const out = await new GLTFExporter().parseAsync(main.object, { binary: true, onlyVisible: true });
    return new Uint8Array(out);
  }

  screenshot() { return this.renderer.domElement.toDataURL('image/png'); }

  dispose() {
    this.running = false;
    cancelAnimationFrame(this.raf);
    this.ro.disconnect();
    this.clear();
    this.transform.dispose();
    this.controls.dispose();
    this.renderer.dispose();
    this.renderer.forceContextLoss?.();
    this.renderer.domElement.remove();
  }
}

/** Contrôles géométriques simples : dimensions, UV, normales, triangles dégénérés, valeurs invalides. */
export function analyse(object) {
  const box = new THREE.Box3().setFromObject(object);
  const size = box.isEmpty() ? new THREE.Vector3() : box.getSize(new THREE.Vector3());
  let meshes = 0, vertices = 0, triangles = 0, noUv = 0, noNormal = 0, degenerate = 0, nan = 0, skinned = 0;
  const mats = new Set();
  const a = new THREE.Vector3(), b = new THREE.Vector3(), c = new THREE.Vector3();
  object.traverse((o) => {
    if (!o.isMesh) return;
    meshes++;
    if (o.isSkinnedMesh) skinned++;
    for (const m of [].concat(o.material)) mats.add(m.name || '(sans nom)');
    const g = o.geometry, pos = g.attributes.position;
    if (!pos) return;
    vertices += pos.count;
    if (!g.attributes.uv) noUv++;
    if (!g.attributes.normal) { noNormal++; g.computeVertexNormals(); }
    for (let i = 0; i < pos.count; i++) if (!Number.isFinite(pos.getX(i) + pos.getY(i) + pos.getZ(i))) { nan++; break; }
    const n = g.index ? g.index.count : pos.count;
    triangles += Math.floor(n / 3);
    for (let i = 0; i + 2 < n && i < 300000; i += 3) {
      const ia = g.index ? g.index.getX(i) : i, ib = g.index ? g.index.getX(i + 1) : i + 1, ic = g.index ? g.index.getX(i + 2) : i + 2;
      a.fromBufferAttribute(pos, ia); b.fromBufferAttribute(pos, ib); c.fromBufferAttribute(pos, ic);
      if (b.clone().sub(a).cross(c.clone().sub(a)).lengthSq() < 1e-14) degenerate++;
    }
  });
  const issues = [];
  if (!meshes) issues.push({ level: 'error', message: 'Aucun maillage affichable dans ce fichier.' });
  if (noUv) issues.push({ level: 'warning', message: `${noUv} maillage(s) sans UV : les textures ne s'y appliqueront pas.` });
  if (noNormal) issues.push({ level: 'info', message: `${noNormal} maillage(s) sans normales : calculées automatiquement.` });
  if (degenerate) issues.push({ level: 'warning', message: `${degenerate} triangle(s) dégénéré(s) (surface nulle).` });
  if (nan) issues.push({ level: 'error', message: `${nan} maillage(s) avec des coordonnées invalides.` });
  if (skinned) issues.push({ level: 'info', message: `${skinned} maillage(s) avec squelette : affichés en pose de repos.` });
  return { meshes, vertices, triangles, materials: [...mats], size, dimensions: [size.x, size.y, size.z].map((v) => Math.round(v * 1000) / 1000), issues };
}

function disposeObject(o) {
  o.traverse((x) => {
    if (x.geometry) x.geometry.dispose();
    for (const m of [].concat(x.material || [])) { for (const k of Object.keys(m)) if (m[k]?.isTexture) m[k].dispose(); m.dispose?.(); }
  });
}
