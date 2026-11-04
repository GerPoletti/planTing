#!/usr/bin/env python3
"""Revisiones estáticas sin compilar: importaciones, rutas, paréntesis y textos dinámicos."""
import json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
errors = []

def strip_code(src):
    """Quita comentarios y literales de texto para contar paréntesis."""
    src = re.sub(r"//[^\n]*", "", src)
    src = re.sub(r"/\*.*?\*/", "", src, flags=re.S)
    src = re.sub(r"'''.*?'''", "''", src, flags=re.S)
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if c in "'\"":
            q, i = c, i + 1
            depth = 0
            while i < n:
                if src[i] == "\\":
                    i += 2
                    continue
                if src[i] == "$" and i + 1 < n and src[i + 1] == "{":
                    depth += 1
                    i += 2
                    continue
                if depth and src[i] == "}":
                    depth -= 1
                    i += 1
                    continue
                if src[i] == q and not depth:
                    break
                i += 1
            out.append("''")
        else:
            out.append(c)
        i += 1
    return "".join(out)

dart_files = sorted((ROOT / "lib").rglob("*.dart")) + sorted((ROOT / "test").rglob("*.dart"))
native = ROOT / "native" / "mirasol_light.dart"
dart_files.append(native)

# 1) importaciones
for f in dart_files:
    text = f.read_text(encoding="utf-8")
    for m in re.finditer(r"^import '([^']+)'", text, re.M):
        path = m.group(1)
        if path.startswith("package:plantapp/"):
            target = ROOT / "lib" / path[len("package:plantapp/"):]
        elif path.startswith(("dart:", "package:")):
            continue
        else:
            target = (f.parent / path).resolve()
        if not target.exists():
            errors.append(f"{f.relative_to(ROOT)}: importación inexistente {path}")

# 2) balance de paréntesis
pairs = {")": "(", "]": "[", "}": "{"}
for f in dart_files:
    code = strip_code(f.read_text(encoding="utf-8"))
    stack = []
    for ch in code:
        if ch in "([{":
            stack.append(ch)
        elif ch in ")]}":
            if not stack or stack.pop() != pairs[ch]:
                errors.append(f"{f.relative_to(ROOT)}: paréntesis desparejados")
                break
    else:
        if stack:
            errors.append(f"{f.relative_to(ROOT)}: falta cerrar {stack[-1]}")

# 3) rutas usadas vs. definidas
router = (ROOT / "lib/app/router.dart").read_text(encoding="utf-8")
defined = set(re.findall(r"path: '([^']+)'", router))
def matches(route):
    route = route.split("?")[0]
    for d in defined:
        pattern = "^" + re.sub(r":\w+", r"[^/]+", d) + "$"
        if re.match(pattern, re.sub(r"\$\{[^}]*\}|\$\w+", "x", route)):
            return True
    return False
for f in (ROOT / "lib").rglob("*.dart"):
    text = f.read_text(encoding="utf-8")
    for m in re.finditer(r"context\.(?:push|go|pushReplacement)\(\s*'([^']*)'", text):
        if not matches(m.group(1)):
            errors.append(f"{f.relative_to(ROOT)}: ruta sin definir {m.group(1)}")
    for m in re.finditer(r"context\.(?:push|go|pushReplacement)\(\s*(?:plantId == null \? '([^']*)' : )?'([^']*)'", text):
        pass

# 4) textos con clave dinámica
es = json.loads((ROOT / "assets/l10n/es.json").read_text(encoding="utf-8"))
def need(prefix, names, suffixes=("",)):
    for n in names:
        for sfx in suffixes:
            k = f"{prefix}{n}{sfx}"
            if k not in es:
                errors.append(f"falta el texto {k}")
need("plant.event.", ["water", "fertilize", "repot", "prune", "note", "photo", "problem", "treatment"])
need("species.place.", ["indoor", "outdoor", "both"])
need("measure.src.", ["sun", "ledCool", "ledWarm", "fluorescent", "hps"])
need("onb.room.", ["living", "kitchen", "bedroom", "balcony", "office"])
need("window.wall.", ["t", "r", "b", "l"])
need("dir.", ["n", "ne", "e", "se", "s", "sw", "w", "nw"])
need("moisture.level.", ["dry", "drying", "moist", "wet"])
need("moisture.hint.", ["dry", "drying", "moist", "wet"])
need("primer.", ["location", "camera", "notifications"], (".title", ".body", ".how", ".not", ".note"))
need("primer.", ["location", "camera"], (".alt",))

if errors:
    print("\n".join(errors))
    sys.exit(1)
print("revisión estática: ok (", len(dart_files), "archivos Dart )")
