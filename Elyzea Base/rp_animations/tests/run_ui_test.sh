#!/usr/bin/env bash
# Test de l'interface NUI dans Chromium (Playwright), avec les vraies données envoyées par client/menu.lua.
# Prérequis : python3 + lupa, node + playwright. Captures d'écran écrites dans le dossier passé en argument (défaut /tmp/rp_ui).
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-/tmp/rp_ui}"
mkdir -p "$OUT"
cd "$HERE/.."
python3 - "$OUT" <<'PY'
import sys
sys.path.insert(0, 'tests')
from lupa import lua54
import run_tests as R
lua = lua54.LuaRuntime()
for f in ['tests/fivem_mock.lua'] + R.SHARED + ['tests/client_mock.lua'] + R.CLIENT:
    R.load(lua, f)
lua.execute("Mock.Advance(10); RPA.Anim.CheckAll(); Mock.Advance(5000); Mock.commands['danses']()")
open(sys.argv[1] + '/open.json', 'w').write(lua.eval("json.encode(CM.NuiMsgs('open')[1])"))
PY
NODE_PATH="$(npm root -g)" node "$HERE/ui_test.js" "$OUT" "$HERE/../html/index.html"
