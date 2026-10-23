"""Copia exclusivamente efeitos classificados no catálogo; gera seus IDs.

python tools/sons/preparar.py [--verificar]
Preencher assetId com o ID enviado ao Roblox. semVozConfirmado registra escuta,
se feita; a seleção inicial usa o catálogo do site e exclui toda vocalização
identificada. Hash diferente invalida a associação com o ID existente.
"""
from pathlib import Path
import hashlib
import json
import re
import shutil
import sys

ROOT = Path(__file__).resolve().parents[2]
SITE = ROOT.parent / "Moshoku tensei rpg"
DEST = ROOT / "assets" / "sons"
MANIFESTO = Path(__file__).with_name("manifesto.json")
NOMES = "espada-corte espada-metal espada-combo aparar flecha-impacto-1 flecha-impacto-2 lanca soco moedas brilho fogo fogo-impacto gelo agua vento vento-impacto terra cura-1 cura-2".split()
verificar = "--verificar" in sys.argv
anterior = json.loads(MANIFESTO.read_text(encoding="utf-8")) if MANIFESTO.exists() else {}
if set(anterior) - set(NOMES):
    raise SystemExit("Manifesto tem áudio fora da lista de efeitos permitidos.")
resultado, ids = {}, {}
for nome in NOMES:
    origem = SITE / "public" / "sons" / "arena" / f"{nome}.mp3"
    digest = hashlib.sha256(origem.read_bytes()).hexdigest()
    item = anterior.get(nome, {})
    revisado = item.get("semVozConfirmado") is True and item.get("sha256") == digest
    asset = item.get("assetId", "")
    if asset and not re.fullmatch(r"rbxassetid://[1-9][0-9]*", asset):
        raise SystemExit(f"ID inválido: {nome}")
    if asset and item.get("sha256") != digest:
        raise SystemExit(f"Áudio alterado: {nome}; ID não ativado.")
    resultado[nome] = {"arquivo": f"assets/sons/{nome}.mp3", "origem": f"public/sons/arena/{nome}.mp3", "sha256": digest, "classificacao": "efeito-no-catalogo-do-site", "semVozConfirmado": revisado, "assetId": asset}
    if asset:
        ids[nome] = asset
    if verificar:
        if not (DEST / origem.name).exists() or hashlib.sha256((DEST / origem.name).read_bytes()).hexdigest() != digest:
            raise SystemExit(f"Cópia ausente ou divergente: {nome}")
    else:
        DEST.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(origem, DEST / origem.name)
modulo = '-- Gerado por python tools/sons/preparar.py; efeitos selecionados pelo catálogo do site.\nreturn {\n' + ''.join(f'\t["{nome}"] = "{asset}",\n' for nome, asset in sorted(ids.items())) + '}\n'
saida = ROOT / "src" / "shared" / "SonsIds.luau"
if verificar:
    if resultado != anterior or saida.read_text(encoding="utf-8") != modulo:
        raise SystemExit("Manifesto/IDs divergentes; execute preparar.py.")
else:
    MANIFESTO.write_text(json.dumps(resultado, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    saida.write_text(modulo, encoding="utf-8")
print(f"Sons: {len(resultado)} candidatos, {sum(i['semVozConfirmado'] for i in resultado.values())} ouvidos sem voz, {len(ids)} IDs ativos.")
