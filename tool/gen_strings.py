#!/usr/bin/env python3
"""Genera assets/l10n/{es,es_AR,it}.json a partir de los módulos de tool/strings/.

Cada módulo define una lista STRINGS con tuplas:
    (clave, es_ES, it)                 o
    (clave, es_ES, it, es_AR)          cuando el voseo cambia el texto.
La base `es` está en tuteo (España); `es_AR` solo guarda lo que cambia.
Falla si una clave se repite o si los marcadores {x} no coinciden entre idiomas.
"""
import importlib.util, json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/l10n"

def markers(text):
    return sorted(re.findall(r"\{(\w+)\}", text))

def main():
    es, it, es_ar = {}, {}, {}
    for path in sorted((ROOT / "tool/strings").glob("*.py")):
        spec = importlib.util.spec_from_file_location(path.stem, path)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        for row in mod.STRINGS:
            key, e, i = row[0], row[1], row[2]
            ar = row[3] if len(row) > 3 else None
            if key in es:
                sys.exit(f"Clave repetida: {key} ({path.name})")
            if markers(e) != markers(i) or (ar and markers(ar) != markers(e)):
                sys.exit(f"Marcadores distintos en {key}")
            es[key], it[key] = e, i
            if ar and ar != e:
                es_ar[key] = ar
    OUT.mkdir(parents=True, exist_ok=True)
    for name, data in (("es", es), ("es_AR", es_ar), ("it", it)):
        (OUT / f"{name}.json").write_text(json.dumps(data, ensure_ascii=False, indent=1, sort_keys=True), encoding="utf-8")
    print(len(es), "textos;", len(es_ar), "con voseo")

if __name__ == "__main__":
    main()
