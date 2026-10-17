#!/usr/bin/env python3
"""Génère docs/CATALOGUE.md depuis shared/catalog.lua (source unique). Usage : python3 tests/gen_catalogue.py"""
import os
from lupa import lua54

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
lua = lua54.LuaRuntime()
for rel in ['config.lua', 'shared/catalog.lua']:
    lua.execute(open(os.path.join(ROOT, rel), encoding='utf-8').read())
C = lua.globals().Catalog
cats = {c.id: c.label for c in C.Categories.values()}


def clip(c):
    return f'`{c.d}` / `{c.c}`' if c else '—'


def off(o):
    return f'x {o.x:g}, y {o.y:g}, z {o.z:g}, h {o.h:g}' if o else '—'


rows, details = [], []
counts = {}
for e in C.List.values():
    counts[e.status] = counts.get(e.status, 0) + 1
    steps = list(e.steps.values()) if e.steps else []
    rows.append(f'| {e.n} | `{e.id}` | {e.label} | {cats[e.cat]} | {e.type} | {C.Sources[e.source]} | {C.Statuses[e.status]} |')
    d = [f'### {e.n}. {e.label}  (`{e.id}`)', '',
         f'- Catégorie : {cats[e.cat]} · Type : {e.type} · Source : {C.Sources[e.source]}',
         f'- Statut : **{C.Statuses[e.status]}**' + (' · Adulte (option + confirmation explicite)' if e.adult else '') + (' · Fondu au noir facultatif' if e.fade else ''),
         f'- Description : {e.desc}']
    if e.roles:
        d.append(f'- Rôles : A = {e.roles.A} (reste sur place, repère) · B = {e.roles.B} (rejoint sa place, attaché à A)')
    if steps:
        mode = 'cycle (les étapes recommencent)' if e.cycle else ('boucle' if e.loop else 'une fois (fin automatique)')
        d.append(f'- Lecture : {mode}' + (' · le joueur peut marcher (haut du corps)' if e.move else ''))
        for i, st in enumerate(steps, 1):
            t = f'{st.time / 1000:g} s' if st.time else ('boucle' if (e.loop or e.cycle) else 'jusqu\'à la fin du clip')
            line = f'  - Étape {i} ({t}) : A {clip(st.A)}'
            if st.B:
                line += f' · B {clip(st.B)} · offset B/A : {off(st.off)} (estimation, à calibrer)'
            d.append(line)
    d.append('- Conditions : à pied, vivant, ni menotté, ni porté, ni escorté, hors véhicule' + ('; les deux participants à moins de 3 m, consentement de B' if e.type == 'duo' else ''))
    if e.deps:
        d.append('- Dépendances : ' + ', '.join(e.deps.values()))
    if e.ref:
        d.append(f'- Origine des noms de clips : {e.ref}')
    if e.note:
        d.append(f'- Remarque : {e.note}')
    details.append('\n'.join(d))

summary = ' · '.join(f'{C.Statuses[k]} : {v}' for k, v in counts.items())
out = f"""# Catalogue technique rp_animations

Généré automatiquement depuis `shared/catalog.lua` (`python3 tests/gen_catalogue.py`). Ne pas modifier à la main.

**Bilan : {summary}** (sur {len(rows)} fiches).

Statuts :
- **À valider en jeu** : le dictionnaire et le clip sont référencés (noms repris de rpemotes ou du jeu de base) et la ressource
  vérifie au chargement qu'ils existent chez le joueur. Le rendu visuel, l'offset et l'orientation n'ont **pas** encore été
  regardés en jeu. Une fois validée, le staff tape `/rpanim_valider <id>` et la fiche passe en « Native validée ».
- **À créer** : aucun clip existant ne correspond ; il faut produire une animation personnalisée (docs/ANIMATIONS_PERSONNALISEES.md).
  La fiche apparaît grisée dans le menu avec un message clair.
- **Native validée** / **Personnalisée produite et testée** : aucune pour l'instant (aucun test en jeu n'a pu être fait).

## Tableau

| N° | Identifiant | Nom | Catégorie | Type | Source | Statut |
|---|---|---|---|---|---|---|
""" + '\n'.join(rows) + '\n\n## Fiches détaillées\n\n' + '\n\n'.join(details) + '\n'

with open(os.path.join(ROOT, 'docs', 'CATALOGUE.md'), 'w', encoding='utf-8') as f:
    f.write(out)
print('docs/CATALOGUE.md :', summary)
