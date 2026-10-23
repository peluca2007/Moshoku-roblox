-- Executar no CLIENTE em Play após sincronizar os fontes; não altera telas existentes.
local player = game:GetService("Players").LocalPlayer
assert(player, "Executar no cliente")
local C = require(player.PlayerScripts.Client.UI.Componentes)
local T = require(player.PlayerScripts.Client.UI.Tema)
local pg = player.PlayerGui
local antiga = pg:FindFirstChild("VitrineUI"); if antiga then antiga:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "VitrineUI"; gui.ResetOnSpawn = false; gui.DisplayOrder = 100
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; gui.Parent = pg
local root = Instance.new("Frame"); root.Name = "Tela"; root.BackgroundTransparency = 1; root.Size = UDim2.fromScale(1,1); root.Parent = gui
local escala = C.aplicarEscala(root)
local function ajustarTela() root.Size = UDim2.fromScale(1/escala.Scale, 1/escala.Scale) end
escala:GetPropertyChangedSignal("Scale"):Connect(ajustarTela)
ajustarTela()
-- Scroll mantém o catálogo acessível em retrato; a vitrine não usa o joystick.
local scroll = Instance.new("ScrollingFrame")
scroll.Name = "Catalogo"; scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0
scroll.Position = UDim2.fromOffset(16,180); scroll.Size = UDim2.new(0.55,-32,1,-196)
scroll.ClipsDescendants = true
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; scroll.CanvasSize = UDim2.new(); scroll.ScrollBarThickness = 6; scroll.Parent = root
local lista = C.lista({ parent=scroll, espaco=24 })
local painel = C.painel({ parent=lista, ordem=1, tamanho=UDim2.new(1,-24,0,180), losangos=true })
C.titulo({ parent=painel.Conteudo, texto="MOSHOKU", ornamento=true })
C.texto({ parent=painel.Conteudo, texto="Interface V2 • escuro com ouro", subtitulo=true, posicao=UDim2.fromOffset(0,54) })
C.texto({ parent=painel.Conteudo, texto="Uma jornada começa na vila.", posicao=UDim2.fromOffset(0,88) })
local legenda = C.texto({ parent=painel.Conteudo, texto="Legenda • 15 px, mínimo físico 14", posicao=UDim2.fromOffset(0,120) }); legenda.TextSize=T.tamanhos.legenda
local botoes = C.lista({ parent=lista, ordem=2 })
for i, variante in { "principal", "secundario", "perigo", "fantasma" } do
	C.botao({ parent=botoes, ordem=i, texto=variante, variante=variante, icone="run", aoClicar=function()
		C.aviso({parent=gui,titulo="Escolha recebida",detalhe=variante,tipo="info"})
	end })
end
 C.botao({ parent=botoes, ordem=5, texto="Indisponível", variante="secundario", icone="fechar", desabilitado=true })
local _, atualizar = C.barra({ parent=lista, ordem=3, rotulo="Tempo restante", valor=1, numero="60s", destaque=T.cores.alerta })
task.spawn(function() for segundos=60,0,-1 do if not gui.Parent then return end; atualizar(segundos/60, segundos.."s"); task.wait(1) end end)
local cartao = C.cartao({ parent=lista, ordem=4, tamanho=UDim2.new(1,-24,0,130) })
C.titulo({ parent=cartao.Conteudo, texto="Árvore da Água" })
C.texto({ parent=cartao.Conteudo, texto="Identidade canônica em Tema.arvore.", posicao=UDim2.fromOffset(0,62) })
local hud = C.grade({ parent=lista, ordem=5, celula=UDim2.fromOffset(140,94) })
local nomes = {}; for nome in T.ICONES do table.insert(nomes, nome) end; table.sort(nomes)
for i, nome in nomes do
	C.iconeBotao({parent=hud,ordem=i,icone=nome,rotulo=nome,tamanho=UDim2.fromOffset(140,94)})
end
-- Diálogo no catálogo para permitir inspeção sem cobrir o jogo inteiro.
C.dialogoNpc({ parent=lista, ordem=6, ancora=Vector2.zero, posicao=UDim2.new(), tamanho=UDim2.new(1,-8,0,0), nomeNpc="Hanzo", fala="Todo caminho começa com um primeiro treino.", opcoes={
	{texto="Quero treinar",aoClicar=function() C.aviso({parent=gui,tipo="sucesso",titulo="Treino",detalhe="Exemplo de opção."}) end},
	{texto="Até logo",aoClicar=function() C.aviso({parent=gui,titulo="Até logo",detalhe="A vila espera por você."}) end},
} })
C.aviso({parent=gui,tipo="sucesso",titulo="Aprovado!",detalhe="Árvore da Água • 1 dia de treino\nLoot raro recebido",destaque=true,duracao=5})
for _, tipo in {"info","sucesso","perigo","alerta"} do
	C.aviso({parent=gui,tipo=tipo,titulo=string.upper(tipo),detalhe="Banner no alto • fila sem sobreposição",duracao=2})
end
return "VitrineUI criada. Destruir PlayerGui.VitrineUI encerra a vitrine."
