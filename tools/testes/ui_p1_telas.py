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
assert 'HistoriaV1' not in run  # diário: sem caminho do mundo aberto antigo
assert 'Entrar na luta' not in run and '"votar"' not in run  # luta e votação são da ExpedicaoView
assert 'Apresentacao.nomeArvore(id, Catalogo)' in run
assert 'Tela.diario(dado, nomeDe)' in run and 'Tela.textoFim(dado)' in run
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
assert "Crie seu aventureiro" in ajuda and "porta do esgoto" in ajuda  # primeiros passos do jogo atual (cidade + expedição)
assert "8 minutos" not in ajuda and "relógio" not in ajuda and "trilha" not in ajuda  # texto do mundo aberto antigo
assert 'dica = "Toque em AJUDA para abrir o guia"' in ajuda

resultado = read("src/client/ResultadoView.luau")
assert 'r.titulo .. (if venceu then "!" else "")' in resultado
assert 'T.icone("combate")' in resultado
assert 'Objetivos.atual({ run = ultimoRun' in resultado
assert 'if fundo.Visible and atualizar then atualizar(state.snapshot()) end' in resultado
assert "Grupo recuperado" in resultado
assert "consulte RUN" not in resultado and "Objetivos.textoProximo(objetivo)" in resultado  # sem jargão do jogo antigo
assert "Dano observado nesta conexão" not in resultado
assert "Reúna-se e tente outra estratégia" in read("src/shared/ApresentacaoResultado.luau")

criação = read("src/client/CriacaoPersonagemView.luau")
assert "BorderSizePixel = 0, Text = texto" in criação
assert "BorderSizePixel=0" in criação

# Barra única de atalhos (substitui a varredura periódica e o fade por botão).
atalhos = read("src/client/Atalhos.luau")
assert "C.painel(" in atalhos and 'Instance.new("UIListLayout")' in atalhos and "AtalhosLayout" in atalhos
assert "Heartbeat" not in atalhos and atalhos.count("GetDescendants") == 1  # só a varredura inicial
assert "DescendantAdded" in atalhos and 'GetAttributeChangedSignal("InterfaceCombate")' in atalhos
assert "function Atalhos.criar(" in atalhos and "function Atalhos.ocultar(" in atalhos and "function Atalhos.livre(" in atalhos

treinador = read("src/client/TreinadorView.luau")
assert "local function ajustarAltura()" in treinador
assert "conteudoLayout.AbsoluteContentSize.Y" in treinador

# o MENU e o ÁRVORES nascem na barra; DIÁRIO, CONTA e AJUDA (Extra.atalho) são adotados pelo atributo AtalhoMundo
assert 'Atalhos.criar({nome="MENU"' in inicio and 'Atalhos.criar({ nome = "AbrirArvores"' in read("src/client/ArvoresView.luau")
assert 'atalho.Position =' not in read("src/client/AjudaView.luau")
assert 'lista.ClipsDescendants = true' in read("src/client/UI/ExtraTelas.luau")
assert 'ClipsDescendants = true' in criação
assert '"AJUDA"' in read("src/client/AjudaView.luau")
assert 'state.send("personagemPessoalConsultar",{})' in inicio

print("P1 telas: nomes legíveis, ajuda, resultado, aparência, restauração do MENU e altura do treinador ok (estático)")
