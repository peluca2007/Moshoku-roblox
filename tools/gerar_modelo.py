"""Gera um modelo no Blender, envia ao Roblox, recolore no Studio e grava em Mundo/Modelos.

Uso:
  python tools/gerar_modelo.py <modelo> <NomeModulo> [--semente N] [--flores 1] [--variante trilhos|ripas]
Exemplo:
  python tools/gerar_modelo.py rocha Rocha3 --semente 3

Passos (tudo automático, Studio aberto em modo Edit com um place):
  1. Blender (tools/blender/modelos.py) -> build/blender/<NomeModulo>.fbx/.json/.png
  2. upload pela Open Cloud (tools/roblox_upload.py), reaproveitado se geradores e argumentos não mudaram
     (registro em tools/blender/assets.json)
  3. InsertService:LoadAsset no Studio, repinta cada MeshPart pelo grupo (.json) e confere
     que só há Model/MeshPart (nada de scripts)
  4. tools/exportar_modelo.py grava src/server/Mundo/Modelos/<NomeModulo>.luau
Depois: python tools/studio_sync.py e, se for adereço, cadastrar em shared/Mundo/PropsLayout.
"""
import argparse
import hashlib
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(__file__))
import roblox_upload  # noqa: E402
from studio_mcp import Client  # noqa: E402

REGISTRO = os.path.join(ROOT, "tools", "blender", "assets.json")

LUAU = r'''
local HttpService = game:GetService("HttpService")
local dados = HttpService:JSONDecode(%(dados)s)
local ok, carregado = pcall(function() return game:GetService("InsertService"):LoadAsset(%(asset)s) end)
if not ok then return "ERRO: " .. tostring(carregado) end
local pasta = game.ServerStorage:FindFirstChild("BlenderProntos")
if not pasta then pasta = Instance.new("Folder") pasta.Name = "BlenderProntos" pasta.Parent = game.ServerStorage end
local antigo = pasta:FindFirstChild(dados.nome)
if antigo then antigo:Destroy() end
local modelo = carregado:FindFirstChildOfClass("Model") or carregado
modelo.Name = dados.nome
local problemas = {}
for _, d in ipairs(modelo:GetDescendants()) do
	if d:IsA("LuaSourceContainer") or d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
		table.insert(problemas, d.ClassName .. ":" .. d.Name)
	end
end
if #problemas > 0 then carregado:Destroy() return "ERRO: scripts no asset: " .. table.concat(problemas, ",") end
local partes, faltam = 0, {}
for _, d in ipairs(modelo:GetDescendants()) do
	if d:IsA("MeshPart") then
		local g = dados.grupos[d.Name]
		if g then
			d.Color = Color3.fromRGB(g.cor[1], g.cor[2], g.cor[3])
			d.Material = Enum.Material[g.material]
			if d.Name == "Fumaca" then
				-- marcador de chaminé: peça invisível sem colisão com fumaça
				d.Transparency, d.CanCollide = 1, false
				local fumaca = Instance.new("Smoke")
				fumaca.Color, fumaca.Size, fumaca.Opacity, fumaca.RiseVelocity = Color3.fromRGB(190, 190, 190), 1.4, 0.3, 3
				fumaca.Parent = d
			end
			partes += 1
		else
			table.insert(faltam, d.Name)
		end
	end
end
for _, d in ipairs(modelo:GetDescendants()) do
	if d:IsA("PackageLink") then d:Destroy() end
end
modelo.Parent = pasta
carregado:Destroy()
local c, t = modelo:GetBoundingBox()
return string.format("OK partes=%%d sem_grupo=[%%s] caixa=%%.2f,%%.2f,%%.2f", partes, table.concat(faltam, ","), t.X, t.Y, t.Z)
'''


def sha(caminho):
    with open(caminho, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def chave_cache(args):
    """Hash dos geradores + argumentos: o FBX em si muda a cada execução (carimbos), o conteúdo não."""
    h = hashlib.sha256()
    # Todos os geradores entram no hash (vegetacao/props/ruinas/formas vieram em 16/10).
    for nome in sorted(n for n in os.listdir(os.path.join(ROOT, "tools", "blender")) if n.endswith(".py")):
        with open(os.path.join(ROOT, "tools", "blender", nome), "rb") as f:
            h.update(f.read())
    h.update(json.dumps([args.modelo, args.modulo, args.semente, args.flores, args.variante]).encode())
    return h.hexdigest()


def carregar_registro():
    if os.path.isfile(REGISTRO):
        with open(REGISTRO, encoding="utf-8") as f:
            return json.load(f)
    return {}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("modelo")
    ap.add_argument("modulo")
    ap.add_argument("--semente", default="1")
    ap.add_argument("--flores", default="0")
    ap.add_argument("--variante", default="trilhos")
    args = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")

    saida = os.path.join(ROOT, "build", "blender", args.modulo + ".fbx")
    previa = os.path.join(ROOT, "build", "blender", args.modulo + ".png")
    r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "blender_rodar.py"),
                        os.path.join(ROOT, "tools", "blender", "modelos.py"),
                        "--modelo", args.modelo, "--semente", args.semente, "--flores", args.flores,
                        "--variante", args.variante, "--saida", saida, "--previa", previa],
                       capture_output=True, text=True, encoding="utf-8", errors="replace")
    if r.returncode != 0 or not os.path.isfile(saida):
        sys.exit("Blender falhou:\n" + r.stdout[-1500:] + r.stderr[-800:])
    lateral = os.path.splitext(saida)[0] + ".json"
    with open(lateral, encoding="utf-8") as f:
        dados = json.load(f)
    dados["nome"] = args.modulo

    registro = carregar_registro()
    hash_atual = chave_cache(args)
    entrada = registro.get(args.modulo)
    if entrada and entrada.get("sha256") == hash_atual:
        asset = entrada["asset"]
        print(f"[{args.modulo}] FBX igual ao já enviado; reaproveitando asset {asset}")
    else:
        asset = roblox_upload.enviar(saida, "Moshoku " + args.modulo)
        registro[args.modulo] = {"asset": asset, "sha256": hash_atual, "modelo": args.modelo, "semente": args.semente}
        with open(REGISTRO, "w", encoding="utf-8") as f:
            json.dump(registro, f, ensure_ascii=False, indent=1, sort_keys=True)
        print(f"[{args.modulo}] enviado: asset {asset}")

    cliente = Client()
    try:
        studio = cliente.studio_id()
        codigo = LUAU % {"dados": json.dumps(json.dumps(dados)), "asset": asset}
        saida_luau = cliente.call("execute_luau", {"studio_id": studio, "datamodel_type": "Edit", "code": codigo})["text"]
        print(f"[{args.modulo}] Studio: {saida_luau}")
        if not saida_luau.startswith("OK"):
            sys.exit(1)
    finally:
        cliente.close()
    caminho = f"ServerStorage.BlenderProntos.{args.modulo}"
    r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "exportar_modelo.py"), caminho, args.modulo,
                        "--asset", asset, "--autor", "Blender (tools/blender/modelos.py)",
                        "--nome", f"{args.modelo} semente {args.semente}"],
                       capture_output=True, text=True, encoding="utf-8", errors="replace")
    print(r.stdout.strip()[-600:])
    if r.returncode != 0:
        sys.exit(r.stderr[-800:])
    if dados.get("pivos"):
        gravar_pivos(args.modulo, dados["pivos"])


PIVOS = os.path.join(ROOT, "src", "shared", "Mundo", "PivosModelos.luau")


def gravar_pivos(modulo, pivos):
    """Juntas articuláveis (criaturas.py) em dados Luau: { [Modulo] = { Parte = {x, y, z} } }, base no chão."""
    tabela = {}
    if os.path.isfile(PIVOS):
        with open(PIVOS, encoding="utf-8") as f:
            for linha in f:
                if linha.startswith("\t[\"") and "-- json:" in linha:
                    nome, bruto = linha.split("-- json:", 1)
                    tabela[nome.split('"')[1]] = json.loads(bruto)
    tabela[modulo] = pivos
    linhas = ["-- Gerado por tools/gerar_modelo.py: pivôs das partes articuláveis (Corpo, Cabeca, BracoE/D, PernaE/D,",
              "-- Cauda, Arma) em coordenadas Roblox relativas à base do modelo (centro x/z, y=0 no chão).",
              "-- Os grupos das MeshParts seguem `<Parte>_<Cor>`; animar por Name:match(\"^(%a+)_\").",
              "return {"]
    for nome in sorted(tabela):
        partes = ", ".join(f"{p} = {{ {v[0]:.3f}, {v[1]:.3f}, {v[2]:.3f} }}" for p, v in sorted(tabela[nome].items()))
        linhas.append(f"\t[\"{nome}\"] = {{ {partes} }}, -- json:{json.dumps(tabela[nome], sort_keys=True)}")
    linhas.append("}")
    with open(PIVOS, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(linhas) + "\n")
    print(f"[{modulo}] pivôs gravados em {PIVOS}")


main()
