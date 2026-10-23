"""Contratos estáticos U4. Não simula renderização nem mede fontes no Roblox."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
files = [ROOT / "src/client" / (name + ".luau") for name in (
    "Carregamento", "InicioView", "CriacaoPersonagemView", "CameraMundo", "UI/ExtraEntrada")]
sources = {p.stem: p.read_text(encoding="utf-8", errors="strict") for p in files}
for name, source in sources.items():
    assert not re.search(r"(?:Color3\.(?:new|fromRGB|fromHSV)|Font\.(?:new|fromName)|Enum\.Font\.)", source), name + ": estilo fora do tema"
    assert "�" not in source, name + ": codificação inválida"

helper = sources["ExtraEntrada"]
assert "MinSize = Vector2.new(T.toqueMinimo, T.toqueMinimo)" in helper
assert 'obj:IsA("TextButton") or obj:IsA("TextBox")' in helper
assert "VerticalScrollBarInset = Enum.ScrollBarInset.Always" in helper
assert "PaddingRight = UDim.new(0, 16)" in helper
creation = sources["CriacaoPersonagemView"]
assert "Extra.estilizar(objeto, props.FontFace)" in creation
assert "Extra.rolagem(conteudo)" in creation and "Extra.rolagem(lista)" in creation
assert "UDim2.fromOffset(44, 44)" in creation
assert "controles.raca = Extra.cartao" in creation and "controles.antecedente = Extra.cartao" in creation
assert "aparenciaFluxo.editar" in creation
assert "1 Raça → 2 Antecedente → 3 Atributos → 4 Perícias → 5 Árvore → 6 Aparência → 7 Confirmar" in creation
# '+' fica antes do trilho reservado; botões têm 44px sem UIScale nos módulos U4.
for width in (375, 667, 1280):
    panel = min(width * .92, 760)
    content = panel - 36 - 8 - 16 - 2
    plus_left, plus_right = content - 48, content - 4
    minus_left, minus_right = content - 100, content - 56
    assert plus_right - plus_left >= 44 and minus_right - minus_left >= 44
    assert minus_right < plus_left and plus_right < content and minus_left > 0
camera = sources["CameraMundo"]
assert "Componentes.iconeBotao" in camera and "novo.DisplayOrder = -1" in camera
assert "↺" not in camera and "↻" not in camera
assert int(re.search(r"LADO_BOTAO = (\d+)", camera)[1]) >= 44
menu = sources["InicioView"]
assert 'Fluxo.novaExpedicao()' in menu and 'WaitForChild("RunJogo")' in menu
assert 'remoteRun:FireServer({acao="consultar"})' in menu
assert 'botao(home,"OutrosModos"' in menu and 'botao(jogar,"Treinar"' in menu
assert 'botao(home,"Treinar"' not in menu
assert "Nova expedição" in menu and "Continuar" in menu
assert "IndicacaoRolagem" in menu
assert not any("UIScale" in sources[n] for n in ("InicioView", "CriacaoPersonagemView", "Carregamento"))
print("Interface U4: UTF-8/tema, controles >=44px, margem de rolagem e contratos de entrada ok (estático)")
