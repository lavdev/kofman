#!/usr/bin/env bash
# Byte Eater — patch the compiled index.html to load the keyboard bridge.
set -euo pipefail

HTML="web/index.html"
BRIDGE="keyboard_bridge.js"
STYLE="retro.css"

cp assets/web-input.js "web/$BRIDGE"
cp assets/retro.css "web/$STYLE"

python3 - "$HTML" <<'PY'
import io, sys
p = sys.argv[1]
s = io.open(p, encoding='utf-8').read()
tag = '<script src="keyboard_bridge.js"></script>'
if tag not in s:
    s = s.replace('</body>', tag + '\n</body>')
style = '<link rel="stylesheet" href="retro.css">'
if style not in s:
    s = s.replace('</head>', style + '\n</head>')
io.open(p, 'w', encoding='utf-8').write(s)
PY
