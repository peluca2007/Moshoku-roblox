"""Contrato estático das telas U2, executado por testar.ps1; fontes sempre UTF-8."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[2]
names = ("Hud", "Atalhos", "TreinadorView", "ProvacoesView", "AvisosJogo", "AjudaView", "ContaView", "ViagemView", "RunView", "AparenciaEditor", "AparenciaFluxo")
errors = []
for name in names:
    path = root / "src/client" / (name + ".luau")
    source = path.read_text(encoding="utf-8-sig")
    code = re.sub(r"--[^\n]*", "", source)
    for token in ("Color3.fromRGB", "Color3.new", "Color3.fromHex", "Font.fromName", "Enum.Font", "Estilo."):
        if token in code:
            errors.append(f"{name}: estilo fora do Tema: {token}")
    if ".UI." not in code:
        errors.append(f"{name}: não usa a base V2")
# Os avisos genéricos devem preservar os dois filtros de missão, inclusive os acentos.
avisos = (root / "src/client/AvisosJogo.luau").read_text(encoding="utf-8")
for text in ("^Missão cumprida:", "^Missão entregue:", "C.aviso"):
    if text not in avisos:
        errors.append("AvisosJogo: contrato ausente: " + text)
for error in errors:
    print("FALHA U2:", error)
print(f"UI U2: {len(names)} fontes verificadas, {len(errors)} falha(s)")
raise SystemExit(bool(errors))
