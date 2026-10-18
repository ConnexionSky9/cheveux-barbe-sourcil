#!/usr/bin/env bash
# =====================================================================
#  Bébé Elyzea : chaîne complète, sans aucune action manuelle
#  1. modèle 3D (Blender)  1b. porte-bébés et poussette  2. conversion GTA (Sollumz -> XML)  3. binaires GTA (CodeWalker.Core)
#  4. liste des modèles de la ressource FiveM  5. contrôles  6. planches de rendu
#
#  Prérequis (Linux ou WSL ; testé sous Linux) :
#    pip install bpy==5.2.* numpy pillow scikit-image szio==1.3.0.dev9
#    extension Sollumz v2.9.0 dans ~/.config/blender/5.2/scripts/addons/sollumz (voir README_BEBE.md)
#    .NET 8 SDK, git
# =====================================================================
set -euo pipefail
ICI="$(cd "$(dirname "$0")" && pwd)"
RES="$ICI/../../Elyzea Base/elyzea_bebe_modele"
cd "$ICI/scripts"
echo "== 1/8 Modèle 3D du bébé";     python3 generate_baby.py --out ../build
echo "== 2/8 Porte-bébés, poussette"; python3 equipements.py --build ../build
echo "== 3/8 Export GTA (XML)";      python3 export_gta.py --build ../build
echo "== 4/8 Binaires GTA";          rm -f "$RES/stream/"ely_bebe*; ../convertisseur/convertir.sh ../build/gta_xml "$RES/stream"
echo "== 5/8 Ressource FiveM";       python3 make_resource.py --build ../build
echo "== 6/8 Contrôles";             python3 validate.py --build ../build
echo "== 7/8 Planches de rendu";     python3 render_galerie.py --build ../build
echo "== 8/8 Rendu des fichiers du jeu (relus)"; python3 rendu_jeu.py --build ../build
echo "Terminé."
