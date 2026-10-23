-- Vinhetas curtas de turno e ação. Só lê snapshots/recibos já filtrados.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Estilo = require(Shared.Estilo)
local Catalogo = require(Shared.Livro.Catalogo)
local Execucao = require(Shared.Regras.Execucao)
local FX = require(script.Parent.MenuEfeitos)
local Ritmo = {}

function Ritmo.start(state)
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "RitmoCombate", false, 8
	gui.IgnoreGuiInset = true
	gui.Parent = pg
	local faixa = Instance.new("Frame")
	faixa.Name, faixa.AnchorPoint = "Faixa", Vector2.new(.5, 0)
	faixa.Position, faixa.Size = UDim2.new(.5, 0, 0, 84), UDim2.new(.92, 0, 0, 34)
	faixa.BackgroundColor3, faixa.BackgroundTransparency, faixa.Visible = Estilo.PAPEL_2, .08, false
	faixa.Parent = gui
	local limite = Instance.new("UISizeConstraint"); limite.MaxSize = Vector2.new(500, 34); limite.Parent = faixa
	local canto = Instance.new("UICorner"); canto.CornerRadius = UDim.new(0, 8); canto.Parent = faixa
	local borda = Instance.new("UIStroke"); borda.Thickness = 1.5; borda.Parent = faixa
	local function rotulo(nome, y, altura, fonte, tamanho)
		local t = Instance.new("TextLabel")
		t.Name, t.Position, t.Size = nome, UDim2.fromOffset(12, y), UDim2.new(1, -24, 0, altura)
		t.BackgroundTransparency, t.FontFace, t.TextSize = 1, fonte, tamanho
		t.TextColor3, t.TextTruncate, t.Parent = Estilo.TINTA, Enum.TextTruncate.AtEnd, faixa
		return t
	end
	local titulo = rotulo("Titulo", 0, 20, Estilo.GRITO, 19)
	local dica = rotulo("Dica", 20, 12, Estilo.ROTULO, 12)
	local linha = Instance.new("Frame")
	linha.Name, linha.BorderSizePixel, linha.Position = "Tempo", 0, UDim2.new(0, 0, 1, -2)
	linha.Size, linha.Parent = UDim2.new(1, 0, 0, 2), faixa
	local serial, ultimaVez = 0, nil
	local function ocultar()
		serial += 1
		faixa.Visible = false
	end
	local function mostrar(nome, texto, cor, duracao)
		local menu = pg:FindFirstChild("InicioJogo")
		if menu and menu:FindFirstChild("MenuInicial") and menu.MenuInicial.Visible then return end
		serial += 1
		local atual = serial
		titulo.Text, dica.Text = nome, texto
		titulo.TextColor3, borda.Color, linha.BackgroundColor3 = cor, cor, cor
		faixa.Visible = true
		faixa.Position = UDim2.new(.5, 0, 0, if FX.reduzidos then 84 else 74)
		FX.animar(faixa, .16, { Position = UDim2.new(.5, 0, 0, 84) })
		linha.Visible, linha.Size = not FX.reduzidos, UDim2.new(1, 0, 0, 2)
		if not FX.reduzidos then FX.animar(linha, duracao, { Size = UDim2.new(0, 0, 0, 2) }) end
		task.delay(duracao, function()
			if gui.Parent and serial == atual then faixa.Visible = false end
		end)
	end
	state.onSnapshot(function(s)
		if not s.combat.active then ultimaVez = nil; ocultar(); return end
		local chave = tostring(s.combat.turn) .. ":" .. tostring(s.combat.turnId)
		if chave == ultimaVez then return end
		ultimaVez = chave
		local t = state.findToken(s.combat.turnId)
		if t and t.ownerUserId == state.localUserId() then
			mostrar("SUA VEZ", t.name .. " • Escolha um golpe, apoio ou movimento", Estilo.ALERTA, 1.6)
		end
	end)
	state.onEfeito(function(r)
		local s = state.snapshot()
		if not s or not s.combat.active then return end
		local caster = state.findToken(r.casterId)
		local proprio = caster and caster.ownerUserId == state.localUserId()
		local recebido, dano, cura, critico, errou, resistiu = false, 0, 0, false, false, false
		for _, a in r.alvos or {} do
			local alvo = state.findToken(a.id)
			recebido = recebido or (alvo ~= nil and alvo.ownerUserId == state.localUserId())
			if proprio or (alvo and alvo.ownerUserId == state.localUserId()) then
				dano += a.dano or 0; cura += a.cura or 0
				critico = critico or a.critico == true
				errou = errou or a.acertou == false
				resistiu = resistiu or a.passou == true
			end
		end
		if not proprio and not recebido then return end
		local entrada, mec = Catalogo.POR_ID[r.habilidadeId], Execucao.MECANICAS[r.habilidadeId]
		local nome = if caster then (entrada and entrada.data.name or mec and mec.nome or "Ação") else "Impacto"
		local texto = if dano > 0 then tostring(dano) .. " de dano" elseif cura > 0 then "+" .. cura .. " PV" elseif errou then "Não acertou" elseif resistiu then "O alvo resistiu" else r.resultado or "Efeito confirmado"
		if critico then texto = "CRÍTICO • " .. texto end
		mostrar(Estilo.maiusculas(nome), texto, if critico then Estilo.ALERTA elseif cura > 0 then Estilo.SUCESSO elseif not proprio then Estilo.PERIGO else Estilo.DESTAQUE, 1.4)
	end)
	state.onEncontro(ocultar)
	return gui
end
return Ritmo
