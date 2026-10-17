#!/usr/bin/env bash
# Convertit build/gta_xml (CodeWalker XML) en fichiers binaires GTA V dans la ressource FiveM.
# Prérequis : .NET 8 SDK, git. Linux ou Windows (Git Bash / WSL).
set -euo pipefail
ICI="$(cd "$(dirname "$0")" && pwd)"
CW="$ICI/../CodeWalker"
[ -d "$CW" ] || git clone --depth 1 https://github.com/dexyfex/CodeWalker.git "$CW"
XML="${1:-$ICI/../build/gta_xml}"
SORTIE="${2:-$ICI/../../../Elyzea Base/elyzea_bebe_modele/stream}"
dotnet run -c Release --project "$ICI/ElyConvert.csproj" -p:CodeWalkerCore="$CW/CodeWalker.Core/CodeWalker.Core.csproj" -- "$XML" "$SORTIE"
