"""Contratos estáticos das telas de abertura P1; não substitui renderização no Studio."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def read(path: str) -> str:
    text = (ROOT / path).read_text(encoding="utf-8", errors="strict")
    assert "�" not in text, f"{path}: codificação inválida"
    return text

inicio = read("src/client/InicioView.luau")
assert '"Sem personagem ainda"' in inicio
assert 'string.format("%s · %s · %s"' in inicio
assert 'personagemPessoalConsultar' in inicio
assert 's.you.personagem' not in inicio

run = read("src/client/RunView.luau")
assert 'botao("Nova expedição"' in run and "AberturaFluxo" in run  # P2: sem lista de modos crus
assert 'HistoriaV1.HISTORIA.nos[dado.galho]' in run
assert 'Apresentacao.nomeArvore(id, Catalogo)' in run
assert 'Apresentacao.nomeObjetivo(dado.objetivo, HistoriaV1)' in run
assert 'Apresentacao.nomePronto(plano.prontoId, PersonagensProntos)' in run

viagem = read("src/client/ViagemView.luau")
assert 'Apresentacao.nomeObjetivo(objetivo, HistoriaV1)' in viagem
assert 'personagem.Archivable = true' in viagem and 'personagem:Clone()' in viagem
assert 'ModeloAparencia.criar' in viagem and 'perfilPessoal.aparencia' in viagem
assert 'CreateHumanoidModelFromUserIdAsync' not in viagem
modelo_aparencia = read("src/client/ModeloAparencia.luau")
assert 'Visual.decorar' in modelo_aparencia
editor = read("src/client/AparenciaEditor.luau")
assert 'ModeloAparencia.criar' in editor

nomes = read("src/shared/ApresentacaoAbertura.luau")
assert 'Catalogo' not in nomes and 'Historia' not in nomes
ajuda = read("src/shared/AjudaConteudo.luau")
assert "portão norte" in ajuda and "fale com um mestre" in ajuda  # P2: primeiros passos do fluxo novo
assert 'dica = "Toque em AJUDA para abrir o guia"' in ajuda

resultado = read("src/client/ResultadoView.luau")
assert 'r.titulo .. (if venceu then "!" else "")' in resultado
assert 'T.icone("combate")' in resultado and 'T.icone("conta")' in resultado
assert 'Objetivos.atual({ run = ultimoRun' in resultado
assert 'if fundo.Visible and atualizar then atualizar(state.snapshot()) end' in resultado
assert "Grupo recuperado" in resultado
assert "Dano observado nesta conexão" not in resultado
assert "Reúna-se, ajuste sua estratégia e tente novamente" in resultado

criação = read("src/client/CriacaoPersonagemView.luau")
assert "BorderSizePixel = 0, Text = texto" in criação
assert "BorderSizePixel=0" in criação

atalhos = read("src/client/Atalhos.luau")
assert '"U5BackgroundColor3"' in atalhos and '"U5TextColor3"' in atalhos

treinador = read("src/client/TreinadorView.luau")
assert "local function ajustarAltura()" in treinador
assert "conteudoLayout.AbsoluteContentSize.Y" in treinador

atalho = read("src/client/Atalhos.luau")
assert 'botao.Visible = true' in atalho and 'item.TextTransparency = item:GetAttribute("U5TextTransparency") or 0' in atalho
assert atalho.index('item.TextTransparency = item:GetAttribute("U5TextTransparency") or 0') < atalho.index('botao.Visible = true')
assert 'lista.ClipsDescendants = true' in read("src/client/UI/ExtraTelas.luau")
assert 'ClipsDescendants = true' in criação
assert '"AJUDA"' in read("src/client/AjudaView.luau")
assert 'state.send("personagemPessoalConsultar",{})' in inicio

print("P1 telas: nomes legíveis, ajuda, resultado, aparência, restauração do MENU e altura do treinador ok (estático)")
