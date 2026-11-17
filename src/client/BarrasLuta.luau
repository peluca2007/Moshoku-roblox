-- Barras de vida sobre cada combatente (HUD2): moldura fina dourada, barra com "rastro" de dano (a parte
-- perdida fica clara e some com atraso), número de dano grande que salta do alvo, nome (sempre nos
-- inimigos; nos aliados só de quem age ou está selecionado), losango sobre quem age e marcas de condição.
-- Posição de tela a partir da casa do token (MesaProtocol.cellCenter). Só lê o snapshot.
-- Enquanto a luta durar, esconde o rótulo+barra antigos do BoardView (BillboardGui com "BarraPV"),
-- para não duplicar; ao fim da luta eles voltam.
-- Instances: ScreenGui "BarrasLuta" > <tokenId> > Nome | PV (barra) | Vez | Marcas | Saltos > Salto.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Protocol = require(Shared:WaitForChild("MesaProtocol"))
local T = require(script.Parent.UI.Tema)
local P = require(script.Parent.UI.PecasLuta)
local Feedback = require(script.Parent.FeedbackCombate)

local Barras = {}

local LARGURA = 92
local DURACAO_SALTO = 1.0

-- Abreviação curta da condição para o marcador ("em-chamas" -> "Em ").
function Barras.marca(id: string): string
	local limpo = string.gsub(id, "[-_]", " ")
	return string.upper(string.sub(limpo, 1, 1)) .. string.sub(limpo, 2, 3)
end

-- Afasta verticalmente os marcadores que se sobrepõem na tela (combatentes vizinhos ou alinhados com a
-- câmera): do mais baixo para o mais alto, o que colide sobe até ficar livre. Só mexe na posição desenhada.
local ALTURA_ITEM, FOLGA_X = 46, LARGURA + 24
function Barras.separar(itens: { [string]: any })
	local lista = {}
	for _, item in itens do
		if item.raiz.Visible and item.px then table.insert(lista, item) end
	end
	table.sort(lista, function(a, b) return a.py > b.py end)
	for i, item in lista do
		local y = item.py
		for _ = 1, #lista do
			local colide = false
			for j = 1, i - 1 do
				local o = lista[j]
				if math.abs(o.px - item.px) < FOLGA_X and math.abs(o.yFinal - y) < ALTURA_ITEM then
					y = o.yFinal - ALTURA_ITEM
					colide = true
					break
				end
			end
			if not colide then break end
		end
		item.yFinal = y
		item.raiz.Position = UDim2.fromOffset(item.px, y)
	end
end

function Barras.start(state)
	local jogador = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.DisplayOrder, gui.IgnoreGuiInset = "BarrasLuta", false, 3, true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = jogador:WaitForChild("PlayerGui")
	local itens: { [string]: any } = {}
	local ultimoPv: { [string]: number } = {}
	local escondidos, ultimaContagem = false, -1

	local function criar(id: string, token)
		local raiz = P.novo("Frame", gui, { Name = id, AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(LARGURA, 44), BackgroundTransparency = 1 })
		local nome = P.novo("TextLabel", raiz, {
			Name = "Nome", BackgroundTransparency = 1, Size = UDim2.new(1, 70, 0, 20), Position = UDim2.fromScale(0.5, 0), AnchorPoint = Vector2.new(0.5, 0),
			FontFace = T.fontes.titulo, TextSize = 16, TextColor3 = P.cor.texto, TextStrokeColor3 = P.cor.trilho, TextStrokeTransparency = 0.2,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		local vez = P.pip(raiz, 9)
		vez.Name, vez.Position, vez.Visible = "Vez", UDim2.new(0.5, 0, 0, -6), false
		local barra = P.barra({ parent = raiz, nome = "PV", posicao = UDim2.fromOffset(0, 24), tamanho = UDim2.new(1, 0, 0, 8), cor = if token.criatura then T.barras.baixa else T.barras.cheia })
		local marcas = P.novo("Frame", raiz, { Name = "Marcas", Position = UDim2.new(1, 6, 0, 18), Size = UDim2.fromOffset(120, 18), BackgroundTransparency = 1 })
		P.novo("UIListLayout", marcas, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 3) })
		local saltos = P.novo("Frame", raiz, { Name = "Saltos", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
		local item = { raiz = raiz, nome = nome, vez = vez, barra = barra, marcas = marcas, saltos = saltos, assinatura = "", fim = nil, entrou = false }
		itens[id] = item
		return item
	end

	-- Número grande que salta do alvo: sobe com "pop" (Back) e some.
	-- HAB8: o tamanho cresce com o estrago (fração da vida máxima); golpe que tira 1/3 da vida sai bem maior
	local function saltar(item, valor: number, cura: boolean, pvMax: number?)
		local fracao = math.clamp(math.abs(valor) / math.max(pvMax or 20, 1), 0, 1)
		local tamanho = math.floor(36 + 28 * math.min(1, fracao * 3))
		local l = P.novo("TextLabel", item.saltos, {
			Name = "Salto", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, 20), Size = UDim2.fromOffset(160, tamanho + 8),
			BackgroundTransparency = 1, Text = (if cura then "+" else "") .. tostring(math.abs(valor)),
			FontFace = T.fontes.numero, TextSize = tamanho, TextColor3 = if cura then T.barras.cheia else Color3.fromRGB(255, 226, 170),
			TextStrokeColor3 = if cura then P.cor.trilho else T.barras.baixa:Lerp(P.cor.trilho, 0.55), TextStrokeTransparency = 0, ZIndex = 10,
		})
		local escala = P.novo("UIScale", l, { Scale = 0.3 })
		P.animar(escala, { Scale = 1.3 }, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), "pop")
		task.delay(0.16, function()
			if l.Parent then P.animar(escala, { Scale = 1 }, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), "assenta") end
		end)
		P.animar(l, { Position = UDim2.new(0.5, (math.random() - 0.5) * 36, 0, -34) }, TweenInfo.new(DURACAO_SALTO, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), "sobe")
		task.delay(0.55, function()
			if l.Parent then
				P.animar(l, { TextTransparency = 1, TextStrokeTransparency = 1 }, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), "some")
			end
		end)
		task.delay(DURACAO_SALTO + 0.05, function() if l.Parent then l:Destroy() end end)
	end

	local function marcarBillboards(esconder: boolean)
		if esconder == escondidos then return end
		escondidos = esconder
		for _, d in workspace:GetDescendants() do
			if d:IsA("BillboardGui") and d:FindFirstChild("BarraPV") then d.Enabled = not esconder end
		end
	end

	RunService.RenderStepped:Connect(function()
		local snap = state.snapshot()
		if not snap or not snap.combat.active then
			if next(itens) then
				for id, item in itens do item.raiz:Destroy(); itens[id] = nil end
				table.clear(ultimoPv)
			end
			marcarBillboards(false)
			ultimaContagem = -1
			return
		end
		if #snap.tokens ~= ultimaContagem then
			ultimaContagem = #snap.tokens
			escondidos = false -- token novo pode ter trazido um billboard novo
		end
		marcarBillboards(true)
		local cam = workspace.CurrentCamera
		local selecionado = state.selectedToken()
		local vistos = {}
		local agora = os.clock()
		for _, t0 in snap.tokens do
			local t = Feedback.visto(t0) -- ANIM3: barra e número esperam o impacto do golpe
			local caido = t.derrotado or (t.pv ~= nil and t.pv <= 0)
			if not t.hidden and t.x and t.z and t.pv ~= nil and (t.pvMax or 0) > 0 then
				local item = itens[t.id]
				local anterior = ultimoPv[t.id]
				-- um token que acabou de cair ainda mostra o último golpe por um instante
				if caido and item and not item.fim and anterior and anterior > t.pv then
					item.fim = agora + DURACAO_SALTO + 0.1
				end
				if not caido or (item and item.fim and agora < item.fim) then
					local p, visivel = cam:WorldToViewportPoint(Protocol.cellCenter(t.x, t.z) + Vector3.new(0, 6.2, 0))
					item = item or criar(t.id, t)
					vistos[t.id] = true
					item.raiz.Visible = visivel and p.Z > 0
					if item.raiz.Visible then
						item.px, item.py = p.X, p.Y
						item.barra.definir(t.pv, t.pvMax, not item.entrou)
						if not item.entrou then
							item.entrou = true
							local escala = P.novo("UIScale", item.raiz, { Scale = 0.7 })
							P.animar(escala, { Scale = 1 }, P.ENTRADA, "entrada")
						end
						if anterior and anterior ~= t.pv then
							saltar(item, t.pv - anterior, t.pv > anterior, t.pvMax)
						end
						local daVez = snap.combat.turnId == t.id
						local mostrarNome = t.criatura or daVez or selecionado == t.id
						item.nome.Visible = mostrarNome and not caido
						if mostrarNome then
							item.nome.Text = t.name
							item.nome.TextColor3 = if daVez then P.cor.ouroVivo else P.cor.texto
						end
						item.vez.Visible = daVez and not caido
						item.barra.raiz.Visible = not caido
						item.barra.raiz.Contorno.Color = if t.criatura then P.cor.inimigo else P.cor.ouro
						local ids = {}
						for _, c in t.conditions or {} do table.insert(ids, c.id) end
						local assinatura = table.concat(ids, "|")
						if assinatura ~= item.assinatura then
							item.assinatura = assinatura
							for _, f in item.marcas:GetChildren() do if f:IsA("TextLabel") then f:Destroy() end end
							for i, cid in ids do
								if i > 3 then break end
								local chip = P.novo("TextLabel", nil, {
									Name = "Marca", Text = Barras.marca(cid), AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 18),
									BackgroundColor3 = P.cor.fundo, BackgroundTransparency = 0.15, TextColor3 = P.cor.texto, FontFace = T.fontes.rotulo,
									TextSize = 14, LayoutOrder = i,
								})
								P.novo("UICorner", chip, { CornerRadius = UDim.new(0, 4) })
								P.novo("UIStroke", chip, { Color = P.cor.ouro, Thickness = 1, Transparency = 0.5 })
								P.novo("UIPadding", chip, { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) })
								chip.Parent = item.marcas
							end
						end
					end
				end
			end
			if t.pv ~= nil then ultimoPv[t.id] = t.pv end
		end
		for id, item in itens do
			if not vistos[id] then item.raiz:Destroy(); itens[id] = nil end
		end
		Barras.separar(itens)
	end)
	return gui
end

return Barras
