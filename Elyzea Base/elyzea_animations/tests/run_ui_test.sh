#!/usr/bin/env bash
# Test du menu K dans Chromium (Playwright) avec les vraies données envoyées par client.lua (natives simulées).
# Prérequis : python3 + lupa, node + playwright. Captures écrites dans le dossier donné (défaut /tmp/elyzea_ui).
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-/tmp/elyzea_ui}"
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
lua.execute("Mock.Advance(9000)")
open(sys.argv[1] + '/k_danses.json', 'w').write(lua.eval("json.encode(CM.NuiMsgs('danses')[1])"))
open(sys.argv[1] + '/k_env.json', 'w').write(lua.eval("json.encode(CM.NuiMsgs('env')[1])"))
PY
NODE_PATH="$(npm root -g)" node "$HERE/ui_test.js" "$OUT" "$HERE/../html/index.html"
