"""Contratos visuais J2; chamado exclusivamente por tools/testar.ps1."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[2]
names = ["EncontroAutonomoView", "EncontroAutonomoGradeView", "EncontroAutonomoMapaTaticoView", "EncontroAutonomoApresentacao", "FeedbackCombate", "ResultadoView", "UI/ExtraCombate"]
errors = []
sources = {}
for name in names:
    source = (root / "src/client" / (name + ".luau")).read_text(encoding="utf-8-sig", errors="strict")
    sources[name] = source
    code = re.sub(r"--[^\n]*", "", source)
    for token in ("Color3.fromRGB", "Color3.new", "Color3.fromHex", "Font.fromName", "Enum.Font", "Estilo.", "GetDescendants", "FireServer", "RemoteEvent"):
        if token in code:
            errors.append(f"{name}: contrato proibido: {token}")
    if "\ufffd" in source or "??o" in source:
        errors.append(f"{name}: texto corrompido")
for name in ("EncontroAutonomoGradeView", "EncontroAutonomoMapaTaticoView"):
    for token in ('Instance.new("ScrollingFrame")', 'Enum.ScrollingDirection.XY', 'Tema.toqueMinimo'):
        if token not in sources[name]:
            errors.append(f"{name}: acessibilidade ausente: {token}")
for token in ('InterfaceCombate', '"Render-se"', 'desistirConfirmacaoVersao', 'Extra.acoes'):
    if token not in sources["EncontroAutonomoView"]:
        errors.append("EncontroAutonomoView: contrato ausente: " + token)
for token in ('gui.IgnoreGuiInset = true', '"Voltar à vila"', 'encontroAutonomo.avisarRetorno()'):
    if token not in sources["ResultadoView"]:
        errors.append("ResultadoView: contrato ausente: " + token)
# U7: contratos de apresentação, sem simular renderização.
extra = sources["UI/ExtraCombate"]
for token in ('larguraBotao, 84', '"RotuloCompacto"', '"Habilid."'):
    if token not in extra: errors.append("U7 combate: " + token)
run = (root / "src/client/RunView.luau").read_text(encoding="utf-8")
for token in ('painel.AutomaticSize = Enum.AutomaticSize.Y', 'layout.AbsoluteContentSize.Y', 'diasRestantes', 'objetivo'):
    if token not in run: errors.append("U7 run: " + token)
banner = (root / "src/client/UI/Avisos.luau").read_text(encoding="utf-8")
for token in ('C.painel', 'losangos = true', 'p.corDestaque'):
    if token not in banner: errors.append("U7 banner: " + token)
editor = (root / "src/client/AparenciaEditor.luau").read_text(encoding="utf-8")
for token in ('T.distanciaPrevia', 'InputChanged', 'AutomaticCanvasSize=Enum.AutomaticSize.X'):
    if token not in editor: errors.append("U7 editor: " + token)
for error in errors:
    print("FALHA U3:", error)
print(f"Interface U3: {len(names)} fontes UTF-8/tema/contratos, {len(errors)} falha(s)")
raise SystemExit(bool(errors))
