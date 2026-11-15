-- Linha de anúncio da luta (LUTA-B): "Ren usa Ataque básico." e, logo abaixo, o resultado curto
-- ("5 de dano", "errou"). Texto sobre o mundo, sem caixa, no topo central (geometria em
-- shared/Regras/LayoutLuta, que reserva o canto direito para a faixa do dia/sala). Substitui a faixa
-- do RitmoCombate. Só lê recibos de efeito já filtrados pelo servidor; não decide nada.
-- Instances: ScreenGui "AnuncioLuta" > Anuncio | Resultado.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Catalogo = require(Shared.Livro.Catalogo)
local Execucao = require(Shared.Regras.Execucao)
local Layout = require(Shared.Regras.LayoutLuta)
local T = require(script.Parent.UI.Tema)

local Anuncio = {}

-- Texto do resultado a partir do recibo (puro; coberto por spec indireto via formato).
function Anuncio.resultado(alvos: { any }?): string
	local dano, cura, errou, resistiu, critico = 0, 0, false, false, false
	for _, a in alvos or {} do
		dano += a.dano or 0
		cura += a.cura or 0
		errou = errou or a.acertou == false
		resistiu = resistiu or a.passou == true
		critico = critico or a.critico == true
	end
	local texto = if dano > 0 then dano .. " de dano" elseif cura > 0 then "+" .. cura .. " PV" elseif errou then "errou" elseif resistiu then "resistiu" else ""
	if critico and texto ~= "" then texto = "Crítico! " .. texto end
	return texto
end

function Anuncio.start(state)
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.DisplayOrder, gui.IgnoreGuiInset = "AnuncioLuta", false, 8, true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local function linha(nome: string, tamanho: number, cor: Color3)
		local l = Instance.new("TextLabel")
		l.Name, l.BackgroundTransparency, l.Text, l.Visible = nome, 1, "", false
		l.FontFace, l.TextSize, l.TextColor3 = T.fontes.titulo, tamanho, cor
		l.TextStrokeColor3, l.TextStrokeTransparency = T.cores.fundoTela, 0.15
		l.TextTruncate = Enum.TextTruncate.AtEnd
		l.Parent = gui
		return l
	end
	local anuncio = linha("Anuncio", 22, T.sobreEscuro.titulo)
	local resultado = linha("Resultado", 18, T.sobreEscuro.texto)
	local function posicionar()
		local topo = Layout.topo(workspace.CurrentCamera.ViewportSize.X)
		for r, l in { { topo.anuncio, anuncio }, { topo.resultado, resultado } } do
			l[2].Position, l[2].Size = UDim2.fromOffset(l[1].x, l[1].y), UDim2.fromOffset(l[1].w, l[1].h)
		end
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(posicionar)
	posicionar()

	local serial = 0
	local function ocultar()
		serial += 1
		anuncio.Visible, resultado.Visible = false, false
	end
	local function mostrar(texto: string, detalhe: string, duracao: number)
		serial += 1
		local meu = serial
		anuncio.Text, resultado.Text = texto, detalhe
		anuncio.Visible, resultado.Visible = true, detalhe ~= ""
		task.delay(duracao, function()
			if gui.Parent and serial == meu then ocultar() end
		end)
	end
	state.onSnapshot(function(s)
		if not s.combat.active then ocultar() end
	end)
	state.onEncontro(ocultar)
	state.onEfeito(function(r)
		local s = state.snapshot()
		if not s or not s.combat.active then return end
		local quem = state.findToken(r.casterId)
		local entrada, mec = Catalogo.POR_ID[r.habilidadeId], Execucao.MECANICAS[r.habilidadeId]
		local nome = (entrada and entrada.data.name) or (mec and mec.nome) or "uma ação"
		local detalhe = Anuncio.resultado(r.alvos)
		if detalhe == "" and type(r.resultado) == "string" then detalhe = r.resultado end
		mostrar(string.format("%s usa %s.", quem and quem.name or "Alguém", nome), detalhe, 2.8)
	end)
	return gui
end

return Anuncio
