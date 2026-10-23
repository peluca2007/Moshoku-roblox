"""Monta um arquivo Luau executável fora do Roblox para um spec do TestRunner.

Uso: python harness.py <saida.luau> <spec.luau> <pasta Shared> [<outra pasta Shared>...]

Os specs rodam no Studio pelo TestRunner (src/server/TestRunner.luau). Aqui,
para rodar no Luau puro, cada require(...Shared.X) é substituído pelo código do
módulo X (recursivamente), e Vector3/Color3 ganham substitutos mínimos. Só serve
para módulos puros; código que usa serviços do Roblox precisa do Studio.
"""
import os
import re
import sys

out, spec_path, *dirs = sys.argv[1:]

# Shared.X ou caminhos aninhados como Shared.Regras.Combate (pasta/arquivo).
PATTERN = re.compile(r'require\((?:game:GetService\("ReplicatedStorage"\)\.Shared|Shared)((?:\.\w+)+)\)')


def find(name):
    parts = name.strip(".").split(".")
    for directory in dirs:
        path = os.path.join(directory, *parts) + ".luau"
        if os.path.exists(path):
            source = open(path, encoding="utf-8").read()
            if name == ".Livro.Catalogo":
                source = re.sub(r'local dados = .*\n|local arvores = .*\n', '', source)
                source = source.replace('require(script.Parent:WaitForChild("Manifesto"))', 'require(Shared.Livro.Manifesto)')
                source = re.sub(r'require\(arvores:WaitForChild\("(\w+)"\)\)', r'require(Shared.Livro.Dados.Arvores.\1)', source)
                source = re.sub(r'require\(dados:WaitForChild\("(\w+)"\)\)', r'require(Shared.Livro.Dados.\1)', source)
            return source
    raise SystemExit("módulo não encontrado: " + name)


def inline(source):
    # U2: projeção cliente pura, sem serviços/Instances, compartilhada com o spec.
    client_require = 'require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.UI.ExtraProvacoes)'
    if client_require in source:
        module = os.path.join(os.path.dirname(__file__), "..", "..", "src", "client", "UI", "ExtraProvacoes.luau")
        source = source.replace(client_require, "(function()\n" + open(module, encoding="utf-8").read() + "\nend)()")
    source = source.replace('local Shared = game:GetService("ReplicatedStorage").Shared\n', "")
    return PATTERN.sub(lambda m: "(function()\n" + inline(find(m.group(1))) + "\nend)()", source)


STUBS = """
local V3 = {}; V3.__index = V3
V3.__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
Vector3 = { new = function(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3) end }
local C3 = { __eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end }
Color3 = { new = function(r, g, b) return setmetatable({ R = r, G = g, B = b }, C3) end }
Color3.fromRGB = function(r, g, b) return Color3.new(r / 255, g / 255, b / 255) end
"""

RUNNER = """
local t = {
	eq = function(a, b, msg) if a ~= b then error((msg or "") .. " esperado " .. tostring(b) .. ", obtido " .. tostring(a), 2) end end,
	ok = function(a, msg) if not a then error(msg or "condição falsa", 2) end end,
	fails = function(fn, msg) if pcall(fn) then error(msg or "era esperado erro", 2) end end,
}
local passed, failed = 0, 0
for name, fn in spec do
	local ok, err = pcall(fn, t)
	if ok then passed += 1 else failed += 1; print("FALHA", name, err) end
end
print("RESULTADO", passed, failed)
"""

spec = inline(open(spec_path, encoding="utf-8").read())
open(out, "w", encoding="utf-8").write(STUBS + "\nlocal spec = (function()\n" + spec + "\nend)()\n" + RUNNER)
