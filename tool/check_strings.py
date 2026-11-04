#!/usr/bin/env python3
"""Revisa que todas las claves usadas en el código Dart existan en los textos."""
import json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
es = json.loads((ROOT / "assets/l10n/es.json").read_text(encoding="utf-8"))
used = set()
pattern = re.compile(r"""\bs\.(?:t|plural)\(\s*'([\w.]+)'""")
for f in (ROOT / "lib").rglob("*.dart"):
    used |= set(pattern.findall(f.read_text(encoding="utf-8")))
missing = sorted(k for k in used if k not in es and not any(k + sfx in es for sfx in ("_one", "_other")))
unused = sorted(k for k in es if k not in used and not k.endswith(("_one", "_other")))
print(len(used), "claves usadas;", len(es), "definidas")
if unused:
    print("Sin usar:", ", ".join(unused[:40]), "..." if len(unused) > 40 else "")
if missing:
    sys.exit("Faltan: " + ", ".join(missing))
print("ok")
