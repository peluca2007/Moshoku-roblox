"""Gera o catálogo de voz NPC separado; nenhum upload ou ID inventado."""
import csv
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def gerar():
    base = ROOT / "assets/vozes-npcs"
    manifest = json.loads((base / "manifesto.json").read_text(encoding="utf-8"))
    with (base / "importacao.csv").open(encoding="utf-8-sig", newline="") as file:
        reader = csv.DictReader(file)
        if not reader.fieldnames or len(set(reader.fieldnames)) != len(reader.fieldnames) or not {"chave", "id_roblox"}.issubset(reader.fieldnames):
            raise ValueError("Cabeçalho CSV incompatível")
        ids = {}
        for row in reader:
            key, value = row.get("chave"), row.get("id_roblox")
            if None in row or key not in manifest["gravacoes"] or key in ids or not isinstance(value, str):
                raise ValueError("Linha CSV incompatível/duplicada")
            value = value.removeprefix("rbxassetid://")
            if not re.fullmatch(r"[1-9][0-9]*", value):
                raise ValueError("ID Roblox ausente/inválido: " + key)
            ids[key] = "rbxassetid://" + value
    if set(ids) != set(manifest["gravacoes"]):
        raise ValueError("CSV não cobre todas as gravações")
    lines = ["-- Gerado por tools/dublagem/integrar_npcs.py; não editar à mão.", "return {"]
    for key, entry in sorted(manifest["entradas"].items()):
        lines.append(f'\t["{key}"] = {{ id = "{ids[entry["gravacao"]]}", segundos = {entry["segundos"]} }},')
    lines.append("}\n")
    (ROOT / "src/shared/DublagemNPCs.luau").write_text("\n".join(lines), encoding="utf-8")
    print(f"{len(ids)} IDs reais; {len(manifest['entradas'])} entradas geradas")


if __name__ == "__main__":
    gerar()
