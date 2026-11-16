-- HUD de jogo da luta (HUD2): estrutura de comandos em RPG de turnos, arte e linguagem nossas.
-- Só lê o snapshot; não decide nada. Geometria em shared/Regras/LayoutLuta (pura, com spec).
-- - Grupo (HudJogo.Cartoes > Cartao_<id>): canto inferior esquerdo, um cartão por aliado com retrato
--   (cabeça e ombros), nome, PV (grossa, com número) e PM (fina) e as Ações do turno como losangos
--   acesos; quem age é maior e dourado. Fora da luta: só o seu personagem, no alto à direita.
-- - Ordem dos turnos (HudJogo.Ordem > Vez<i>): coluna de retratos à esquerda, quem age no topo e maior;
--   moldura dourada nos aliados e vermelha nos inimigos. Rodada/prazo: HudJogo.Rodada (topo central).
-- - Chefe (HudJogo.Chefe): vida e aviso da fase, abaixo do topo.
local Players = game:GetService("Players")
local T = require(script.Parent.UI.Tema)
local C = require(script.Parent.UI.Componentes)
local P = require(script.Parent.UI.PecasLuta)
local Retrato = require(script.Parent.RetratoLuta)
local Shared = game:GetService("ReplicatedStorage").Shared
local OrdemVisivel = require(Shared:WaitForChild("OrdemVisivel"))
local Layout = require(Shared.Regras.LayoutLuta)

local Hud = {}
local new = P.novo
local RETRATO = 60
local PIPS_MAX = 6

local function texto(parent, props)
	local l = new("TextLabel", nil, {
		BackgroundTransparency = 1, TextSize = 15, TextTruncate = Enum.TextTruncate.AtEnd, TextYAlignment = Enum.TextYAlignment.Center,
		FontFace = T.fontes.rotulo, TextColor3 = P.cor.texto, TextXAlignment = Enum.TextXAlignment.Left, Text = "",
		TextStrokeColor3 = P.cor.trilho, TextStrokeTransparency = 0.3,
	})
	for k, v in props do
		l[k] = v
	end
	l.Parent = parent
	return l
end

function Hud.start(state)
	local eu = Players.LocalPlayer
	local gui = new("ScreenGui", eu:WaitForChild("PlayerGui"), {
		Name = "HudJogo", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 4,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})

	-- Cartões do grupo.
	local cartoes = new("Frame", gui, { Name = "Cartoes", BackgroundTransparency = 1, Size = UDim2.fromOffset(Layout.CARTAO_LARGURA, Layout.CARTAO_ALTURA), Visible = false })
	C.aplicarEscala(cartoes)
	local fichas: { [string]: any } = {}
	local function cartaoDe(id: string)
		local f = fichas[id]
		if f then return f end
		local q = new("CanvasGroup", cartoes, {
			Name = "Cartao_" .. id, Size = UDim2.fromOffset(Layout.CARTAO_LARGURA, Layout.CARTAO_ALTURA),
			BackgroundColor3 = P.cor.fundo, BackgroundTransparency = 0.45, BorderSizePixel = 0, GroupTransparency = 1,
		})
		new("UICorner", q, { CornerRadius = UDim.new(0, 8) })
		new("UIStroke", q, { Name = "Contorno", Color = P.cor.ouro, Thickness = 1, Transparency = 0.6 })
		P.arte(q, "mancha_cartao", 1) -- HUD3: mancha de tinta pintada sob o conteúdo
		local retrato = Retrato.novo(q, "Retrato", UDim2.fromOffset(RETRATO, RETRATO))
		retrato.raiz.Position = UDim2.fromOffset(8, 8)
		local x = 8 + RETRATO + 10
		local nome = texto(q, { Name = "Nome", Position = UDim2.fromOffset(x, 4), Size = UDim2.new(1, -x - 8, 0, 24), FontFace = T.fontes.titulo, TextSize = 18 })
		local pv = P.barra({ parent = q, nome = "PV", posicao = UDim2.fromOffset(x, 30), tamanho = UDim2.new(1, -x - 8, 0, 14), numero = true, tamanhoTexto = 14 })
		local pm = P.barra({ parent = q, nome = "PM", posicao = UDim2.fromOffset(x, 48), tamanho = UDim2.new(1, -x - 8, 0, 6), cor = P.cor.pm })
		local acoes = new("Frame", q, { Name = "Acoes", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, x, 1, -8), Size = UDim2.new(1, -x - 8, 0, 14), BackgroundTransparency = 1 })
		local pips = {}
		for i = 1, PIPS_MAX do
			local pip = P.pip(acoes, 10)
			pip.Position = UDim2.fromOffset(7 + (i - 1) * 18, 7)
			pip.Visible = false
			pips[i] = pip
		end
		f = { q = q, nome = nome, pv = pv, pm = pm, retrato = retrato, acoes = acoes, pips = pips, ativo = false, alvo = nil, token = nil }
		fichas[id] = f
		P.animar(q, { GroupTransparency = 0 }, P.SUAVE, "grupo")
		return f
	end

	local function moverCartao(f, pos: UDim2, tam: UDim2)
		if f.alvo ~= pos or f.tam ~= tam then
			local novo = f.alvo == nil
			f.alvo, f.tam = pos, tam
			if novo then
				f.q.Position = pos - UDim2.fromOffset(24, 0)
				f.q.Size = tam
			end
			P.animar(f.q, { Position = pos, Size = tam }, P.ENTRADA, "mover")
		end
	end

	local function estiloAtivo(f, ativo: boolean)
		if f.ativo == ativo and f.estiloFeito then return end
		f.ativo, f.estiloFeito = ativo, true
		P.animar(f.q.Contorno, { Thickness = if ativo then 2 else 1, Transparency = if ativo then 0 else 0.35, Color = if ativo then P.cor.ouroVivo else P.cor.ouro }, P.SUAVE, "ativo")
		P.animar(f.q, { BackgroundTransparency = if ativo then 0.08 else 0.2 }, P.SUAVE, "fundo")
		f.nome.TextColor3 = if ativo then P.cor.ouroVivo else P.cor.texto
		P.animar(f.pv.raiz, { Size = UDim2.new(1, -78 - 8, 0, if ativo then 18 else 14), Position = UDim2.fromOffset(78, if ativo then 32 else 30) }, P.SUAVE, "pv")
		P.animar(f.pm.raiz, { Position = UDim2.fromOffset(78, if ativo then 54 else 48), Size = UDim2.new(1, -78 - 8, 0, if ativo then 8 else 6) }, P.SUAVE, "pm")
	end

	-- Chefe: vida e aviso da fase.
	local chefe = P.placa(gui, "Chefe", UDim2.fromOffset(Layout.CHEFE_LARGURA, Layout.CHEFE_ALTURA), { cor = P.cor.inimigo })
	chefe.Visible = false
	local chefeNome = texto(chefe, { Name = "Nome", Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -24, 0, 24), FontFace = T.fontes.titulo, TextSize = 19, TextColor3 = P.cor.inimigo })
	local chefeBarra = P.barra({ parent = chefe, nome = "BarraChefe", posicao = UDim2.fromOffset(12, 30), tamanho = UDim2.new(1, -24, 0, 18), numero = true, cor = P.cor.inimigo })
	local chefeAviso = texto(chefe, { Name = "Aviso", Position = UDim2.fromOffset(12, 56), Size = UDim2.new(1, -24, 0, 22), TextSize = 14, TextColor3 = P.cor.secundario })
	C.aplicarEscala(chefe)

	-- Rodada / prazo da vez (topo central, sem caixa).
	local prazo = new("TextLabel", gui, {
		Name = "Rodada", BackgroundTransparency = 1, Text = "", Visible = false, FontFace = T.fontes.numero, TextSize = 15,
		TextColor3 = P.cor.texto, TextStrokeColor3 = P.cor.trilho, TextStrokeTransparency = 0.25,
	})

	-- Ordem dos turnos: coluna de retratos à esquerda.
	local ordem = new("Frame", gui, { Name = "Ordem", BackgroundTransparency = 1, Size = UDim2.fromOffset(Layout.ORDEM_ATIVO + 110, 400), Position = UDim2.fromOffset(Layout.MARGEM, Layout.ORDEM_Y), Visible = false })
	C.aplicarEscala(ordem)
	local vezes: { [number]: any } = {}
	local function vez(i: number)
		local v = vezes[i]
		if v then return v end
		local q = new("CanvasGroup", ordem, {
			Name = "Vez" .. i, BackgroundColor3 = P.cor.fundo, BackgroundTransparency = 0.1, BorderSizePixel = 0, GroupTransparency = 1,
		})
		new("UICorner", q, { CornerRadius = UDim.new(0, 8) })
		new("UIStroke", q, { Name = "Contorno", Color = P.cor.aliado, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
		local retrato = Retrato.novo(q, "Retrato", UDim2.fromScale(1, 1))
		local mais = texto(q, { Name = "Mais", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, FontFace = T.fontes.numero, TextSize = 18, Visible = false, ZIndex = 5 })
		local nome = texto(ordem, { Name = "Nome" .. i, Size = UDim2.fromOffset(106, 24), FontFace = T.fontes.titulo, TextSize = 16, TextColor3 = P.cor.ouroVivo, Visible = false })
		v = { q = q, retrato = retrato, mais = mais, nome = nome, chave = nil, alvo = nil }
		vezes[i] = v
		return v
	end

	local function atualizarOrdem(snap, vp: Vector2, emLuta: boolean)
		ordem.Visible = emLuta
		local usados = 0
		if emLuta then
			local lista = OrdemVisivel.listar(snap.combat.order or {}, snap.combat.turnId, snap.tokens)
			local col = Layout.ordemColuna(vp.X, vp.Y, #lista)
			for i, r in col.rects do
				local v = vez(i)
				usados = i
				local t = lista[i]
				local ehMais = i > col.mostrados
				local pos = UDim2.fromOffset(r.x - Layout.MARGEM, r.y - Layout.ORDEM_Y)
				local tam = UDim2.fromOffset(r.w, r.h)
				if v.alvo ~= pos or v.tam ~= tam then
					local novo = v.alvo == nil
					v.alvo, v.tam = pos, tam
					if novo or not v.q.Visible then v.q.Position = pos - UDim2.fromOffset(20, 0); v.q.Size = tam end
					P.animar(v.q, { Position = pos, Size = tam }, P.ENTRADA, "mover")
				end
				v.q.Visible = true
				P.animar(v.q, { GroupTransparency = 0 }, P.SUAVE, "grupo")
				v.mais.Visible = ehMais
				v.retrato.raiz.Visible = not ehMais
				local contorno = v.q.Contorno
				if ehMais then
					v.mais.Text = "+" .. col.resto
					v.nome.Visible = false
					contorno.Color, contorno.Thickness = P.cor.secundario, 1
				else
					local daVez = snap.combat.turnId == t.id
					if v.chave ~= t.id then
						v.chave = t.id
						v.retrato.definir(t)
					else
						v.retrato.tentar(t)
					end
					contorno.Color = if t.criatura then P.cor.inimigo elseif daVez then P.cor.ouroVivo else P.cor.aliado
					contorno.Thickness = if daVez then 2.5 else 1.5
					v.nome.Visible = daVez
					v.nome.Text = t.name
					v.nome.Position = UDim2.fromOffset(r.x - Layout.MARGEM + r.w + 8, r.y - Layout.ORDEM_Y + r.h / 2 - 12)
				end
			end
		end
		for i, v in vezes do
			if i > usados then
				v.q.Visible, v.nome.Visible, v.chave, v.alvo = false, false, nil, nil
				v.q.GroupTransparency = 1
			end
		end
	end

	local function posicionar(vp: Vector2, emLuta: boolean, doGrupo: { any }, ativo: number?)
		local topo = Layout.topo(vp.X)
		prazo.Position, prazo.Size = UDim2.fromOffset(topo.rodada.x, topo.rodada.y), UDim2.fromOffset(topo.rodada.w, topo.rodada.h)
		local c = Layout.chefe(vp.X)
		chefe.AnchorPoint = Vector2.zero
		chefe.Position = UDim2.fromOffset(c.x, c.y)
		if emLuta then
			local rects = Layout.cartoes(vp.X, vp.Y, math.max(1, #doGrupo), ativo)
			local ultimo = rects[#rects]
			cartoes.AnchorPoint = Vector2.new(0, 1)
			cartoes.Position = UDim2.fromOffset(rects[1].x, ultimo.y + ultimo.h)
			cartoes.Size = UDim2.fromOffset(rects[1].w, ultimo.y + ultimo.h - rects[1].y)
			return rects
		end
		local r = Layout.cartaoFora(vp.X)
		cartoes.AnchorPoint = Vector2.zero
		cartoes.Position = UDim2.fromOffset(r.x, r.y)
		cartoes.Size = UDim2.fromOffset(r.w, r.h)
		return { r }
	end

	local function atualizar()
		local snap = state.snapshot()
		if not snap then
			return
		end
		local vp = workspace.CurrentCamera.ViewportSize
		local emLuta = snap.combat.active == true
		local boss = snap.encontro and snap.encontro.chefe
		chefe.Visible = emLuta and boss ~= nil
		if boss then
			chefeNome.Text = boss.nome .. " · Fase " .. boss.fase
			chefeBarra.definir(boss.pv, boss.pvMax)
			chefeAviso.Text = if boss.aviso then boss.aviso.nome .. (if boss.areaAtiva then " · Saia da área!" else " · Prévia visual") else "O bosque aguarda…"
		end

		-- Quem ganha cartão: em luta, todo personagem de jogador; fora dela, o meu (o da vez, se houver mais de um).
		local doGrupo, meu = {}, nil
		for _, t in snap.tokens do
			if t.kind == "jogador" then
				if emLuta then table.insert(doGrupo, t) end
				if t.ownerUserId == eu.UserId and (not meu or snap.combat.turnId == t.id) then meu = t end
			end
		end
		if not emLuta and meu then doGrupo = { meu } end
		local usadas = if snap.jogo and snap.jogo.acoes then snap.jogo.acoes else nil
		local ativoIdx = nil
		for i, t in doGrupo do
			if emLuta and snap.combat.turnId == t.id then ativoIdx = i end
		end
		local rects = posicionar(vp, emLuta, doGrupo, ativoIdx)
		local vistos = {}
		for i, t in doGrupo do
			if i > Layout.MAX_CARTOES then break end
			local f = cartaoDe(t.id)
			vistos[t.id] = true
			local r = rects[math.min(i, #rects)]
			f.q.Visible = true
			moverCartao(f, UDim2.fromOffset(0, if emLuta then r.y - rects[1].y else 0), UDim2.fromOffset(r.w, r.h))
			f.nome.Text = t.name
			f.pv.definir(t.pv, t.pvMax)
			f.pm.definir(t.mana, t.manaMax)
			if f.token ~= t.id then f.token = t.id; f.retrato.definir(t) else f.retrato.tentar(t) end
			local daVez = emLuta and snap.combat.turnId == t.id
			estiloAtivo(f, daVez)
			local temAcoes = daVez and usadas ~= nil and usadas.tokenId == t.id
			f.acoes.Visible = temAcoes
			for k, pip in f.pips do
				local existe = temAcoes and k <= usadas.total
				pip.Visible = existe
				if existe then P.pipAceso(pip, k <= usadas.total - usadas.usadas) end
			end
		end
		for id, f in fichas do
			if not vistos[id] then
				fichas[id] = nil
				local q = f.q
				P.animar(q, { GroupTransparency = 1 }, P.SAIDA, "grupo").Completed:Once(function() q:Destroy() end)
			end
		end
		cartoes.Visible = next(vistos) ~= nil
		atualizarOrdem(snap, vp, emLuta)
		prazo.Visible = emLuta
	end

	state.onSnapshot(atualizar)
	task.spawn(function()
		while gui.Parent do
			local snap = state.snapshot()
			local e = snap and snap.encontro
			if e and e.prazoFim and snap.combat.active then
				local resto = math.max(0, math.ceil(e.prazoFim - workspace:GetServerTimeNow()))
				local dono = nil
				for _, t in snap.tokens do
					if t.id == e.prazoId then dono = t end
				end
				prazo.Text = string.format("%s%d s", if dono and dono.ownerUserId == eu.UserId then "Sua vez · " else "", resto)
				prazo.TextColor3 = if resto <= 10 then P.cor.inimigo else P.cor.ouroVivo
			else
				prazo.Text = "" -- a rodada aparece na dica do canto inferior direito (AcoesDoTurno)
				prazo.TextColor3 = P.cor.texto
			end
			-- retratos que ainda esperavam o corpo carregar
			for _, f in fichas do
				if f.token and not f.retrato.raiz.Vista.Visible and snap then
					for _, t in snap.tokens do
						if t.id == f.token then f.retrato.tentar(t) end
					end
				end
			end
			task.wait(0.25)
		end
	end)
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(atualizar)
	atualizar()
	return gui
end

return Hud
