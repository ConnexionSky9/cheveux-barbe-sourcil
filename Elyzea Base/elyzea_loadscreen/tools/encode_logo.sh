#!/usr/bin/env bash
# =====================================================================
#  ELYZEA FA — encodage du logo animé pour le loading screen
#  Usage : bash tools/encode_logo.sh <vidéo source.mp4>
#  Produit dans assets/video/ :
#    logo_4k120.webm    3840×2160, 120 i/s (images intermédiaires calculées par
#                       interpolation de mouvement, pas des doublons), VP9
#    logo_1080p60.webm  1920×1080, 60 i/s, VP9
#    logo_final.webp    dernière image (secours)
#  Le fond quasi noir de la source est ramené au noir pur (colorlevels) : la page
#  pose le logo sur le décor en mode « screen », le noir devient transparent.
#  VP9 : lu par le navigateur de FiveM sans codec propriétaire.
# =====================================================================
set -euo pipefail
SRC="${1:?vidéo source}"
OUT="$(cd "$(dirname "$0")/.." && pwd)/assets/video"
TMP="$(mktemp -d)"
LV="colorlevels=rimin=0.05:gimin=0.04:bimin=0.08"
mkdir -p "$OUT"

# 1) 60 → 120 i/s par interpolation de mouvement (à la taille d'origine)
ffmpeg -v error -y -i "$SRC" -vf "minterpolate=fps=120:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1" \
    -c:v libx264 -preset ultrafast -qp 0 -pix_fmt yuv420p "$TMP/interp120.mkv"

# 2) 4K : agrandissement Lanczos + netteté légère + noir pur, encodage VP9
ffmpeg -v error -y -i "$TMP/interp120.mkv" -vf "scale=3840:2160:flags=lanczos,unsharp=5:5:0.6:5:5:0.0,$LV" -an \
    -c:v libvpx-vp9 -b:v 0 -crf 30 -row-mt 1 -tile-columns 3 -cpu-used 4 -deadline good -pix_fmt yuv420p "$OUT/logo_4k120.webm"

# 3) 1080p 60 i/s (écrans plus petits / PC modestes)
ffmpeg -v error -y -i "$SRC" -vf "$LV" -an -c:v libvpx-vp9 -b:v 0 -crf 26 -row-mt 1 -tile-columns 2 -cpu-used 3 -deadline good \
    -pix_fmt yuv420p "$OUT/logo_1080p60.webm"

# 4) Dernière image
ffmpeg -v error -y -sseof -0.05 -i "$SRC" -frames:v 1 -vf "$LV" "$TMP/final.png"
ffmpeg -v error -y -i "$TMP/final.png" -quality 92 "$OUT/logo_final.webp"

rm -rf "$TMP"
ls -la "$OUT"
