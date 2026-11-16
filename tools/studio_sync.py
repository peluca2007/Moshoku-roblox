"""Copia os scripts de src/ para o place aberto no Studio (modo Edit), via MCP.

Uso: python tools/studio_sync.py [filtro ...]
  filtro: trecho do caminho em src (ex.: client/CeuMundo Mundo/Modelos); sem filtro, sincroniza tudo.

Mesma correspondência do default.project.json:
  src/shared/*            -> ReplicatedStorage.Shared
  src/server/** (pastas)  -> ServerScriptService.Server
  src/client/*            -> StarterPlayer.StarterPlayerScripts.Client
  src/server.server.luau  -> ServerScriptService.RPGServer (Script)
  src/client.client.luau  -> StarterPlayerScripts.RPGClient (LocalScript)
Também cria os MaterialVariant de MaterialService (default.project.json). Cria o que faltar e só reescreve scripts cujo conteúdo mudou. Scripts do Studio
que não existem em src são apenas listados (nada é apagado). O Studio precisa
estar em modo Edit (sem Play).
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from studio_mcp import Client  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")

TARGETS = [
    ("shared", ["ReplicatedStorage", "Shared"]),
    ("server", ["ServerScriptService", "Server"]),
    ("client", ["StarterPlayer", "StarterPlayerScripts", "Client"]),
]
ENTRIES = [
    ("server.server.luau", ["ServerScriptService"], "RPGServer", "Script"),
    ("client.client.luau", ["StarterPlayer", "StarterPlayerScripts"], "RPGClient", "LocalScript"),
]


def long_string(text):
    level = 0
    while ("]" + "=" * level + "]") in text:
        level += 1
    eq = "=" * level
    return "[" + eq + "[\n" + text + "]" + eq + "]"


def collect():
    items = []
    for folder, path in TARGETS:
        base = os.path.join(SRC, folder)
        for current, _, files in os.walk(base):
            relative = os.path.relpath(current, base)
            parents = path + ([] if relative == "." else relative.split(os.sep))
            for name in sorted(files):
                if name.endswith(".luau"):
                    items.append((parents, name[: -len(".luau")], "ModuleScript", os.path.join(current, name)))
    for name, parents, instance, cls in ENTRIES:
        items.append((parents, instance, cls, os.path.join(SRC, name)))
    return items


def chunk_code(items):
    lines = [
        "local changed, created = {}, {}",
        "local function ensure(parent, name, class)",
        "\tlocal child = parent:FindFirstChild(name)",
        "\tif not child then child = Instance.new(class); child.Name = name; child.Parent = parent; table.insert(created, child:GetFullName()) end",
        "\treturn child",
        "end",
    ]
    for parents, name, cls, path in items:
        source = open(path, encoding="utf-8").read().replace("\r\n", "\n")
        walk = "game:GetService(%r)" % parents[0]
        for part in parents[1:]:
            walk = "ensure(%s, %r, 'Folder')" % (walk, part)
        lines.append("do")
        lines.append("\tlocal script = ensure(%s, %r, %r)" % (walk, name, cls))
        lines.append("\tlocal source = " + long_string(source))
        lines.append("\tif script.Source:gsub('\\r\\n', '\\n') ~= source then script.Source = source; table.insert(changed, script:GetFullName()) end")
        lines.append("end")
    lines.append("return 'alterados: ' .. #changed .. (#changed > 0 and (' (' .. table.concat(changed, ', ') .. ')') or '') .. '; criados: ' .. #created")
    return "\n".join(lines)


def codigo_material_variants():
    """Luau que cria/atualiza os MaterialVariant de MaterialService declarados em default.project.json
    (chão do esgoto etc.), para quem sincroniza sem Rojo. Devolve None se não houver nenhum."""
    projeto = json.load(open(os.path.join(ROOT, "default.project.json"), encoding="utf-8"))
    nos = projeto.get("tree", {}).get("MaterialService", {})
    linhas = []
    for nome, no in nos.items():
        if nome.startswith("$") or no.get("$className") != "MaterialVariant":
            continue
        linhas.append("do")
        linhas.append("	local v = game.MaterialService:FindFirstChild(%r) or Instance.new('MaterialVariant')" % nome)
        linhas.append("	v.Name = %r" % nome)
        for chave, valor in no.get("$properties", {}).items():
            if chave == "BaseMaterial":
                linhas.append("	v.BaseMaterial = Enum.Material.%s" % valor)
            else:
                linhas.append("	v.%s = %s" % (chave, json.dumps(valor)))
        linhas.append("	v.Parent = game.MaterialService")
        linhas.append("	table.insert(feitos, v.Name)")
        linhas.append("end")
    if not linhas:
        return None
    return "local feitos = {}\n" + "\n".join(linhas) + "\nreturn 'MaterialVariant: ' .. table.concat(feitos, ', ')"


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    filtros = [f.replace("\\", "/") for f in sys.argv[1:]]
    items = collect()
    if filtros:
        items = [i for i in items if any(f in i[3].replace("\\", "/") for f in filtros)]
        print("Filtrado: %d scripts" % len(items))
    client = Client()
    try:
        studio = client.studio_id()
        state = client.call("get_studio_state", {"studio_id": studio})["text"]
        if "Current Studio Mode: Edit" not in state:
            raise SystemExit("O Studio precisa estar em modo Edit (pare o Play antes de sincronizar).")
        # Lotes pequenos: o código roda na thread principal do Studio.
        for start in range(0, len(items), 6):
            batch = items[start : start + 6]
            result = client.call("execute_luau", {"studio_id": studio, "datamodel_type": "Edit", "code": chunk_code(batch)})
            print(result.get("text", result))
        codigo = codigo_material_variants()
        if codigo and (not filtros or any("MaterialService" in f for f in filtros)):
            print(client.call("execute_luau", {"studio_id": studio, "datamodel_type": "Edit", "code": codigo}).get("text"))
        known = {".".join(p + [n]) for p, n, _, _ in items}
        listing = client.call("execute_luau", {
            "studio_id": studio,
            "datamodel_type": "Edit",
            "code": "local out = {}\n"
            "for _, root in { game.ReplicatedStorage.Shared, game.ServerScriptService, game.StarterPlayer.StarterPlayerScripts } do\n"
            "\tfor _, d in root:GetDescendants() do if d:IsA('LuaSourceContainer') then\n"
            "\t\ttable.insert(out, (d:GetFullName():gsub('^Players%.[^.]+%.', ''))) end end\n"
            "end\nreturn table.concat(out, '\\n')",
        })["text"]
        extras = [line for line in listing.splitlines() if line and line not in known and not line.startswith("ServerScriptService.Server.tests.")]
        extras += [line for line in listing.splitlines() if line.startswith("ServerScriptService.Server.tests.") and line not in known]
        if extras and not filtros:
            print("No Studio mas não em src (não apagados):", ", ".join(sorted(set(extras))))
        print("Sincronização concluída. Salve o place no Studio (Ctrl+S) para manter.")
    finally:
        client.close()


if __name__ == "__main__":
    main()
