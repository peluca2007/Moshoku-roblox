-- Fixture CLI U2. Recebe fontes pelos placeholders no pipeline de testar.ps1.
-- Exercita callbacks e payloads com APIs simuladas; não testa render do Roblox.
local objects, requests, avisos, timers = {}, {}, {}, {}
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, fn) table.insert(callbacks, fn); return { Disconnect = function() end } end,
		Fire = function(_, ...) for _, fn in callbacks do fn(...) end end,
	}
end
local function object(class)
	local data = { ClassName = class, Visible = true, Enabled = true, Children = {}, Activated = signal(),
		OnClientEvent = signal(), Destroying = signal(), events = {} }
	if class == "UIListLayout" then data.AbsoluteContentSize = { X = 0, Y = 0 } end
	local result = {}
	local function attach(child, parent)
		if child.Parent and child.Parent.Children then
			for i, item in child.Parent.Children do if item == child then table.remove(child.Parent.Children, i); break end end
		end
		data.Parent = parent
		if parent and parent.Children then table.insert(parent.Children, child) end
	end
	setmetatable(result, {
		__index = function(_, key)
			if data[key] ~= nil then return data[key] end
			if key == "IsA" then return function(_, name) return name == class or name == "GuiObject" and table.find({ "Frame", "ScrollingFrame", "TextLabel", "TextButton", "TextBox" }, class) ~= nil end end
			if key == "WaitForChild" or key == "FindFirstChild" then return function(_, name)
				for _, child in data.Children do if child.Name == name then return child end end
				return nil
			end end
			if key == "FindFirstChildOfClass" then return function(_, wanted) for _, child in data.Children do if child.ClassName == wanted then return child end end end end
			if key == "GetChildren" then return function() return table.clone(data.Children) end end
			if key == "GetDescendants" then return function()
				local all = {}
				local function visit(parent) for _, child in parent.Children do table.insert(all, child); visit(child) end end
				visit(result); return all
			end end
			if key == "SetAttribute" then return function(_, name, value) data[name] = value end end
			if key == "GetAttribute" then return function(_, name) return data[name] end end
			if key == "GetAttributeChangedSignal" or key == "GetPropertyChangedSignal" then return function(_, name)
				data.events[name] = data.events[name] or signal(); return data.events[name]
			end end
			if key == "Destroy" then return function()
				data.Destroying:Fire(); data.destroyed = true
				if data.Parent and data.Parent.Children then
					for i, child in data.Parent.Children do if child == result then table.remove(data.Parent.Children, i); break end end
				end
				data.Parent = nil
			end end
			return data[key]
		end,
		__newindex = function(_, key, value)
			if key == "Parent" then attach(result, value) else
				local changed = data[key] ~= value; data[key] = value
				if changed and data.events[key] then data.events[key]:Fire() end
			end
		end,
	})
	table.insert(objects, result)
	return result
end

local Instance = { new = function(class, parent)
	local created = object(class)
	if parent then created.Parent = parent end
	return created
end }
local function dim(xs, xo, ys, yo) return { X = { Scale = xs or 0, Offset = xo or 0 }, Y = { Scale = ys or 0, Offset = yo or 0 } } end
local UDim2 = { new = dim, fromScale = function(x, y) return dim(x, 0, y, 0) end,
	fromOffset = function(x, y) return dim(0, x, 0, y) end }
local Vector2 = { new = function(x, y) return { X = x, Y = y } end }
local Enum = setmetatable({}, { __index = function(self, key)
	local group = setmetatable({}, { __index = function(_, item) return key .. "." .. item end })
	rawset(self, key, group); return group
end })
local function ensureSignal(obj, name)
	local value = obj[name]
	if value then return value end
	value = signal(); obj[name] = value; return value
end

local playerGui = object("PlayerGui"); playerGui.Name = "PlayerGui"
local player = object("Player"); player.PlayerGui = playerGui; player.UserId = 101
playerGui.Parent = player
local camera = object("Camera"); camera.ViewportSize = Vector2.new(1280, 720)
local workspace = object("Workspace"); workspace.CurrentCamera = camera
local runRemote = object("RemoteEvent")
runRemote.sent = {}
runRemote.FireServer = function(_, payload) table.insert(runRemote.sent, payload) end
local trainerRemote = object("RemoteEvent")
trainerRemote.sent = {}
trainerRemote.FireServer = function(_, payload) table.insert(trainerRemote.sent, payload) end
local replicated = object("ReplicatedStorage")
replicated.WaitForChild = function(_, name) return if name == "RunJogo" then runRemote elseif name == "TreinadorJogo" then trainerRemote else nil end
local catalog = {
	POR_ID = {
		["tree/fogo"] = { data = { name = "Magia de Fogo" } },
		["race/humano"] = { data = { name = "Humano" } },
	},
}
local historia = {
	OBJETIVO = { id = "levar-o-selo-a-vila" },
	HISTORIA = { nos = { vila = { titulo = "A vila" } } },
}
local personagensProntos = { { id = "mago-de-fogo", nome = "Ignis, Aprendiz de Fogo", arvore = "fogo" } }
local shared = object("Folder")
local livro = object("Folder"); livro.Catalogo = "Catalogo"; shared.Livro = livro
local mundo = object("Folder"); mundo.HistoriaV1 = "HistoriaV1"; shared.Mundo = mundo
shared.PersonagensProntos = "PersonagensProntos"
shared.ApresentacaoAbertura = "ApresentacaoAbertura"
shared.Regras = { ProvacaoPrompts = "ProvacaoPrompts" }
replicated.Shared = shared
local service = {
	Players = { LocalPlayer = player }, ReplicatedStorage = replicated,
	HttpService = { GenerateGUID = function() return "request-u2" end },
	ContextActionService = {}, RunService = {},
}
local game = { GetService = function(_, name) assert(service[name], name); return service[name] end }
local task = {
	delay = function(seconds, fn) table.insert(timers, { seconds = seconds, fn = fn }) end,
	spawn = function(fn) fn() end,
	defer = function(fn) fn() end,
}
local function advance(seconds)
	local pending = timers; timers = {}
	for _, timer in pending do if timer.seconds <= seconds then timer.fn() else table.insert(timers, timer) end end
end

local function makeButton(parent, name, text, callback)
	local button = Instance.new("TextButton")
	button.Name, button.Text, button.Parent = name or "Button", text or "", parent
	button.Rotulo = Instance.new("TextLabel"); button.Rotulo.Name = "Rotulo"; button.Rotulo.Text = button.Text; button.Rotulo.Parent = button
	if callback then button.Activated:Connect(callback) end
	return button
end
local Componentes, Tema, ExtraTelas, provacaoClose
local function requireMock(module)
	if module == "Catalogo" then return catalog end
	if module == "HistoriaV1" then return historia end
	if module == "PersonagensProntos" then return personagensProntos end
	if module == "ApresentacaoAbertura" then return {
		nomeArvore = function(id) local entrada = catalog.POR_ID["tree/" .. tostring(id)]; return entrada and entrada.data.name or "Árvore" end,
		nomeObjetivo = function(objetivo) if objetivo and objetivo.id == historia.OBJETIVO.id then return "Levar o Selo do guardião à vila" end; return objetivo and (objetivo.titulo or objetivo.texto) or "Expedição" end,
		nomePronto = function(id) for _, p in personagensProntos do if p.id == id then return p.nome end end; return "Personagem pronto" end,
	} end
	if module == "ExtraTelas" then return ExtraTelas end
	if module == "Componentes" then return Componentes end
	if module == "Tema" then return Tema end
	if module == "ProvacoesView" then return { start = function(remote, fechar) provacaoClose = fechar end } end
	if module == "ExtraProvacoes" then return {} end
	if module == "ExtraAvisos" then return {} end
	-- Esta fixture só carrega ProvacoesView; a política pura tem spec CLI próprio.
	if module == "ProvacaoPrompts" then return {} end
	error("require sem mock: " .. tostring(module))
end
local script = { Parent = { UI = { ExtraTelas = "ExtraTelas", Componentes = "Componentes", Tema = "Tema",
	ExtraProvacoes = "ExtraProvacoes", ExtraAvisos = "ExtraAvisos" }, ProvacoesView = "ProvacoesView" } }
local require = requireMock

Componentes = {}
Tema = { cores = { borda = "borda", titulo = "titulo", painel = "painel", alerta = "alerta", perigo = "perigo", sucesso = "sucesso" },
	espessuras = { destaque = 3 }, arvore = function() return { selo = "ÁGUA", cor = "água" } end }
Componentes.dialogoNpc = function(p)
	local root = Instance.new("Frame"); root.Parent = p.parent
	local content = Instance.new("Frame"); content.Name = "Conteudo"; content.Parent = root; root.Conteudo = content
	local layout = Instance.new("UIListLayout"); layout.Parent = content
	local title = Instance.new("TextLabel"); title.Text = p.nomeNpc or ""; title.LayoutOrder = 1; title.Parent = content
	local speech = Instance.new("TextLabel"); speech.Text = p.fala or ""; speech.LayoutOrder = 2; speech.Parent = content
	Instance.new("UISizeConstraint").Parent = root
	return root
end
Componentes.texto = function(p)
	local label = Instance.new("TextLabel"); label.Name = p.nome or "Texto"; label.Text = p.texto or ""; label.LayoutOrder = p.ordem or 0; label.Parent = p.parent; return label
end
Componentes.botao = function(p)
	local b = makeButton(p.parent, p.nome, p.texto, p.aoClicar); b.LayoutOrder = p.ordem or 0; return b
end
Componentes.aviso = function(p) table.insert(avisos, p); return function() end end

ExtraTelas = {}
ExtraTelas.atalho = function(parent, name, _, label)
	local b = makeButton(parent, name, label); return b
end
ExtraTelas.painel = function(parent, name)
	local p = Instance.new("Frame"); p.Name = name; p.Parent = parent; p.Visible = false
	local content = Instance.new("Frame"); content.Name = "Conteudo"; content.Parent = p; p.Conteudo = content
	return p
end
ExtraTelas.tituloPainel = function(parent, value, order)
	local l = Componentes.texto({ parent = parent, texto = value, ordem = order }); return l
end
ExtraTelas.fechar = function(parent, panel)
	return makeButton(parent, "Fechar", "Fechar", function() panel.Visible = false end)
end
ExtraTelas.lista = function(parent, name)
	local list = Instance.new("ScrollingFrame"); list.Name = name; list.Parent = parent
	local layout = Instance.new("UIListLayout"); layout.Parent = list
	return list, layout
end
ExtraTelas.limpar = function(list, layout)
	for _, child in list:GetChildren() do if child ~= layout then child:Destroy() end end
end
ExtraTelas.texto = function(parent, text, order)
	return Componentes.texto({ parent = parent, texto = text, ordem = order })
end
ExtraTelas.botao = function(parent, name, text, order, enabled, callback)
	local b = makeButton(parent, name, text, if enabled then callback else nil); b.LayoutOrder = order; return b
end

local RunView = (function()
-- U2_RUN_SOURCE
end)()
local TrainerView = (function()
-- U2_TREINADOR_SOURCE
end)()
local ProvacoesView = (function()
-- U2_PROVACOES_SOURCE
end)()
local AvisosJogo = (function()
-- U2_AVISOS_SOURCE
end)()

local function assertEqual(actual, expected, message)
	assert(actual == expected, (message or "valor") .. ": esperado " .. tostring(expected) .. ", recebido " .. tostring(actual))
end
local function find(parent, name, class)
	for _, item in objects do if item.Parent == parent and item.Name == name and (not class or item.ClassName == class) then return item end end
	error("objeto ausente: " .. tostring(name))
end

-- Run: atalhos consultam; intenção de iniciar e votação preservam payloads originais.
RunView.start()
find(find(playerGui, "RunJogo", "ScreenGui"), "AtalhoRun", "TextButton").Activated:Fire()
assertEqual(runRemote.sent[1].acao, "consultar", "Run consultar")
runRemote.OnClientEvent:Fire("run", { semRun = true })

local function descendantByText(root, text)
	for _, item in objects do if item.Text == text and item.ClassName == "TextButton" then
		local ancestor = item.Parent
		while ancestor and ancestor ~= root do ancestor = ancestor.Parent end
		if ancestor == root then return item end
	end end
	error("botão ausente: " .. text)
end
-- P2: sem run a tela oferece só "Nova expedição" (o AberturaFluxo decide o modo); sem lista de modos crus.
descendantByText(playerGui, "Nova expedição")
runRemote.OnClientEvent:Fire("run", { dia = 1, diasRestantes = 4, objetivo = { id = "rota", status = "em andamento" },
	semRun = false, galho = "rota", opcoes = { { id = "bosque", texto = "Bosque", dias = 1, liberada = true } }, grupo = {} })
local voto = descendantByText(playerGui, "Bosque · 1.00 dia(s)")
voto.Activated:Fire()
assertEqual(runRemote.sent[#runRemote.sent].acao, "votar", "Run votar")
assertEqual(runRemote.sent[#runRemote.sent].opcao, "bosque", "Run payload de voto")

-- Treinador: fala separada e retry reutiliza o mesmo requestId.
TrainerView.start()
trainerRemote.OnClientEvent:Fire({ oferta = { npcId = "agua", titulo = "Mestra", fala = "A fala fica separada.", arvore = "agua", resumo = "Resumo", podeComprar = true } })
local confirmar = descendantByText(playerGui, "Aceitar provação")
assert(confirmar and confirmar.Parent)
assertEqual(confirmar.Parent:FindFirstChild("Fala").Text, "A fala fica separada.", "fala do treinador")
confirmar.Activated:Fire()
local requestId = trainerRemote.sent[1].requestId
assertEqual(trainerRemote.sent[1].acao, "aceitar", "Treinador aceitar")
advance(10)
assertEqual(confirmar.Rotulo.Text, "Tentar novamente", "Treinador retry disponível")
confirmar.Activated:Fire()
assertEqual(trainerRemote.sent[2].requestId, requestId, "Treinador retry conserva requestId")
trainerRemote.OnClientEvent:Fire({ requestId = requestId, ok = true, mensagem = "Treino concluído." })
assertEqual(confirmar.Visible, false, "Treinador oculta após aceite")

-- Avisos: recusa genérica e missões entram na fila; logs comuns são ignorados.
local listener
local noticeState = { onLog = function(callback) listener = callback end }
AvisosJogo.start(noticeState)
listener({ tone = "publica", text = "linha comum" })
listener({ tone = "erro", text = "Pedido recusado." })
listener({ tone = "sistema", text = "Missão cumprida: sino" })
listener({ tone = "sistema", text = "Missão entregue: sino" })
assertEqual(#avisos, 3, "Avisos filtros")
assertEqual(avisos[1].tipo, "perigo", "Aviso de erro")
assertEqual(avisos[2].tipo, "sucesso", "Aviso missão cumprida")
assertEqual(avisos[3].tipo, "sucesso", "Aviso missão entregue")

print("U2 fixture: Run consultar/iniciar/votar, Treinador aceitar/retry e Avisos filtros OK; Provacoes fonte injetada, runtime não exercitado")
