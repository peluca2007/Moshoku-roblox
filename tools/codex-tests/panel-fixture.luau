-- Simula callbacks, permissões, abas, medidas declaradas e destinos de tweens.
-- Não verifica render, fontes reais ou duração real no Roblox.
local objects, tweens = {}, {}
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, fn) table.insert(callbacks, fn) end,
		Fire = function(_, ...) for _, fn in callbacks do fn(...) end end,
	}
end
local function object(class)
	local data = {
		ClassName = class, Visible = true, AbsoluteCanvasSize = { X = 500, Y = 500 },
		AbsoluteSize = { X = 300, Y = 190 }, events = {},
		Activated = signal(), MouseEnter = signal(), MouseLeave = signal(),
		InputBegan = signal(), InputEnded = signal(),
	}
	local result = {}
	setmetatable(result, {
		__index = function(_, key)
			if key == "GetPropertyChangedSignal" then
				return function(_, property)
					if not data.events[property] then data.events[property] = signal() end
					return data.events[property]
				end
			end
			if key == "WaitForChild" then return function(_, name) return data[name] end end
			if key == "IsA" then
				return function(_, name)
					return name == class or (name == "GuiObject" and table.find({
						"Frame", "ScrollingFrame", "TextLabel", "TextButton", "TextBox",
					}, class) ~= nil)
				end
			end
			if key == "Destroy" then
				return function()
					data.destroyed, data.Parent = true, nil
					for _, child in objects do
						if child.Parent == result then child:Destroy() end
					end
				end
			end
			return data[key]
		end,
		__newindex = function(_, key, value)
			local changed = data[key] ~= value
			data[key] = value
			if changed and data.events[key] then data.events[key]:Fire() end
		end,
	})
	table.insert(objects, result)
	return result
end

local Instance = { new = object }
local UDim = { new = function(scale, offset) return { Scale = scale, Offset = offset } end }
local UDim2 = {
	new = function(xs, xo, ys, yo)
		return { X = { Scale = xs or 0, Offset = xo or 0 }, Y = { Scale = ys or 0, Offset = yo or 0 } }
	end,
}
UDim2.fromScale = function(x, y) return UDim2.new(x, 0, y, 0) end
UDim2.fromOffset = function(x, y) return UDim2.new(0, x, 0, y) end
local Vector2 = { new = function(x, y) return { X = x, Y = y } end }
local Color3 = {}
local function color(r, g, b)
	return {
		R = r, G = g, B = b,
		Lerp = function(self, other, amount)
			return color(
				self.R + (other.R - self.R) * amount,
				self.G + (other.G - self.G) * amount,
				self.B + (other.B - self.B) * amount
			)
		end,
	}
end
Color3.fromRGB = function(r, g, b) return color(r / 255, g / 255, b / 255) end
local Font = { fromName = function(name, weight) return { Name = name, Weight = weight } end }
local Enum = setmetatable({}, {
	__index = function(self, key)
		local values = setmetatable({}, { __index = function(_, name) return key .. "." .. name end })
		rawset(self, key, values)
		return values
	end,
})
local TweenInfo = { new = function(duration, style, direction)
	return { duration = duration, style = style, direction = direction }
end }
local tweenService = {
	Create = function(_, target, info, goals)
		local record = { target = target, info = info, goals = goals, cancelled = false }
		table.insert(tweens, record)
		return {
			Cancel = function() record.cancelled = true end,
			Play = function()
				record.played = true
				-- Nenhum Completed: comandos devem funcionar sem esperar animações.
				for key, value in goals do target[key] = value end
			end,
		}
	end,
}
local task = { defer = function(fn) fn() end }
local fixtureClock = 0
local realOs = os
local os = { clock = function() return fixtureClock end, date = realOs.date }
local camera = object("Camera")
camera.ViewportSize = { X = 360, Y = 740 }
local workspace = { CurrentCamera = camera }
local localPlayer = object("Player")
localPlayer.UserId, localPlayer.PlayerGui = 10, object("PlayerGui")

local catalog = {
	LISTA = {
		{ id = "agarrado", nome = "Agarrado", efeito = "Efeito de Agarrado.", acumulavel = false },
		{ id = "amedrontado", nome = "Amedrontado", efeito = "Efeito de Amedrontado.", acumulavel = false },
		{ id = "dose", nome = "Dose", efeito = "Efeito de Dose.", duracao = "Até o fim do combate", acumulavel = true, teto = 3 },
		{ id = "atordoado", nome = "Atordoado", efeito = "Efeito de Atordoado.", acumulavel = false },
		{ id = "caido", nome = "Caído", efeito = "Efeito de Caído.", duracao = "Até se levantar", acumulavel = false },
		{ id = "cego", nome = "Cego", efeito = "Efeito de Cego.", acumulavel = false },
		{ id = "envenenado", nome = "Envenenado", efeito = "Efeito de Envenenado.", acumulavel = false },
		{ id = "conjurando", nome = "Conjurando", efeito = "Efeito de Conjurando.", acumulavel = false, regra = true },
	},
	POR_ID = {}, TETO_PADRAO = 12,
}
for index = 1, 20 do
	table.insert(catalog.LISTA, {
		id = "teste-" .. index, nome = "Condição de teste " .. index,
		efeito = "Referência " .. index, acumulavel = false,
	})
end
for _, entry in catalog.LISTA do catalog.POR_ID[entry.id] = entry end
local rulesStub = {
	labels = function(list, suppliedCatalog)
		assert(suppliedCatalog == catalog)
		local result = {}
		for _, item in list do
			local entry = suppliedCatalog.POR_ID[item.id]
			table.insert(result, entry.nome .. (if entry.acumulavel then " ×" .. item.stacks else ""))
		end
		return result
	end,
}
local shared = object("Folder")
shared.Condicoes, shared.CondicaoRules = "catalog", "rules"
shared.Livro = object("Folder")
shared.Livro.Catalogo = "book"
shared.Estilo = "estilo"
-- Os mesmos tokens de src/shared/Estilo.luau (estética Livro Noite), em RGB.
local function rgb(hex)
	return Color3.fromRGB(tonumber(string.sub(hex, 2, 3), 16), tonumber(string.sub(hex, 4, 5), 16), tonumber(string.sub(hex, 6, 7), 16))
end
local estiloStub = {
	PAPEL = rgb("#141418"), PAPEL_2 = rgb("#1e1e24"), TINTA = rgb("#e8e3d9"), TINTA_SUAVE = rgb("#aca79d"),
	BOTAO = rgb("#26262e"), FIO_COR = rgb("#3a3a44"), PERIGO_FUNDO = rgb("#663235"),
	DESTAQUE = rgb("#b197fc"), DESTAQUE_FUNDO = rgb("#5b4a9c"), PERIGO = rgb("#ff6b6b"),
	ALERTA = rgb("#ffd43b"), SUCESSO = rgb("#38d9a9"),
	GRITO = Font.fromName("Oswald"), ROTULO = Font.fromName("RobotoCondensed"),
	ROTULO_FORTE = Font.fromName("RobotoCondensed"), CORPO = Font.fromName("Merriweather"),
	ELEGANTE = Font.fromName("Merriweather"),
}
local script = { Parent = { FichaDetalhe = "details" } }
local detailRender, detailDestroyed = nil, 0
local detailStub = { montar = function(_, ficha)
	detailRender = ficha
	return {
		atualizar = function(nextFicha) detailRender = nextFicha end,
		destruir = function() detailRender = nil; detailDestroyed += 1 end,
	}
end }
local storage = object("ReplicatedStorage")
storage.Shared = shared
local game = {
	GetService = function(_, name)
		if name == "Players" then return { LocalPlayer = localPlayer } end
		if name == "TweenService" then return tweenService end
		assert(name == "ReplicatedStorage", name)
		return storage
	end,
}
local require = function(module)
	if module == "catalog" then return catalog end
	if module == "book" then return {} end
	if module == "details" then return detailStub end
	if module == "estilo" then return estiloStub end
	assert(module == "rules", tostring(module))
	return rulesStub
end

local callbacks, sent = {}, {}
local token = {
	id = "t1", name = "Hero", pv = 10, pvMax = 20, mana = 4, manaMax = 8,
	kind = "jogador", ownerUserId = 10, color = Color3.fromRGB(70, 120, 200),
	hidden = false, showStats = true, conditions = {},
}
local snapshot = {
	you = { master = true }, tokens = { token }, players = { { userId = 10, name = "Pedro" } },
	combat = { active = true, round = 1, turn = 7, turnId = "t1" },
	campaign = { status = "livre", dirty = false }, map = { terrain = {}, fog = {} },
}
local selected, view, brush = nil, false, nil
local selectedX, selectedZ = 3, 4
local state = {}
state.snapshot = function() return snapshot end
state.isMaster = function() return snapshot.you.master end
state.localUserId = function() return 10 end
state.findToken = function(id)
	for _, item in snapshot.tokens do if item.id == id then return item end end
	return nil
end
state.canControl = function(item) return state.isMaster() or item.ownerUserId == 10 end
state.selectedToken = function() return selected end
state.selectedCell = function() return selectedX, selectedZ end
state.selectToken = function(id)
	selected, selectedX, selectedZ = id, nil, nil
	if callbacks.selection then callbacks.selection(id) end
end
state.tableView = function() return view end
state.setTableView = function(value) view = value; callbacks.tableView(value) end
state.brush = function() return brush end
state.setBrush = function(value)
	if brush ~= value then brush = value; if callbacks.brush then callbacks.brush(value) end end
end
state.send = function(command, payload) table.insert(sent, { command = command, payload = payload }) end
-- Ficha v2: mesma detecção do MesaState; o envio em partes fica registrado.
local v2Sends = {}
state.ehFichaV2 = function(text)
	local body = string.match(text, "^%s*(.-)%s*$")
	return string.sub(body, 1, 1) == "{" and string.find(body, '"mesa":2', 1, true) ~= nil
end
state.enviarFichaV2 = function(text, options, progress)
	table.insert(v2Sends, { text = text, options = options })
	progress("Ficha recebida: confira a proposta p1 e aprove.", true, false)
end
state.onSnapshot = function(fn) callbacks.snapshot = fn; fn(snapshot) end
state.onLog = function(fn) callbacks.log = fn end
state.onSelection = function(fn) callbacks.selection = fn end
state.onTableView = function(fn) callbacks.tableView = fn end
state.onBrush = function(fn) callbacks.brush = fn end
state.onRoll = function(fn) callbacks.roll = fn end
local detailFixture = nil
state.fichaDetalhe = function() return detailFixture end
state.onFichaDetalhe = function(fn) callbacks.fichaDetalhe = fn end

local MesaPanel = (function()
-- PANEL_SOURCE
end)()
MesaPanel.start(state)

local function findProperty(class, property, value)
	for _, item in objects do
		if not item.destroyed and item.ClassName == class and item[property] == value then return item end
	end
	error("Objeto não encontrado: " .. class .. " / " .. property .. " / " .. tostring(value))
end
local function text(class, value) return findProperty(class, "Text", value) end
local function named(class, value) return findProperty(class, "Name", value) end
local function shown(item)
	while item do
		if item.destroyed or (item:IsA("GuiObject") and not item.Visible) then return false end
		item = item.Parent
	end
	return true
end
local function press(value)
	local item = text("TextButton", value)
	assert(shown(item), "Clique em botão de aba fechada: " .. value)
	item.Activated:Fire()
end
local function pressNamed(value)
	local item = named("TextButton", value)
	assert(shown(item), "Clique em botão escondido: " .. value)
	item.Activated:Fire()
end
local function force(value) text("TextButton", value).Activated:Fire() end
local function forceNamed(value) named("TextButton", value).Activated:Fire() end
local function last(command)
	local request = sent[#sent]
	assert(request and request.command == command, command)
	return request.payload
end
local function deliverCampaign(campaign)
	local nextSnapshot = {}
	for key, value in snapshot do nextSnapshot[key] = value end
	nextSnapshot.campaign = campaign
	snapshot = nextSnapshot
	callbacks.snapshot(snapshot)
end
local function visibleChoices()
	local result = {}
	for _, entry in catalog.LISTA do
		if named("TextButton", "ConditionChoice_" .. entry.id).Visible then table.insert(result, entry.id) end
	end
	return result
end
local function logCount()
	local count = 0
	for _, item in objects do
		if not item.destroyed and item.ClassName == "TextLabel"
			and item.Parent == named("ScrollingFrame", "MesaLog") then count += 1 end
	end
	return count
end
local function sameColor(actual, r, g, b)
	return math.abs(actual.R - r / 255) < 1e-9
		and math.abs(actual.G - g / 255) < 1e-9
		and math.abs(actual.B - b / 255) < 1e-9
end

-- M6/V1: hierarquia independente dos textos posteriores de confirmação.
assert(sameColor(text("TextButton", "Rolar").BackgroundColor3, 91, 74, 156))
assert(sameColor(text("TextButton", "Rolar").TextColor3, 232, 227, 217))
for _, title in { "d4", "d20", "Modo: Normal", "Rolagem pública", "Visão da mesa (M)" } do
	assert(sameColor(text("TextButton", title).BackgroundColor3, 38, 38, 46))
end
for _, title in { "Enviar ficha ao servidor", "Importar na casa selecionada" } do
	assert(sameColor(text("TextButton", title).BackgroundColor3, 91, 74, 156))
end
for _, title in { "Remover ficha selecionada…", "Limpar mesa", "Cobrir tudo com névoa", "Salvar mesmo assim" } do
	assert(sameColor(text("TextButton", title).BackgroundColor3, 102, 50, 53))
end

-- M6/V2: Mesa fixa, fileira única, fórmula com Rolar e Registro flexível.
local mesa = named("Frame", "Page_Mesa")
local root = named("Frame", "PanelRoot")
local controls = named("ScrollingFrame", "MesaControls")
local history = named("Frame", "HistorySection")
local quick = named("ScrollingFrame", "DiceChoices")
local log = named("ScrollingFrame", "MesaLog")
assert(mesa.Visible and not named("Frame", "Page_Ficha").Visible)
assert(root.AnchorPoint.X == 0.5 and root.AnchorPoint.Y == 1)
assert(root.Position.Y.Scale == 1 and root.Position.Y.Offset == -8)
assert(root.Size.X.Offset == 344)
assert(not controls.ScrollingEnabled and controls.Size.Y.Offset == 232)
assert(history.Size.Y.Scale == 1 and history.Position.Y.Offset == 238)
assert(root.Size.Y.Offset - 166 - history.Position.Y.Offset > 200)
assert(log.Size.Y.Scale == 1)
assert(quick.ScrollingDirection == Enum.ScrollingDirection.X)
for _, sides in { 4, 6, 8, 10, 12, 20, 100 } do
	local item = text("TextButton", "d" .. sides)
	assert(item.Parent == quick and item.Size.X.Offset >= 44 and item.Size.Y.Offset == 44)
end
assert(text("TextButton", "Rolar").Parent == named("TextBox", "DiceFormula").Parent)
assert(text("TextButton", "Modo: Normal").Parent == text("TextButton", "Rolagem pública").Parent)

-- Abas, fonte e intenção imediata durante hover/press.
assert(not shown(text("TextButton", "PV -5")))
press("Mestre"); assert(shown(text("TextButton", "Nova ficha")))
press("Campanha"); assert(shown(text("TextButton", "Salvar")))
press("Ficha"); assert(named("Frame", "Page_Ficha").Visible)
press("Mesa"); assert(not shown(text("TextButton", "Nova ficha")))
local rollButton = text("TextButton", "Rolar")
assert(rollButton.FontFace.Name == "RobotoCondensed")
assert(text("TextLabel", "Dados").FontFace.Name == "Oswald")
local count = #sent
rollButton.MouseEnter:Fire()
rollButton.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1 })
rollButton.Activated:Fire()
assert(#sent == count + 1 and last("roll").formula == "1d20")
rollButton.InputEnded:Fire({ UserInputType = Enum.UserInputType.MouseButton1 })
rollButton.MouseLeave:Fire()
assert(sameColor(rollButton.BackgroundColor3, 91, 74, 156))

-- roll não cria nem altera linhas do histórico.
assert(not named("Frame", "LastRoll").Visible)
count = #sent
local beforeLogs = logCount()
callbacks.roll({ by = "Pedro", text = "1d20: [20] → 20", total = 20, critical = "sucesso", secret = false })
assert(#sent == count and logCount() == beforeLogs)
assert(named("TextLabel", "LastRollTotal").Text == "20 • Crítico")
assert(named("TextLabel", "LastRollTotal").FontFace.Name == "Oswald")
assert(sameColor(named("TextLabel", "LastRollTotal").TextColor3, 177, 151, 252))
assert(log.Position.Y.Offset == 114 and log.Size.Y.Scale == 1)
assert(root.Size.Y.Offset - 166 - history.Position.Y.Offset - 122 >= 90)
callbacks.log({ text = "Pedro rolou 1d20: [20] → 20", tone = "publica" })
assert(logCount() == beforeLogs + 1)
callbacks.roll({ by = "Pedro", label = "Iniciativa", text = "1d20: [1] → 1", total = 1, critical = "falha", secret = true })
assert(named("TextLabel", "LastRollTotal").Text == "1 • Falha")
assert(named("TextLabel", "LastRollTitle").Text == "Pedro • Iniciativa • secreta")
assert(sameColor(named("Frame", "LastRoll").BackgroundColor3, 102, 50, 53))
callbacks.roll({ by = "Pedro", text = "1d6: [4] → 4", total = 4, secret = false })
assert(named("TextLabel", "LastRollTotal").Text == "4")
assert(sameColor(named("Frame", "LastRoll").BackgroundColor3, 20, 20, 24))

-- Rolador, criação, rascunho, ajustes e turno.
press("Visão da mesa (M)"); assert(view)
press("Modo: Normal"); press("Rolagem pública"); press("Rolar")
local payload = last("roll")
assert(payload.mode == "vantagem" and payload.visibility == "mestre" and payload.formula == "1d20")
press("Mestre"); press("Enviar ficha ao servidor")
payload = last("createToken")
assert(payload.x == 3 and payload.z == 4 and payload.pv == nil)
state.selectToken("t1")
press("Editar seleção")
local nameBox = text("TextBox", "Hero")
nameBox.Text = "Hero renomeado"
press("Mesa"); press("Mestre")
callbacks.snapshot(snapshot)
assert(nameBox.Text == "Hero renomeado")
press("Enviar ficha ao servidor")
payload = last("updateToken")
assert(payload.id == "t1" and payload.name == "Hero renomeado" and payload.pv == nil)
press("Ficha"); press("PV +1")
assert(last("adjust").delta == 1)
press("Encerrar meu turno")
assert(last("nextTurn").expectedId == "t1" and last("nextTurn").expectedTurn == 7)
press("Mestre"); press("Próximo turno")
assert(last("nextTurn").expectedTurn == 7)
count = #sent
press("Remover ficha selecionada…"); assert(#sent == count)
assert(sameColor(text("TextButton", "Confirmar remoção: Hero").BackgroundColor3, 102, 50, 53))
press("Confirmar remoção: Hero"); assert(last("removeToken").id == "t1")
press("Iniciar / reiniciar o combate")
assert(last("combatStart").entries[1].id == "t1")
press("Encerrar combate"); assert(sent[#sent].command == "combatEnd")

-- M2: destinos, confirmações, expiração, conflitos e estados ocupados.
press("Campanha")
for slot = 1, 5 do
	press("Salvar"); assert(last("campaignSave").slot == slot)
	press("Espaço: " .. slot .. " / 5")
end
count = #sent
press("Carregar"); assert(#sent == count)
token.pv = 9
callbacks.snapshot(snapshot)
press("Confirmar carregar espaço 1"); assert(last("campaignLoad").slot == 1)
press("Carregar")
fixtureClock += 5
count = #sent
press("Confirmar carregar espaço 1"); assert(#sent == count)
press("Cancelar confirmação")
press("Carregar"); press("Espaço: 1 / 5"); press("Carregar")
assert(text("TextButton", "Confirmar carregar espaço 2"))
press("Cancelar confirmação")
count = #sent
press("Limpar mesa"); assert(#sent == count)
press("Confirmar limpar mesa")
assert(sent[#sent].command == "tableClear" and sent[#sent].payload == nil)
local savedAt = 1700000000
deliverCampaign({ status = "ok", slot = 3, revision = 4, savedAt = savedAt, dirty = true })
assert(text("TextLabel", "ok • espaço atual 3 • revisão 4 • salvo às "
	.. os.date("%H:%M", savedAt) .. " • alterações não salvas"))
deliverCampaign({ status = "conflito", slot = 3, revision = 4, dirty = true })
press("Espaço: 3 / 5"); press("Salvar mesmo assim")
assert(last("campaignSave").slot == 3 and last("campaignSave").force)
for _, status in { "salvando", "carregando" } do
	deliverCampaign({ status = "ok", slot = 3 })
	press("Carregar")
	deliverCampaign({ status = status, slot = 3 })
	assert(text("TextButton", "Carregar"))
	count = #sent
	press("Salvar"); press("Carregar"); press("Limpar mesa"); force("Salvar mesmo assim")
	assert(#sent == count)
end
deliverCampaign({ status = "ok", slot = 3 })

-- M3: texto integral, dono, posição e atributos importados.
press("Mestre")
local codeBox = named("TextBox", "FichaImportCode")
count = #sent
press("Importar na casa selecionada"); assert(#sent == count)
codeBox.Text = string.rep("x", 1001)
press("Atualizar ficha selecionada")
payload = last("importToken")
assert(#payload.code == 1001 and payload.id == "t1" and payload.ownerUserId == nil)
state.selectToken(nil)
selectedX, selectedZ = 3, 4
press("Importar na casa selecionada")
payload = last("importToken")
assert(payload.ownerUserId == 10 and payload.x == 3 and payload.z == 4 and payload.id == nil)
press("Dono: Pedro")
selectedX, selectedZ = nil, nil
press("Importar na casa selecionada")
assert(last("importToken").ownerUserId == 0 and last("importToken").x == nil)
press("Dono: sem dono")

-- Ficha v2: vai em partes (MesaState) e não usa importToken; política de sessão no atualizar.
count = #sent
codeBox.Text = '  {"mesa":2,"envelopeVersion":2}  '
selectedX, selectedZ = 2, 5
press("Importar na casa selecionada")
assert(#sent == count and #v2Sends == 1)
assert(v2Sends[1].options.x == 2 and v2Sends[1].options.z == 5 and v2Sends[1].options.targetId == nil)
assert(named("TextLabel", "FichaImportStatus").Visible)
state.selectToken("t1")
press("Atualizar ficha selecionada")
assert(v2Sends[2].options.targetId == "t1" and v2Sends[2].options.sessionPolicy == "preserve")
press("Ao atualizar: manter PV, mana e condições da mesa")
press("Atualizar ficha selecionada")
assert(v2Sends[3].options.sessionPolicy == "replace")
press("Ao atualizar: usar PV, mana e condições do site")
assert(#sent == count)
selectedX, selectedZ = nil, nil

-- Propostas: cartão com o resumo; aprovar e recusar mandam o id e a versão.
snapshot.fichaPropostas = { {
	id = "p1", version = 1, name = "Aria", sessionPolicy = "replace", venceEm = 590,
	avisos = { "Site: Inventário por valor" },
	resumo = {
		pv = 22, pm = 12, pt = 0, pp = 0, ca = 11, iniciativa = 1, vantagemIniciativa = false,
		deslocamento = 7.5, atributos = { forca = 0, agilidade = 1, vigor = 0, intelecto = 3, espirito = 0 },
		atuais = { pv = 20, pm = 12, pt = 0, pp = 0 }, compras = 2, ranks = 1, inventario = 1, condicoes = 1, completa = true,
	},
} }
callbacks.snapshot(snapshot)
assert(named("Frame", "Proposta_p1"))
pressNamed("Aprovar_p1")
assert(last("fichaImportApply").proposalId == "p1" and last("fichaImportApply").version == 1)
pressNamed("Recusar_p1")
assert(last("fichaImportReject").proposalId == "p1")
snapshot.fichaPropostas = nil
callbacks.snapshot(snapshot)
assert(not pcall(named, "Frame", "Proposta_p1"))
state.selectToken("t1")
token.sheet = {
	forca = 1, agilidade = 3, vigor = 2, intelecto = 0, espirito = 4,
	ca = 13, deslocamento = 9.1, iniciativa = 3, vantagemIniciativa = true,
}
callbacks.snapshot(snapshot)
press("Ficha")
local sheetLabel = named("TextLabel", "SelectedSheet")
assert(sheetLabel.Text == "FOR +1 • AGI +3 • VIG +2 • INT +0 • ESP +4\nCA 13 • Deslocamento 9,1 m\nIniciativa +3 • vantagem")
token.sheet.deslocamento, token.sheet.vantagemIniciativa = 9, false
callbacks.snapshot(snapshot)
assert(string.find(sheetLabel.Text, "Deslocamento 9 m", 1, true))
assert(not string.find(sheetLabel.Text, "vantagem", 1, true))
local secondToken = {
	id = "t2", name = "NPC", ownerUserId = 0, kind = "npc",
	pv = 5, pvMax = 5, mana = 0, manaMax = 0,
	color = Color3.fromRGB(185, 74, 70), conditions = {},
}
snapshot.tokens = { secondToken, token }
callbacks.snapshot(snapshot)
press("Mestre")
text("TextBox", "0").Text = "inválido"
press("Rolar iniciativa")
payload = last("rollInitiative")
assert(payload.ids[1] == "t2" and payload.ids[2] == "t1")
press("✓ NPC"); press("Rolar iniciativa"); assert(#last("rollInitiative").ids == 1)
press("✓ Hero")
count = #sent
press("Rolar iniciativa"); assert(#sent == count)
press("— Hero")
snapshot.tokens = { token }
callbacks.snapshot(snapshot)

-- R1: sugestões, busca limitada, acentos e busca literal.
press("Ficha")
local conditionSection = named("Frame", "ConditionsSection")
assert(conditionSection.Visible)
local search, hint = named("TextBox", "ConditionSearch"), named("TextLabel", "ConditionSearchHint")
local suggestions = visibleChoices()
local expected = { "agarrado", "amedrontado", "atordoado", "caido", "cego", "envenenado" }
assert(#suggestions == 6)
for index, id in expected do assert(suggestions[index] == id) end
assert(not named("TextButton", "ConditionChoice_conjurando").Visible)
assert(not named("TextButton", "ConditionChoice_dose").Visible)
assert(string.find(hint.Text, "Digite para buscar", 1, true))
search.Text = "Condição"
local results = visibleChoices()
assert(#results == 8)
for index = 1, 8 do assert(results[index] == "teste-" .. index) end
assert(hint.Text == "20 resultados; mostrando 8. Refine a busca.")
press("Mesa"); press("Ficha")
callbacks.snapshot(snapshot)
assert(search.Text == "Condição" and #visibleChoices() == 8)
search.Text = "  CAÍDO  "
results = visibleChoices()
assert(#results == 1 and results[1] == "caido")
assert(hint.Text == "1 resultado(s).")
search.Text = "["
assert(#visibleChoices() == 0 and string.find(hint.Text, "Nenhuma condição", 1, true))
search.Text = "   "; assert(#visibleChoices() == 6)
count = #sent
forceNamed("ConditionChoice_dose"); pressNamed("ConditionAdd"); assert(#sent == count)

-- M5: referência, nota, acúmulos, remoção e callback antigo.
search.Text = "Dose"
pressNamed("ConditionChoice_dose")
assert(named("TextLabel", "ConditionDetails").Text == "Dose\nEfeito de Dose.\nDuração: Até o fim do combate")
local noteBox = named("TextBox", "ConditionNote")
noteBox.Text = "Até purgar"
press("Mestre"); press("Ficha")
callbacks.snapshot(snapshot)
assert(noteBox.Text == "Até purgar")
pressNamed("ConditionAdd")
payload = last("conditionAdd")
assert(payload.id == "t1" and payload.condition == "dose" and payload.note == "Até purgar" and payload.stacks == nil)
noteBox.Text = ""
pressNamed("ConditionAdd"); assert(last("conditionAdd").note == nil)
search.Text = "conjur"
pressNamed("ConditionChoice_conjurando")
assert(string.find(named("TextLabel", "ConditionDetails").Text, "Não especificada", 1, true))
token.conditions = { { id = "caido", stacks = 1, note = "Depois" }, { id = "dose", stacks = 2 } }
callbacks.snapshot(snapshot)
assert(named("TextLabel", "ConditionLabel_caido").Text == "Caído\nNota: Depois")
assert(named("TextLabel", "ConditionLabel_dose").Text == "Dose ×2")
pressNamed("ConditionPlus_dose")
payload = last("conditionAdd")
assert(payload.condition == "dose" and payload.stacks == 1 and payload.note == nil)
pressNamed("ConditionMinus_dose")
assert(last("conditionRemove").condition == "dose" and last("conditionRemove").stacks == 1)
local staleRemove = named("TextButton", "ConditionRemove_dose")
pressNamed("ConditionRemove_caido")
assert(last("conditionRemove").condition == "caido" and last("conditionRemove").stacks == nil)
state.selectToken(nil)
count = #sent
staleRemove.Activated:Fire(); assert(#sent == count)
state.selectToken("t1"); assert(noteBox.Text == "")

-- M4: pincéis, estado externo e confirmação de névoa.
press("Mestre")
for _, item in {
	{ "parede", "Parede" }, { "dificil", "Terreno difícil" }, { "agua", "Água" },
	{ "limpar", "Apagar terreno" }, { "nevoa", "Névoa" }, { "revelar", "Revelar" },
} do
	pressNamed("Brush_" .. item[1]); assert(brush == item[1])
	assert(named("TextLabel", "BrushInfo").Text == "Pincel: " .. item[2])
	pressNamed("Brush_" .. item[1]); assert(brush == nil)
end
state.setBrush("agua")
assert(named("TextButton", "Brush_agua").Text == "✓ Água")
named("TextButton", "Brush_agua").MouseEnter:Fire()
named("TextButton", "Brush_agua").MouseLeave:Fire()
assert(sameColor(named("TextButton", "Brush_agua").BackgroundColor3, 177, 151, 252))
state.setBrush(nil)
count = #sent
press("Cobrir tudo com névoa"); assert(#sent == count)
callbacks.snapshot(snapshot)
press("Confirmar cobrir tudo com névoa"); assert(last("fogAll").covered == true)
count = #sent
press("Revelar tudo")
fixtureClock += 5
press("Confirmar revelar tudo"); assert(#sent == count)
press("Confirmar revelar tudo"); assert(last("fogAll").covered == false)
press("Cobrir tudo com névoa"); press("Revelar tudo")
assert(text("TextButton", "Cobrir tudo com névoa"))
press("Cancelar confirmação da névoa"); assert(text("TextButton", "Revelar tudo"))

-- Carregamento bloqueia; salvamento permite mutações.
press("Cobrir tudo com névoa")
deliverCampaign({ status = "carregando", slot = 3 })
assert(text("TextButton", "Cobrir tudo com névoa"))
count = #sent
press("Ficha"); pressNamed("ConditionRemove_dose"); pressNamed("ConditionPlus_dose")
press("Mestre"); press("Cobrir tudo com névoa"); pressNamed("Brush_parede")
press("Atualizar ficha selecionada"); press("Rolar iniciativa")
assert(#sent == count and brush == nil)
deliverCampaign({ status = "salvando", slot = 3 })
press("Ficha"); pressNamed("ConditionPlus_dose")
assert(last("conditionAdd").condition == "dose")
deliverCampaign({ status = "ok", slot = 3 })

-- Perder papel fecha abas administrativas e invalida confirmações.
press("Mestre")
state.setBrush("nevoa")
press("Cobrir tudo com névoa")
press("Campanha"); press("Carregar")
snapshot.you.master = false
callbacks.snapshot(snapshot)
assert(brush == nil and mesa.Visible)
assert(not shown(named("TextButton", "Tab_Mestre")) and not shown(named("TextButton", "Tab_Campanha")))
assert(text("TextButton", "Cobrir tudo com névoa") and text("TextButton", "Carregar"))
assert(text("TextLabel", "Ferramentas do mestre").Parent.Visible == false)
press("Ficha")
assert(conditionSection.Visible)
pressNamed("ConditionRemove_dose"); assert(last("conditionRemove").id == "t1")
count = #sent
forceNamed("Tab_Mestre"); forceNamed("Tab_Campanha")
assert(named("Frame", "Page_Ficha").Visible)
forceNamed("Brush_parede"); force("Cobrir tudo com névoa")
force("Atualizar ficha selecionada"); force("Rolar iniciativa")
assert(#sent == count and brush == nil)
snapshot.you.master = true
callbacks.snapshot(snapshot)
press("Mestre")
count = #sent
press("Cobrir tudo com névoa"); assert(#sent == count)
press("Cancelar confirmação da névoa")
press("Campanha"); press("Carregar"); assert(#sent == count)
press("Cancelar confirmação")

-- Outro jogador não pode administrar ficha ou campanha.
snapshot.you.master = false
token.ownerUserId, token.conditions, token.sheet = 99, { { id = "dose", stacks = 1 } }, nil
token.pv, token.pvMax, token.mana, token.manaMax = nil, nil, nil, nil
callbacks.snapshot(snapshot)
press("Ficha")
assert(not conditionSection.Visible and not sheetLabel.Visible and sheetLabel.Text == "")
assert(text("TextLabel", "Hero\nPV não revelados • Mana não revelada"))
count = #sent
search.Text = "dose"
forceNamed("ConditionChoice_dose"); forceNamed("ConditionAdd")
force("Salvar"); force("Carregar"); force("Limpar mesa"); force("Salvar mesmo assim")
assert(#sent == count)

-- Redimensionamento: Registro permanece separado da área de controles.
press("Recolher")
assert(text("TextButton", "Abrir") and not named("Frame", "TabContent").Visible)
assert(root.Size.Y.Offset == 54)
press("Abrir")
assert(named("Frame", "TabContent").Visible and named("Frame", "Page_Ficha").Visible)
camera.ViewportSize = { X = 1280, Y = 800 }
assert(root.AnchorPoint.X == 1 and root.AnchorPoint.Y == 0 and root.Size.X.Offset == 480)
assert(not controls.ScrollingEnabled)
for _, sides in { 4, 6, 8, 10, 12, 20, 100 } do
	assert(text("TextButton", "d" .. sides).Size.X.Offset > 44)
end
press("Mesa"); press("Ficha"); press("Mesa")
assert(mesa.Visible and not named("Frame", "Page_Ficha").Visible)
press("Recolher"); press("Abrir"); press("Recolher"); press("Abrir")
assert(named("Frame", "TabContent").Visible and root.Size.X.Offset == 480)
camera.ViewportSize = { X = 640, Y = 400 }
assert(controls.ScrollingEnabled)
assert(history.Position.Y.Offset < 238)
assert(root.Size.Y.Offset - 166 - history.Position.Y.Offset >= 120)
camera.ViewportSize = { X = 360, Y = 740 }
assert(root.AnchorPoint.Y == 1 and root.Size.X.Offset == 344 and not controls.ScrollingEnabled)

-- Log limitado, fades, decoração e LayoutOrder sem empates.
for index = 1, 55 do callbacks.log({ text = "log " .. index, tone = "publica" }) end
local countLogs, orders, corners, strokes = 0, {}, 0, 0
for _, item in objects do
	if item.destroyed then continue end
	if item.ClassName == "UICorner" then corners += 1 end
	if item.ClassName == "UIStroke" then strokes += 1 end
	if item.ClassName == "TextLabel" and string.match(item.Text or "", "^log %d+$") then
		countLogs += 1
		assert(item.TextTransparency == 0)
	end
	if item:IsA("GuiObject") then
		assert(type(item.LayoutOrder) == "number")
		if item.Parent then
			orders[item.Parent] = orders[item.Parent] or {}
			assert(not orders[item.Parent][item.LayoutOrder], "LayoutOrder repetido")
			orders[item.Parent][item.LayoutOrder] = true
		end
	end
	if item.ClassName == "TextButton" then
		assert(item.Size.Y.Offset >= 44 or item.Size.Y.Scale == 1, "Botão abaixo de 44 px")
	end
end
assert(countLogs == 50 and logCount() == 50 and corners > 0 and strokes > 0)
local fades = 0
for _, tween in tweens do
	if tween.goals.TextTransparency == 0 then fades += 1 end
	assert(tween.info.duration <= 0.2)
end
assert(fades >= 55)

-- Contraste normal, hover e pressão nas três hierarquias.
local function luminance(c)
	local function channel(value)
		return if value <= 0.04045 then value / 12.92 else ((value + 0.055) / 1.055) ^ 2.4
	end
	return channel(c.R) * 0.2126 + channel(c.G) * 0.7152 + channel(c.B) * 0.0722
end
local function contrast(a, b)
	local first, second = luminance(a), luminance(b)
	return (math.max(first, second) + 0.05) / (math.min(first, second) + 0.05)
end
for _, title in { "Rolar", "d20", "Limpar mesa" } do
	local item = text("TextButton", title)
	item.MouseEnter:Fire()
	assert(contrast(item.TextColor3, item.BackgroundColor3) >= 4.5)
	item.InputBegan:Fire({ UserInputType = Enum.UserInputType.Touch })
	assert(contrast(item.TextColor3, item.BackgroundColor3) >= 4.5)
	item.InputEnded:Fire({ UserInputType = Enum.UserInputType.Touch })
	item.MouseLeave:Fire()
end
for _, item in objects do
	if item.destroyed then continue end
	if item.ClassName == "TextButton" or item.ClassName == "TextBox" then
		assert(contrast(item.TextColor3, item.BackgroundColor3) >= 4.5, "Contraste de controle")
		if item.PlaceholderColor3 then
			assert(contrast(item.PlaceholderColor3, item.BackgroundColor3) >= 4.5, "Contraste de placeholder")
		end
	end
end
-- A ficha v2 é montada sob demanda e descartada ao perder acesso/seleção.
snapshot.you.master = true
snapshot.tokens = { token }
token.ficha2Versao = "1:2"
state.selectToken(token.id)
callbacks.snapshot(snapshot)
press("Ficha")
press("Abrir ficha completa")
assert(shown(named("TextLabel", "FichaDetalheStatus")))
detailFixture = { name = "Ficha recebida" }
callbacks.fichaDetalhe(token.id)
assert(detailRender == detailFixture)
assert(not shown(named("TextLabel", "FichaDetalheStatus")))
token.ficha2Versao = nil
callbacks.snapshot(snapshot)
assert(detailRender == nil and detailDestroyed > 0)
assert(not shown(named("Frame", "FichaCompleta")))
assert(shown(named("ScrollingFrame", "FichaControls")))
print("Painel: regressões M2/M3/M4/M5, M6 e integração F2 OK (APIs simuladas; sem render Roblox)")
