#!/usr/bin/env python3
"""Generate the metric reference in Metrics.md from the definitions in
control.lua. Single source of truth: the Lua code. Run with --check in CI
to fail when the committed Metrics.md has drifted from the code."""
import re, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
lua = (ROOT / "control.lua").read_text(encoding="utf-8")

pattern = re.compile(
    r'prometheus\.(gauge|counter|histogram)\(\s*"([^"]+)"\s*,\s*"([^"]*)"'
    r'(?:\s*,\s*\{([^}]*)\})?', re.S)

rows = []
for kind, name, help_, labels in pattern.findall(lua):
    label_list = [l.strip().strip('"') for l in labels.split(",") if l.strip()] if labels else []
    rows.append((name, kind, ", ".join(label_list), help_))

header = "# Metrics\n\nGenerated from control.lua by scripts/gen_metrics.py -- do not edit by hand.\n\n"
table = "| Metric | Type | Labels | Description |\n| --- | --- | --- | --- |\n"
for name, kind, labels, help_ in rows:
    table += f"| {name} | {kind} | {labels} | {help_} |\n"
out = header + table

target = ROOT / "Metrics.md"
if "--check" in sys.argv:
    current = target.read_text(encoding="utf-8") if target.exists() else ""
    if current != out:
        print("Metrics.md ist nicht aktuell -- scripts/gen_metrics.py ausfuehren", file=sys.stderr)
        sys.exit(1)
    print(f"Metrics.md aktuell ({len(rows)} Metriken)")
else:
    target.write_text(out, encoding="utf-8")
    print(f"Metrics.md generiert: {len(rows)} Metriken")
