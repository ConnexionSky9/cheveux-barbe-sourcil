#!/usr/bin/env bash
# Copie le kit de marque Elyzea FA (elyzea_core/brand) dans les interfaces qui l'utilisent.
# Usage : bash elyzea_core/brand/sync_brand.sh   (depuis le dossier « Elyzea Base »)
set -e
B="$(cd "$(dirname "$0")" && pwd)"
cd "$B/../.."
for d in elyzea_multichar/html elyzea_hud/html elyzea_aura/html elyzea_papiers/html elyzea_permis/html; do
  [ -d "$d" ] || continue
  cp "$B/brand.css" "$B/brand.js" "$d/"
  case "$d" in elyzea_multichar/*|elyzea_hud/*) ;; *) cp "$B/cards.css" "$B/cards.js" "$d/" ;; esac
  echo "kit copié → $d"
done
