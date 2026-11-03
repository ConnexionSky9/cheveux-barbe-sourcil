#!/usr/bin/env bash
# Lance tous les tests hors jeu d'elyzea_lasergame (depuis n'importe où).
#   Prérequis : python3 (+ lupa, numpy, pillow), node + playwright (Chromium)
set -u
cd "$(dirname "$0")/.."
FAIL=0
run() { echo; echo "=== $1 ==="; shift; "$@" || FAIL=$((FAIL + 1)); }
run "Syntaxe Lua 5.4 (tous les fichiers)"           python3 tests/syntax_check.py
run "Syntaxe JavaScript (interface)"                node --check html/script.js
run "Cartes : génération + validation"              python3 tools/mapgen/build_all.py
run "Contrats serveur / client / interface"         python3 tests/contract_check.py
run "Simulation du serveur (PVP, Zombie, argent…)"  python3 tests/run_server_sim.py
run "Interface dans Chromium (16 écrans)"           node tests/ui_screens.cjs "${SCREENS_DIR:-tests/screens}"
echo
if [ "$FAIL" -eq 0 ]; then echo "TOUS LES TESTS SONT PASSÉS"; else echo "$FAIL SUITE(S) EN ÉCHEC"; fi
exit "$FAIL"
