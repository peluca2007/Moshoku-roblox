"""Executa o spec puro do servidor sem alterar o harness compartilhado.
Uso: python src/server/tests/R2Patrulha_cli.py [caminho/luau.exe]
Somente o require server e os tipos vetoriais recebem adaptacao de teste.
"""
from pathlib import Path
import os
import subprocess
import sys
import tempfile

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[2]
STUB = """
local nativeTypeof = typeof
local V = {}
V.__index = function(a, k)
 if k == "Magnitude" then return math.sqrt(a.X*a.X + a.Y*a.Y + a.Z*a.Z) end
 if k == "Unit" then local n = a.Magnitude; return Vector3.new(a.X/n, a.Y/n, a.Z/n) end
 if k == "Dot" then return function(a,b) return a.X*b.X + a.Y*b.Y + a.Z*b.Z end end
end
Vector3 = {new = function(x,y,z) return setmetatable({X=x,Y=y,Z=z},V) end}
Vector3.zero = Vector3.new(0,0,0)
typeof = function(v) return if getmetatable(v) == V then "Vector3" else nativeTypeof(v) end
"""
RUNNER = """
local passed = 0
local t = {eq = function(a,b,msg) assert(a == b, msg or ("esperado "..tostring(b)..", obtido "..tostring(a))) end}
for name,fn in spec do fn(t); passed += 1; print(name .. ": ok") end
print("Patrulha CLI: " .. passed .. " ok, 0 falha(s)")
"""

def main():
    sys.stdout.reconfigure(encoding="utf-8")
    candidates = [
        Path(os.environ.get("LUAU_DIR", os.environ["LOCALAPPDATA"] + "/moshoku-luau-0.741")) / "luau.exe",
        Path.home() / "AppData/Local/Temp/moshoku-luau-0.741/luau.exe",
    ]
    exe = Path(sys.argv[1]) if len(sys.argv) > 1 else next((p for p in candidates if p.is_file()), None)
    if exe is None:
        raise SystemExit("Informe o caminho do luau.exe.")
    source = (ROOT / "src/server/Mundo/Patrulha.luau").read_text(encoding="utf-8")
    spec = (BASE / "Patrulha.spec.luau").read_text(encoding="utf-8")
    spec = spec.replace("require(script.Parent.Parent.Mundo.Patrulha)", "(function()\n" + source + "\nend)()")
    # Arquivo unico dentro do workspace; exclusao apenas dele, sem limpeza recursiva.
    with tempfile.NamedTemporaryFile(dir=BASE, prefix="R2Patrulha-", suffix=".tmp", delete=False) as tmp:
        path = Path(tmp.name)
    try:
        path.write_text(STUB + "\nlocal spec=(function()\n" + spec + "\nend)()\n" + RUNNER, encoding="utf-8")
        return subprocess.run([str(exe), str(path.relative_to(ROOT))], cwd=ROOT, check=False).returncode
    finally:
        path.unlink()

if __name__ == "__main__":
    raise SystemExit(main())
