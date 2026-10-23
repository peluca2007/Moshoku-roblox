"""Exporta um Model do Studio (modo Edit, via MCP) como dados Luau em src/server/Mundo/Modelos.

Uso:
  python tools/exportar_modelo.py <caminho no Studio> <NomeModulo> \
      --asset 13280911060 --autor GrymhetSS --nome "Medieval Village Set"

O caminho é separado por pontos a partir do DataModel, por exemplo
"ServerStorage.ClaudeQuarentena.MedievalVillageSet.Peasant Home". Só lê o Studio.
Cada BasePart (Part, WedgePart, CornerWedgePart, Seat) é gravada relativa ao pivô do
modelo; Smoke, SurfaceGui e TextLabel filhos de peças também. Outras classes são
ignoradas, contadas e avisadas. O formato do arquivo é descrito em
src/server/Mundo/MontarModelo.luau, que o monta em runtime.
"""
import argparse
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from studio_mcp import Client  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SAIDA = os.path.join(ROOT, "src", "server", "Mundo", "Modelos")
LIMITE_TEXTO = 60000  # a saída do MCP é cortada perto de 100000 caracteres

LUAU = r'''
local HttpService = game:GetService("HttpService")
local caminho = HttpService:JSONDecode(%(caminho)s)
local no = game
for _, nome in ipairs(caminho) do
	no = if no == game then game:GetService(nome) else no:FindFirstChild(nome)
	if not no then return "ERRO: caminho nao encontrado em '" .. nome .. "'" end
end
if not no:IsA("Model") then return "ERRO: " .. no:GetFullName() .. " nao e um Model" end

local inicio, fim = %(inicio)d, %(fim)d
local raiz = no
local inv = raiz:GetPivot():Inverse()
local SUPORTADAS = { Part = true, WedgePart = true, CornerWedgePart = true, Seat = true, MeshPart = true }

local function r(n, p)
	local m = 10 ^ p
	return math.floor(n * m + 0.5) / m
end
local function cor(c)
	return math.floor(c.R * 255 + 0.5) * 65536 + math.floor(c.G * 255 + 0.5) * 256 + math.floor(c.B * 255 + 0.5)
end
local function grupo(parte)
	local nomes = {}
	local pai = parte.Parent
	while pai and pai ~= raiz do
		table.insert(nomes, 1, pai.Name)
		pai = pai.Parent
	end
	return table.concat(nomes, "/")
end
local function udim2(u)
	return { r(u.X.Scale, 4), u.X.Offset, r(u.Y.Scale, 4), u.Y.Offset }
end

local pecas, ignoradas = {}, {}
local function ignorar(inst)
	ignoradas[inst.ClassName] = (ignoradas[inst.ClassName] or 0) + 1
end

for _, d in ipairs(raiz:GetDescendants()) do
	if d:IsA("BasePart") then
		if SUPORTADAS[d.ClassName] then
			local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = (inv * d.CFrame):GetComponents()
			local filhos = {}
			for _, f in ipairs(d:GetChildren()) do
				if f:IsA("Smoke") then
					table.insert(filhos, { "S", cor(f.Color), r(f.Size, 3), r(f.Opacity, 3), r(f.RiseVelocity, 3) })
				elseif f:IsA("SurfaceGui") then
					local rotulos = {}
					for _, l in ipairs(f:GetChildren()) do
						if l:IsA("TextLabel") then
							table.insert(rotulos, {
								l.Text, cor(l.TextColor3), l.Font.Name, l.TextScaled and 1 or 0,
								r(l.BackgroundTransparency, 3), udim2(l.Size), udim2(l.Position), l.TextSize,
							})
						else
							ignorar(l)
						end
					end
					table.insert(filhos, {
						"G", f.Face.Name, f.SizingMode.Name, r(f.PixelsPerStud, 3),
						f.CanvasSize.X, f.CanvasSize.Y, r(f.LightInfluence, 3), rotulos,
					})
				else
					ignorar(f)
				end
			end
			table.insert(pecas, {
				d.ClassName, d.Name, grupo(d),
				r(d.Size.X, 4), r(d.Size.Y, 4), r(d.Size.Z, 4), r(x, 4), r(y, 4), r(z, 4),
				r(r00, 5), r(r01, 5), r(r02, 5), r(r10, 5), r(r11, 5), r(r12, 5), r(r20, 5), r(r21, 5), r(r22, 5),
				cor(d.Color), d.Material.Name, r(d.Transparency, 3), r(d.Reflectance, 3),
				d.CanCollide and 1 or 0, d.CastShadow and 1 or 0,
				if d.ClassName == "Part" then (d :: Part).Shape.Value else 0,
				filhos,
				if d.ClassName == "MeshPart" then (d :: MeshPart).MeshId else "",
				if d.ClassName == "MeshPart" then (d :: MeshPart).TextureID else "",
			})
		else
			ignorar(d)
		end
	elseif d:IsA("Model") then
		-- contêiner: vira o campo de grupo das peças
	elseif d:IsA("Smoke") or d:IsA("SurfaceGui") then
		if not (d.Parent and d.Parent:IsA("BasePart") and SUPORTADAS[d.Parent.ClassName]) then ignorar(d) end
	elseif d:IsA("TextLabel") then
		local gui = d.Parent
		local parte = gui and gui.Parent
		if not (gui and gui:IsA("SurfaceGui") and parte and parte:IsA("BasePart") and SUPORTADAS[parte.ClassName]) then ignorar(d) end
	else
		ignorar(d)
	end
end

local corpo = HttpService:JSONEncode({ pecas = pecas, ignoradas = ignoradas })
local ultimo = math.min(#corpo, fim)
return #corpo .. "|" .. string.sub(corpo, inicio, ultimo)
'''


def luau_string(texto):
    # Literal Luau seguro para qualquer conteúdo.
    nivel = 0
    while ("]" + "=" * nivel + "]") in texto:
        nivel += 1
    return "[" + "=" * nivel + "[" + chr(10) + texto + chr(10) + "]" + "=" * nivel + "]"


def baixar(client, studio, caminho):
    partes = caminho.split(".")
    pedaco = luau_string(json.dumps(partes, ensure_ascii=False))
    texto, total, inicio = "", None, 1
    while total is None or inicio <= total:
        codigo = LUAU % {"caminho": pedaco, "inicio": inicio, "fim": inicio + LIMITE_TEXTO - 1}
        saida = client.call("execute_luau", {"studio_id": studio, "datamodel_type": "Edit", "code": codigo})
        resposta = saida.get("text", "")
        if saida.get("isError") or "|" not in resposta[:20]:
            raise SystemExit("Falha no Studio: " + resposta[:500])
        cabeca, _, corpo = resposta.partition("|")
        if total is not None and int(cabeca) != total:
            raise SystemExit("O modelo mudou durante a exportação; tente de novo.")
        total = int(cabeca)
        texto += corpo
        inicio += LIMITE_TEXTO
    texto = texto[:total]  # o MCP pode acrescentar quebra de linha no fim
    if len(texto) != total:
        raise SystemExit("Tamanho recebido (%d) difere do esperado (%d)." % (len(texto), total))
    dados = json.loads(texto)
    if not isinstance(dados["ignoradas"], dict):  # tabela vazia vira lista no JSON
        dados["ignoradas"] = {}
    return dados


def numero(valor):
    """Número Luau curto: inteiro sem '.0', sem '-0'."""
    if isinstance(valor, bool):
        return "1" if valor else "0"
    if float(valor) == int(valor):
        return str(int(valor))
    texto = repr(float(valor))
    if "e" in texto:
        texto = "%.10f" % valor
        texto = texto.rstrip("0").rstrip(".")
    if texto.startswith("0."):
        texto = texto[1:]
    elif texto.startswith("-0."):
        texto = "-" + texto[2:]
    return texto


def luau_texto(valor):
    return '"' + valor.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def arredonda(lista, casas):
    saida = []
    for v in lista:
        v = round(float(v), casas)
        saida.append(0.0 if v == 0 else v)
    return saida


def caixa(linhas):
    """Caixa envolvente (alinhada ao pivô) e seu centro, pelos extremos de cada peça."""
    minimo = [math.inf] * 3
    maximo = [-math.inf] * 3
    for p in linhas:
        tamanho, posicao, rot = p[3:6], p[6:9], p[9:18]
        for eixo in range(3):
            meia = sum(abs(rot[eixo * 3 + j]) * tamanho[j] / 2 for j in range(3))
            minimo[eixo] = min(minimo[eixo], posicao[eixo] - meia)
            maximo[eixo] = max(maximo[eixo], posicao[eixo] + meia)
    return [maximo[i] - minimo[i] for i in range(3)], [(maximo[i] + minimo[i]) / 2 for i in range(3)]


def gerar(dados, modulo, nome, asset, autor, caminho):
    pecas = dados["pecas"]
    if not pecas:
        raise SystemExit("Nenhuma peça exportada.")
    strings, indice = [], {}

    def s(texto):
        if texto not in indice:
            strings.append(texto)
            indice[texto] = len(strings)
        return indice[texto]

    rotacoes, indice_rot = [], {}
    linhas_num = []
    for p in pecas:
        p = list(p)
        p[3:9] = arredonda(p[3:9], 3)
        p[9:18] = arredonda(p[9:18], 5)
        linhas_num.append(p)
    tamanho, centro = caixa(linhas_num)

    linhas = []
    for p in linhas_num:
        rot = tuple(p[9:18])
        if rot not in indice_rot:
            rotacoes.append(rot)
            indice_rot[rot] = len(rotacoes)
        flags = int(p[22]) + 2 * int(p[23])  # 1 = CanCollide, 2 = CastShadow
        campos = [
            s(p[0]), s(p[1]), s(p[2]),
            numero(p[3]), numero(p[4]), numero(p[5]), numero(p[6]), numero(p[7]), numero(p[8]),
            indice_rot[rot], int(p[18]), s(p[19]), numero(p[20]), numero(p[21]), flags, int(p[24]),
        ]
        filhos = []
        for f in p[25]:
            if f[0] == "S":
                filhos.append("{1,%d,%s,%s,%s}" % (f[1], numero(f[2]), numero(f[3]), numero(f[4])))
            else:
                rotulos = []
                for l in f[7]:
                    rotulos.append("{%d,%d,%d,%d,%s,{%s},{%s},%d}" % (
                        s(l[0]), l[1], s(l[2]), l[3], numero(l[4]),
                        ",".join(numero(v) for v in l[5]), ",".join(numero(v) for v in l[6]), l[7]))
                filhos.append("{2,%d,%d,%s,%s,%s,%s,{%s}}" % (
                    s(f[1]), s(f[2]), numero(f[3]), numero(f[4]), numero(f[5]), numero(f[6]), ",".join(rotulos)))
        linha = "{" + ",".join(str(c) if not isinstance(c, str) else c for c in campos)
        malha = p[0] == "MeshPart"
        if filhos or malha:
            linha += ",{" + ",".join(filhos) + "}"
        if malha:
            # 18º campo: { MeshId, TextureID } como índices em S (Mundo/MontarModelo.luau).
            linha += ",{%d,%d}" % (s(p[26]), s(p[27]))
        linhas.append(linha + "}")

    cabeca = (
        "-- GERADO por tools/exportar_modelo.py; não editar. Fonte: %s (asset %s, %s), "
        "Creator Store grátis; scripts/uniões removidos.\n" % (nome, asset, autor)
        + "-- Modelo %s (%s): %d peças; caixa original %s x %s x %s studs (alinhada ao pivô).\n"
        % (modulo, caminho.split(".")[-1], len(linhas), numero(round(tamanho[0], 2)), numero(round(tamanho[1], 2)), numero(round(tamanho[2], 2)))
        + "-- Formato das linhas de P e das tabelas S/R: ver Mundo/MontarModelo.luau.\n"
    )
    corpo = "return {\n"
    corpo += "\tversao = 1,\n"
    corpo += "\tfonte = { nome = %s, asset = %s, autor = %s },\n" % (luau_texto(nome), asset, luau_texto(autor))
    corpo += "\tcaixa = { %s, %s, %s },\n" % tuple(numero(round(v, 3)) for v in tamanho)
    corpo += "\tcentro = { %s, %s, %s },\n" % tuple(numero(round(v, 3)) for v in centro)
    corpo += "\tS = {" + ",".join(luau_texto(t) for t in strings) + "},\n"
    corpo += "\tR = {\n" + "".join("\t\t{" + ",".join(numero(v) for v in rot) + "},\n" for rot in rotacoes) + "\t},\n"
    corpo += "\tP = {\n" + "".join("\t\t" + l + ",\n" for l in linhas) + "\t},\n}\n"
    return cabeca + corpo, len(linhas), tamanho


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("caminho")
    ap.add_argument("modulo")
    ap.add_argument("--asset", required=True)
    ap.add_argument("--autor", required=True)
    ap.add_argument("--nome", required=True)
    args = ap.parse_args()
    if not args.modulo.isidentifier():
        raise SystemExit("NomeModulo precisa ser um identificador (letras, números, _).")
    client = Client()
    try:
        studio = client.studio_id()
        estado = client.call("get_studio_state", {"studio_id": studio})["text"]
        if "Current Studio Mode: Edit" not in estado:
            raise SystemExit("O Studio está em Play; espere e tente de novo (esta ferramenta só lê no modo Edit).")
        dados = baixar(client, studio, args.caminho)
    finally:
        client.close()
    texto, quantas, tamanho = gerar(dados, args.modulo, args.nome, args.asset, args.autor, args.caminho)
    os.makedirs(SAIDA, exist_ok=True)
    destino = os.path.join(SAIDA, args.modulo + ".luau")
    with open(destino, "w", encoding="utf-8", newline="\n") as arquivo:
        arquivo.write(texto)
    print("%s: %d peças, caixa %.1f x %.1f x %.1f, %.1f KB" % (destino, quantas, *tamanho, len(texto.encode("utf-8")) / 1024))
    if dados["ignoradas"]:
        print("AVISO: classes ignoradas: " + ", ".join("%s=%d" % kv for kv in sorted(dados["ignoradas"].items())))


if __name__ == "__main__":
    main()
