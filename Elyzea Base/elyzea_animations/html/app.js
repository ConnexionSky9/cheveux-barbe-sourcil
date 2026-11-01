/* Elyzea · Menu des animations (NUI)
   Liste virtualisée : seules les cartes visibles existent dans la page (aucun gel, même avec 1 800 animations).
   Messages reçus de client.lua : open, close, notify, request, requestEnd, stopped, placed, init, env, outgoing, outgoingEnd
   Callbacks envoyés : close, playEmote, preview, previewEnd, stopEmote, placeEmote, respond, saveSettings, saveBinds,
                       getNearbyPlayers, propose, cancelOutgoing */
(() => {
"use strict";

/* ===================== DONNÉES ===================== */
const EMOTES = window.ELY_EMOTES || {};
const META = [
  {id:"gestes",name:"Gestes",icon:"hand",desc:"Saluer, montrer, réagir avec les mains."},
  {id:"reactions",name:"Réactions",icon:"laugh",desc:"Émotions et état du personnage."},
  {id:"danses",name:"Danses",icon:"music",desc:"Pour les soirées, les clubs et le reste."},
  {id:"duo",name:"À deux",icon:"users",type:"duo",desc:"Choisis un joueur proche : il reçoit une demande à accepter."},
  {id:"manger",name:"Boire & manger",icon:"utensils",desc:"Boissons et nourriture en main."},
  {id:"objets",name:"Objets",icon:"package",desc:"Animations avec un accessoire."},
  {id:"assis",name:"Assis & allongé",icon:"armchair",desc:"S'asseoir, s'allonger, s'agenouiller."},
  {id:"debout",name:"Debout & poses",icon:"person-standing",desc:"Attendre, s'adosser, prendre la pose."},
  {id:"sport",name:"Sport",icon:"dumbbell",desc:"Échauffement, entraînement, combat."},
  {id:"metiers",name:"Métiers",icon:"briefcase",desc:"Pour le RP des services et des entreprises."},
  {id:"rue",name:"Rue",icon:"skull",type:"rue",side:"rue",desc:"Le côté illégal d'Elyzea."},
  {id:"autres",name:"Divers",icon:"sparkles",desc:"Tout le reste : chutes, voitures, déguisements, situations."},
  {id:"marches",name:"Démarches",icon:"footprints",desc:"Ta façon de marcher, gardée jusqu'à « Par défaut » (même après une réapparition)."},
  {id:"humeurs",name:"Humeurs",icon:"smile",desc:"Expression du visage, gardée pendant que tu bouges."}
];
const ICONS = new Set(["hand","laugh","music","users","utensils","package","armchair","person-standing","dumbbell","briefcase","skull",
  "sparkles","footprints","smile","star","history","heart","handshake","car","flame","box","link","move","keyboard"]);
const ICON_ALIAS = {"heart-handshake":"heart","heart-pulse":"heart"};
const icon = n => { n = ICON_ALIAS[n] || n; return `<svg><use href="#i-${ICONS.has(n) ? n : "users"}"/></svg>`; };

const typeOf = cmd => cmd.startsWith("walk_") ? "walk" : cmd.startsWith("mood_") ? "mood" : cmd.startsWith("nearby_") ? "shared" : "emote";
const cmdLabel = i => i.type === "shared" ? "à deux · " + i.cmd.slice(7) : "/anim " + i.cmd;
function makeItem(n, cmd, f, cat, t, mode){
  const type = mode === "together" ? "together" : typeOf(cmd);
  const it = {n, cmd, f:f||"", cat, t:t||"", type, mode};
  it.code = cmdLabel(it);
  it.hay = (n + " " + cmd + " " + it.code).toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "");
  return it;
}
const CATS = [
  {id:"fav",name:"Favoris",icon:"star",desc:"Donne une touche à tes favoris pour les lancer sans ouvrir le menu."},
  {id:"recent",name:"Récents",icon:"history",desc:"Les 12 dernières animations lancées."},
  ...META.map(c => ({...c, items:(EMOTES[c.id] || []).map(([n, cmd, f]) => makeItem(n, cmd, f, c.id, c.type))}))
];
const ALL = CATS.flatMap(c => c.items || []);
const byCmd = Object.fromEntries(ALL.map(i => [i.cmd, i]));

/* Mode « proposer à un joueur » (menu ALT) : seulement les animations à deux */
let PROPOSE = null;
const curCats = () => PROPOSE ? PROPOSE.cats : CATS;
const curAll = () => PROPOSE ? PROPOSE.all : ALL;
const find = cmd => (PROPOSE && PROPOSE.byCmd[cmd]) || byCmd[cmd];

/* ===================== ÉTAT ===================== */
const DEF = {openKey:"K", stopKey:"X", pos:"left", preview:true, genderFilter:true, scale:100, amb:"both", showCmd:true, closeOnPlay:false};
const store = {
  get(k, d){ try { const v = localStorage.getItem("elyzea_anim_" + k); return v ? JSON.parse(v) : d; } catch(e){ return d; } },
  set(k, v){ try { localStorage.setItem("elyzea_anim_" + k, JSON.stringify(v)); } catch(e){} }
};
let S = {...DEF, ...store.get("settings", {})};
let favs = store.get("favs", []), recent = store.get("recent", []);
let binds = store.get("binds", {});
let ENV = {hidden:new Set(), inVehicle:false, male:null};
let cat = "gestes", playing = null, binding = null, bindingEmote = null, req = null;
let REQ_KEYS = {accept:"Y", refuse:"L", place:"J", fx:"G"};
let OTHER_KEYS = {F7:"Mes animaux (elyzea_animaux)"};
const BASE_RESERVED = ["W","A","S","D","Z","Q","E","F","G","R","T","C","V","H","P","N","U","I","L","M","ESPACE","TAB","ESCAPE",
  "1","2","3","4","5","F1","F2","F3","F4","F5","F6","F7","F8","F9","F10","F11","F12"];
const isReserved = k => BASE_RESERVED.includes(k) || !!OTHER_KEYS[k] || k === REQ_KEYS.accept || k === REQ_KEYS.refuse
  || (REQ_KEYS.place && k === REQ_KEYS.place) || (REQ_KEYS.fx && k === REQ_KEYS.fx);
const canDo = i => {
  if (ENV.hidden.has(i.cmd)) return false;
  if (i.f.includes("v") && !ENV.inVehicle) return false;
  if (i.f.includes("n") && ENV.inVehicle) return false;
  if (S.genderFilter && ENV.male !== null && ((ENV.male && i.f.includes("f")) || (!ENV.male && i.f.includes("m")))) return false;
  return true;
};
const canPlace = i => !PROPOSE && REQ_KEYS.place !== null && i.type === "emote" && !ENV.inVehicle && !i.f.includes("v");

const IS_FIVEM = typeof GetParentResourceName === "function";
if (IS_FIVEM) document.body.classList.replace("demo", "fivem");
function nui(ev, data){
  if (!IS_FIVEM) return Promise.resolve(null);
  return fetch(`https://${GetParentResourceName()}/${ev}`, {method:"POST", headers:{"Content-Type":"application/json"}, body:JSON.stringify(data || {})})
    .then(r => r.json()).catch(() => null);
}

/* ===================== OUTILS ===================== */
const $ = id => document.getElementById(id);
const esc = s => String(s).replace(/[&<>"]/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]));
const keyOf = cmd => Object.keys(binds).find(k => binds[k] && binds[k].emote === cmd);
const pretty = k => k.startsWith("NUMPAD") ? "Num " + k.slice(6) : k;
function keyName(e){
  if (e.code && e.code.startsWith("Digit")) return e.code.slice(5);
  if (e.code && e.code.startsWith("Numpad") && /\d$/.test(e.code)) return "NUMPAD" + e.code.slice(-1);
  if (/^F\d{1,2}$/.test(e.key)) return e.key;
  if (e.key === " ") return "ESPACE";
  if (e.key === "Tab") return "TAB";
  if (e.key === "Escape") return "ESCAPE";
  if (/^[a-z]$/i.test(e.key)) return e.key.toUpperCase();
  if (e.code && e.code.startsWith("Key")) return e.code.slice(3);
  return null;
}
function toast(t, kind){
  const e = $("toast"); e.textContent = t; e.classList.remove("ok", "err");
  if (kind) e.classList.add(kind);
  e.classList.add("show"); clearTimeout(e._t); e._t = setTimeout(() => e.classList.remove("show"), 2200);
}
const panel = $("panel"), wrap = $("listwrap"), spacer = $("spacer");
const isOpen = () => panel.classList.contains("open");

/* ===================== LISTE VIRTUALISÉE ===================== */
const ROW_H = 66, GAP = 8, MIN_W = 170;
let view = [], favView = false, sel = -1, cols = 1, colW = 0, frame = 0;

function layout(){
  const w = wrap.clientWidth - 4;
  cols = Math.max(1, Math.floor((w + GAP) / (MIN_W + GAP)));
  colW = Math.floor((w - GAP * (cols - 1)) / cols);
  spacer.style.height = Math.ceil(view.length / cols) * ROW_H + "px";
}
function tile(i, idx){
  const r = Math.floor(idx / cols), c = idx % cols;
  const on = favs.includes(i.cmd), k = keyOf(i.cmd);
  const bd = (i.f.includes("p") ? icon("box") : "") + (i.f.includes("x") ? icon("flame") : "") + (i.f.includes("v") ? icon("car") : "") + (i.f.includes("t") ? icon("link") : "");
  const keyUi = favView ? `<span class="keybtn ${k ? "set" : ""}" role="button" data-bind="${esc(i.cmd)}">${k ? esc(pretty(k)) : "+ Touche"}</span>`
    : (k ? `<span class="keytag">${esc(pretty(k))}</span>` : "");
  const placeUi = canPlace(i) ? `<span class="place" role="button" data-place="${esc(i.cmd)}" title="Placer où je veux (clic droit)">${icon("move")}</span>` : "";
  return `<div class="emote ${i.t} ${playing === i.cmd ? "playing" : ""} ${idx === sel ? "sel" : ""} ${k && !favView ? "bound" : ""}" role="button" data-i="${idx}" data-cmd="${esc(i.cmd)}"
    style="top:${r * ROW_H}px;left:${c * (colW + GAP)}px;width:${colW}px">
    <b title="${esc(i.n)}">${esc(i.n)}</b><span class="sub">${favView ? keyUi : ""}<code>${esc(i.code)}</code>${bd ? `<span class="bdg">${bd}</span>` : ""}</span>
    ${favView ? "" : keyUi}${placeUi}
    <span class="fav ${on ? "on" : ""}" role="button" data-fav="${esc(i.cmd)}" title="${on ? "Retirer des favoris" : "Ajouter aux favoris"}">${icon("star")}</span></div>`;
}
function paint(){
  frame = 0;
  if (!view.length){ spacer.innerHTML = ""; return; }
  const top = wrap.scrollTop, h = wrap.clientHeight || 600;
  const r0 = Math.max(0, Math.floor(top / ROW_H) - 2), r1 = Math.ceil((top + h) / ROW_H) + 2;
  const a = r0 * cols, b = Math.min(view.length, r1 * cols);
  let html = "";
  for (let idx = a; idx < b; idx++) html += tile(view[idx], idx);
  spacer.innerHTML = html;
}
const schedule = () => { if (!frame) frame = requestAnimationFrame(paint); };
wrap.addEventListener("scroll", schedule, {passive:true});
if (window.ResizeObserver) new ResizeObserver(() => { layout(); schedule(); }).observe(wrap);

function setSel(idx, scroll){
  if (!view.length){ sel = -1; return; }
  sel = Math.max(0, Math.min(view.length - 1, idx));
  if (scroll){
    const y = Math.floor(sel / cols) * ROW_H;
    if (y < wrap.scrollTop) wrap.scrollTop = y;
    else if (y + ROW_H > wrap.scrollTop + wrap.clientHeight) wrap.scrollTop = y + ROW_H - wrap.clientHeight;
  }
  paint();
}

/* ===================== RENDU ===================== */
function countFor(c){
  if (c.id === "fav") return favs.filter(k => find(k) && canDo(find(k))).length;
  if (c.id === "recent") return recent.filter(k => byCmd[k] && canDo(byCmd[k])).length;
  return c.items.filter(canDo).length;
}
function renderRail(){
  const q = $("q").value.trim();
  $("rail").innerHTML = curCats().map(c => `<button class="cat" role="tab" data-id="${c.id}" ${c.side ? `data-side="${c.side}"` : ""}
    aria-selected="${c.id === cat && !q}" type="button">${icon(c.icon)}${esc(c.name)}<span class="n">${countFor(c)}</span></button>`).join("");
}
function renderShortlist(show){
  const ks = Object.keys(binds).filter(k => binds[k]);
  $("shortlist").innerHTML = show && ks.length
    ? `<div class="shortlist">${ks.sort().map(k => `<span><kbd>${esc(pretty(k))}</kbd>${esc(byCmd[binds[k].emote]?.n || binds[k].emote)}</span>`).join("")}</div>` : "";
}
function renderList(keepScroll){
  const raw = $("q").value.trim().toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "");
  let items, title, desc;
  favView = false;
  if (raw){
    const words = raw.split(/\s+/);
    items = curAll().filter(i => words.every(w => i.hay.includes(w)));
    title = "Recherche"; desc = "";
  } else {
    const c = curCats().find(c => c.id === cat) || curCats()[0];
    title = c ? c.name : ""; desc = c ? c.desc : "";
    favView = cat === "fav";
    items = cat === "fav" ? favs.map(find).filter(Boolean) : cat === "recent" ? recent.map(k => byCmd[k]).filter(Boolean) : (c ? c.items : []);
  }
  view = items.filter(canDo);
  $("catTitle").textContent = title;
  $("catDesc").textContent = desc; $("catDesc").hidden = !desc;
  $("catCount").textContent = view.length + (view.length > 1 ? " animations" : " animation");
  $("qcount").textContent = raw ? String(view.length) : "";
  renderShortlist(favView);
  const empty = $("empty");
  if (!view.length){
    const m = raw ? ["Aucun résultat", `Rien ne correspond à « ${esc($("q").value)} ». Essaie un autre mot ou une commande.`]
      : PROPOSE ? ["Aucune animation à deux", "Aucune animation à deux n'est disponible ici."]
      : cat === "fav" ? ["Pas encore de favoris", "Touche l'étoile d'une animation, puis reviens ici pour lui donner une touche."]
      : cat === "recent" ? ["Rien de lancé", "Les animations que tu lances apparaîtront ici."]
      : ["Rien ici", "Aucune animation de cette catégorie n'est disponible pour ton personnage."];
    empty.innerHTML = `<b>${m[0]}</b>${m[1]}`;
  }
  empty.hidden = view.length > 0;
  if (!keepScroll){ wrap.scrollTop = 0; sel = view.length ? 0 : -1; }
  else if (sel >= view.length) sel = view.length - 1;
  layout(); paint();
}
function renderAll(keepScroll){ renderRail(); renderList(keepScroll); }

function setNow(i){
  playing = i ? i.cmd : null;
  $("nowbar").hidden = !i;
  $("nowName").textContent = i ? i.n : "";
  $("fxHint").hidden = !(i && i.f.includes("x"));
  $("fxKey").textContent = pretty(REQ_KEYS.fx || "G");
}

/* ===================== ACTIONS ===================== */
function play(cmd, target){
  if (PROPOSE){
    const p = PROPOSE.byCmd[cmd]; if (!p) return;
    nui("propose", {emote:cmd, target:PROPOSE.id});
    if (!IS_FIVEM){ showOutgoing({name:PROPOSE.name, label:p.n, timeout:15, key:REQ_KEYS.refuse}); setTimeout(() => showRequest({name:"Toi (aperçu)", label:p.n, timeout:15, preview:true}), 700); }
    close(); return;
  }
  const i = byCmd[cmd]; if (!i) return;
  const type = i.type;
  if (type === "shared" && target === undefined && isOpen()) return openPicker(i);
  nui("playEmote", {emote:cmd, type, label:i.n, target:target ?? null});
  if (type === "shared" && !IS_FIVEM && target !== undefined) setTimeout(() => showRequest({name:"Joueur " + target, label:i.n, timeout:15, preview:true}), 700);
  if (type === "emote") setNow(i);
  addRecent(cmd);
  if (!(type === "shared" && IS_FIVEM)) toast(type === "shared" ? `Demande envoyée : ${i.n}` : type === "walk" ? `Démarche : ${i.n}` : type === "mood" ? `Humeur : ${i.n}` : `Animation : ${i.n}`);
  renderAll(true);
  if (S.closeOnPlay && isOpen()) close();
}
function addRecent(cmd){ recent = [cmd, ...recent.filter(c => c !== cmd)].slice(0, 12); store.set("recent", recent); }
function place(cmd){
  const i = byCmd[cmd]; if (!i || !canPlace(i)) return;
  if (!IS_FIVEM) return toast("En jeu : déplace ton fantôme, puis valide avec Entrée");
  nui("placeEmote", {emote:cmd, label:i.n});
}
function placed(cmd){
  const i = byCmd[cmd]; if (!i) return;
  setNow(i); addRecent(cmd); toast(`Animation placée : ${i.n}`, "ok"); renderAll(true);
}
function stop(){
  nui("stopEmote");
  if (playing){ setNow(null); toast("Animation arrêtée"); renderList(true); }
}
function saveBinds(){ store.set("binds", binds); nui("saveBinds", {binds}); }
function toggleFav(cmd){
  if (favs.includes(cmd)){
    favs = favs.filter(c => c !== cmd);
    const k = keyOf(cmd); if (k){ delete binds[k]; saveBinds(); }
    toast("Retiré des favoris");
  } else { favs = [...favs, cmd]; toast("Ajouté aux favoris"); }
  store.set("favs", favs); renderAll(true);
}
function openBind(cmd){
  const i = byCmd[cmd]; if (!i) return;
  bindingEmote = cmd;
  const k = keyOf(cmd);
  $("bindName").textContent = i.n;
  $("bindKey").textContent = k ? pretty(k) : "…";
  $("bindRemove").hidden = !k;
  $("bindSheet").classList.add("open");
  document.activeElement?.blur();
}
function closeBind(){ bindingEmote = null; $("bindSheet").classList.remove("open"); }
function assign(k){
  if (k === S.openKey || k === S.stopKey) return toast(`${pretty(k)} sert déjà à ${k === S.openKey ? "ouvrir le menu" : "arrêter"}`);
  if (isReserved(k)) return toast(`${pretty(k)} est déjà utilisée par le jeu ou par le menu, choisis une autre touche`, "err");
  const i = byCmd[bindingEmote]; if (!i) return closeBind();
  const old = keyOf(bindingEmote); if (old) delete binds[old];
  const prev = binds[k];
  binds[k] = {emote:bindingEmote, type:i.type, label:i.n};
  if (!favs.includes(bindingEmote)){ favs = [...favs, bindingEmote]; store.set("favs", favs); }
  saveBinds();
  toast(prev && prev.emote !== bindingEmote ? `${pretty(k)} remplace ${byCmd[prev.emote]?.n || prev.emote}` : `${pretty(k)} lance ${i.n}`);
  closeBind(); renderAll(true);
}
async function openPicker(i){
  $("pickTitle").textContent = i.n + " avec…";
  $("pickList").innerHTML = `<div class="empty"><b>Recherche…</b></div>`;
  $("pickList").dataset.cmd = i.cmd;
  $("picker").classList.add("open");
  let players = await nui("getNearbyPlayers");
  if (!players) players = IS_FIVEM ? [] : [{id:12, name:"Joueur 12", dist:1.4}, {id:37, name:"Joueur 37", dist:2.8}];
  if ($("pickList").dataset.cmd !== i.cmd) return;
  $("pickList").innerHTML = players.length ? players.map(p => `<button class="player" data-pid="${Number(p.id)}" type="button">
      <span class="id">${Number(p.id)}</span><span><b>${esc(p.name)}</b><small>à ${Number(p.dist).toFixed(1)} m</small></span></button>`).join("")
    : `<div class="empty"><b>Personne à côté</b>Approche-toi à moins de 3 mètres d'un joueur, puis réessaie.</div>`;
}

/* ===================== DEMANDES À DEUX ===================== */
function runBar(bar, t){
  bar.style.transition = "none"; bar.style.transform = "scaleX(1)";
  requestAnimationFrame(() => requestAnimationFrame(() => { bar.style.transition = `transform ${t}s linear`; bar.style.transform = "scaleX(0)"; }));
}
function showRequest(r){
  req = r;
  $("reqName").textContent = r.name || "Un joueur";
  $("reqLabel").textContent = r.label || r.emote || "une animation";
  $("reqPreview").hidden = !r.preview;
  $("reqKeyYes").textContent = pretty(REQ_KEYS.accept);
  $("reqKeyNo").textContent = pretty(REQ_KEYS.refuse);
  const t = r.timeout || 15;
  runBar($("reqBar"), t);
  $("req").classList.add("show");
  clearTimeout(showRequest._t);
  showRequest._t = setTimeout(() => { if (req === r){ hideRequest(); if (!IS_FIVEM) toast("Demande expirée", "err"); } }, t * 1000);
}
function hideRequest(){ req = null; clearTimeout(showRequest._t); $("req").classList.remove("show"); }
function respond(accept){
  if (!req) return;
  const r = req; hideRequest();
  nui("respond", {accept});
  if (!IS_FIVEM) toast(accept ? `Tu as accepté : ${r.label}` : `Tu as refusé : ${r.label}`, accept ? "ok" : "err");
}
$("reqYes").onclick = () => respond(true);
$("reqNo").onclick = () => respond(false);
function showOutgoing(o){
  $("outName").textContent = o.name || "un joueur";
  $("outLabel").textContent = o.label || "une animation";
  $("outKey").textContent = pretty(o.key || REQ_KEYS.refuse);
  const t = o.timeout || 15;
  runBar($("outBar"), t);
  $("out").classList.add("show");
  clearTimeout(showOutgoing._t);
  showOutgoing._t = setTimeout(hideOutgoing, (t + 1) * 1000);
}
function hideOutgoing(){ clearTimeout(showOutgoing._t); $("out").classList.remove("show"); }
$("outCancel").onclick = () => { nui("cancelOutgoing"); if (!IS_FIVEM){ hideOutgoing(); toast("Invitation annulée"); } };
$("proposeQuit").onclick = () => close();

function setPropose(p){
  if (!p){ PROPOSE = null; document.body.classList.remove("proposing"); $("proposeBar").hidden = true; if (cat.startsWith("px_")) cat = "gestes"; return; }
  const cats = (p.cats || []).map(c => ({id:c.id, name:c.name, icon:c.icon || "users", desc:c.desc || "", mode:c.mode,
    items:(c.items || []).map(([n, cmd, f]) => makeItem(n, cmd, f, c.id, "duo", c.mode))}));
  const all = cats.flatMap(c => c.items);
  PROPOSE = {id:p.id, name:p.name, cats, all, byCmd:Object.fromEntries(all.map(i => [i.cmd, i]))};
  cat = cats.length ? cats[0].id : "gestes";
  $("proposeName").textContent = p.name || ("ID " + p.id);
  $("proposeBar").hidden = false;
  document.body.classList.add("proposing");
}

/* ===================== APERÇU 3D (en jeu : ton personnage) ===================== */
let pvCmd = null, pvTimer = null;
function hoverPreview(cmd){
  if (!S.preview || cmd === pvCmd || !IS_FIVEM) return;
  pvCmd = cmd; clearTimeout(pvTimer);
  pvTimer = setTimeout(() => nui("preview", {emote:cmd}), 150);
}
function endPreview(){
  clearTimeout(pvTimer); if (pvCmd === null) return; pvCmd = null;
  if (IS_FIVEM) nui("previewEnd");
}
function setEnv(e){
  if (Array.isArray(e.hidden)) ENV.hidden = new Set(e.hidden);
  if (typeof e.inVehicle === "boolean") ENV.inVehicle = e.inVehicle;
  if (typeof e.male === "boolean") ENV.male = e.male;
  applySettings(); renderAll(true);
}

/* ===================== OUVERTURE ===================== */
function open(propose){
  setPropose(propose || null); $("q").value = ""; panel.classList.add("open"); renderAll();
  $("hint").style.opacity = 0; setTimeout(() => $("q").focus(), 50);
}
function close(){
  const was = isOpen();
  panel.classList.remove("open");
  if (PROPOSE){ setPropose(null); renderAll(); }
  ["settings", "picker", "bindSheet"].forEach(id => $(id).classList.remove("open"));
  bindingEmote = null; binding = null; endPreview(); $("hint").style.opacity = 1; document.activeElement?.blur();
  if (was || IS_FIVEM) nui("close");
}
window.addEventListener("message", e => {
  const d = e.data || {};
  if (d.env) setEnv(d.env);
  switch (d.action){
    case "open": open(d.propose); break;
    case "close": close(); break;
    case "outgoing": showOutgoing(d); break;
    case "outgoingEnd": hideOutgoing(); break;
    case "stopped": if (playing){ setNow(null); renderList(true); } break;
    case "placed": placed(d.emote); break;
    case "request": showRequest(d); break;
    case "requestEnd": hideRequest(); break;
    case "notify": toast(d.text, d.kind); break;
    case "init":
      if (d.keys) REQ_KEYS = {...REQ_KEYS, place:null, ...d.keys};
      if (d.reserved && typeof d.reserved === "object") OTHER_KEYS = d.reserved;
      if (d.settings) S = {...S, ...d.settings};
      if (d.binds && typeof d.binds === "object") binds = d.binds;
      store.set("settings", S); store.set("binds", binds); applySettings(); renderAll(true);
      break;
  }
});

/* ===================== PARAMÈTRES ===================== */
function applySettings(){
  panel.classList.toggle("left", S.pos === "left");
  document.documentElement.style.setProperty("--scale", S.scale / 100);
  document.body.classList.remove("amb-legal", "amb-illegal");
  if (S.amb !== "both") document.body.classList.add("amb-" + S.amb);
  document.body.classList.toggle("nocmd", !S.showCmd);
  ["kOpen", "hintKey", "bindOpen"].forEach(id => $(id).textContent = pretty(S.openKey));
  ["kStop", "bindStop"].forEach(id => $(id).textContent = pretty(S.stopKey));
  $("scale").value = S.scale; $("scaleVal").textContent = S.scale + " %";
  document.querySelectorAll("#segPos button").forEach(b => b.classList.toggle("on", b.dataset.v === S.pos));
  document.querySelectorAll("#segAmb button").forEach(b => b.classList.toggle("on", b.dataset.v === S.amb));
  $("swCmd").setAttribute("aria-checked", S.showCmd);
  $("swClose").setAttribute("aria-checked", S.closeOnPlay);
  $("swPreview").setAttribute("aria-checked", S.preview);
  $("swGender").setAttribute("aria-checked", S.genderFilter);
  $("kPlaceWrap").hidden = REQ_KEYS.place === null;
  $("fxKey").textContent = pretty(REQ_KEYS.fx || "G");
  $("subtitle").textContent = `Elyzea roleplay · ${ALL.filter(canDo).length} animations`;
}
function save(){ store.set("settings", S); applySettings(); nui("saveSettings", S); }
function startBind(which){ binding = which; const b = $(which === "open" ? "bindOpen" : "bindStop"); b.classList.add("listening"); b.textContent = "…"; }
function endBind(){ binding = null; $("bindOpen").classList.remove("listening"); $("bindStop").classList.remove("listening"); applySettings(); }

/* ===================== ÉVÉNEMENTS ===================== */
$("rail").addEventListener("click", e => {
  const b = e.target.closest(".cat"); if (!b) return;
  cat = b.dataset.id; $("q").value = ""; renderAll();
});
function tileAction(e){
  const bd = e.target.closest("[data-bind]"); if (bd){ e.stopPropagation(); e.preventDefault(); return openBind(bd.dataset.bind); }
  const f = e.target.closest("[data-fav]"); if (f){ e.stopPropagation(); e.preventDefault(); return toggleFav(f.dataset.fav); }
  const pl = e.target.closest("[data-place]"); if (pl){ e.stopPropagation(); e.preventDefault(); return place(pl.dataset.place); }
  const t = e.target.closest(".emote"); if (t){ e.preventDefault(); const i = view[+t.dataset.i]; if (i) play(i.cmd); }
}
spacer.addEventListener("click", tileAction);
spacer.addEventListener("contextmenu", e => { const t = e.target.closest(".emote"); if (!t) return; e.preventDefault(); const i = view[+t.dataset.i]; if (i) place(i.cmd); });
spacer.addEventListener("mouseover", e => {
  const t = e.target.closest(".emote"); if (!t) return;
  const idx = +t.dataset.i;
  if (idx !== sel){ const old = spacer.querySelector(".emote.sel"); if (old) old.classList.remove("sel"); t.classList.add("sel"); sel = idx; }
  if (view[idx]) hoverPreview(view[idx].cmd);
});
wrap.addEventListener("mouseleave", endPreview);
$("pickList").addEventListener("click", e => {
  const p = e.target.closest(".player"); if (!p) return;
  $("picker").classList.remove("open"); play($("pickList").dataset.cmd, Number(p.dataset.pid));
});
let qTimer = 0;
$("q").addEventListener("input", () => { clearTimeout(qTimer); qTimer = setTimeout(() => renderAll(), 70); });
$("stopBtn").onclick = stop;
$("closeBtn").onclick = close;
$("openBtn").onclick = () => open();
$("settingsBtn").onclick = () => $("settings").classList.add("open");
document.querySelectorAll("[data-close]").forEach(b => b.onclick = () => { b.dataset.close === "bindSheet" ? closeBind() : $(b.dataset.close).classList.remove("open"); });
$("bindCancel").onclick = closeBind;
$("bindRemove").onclick = () => { const k = keyOf(bindingEmote); if (k){ delete binds[k]; saveBinds(); toast(`Raccourci ${pretty(k)} retiré`); } closeBind(); renderAll(true); };
$("bindOpen").onclick = () => startBind("open");
$("bindStop").onclick = () => startBind("stop");
$("segPos").onclick = e => { const b = e.target.closest("button"); if (b){ S.pos = b.dataset.v; save(); } };
$("segAmb").onclick = e => { const b = e.target.closest("button"); if (b){ S.amb = b.dataset.v; save(); } };
$("scale").oninput = e => { S.scale = +e.target.value; save(); };
$("swCmd").onclick = () => { S.showCmd = !S.showCmd; save(); };
$("swClose").onclick = () => { S.closeOnPlay = !S.closeOnPlay; save(); };
$("swPreview").onclick = () => { S.preview = !S.preview; save(); if (!S.preview) endPreview(); };
$("swGender").onclick = () => { S.genderFilter = !S.genderFilter; save(); renderAll(true); };
$("resetBinds").onclick = () => { binds = {}; saveBinds(); renderAll(true); toast("Raccourcis retirés"); };
$("resetFav").onclick = () => { favs = []; recent = []; binds = {}; store.set("favs", favs); store.set("recent", recent); saveBinds(); renderAll(true); toast("Favoris et historique vidés"); };

document.addEventListener("keydown", e => {
  const k = keyName(e);
  if (bindingEmote){
    e.preventDefault();
    if (e.key === "Escape") return closeBind();
    if (e.key === "Delete" || e.key === "Backspace") return $("bindRemove").click();
    if (k) assign(k);
    return;
  }
  if (binding){
    e.preventDefault();
    if (e.key === "Escape") return endBind();
    if (!k || k === "ESCAPE") return;
    const other = binding === "open" ? S.stopKey : S.openKey;
    if (k === other) return toast(`${pretty(k)} est déjà utilisée`);
    if (OTHER_KEYS[k]) return toast(`${pretty(k)} est réservée à ${OTHER_KEYS[k]}, choisis une autre touche`, "err");
    if (binds[k]) return toast(`${pretty(k)} lance déjà ${byCmd[binds[k].emote]?.n || "une animation"}`);
    if (binding === "open") S.openKey = k; else S.stopKey = k;
    endBind(); save(); toast(`Touche enregistrée : ${pretty(k)}`); return;
  }
  if (e.key === "Escape"){
    if ($("picker").classList.contains("open")) return $("picker").classList.remove("open");
    if ($("settings").classList.contains("open")) return $("settings").classList.remove("open");
    if (isOpen()) return close();
  }
  // Navigation au clavier dans la liste (aussi depuis la recherche)
  if (isOpen() && !$("settings").classList.contains("open") && !$("picker").classList.contains("open")){
    const inQ = document.activeElement === $("q");
    const step = {ArrowDown:cols, ArrowUp:-cols, ArrowRight:inQ ? 0 : 1, ArrowLeft:inQ ? 0 : -1, PageDown:cols * 6, PageUp:-cols * 6}[e.key];
    if (step){ e.preventDefault(); return setSel(sel < 0 ? 0 : sel + step, true); }
    if (e.key === "Enter" && sel >= 0 && view[sel]){ e.preventDefault(); return play(view[sel].cmd); }
  }
  if (document.activeElement === $("q")) return;
  if (!k) return;
  if (req && k === REQ_KEYS.accept){ e.preventDefault(); return respond(true); }
  if (req && k === REQ_KEYS.refuse){ e.preventDefault(); return respond(false); }
  if (!req && k === REQ_KEYS.refuse && $("out").classList.contains("show")){ e.preventDefault(); return $("outCancel").click(); }
  if (k === S.openKey){ e.preventDefault(); return isOpen() ? close() : open(); }
  if (k === S.stopKey) return stop();
  // Raccourcis (dans le navigateur ; en jeu c'est client.lua qui les gère menu fermé)
  if (!IS_FIVEM && binds[k]){ e.preventDefault(); play(binds[k].emote); }
});

applySettings(); renderAll();
if (!IS_FIVEM) setTimeout(open, 300);
window.__ely = {view:() => view, sel:() => sel, cols:() => cols, total:ALL.length};
})();
