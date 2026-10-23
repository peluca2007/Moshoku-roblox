-- Tela de carregamento no tema Livro Noite. O servidor leva alguns segundos para montar o
-- mundo; até lá o jogador veria um fundo vazio. Cobre a tela, mostra o título e some com
-- fade quando o servidor sinaliza `MesaPronta` e o personagem existe (ou após o limite).
-- Só apresentação local; não decide nada.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Extra = require(script.Parent.UI.ExtraEntrada)
local T, C = Extra.T, Extra.C
local Protocol = require(ReplicatedStorage.Shared.MesaProtocol)

local Carregamento = {}

local LIMITE_S = 90 -- depois disso a tela some mesmo sem sinal (nunca prende o jogador)
local DICAS = {
	"Toque em RUN para começar uma expedição.",
	"Inimigos visíveis patrulham: chegar por trás dá surpresa.",
	"O grupo decide a viagem por votação; quem tem Navegação e Liderança vota com peso 2.",
	"A Floresta Sombria é perigosa para quem vai sozinho.",
	"Fale com Mestre Hanzo para treinar no dojo.",
}

-- Indica se o jogo já pode ser mostrado: servidor pronto + personagem + pedaços do mundo no lugar.
function Carregamento.pronto(): boolean
	if ReplicatedStorage:GetAttribute(Protocol.READY_ATTRIBUTE) ~= true then
		return false
	end
	local personagem = Players.LocalPlayer.Character
	if not personagem or not personagem:FindFirstChild("HumanoidRootPart") then
		return false
	end
	return workspace:FindFirstChild("Vila") ~= nil and workspace:FindFirstChild("FlorestaSombria") ~= nil
end

-- A barra mede quatro marcos replicados; não estima download de malhas.
function Carregamento.progresso()
	local personagem = Players.LocalPlayer.Character
	local sinais = {
		ReplicatedStorage:GetAttribute(Protocol.READY_ATTRIBUTE) == true,
		personagem ~= nil and personagem:FindFirstChild("HumanoidRootPart") ~= nil,
		workspace:FindFirstChild("Vila") ~= nil,
		workspace:FindFirstChild("FlorestaSombria") ~= nil,
	}
	local total = 0
	for _, confirmado in sinais do if confirmado then total += 1 end end
	return total / 4, tostring(total) .. "/4"
end
function Carregamento.start()
	if Carregamento.pronto() then return nil end
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.IgnoreGuiInset, gui.ResetOnSpawn, gui.DisplayOrder = "Carregamento", true, false, 1000
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local fundo = Instance.new("CanvasGroup")
	fundo.Size, fundo.BackgroundColor3, fundo.BorderSizePixel = UDim2.fromScale(1,1), T.cores.painel, 0
	fundo.Active, fundo.Parent = true, gui
	local painel = C.painel({parent=fundo, nome="Marca", losangos=true, padding=24,
		tamanho=UDim2.new(.88,0,.8,0), posicao=UDim2.fromScale(.5,.5), ancora=Vector2.new(.5,.5)})
	local limite = Instance.new("UISizeConstraint")
	limite.MaxSize, limite.Parent = Vector2.new(680,460), painel
	local corpo = painel.Conteudo
	local titulo = C.titulo({parent=corpo, texto="Moshoku", posicao=UDim2.fromScale(0,.08), tamanho=UDim2.new(1,0,.25,0)})
	titulo.TextSize, titulo.TextXAlignment = 64, Enum.TextXAlignment.Center
	titulo.TextScaled, titulo.AutomaticSize = true, Enum.AutomaticSize.None
	local kanji = C.texto({parent=corpo, texto="序  ·  Crônicas de uma nova vida", posicao=UDim2.fromScale(0,.36), tamanho=UDim2.new(1,0,0,32)})
	kanji.TextXAlignment, kanji.TextColor3 = Enum.TextXAlignment.Center, T.cores.titulo
	local ornamento = Extra.ornamento(corpo)
	ornamento.Position = UDim2.fromScale(0,.49)
	local _, atualizar = C.barra({parent=corpo, rotulo="Preparando o mundo", posicao=UDim2.fromScale(0,.56), valor=0})
	local dica = C.texto({parent=corpo, texto=DICAS[1], posicao=UDim2.fromScale(0,.78), tamanho=UDim2.new(1,0,.22,0)})
	dica.TextXAlignment, dica.AutomaticSize = Enum.TextXAlignment.Center, Enum.AutomaticSize.None
	local inicio, indice = os.clock(), 1
	local ligacao
	ligacao = RunService.RenderStepped:Connect(function()
		local t = os.clock() - inicio
		local novoIndice = math.floor(t / 5) % #DICAS + 1
		if novoIndice ~= indice then indice = novoIndice; dica.Text = DICAS[indice] end
		local valor, numero = Carregamento.progresso()
		if numero ~= corpo:GetAttribute("Marcos") then
			corpo:SetAttribute("Marcos", numero); atualizar(valor, numero)
		end
		if (t > 1.2 and Carregamento.pronto()) or t > LIMITE_S then
			ligacao:Disconnect()
			TweenService:Create(fundo, TweenInfo.new(.5), {GroupTransparency=1}):Play()
			task.delay(.6, function() gui:Destroy() end)
		end
	end)
	gui.Destroying:Once(function() ligacao:Disconnect() end)
	return gui
end
return Carregamento
