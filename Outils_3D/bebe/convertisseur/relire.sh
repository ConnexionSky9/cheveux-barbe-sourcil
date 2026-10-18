#!/usr/bin/env bash
# Relit des binaires du jeu (.ydr / .ytd) et les réécrit en XML CodeWalker (contrôle : ce que FiveM chargera).
# Usage : relire.sh <dossier_sortie_xml> <fichiers...>
set -euo pipefail
ICI="$(cd "$(dirname "$0")" && pwd)"
CW="$ICI/../CodeWalker"
[ -d "$CW" ] || git clone --depth 1 https://github.com/dexyfex/CodeWalker.git "$CW"
dotnet run -c Release --project "$ICI/ElyConvert.csproj" -p:CodeWalkerCore="$CW/CodeWalker.Core/CodeWalker.Core.csproj" -- --relire "$@"
