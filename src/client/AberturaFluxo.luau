-- Orquestra a primeira vez (P2): Carregamento -> CenaAbertura (uma vez, flag na conta) -> criação em
-- 3 passos -> run automática sem árvore -> nasce no portão norte. Também cuida do menu "Nova
-- expedição", de "Rever abertura" e de aplicar na ficha a árvore que o mestre ensinou.
-- Só apresentação e intenção: o servidor decide modo da run, ficha e conta (RunServico/PersonagemSessao).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalogo = require(Shared.Livro.Catalogo)
local Preset = require(Shared.Regras.CriacaoPreset)
local Conta = require(Shared.Regras.RunConta)
local Abertura = require(Shared.Regras.AberturaRun)
local Componentes = require(script.Parent.UI.Componentes)

local Fluxo = {}

local estado = {
	iniciado = false,
	conta = nil, -- última conta recebida
	perfil = nil, perfilRecebido = false,
	run = nil, -- último estado "run" ({ semRun = true } sem run)
	deps = nil,
}
local pendenteConta -- { requestId, aoResponder }
local aguardandoCriacao -- { aparencia, raceId, desde }
local aguardandoRun -- função(ok, erro)
local pendenteArvore -- { id, nome } aguardando o servidor confirmar a árvore na ficha
local avancadoAtivo = false -- ficha completa aberta pelo assistente: ao criar, a run começa sozinha
local sincronizadas = {} -- chaves "<arvore>" já enviadas para a ficha
local avisos

local function aviso(tipo, titulo, detalhe)
	if avisos then Componentes.aviso({ parent = avisos, tipo = tipo, titulo = titulo, detalhe = detalhe, duracao = 6 }) end
end

local function runAtiva()
	local r = estado.run
	return r ~= nil and r.semRun ~= true and r.fim == nil and r.erro == nil
end

function Fluxo.runAtiva() return runAtiva() end
function Fluxo.temPerfil() return estado.perfil ~= nil end
function Fluxo.modosLiberados() return Conta.modosLiberados(estado.conta) end
function Fluxo.modos() return Abertura.MODOS end

-- ---------------------------------------------------------------- conta (consulta e marca de abertura)
local contaRemote
local function pedirConta(acao, aoResponder)
	if not contaRemote then aoResponder(nil, "Conta indisponível."); return end
	local id = "ab-" .. string.gsub(HttpService:GenerateGUID(false), "[^%w]", "")
	local atual = { requestId = id, aoResponder = aoResponder }
	pendenteConta = atual
	contaRemote:FireServer({ acao = acao, requestId = id })
	task.delay(8, function()
		if pendenteConta == atual then pendenteConta = nil; aoResponder(nil, "Sem resposta da conta.") end
	end)
end

local function consultarConta()
	local resultado, pronto = nil, false
	for _ = 1, 3 do
		pedirConta("consultar", function(conta, motivo) resultado, pronto = { conta = conta, motivo = motivo }, true end)
		local limite = os.clock() + 9
		while not pronto and os.clock() < limite do task.wait(0.1) end
		if resultado and resultado.conta then estado.conta = resultado.conta; return resultado.conta end
		pronto = false
		task.wait(1)
	end
	return nil
end

-- ---------------------------------------------------------------- run
local runRemote
local function enviarRun(pedido) if runRemote then runRemote:FireServer(pedido) end end

-- Inicia a run (modo só vale depois da primeira run; o servidor decide). Bloqueia até a resposta.
local function iniciarRunEsperando(modo)
	if runAtiva() then return true end
	local resultado
	aguardandoRun = function(ok, erro) resultado = { ok = ok, erro = erro } end
	enviarRun({ acao = "iniciar", modo = modo })
	local limite = os.clock() + 12
	while not resultado and os.clock() < limite do task.wait(0.1) end
	aguardandoRun = nil
	if resultado and resultado.ok then return true end
	return false, (resultado and resultado.erro) or "A expedição não respondeu. Tente novamente."
end

-- ---------------------------------------------------------------- criação
local rapida
local function abrirCriacaoRapida()
	local deps = estado.deps
	deps.inicio.esconder()
	local liberadas = Conta.racasLiberadas(estado.conta)
	local lista = Preset.racasDisponiveis(Catalogo, liberadas)
	if #lista == 0 then lista = Preset.racasDisponiveis(Catalogo, nil) end
	rapida.abrir({
		racas = lista,
		cosmeticos = estado.conta and estado.conta.cosmeticos or {},
		aoConfirmar = function(ficha, aparencia, raceId)
			task.spawn(function()
				local ok, motivo = iniciarRunEsperando(nil)
				if not ok then rapida.falhou("Expedição: " .. tostring(motivo)); return end
				aguardandoCriacao = { aparencia = aparencia, raceId = raceId, desde = os.clock() }
				estado.deps.state.send("personagemPessoalCriar", ficha)
				task.delay(20, function()
					if aguardandoCriacao and aguardandoCriacao.desde and os.clock() - aguardandoCriacao.desde >= 19 then
						aguardandoCriacao = nil
						rapida.falhou("Sem resposta do servidor ao criar a ficha. Tente de novo.")
					end
				end)
			end)
		end,
		aoAvancado = function()
			rapida.fechar()
			avancadoAtivo = true
			local criacao = estado.deps.criacao
			if criacao.definirSemArvore then criacao.definirSemArvore(true) end
			criacao.abrir(function()
				-- Fechou a ficha completa: sem personagem volta ao assistente; com personagem segue para o mundo.
				avancadoAtivo = false
				if estado.perfil == nil then abrirCriacaoRapida() end
			end)
		end,
	})
end

local function aoCriarPerfil(perfil)
	-- Ficha confirmada pelo servidor: salva a aparência do assistente e entra no mundo.
	local espera = aguardandoCriacao
	if espera then
		aguardandoCriacao = nil
		estado.deps.aparenciaFluxo.salvar(espera.aparencia, function(ok)
			if not ok then aviso("perigo", "Aparência", "Ficha criada; a aparência não foi confirmada. Use o espelho da vila.") end
		end)
		rapida.fechar()
		estado.deps.inicio.esconder()
		return
	end
	-- Ficha criada pela tela avançada: garante a run (o servidor define o modo) e entra no mundo.
	if avancadoAtivo and not runAtiva() then
		avancadoAtivo = false
		task.spawn(function()
			local ok, motivo = iniciarRunEsperando(nil)
			if not ok then aviso("perigo", "Expedição", tostring(motivo)) end
			estado.deps.criacao.fechar()
			estado.deps.inicio.esconder()
		end)
	end
end

-- Depois da provação: a ficha ganha a árvore que a run concedeu (mesmo preset, mesmos atributos).
local function sincronizarArvore(run)
	local plano = run and run.plano
	local perfil = estado.perfil
	if not plano or not perfil or not perfil.construcao or run.fim then return end
	local arvore = plano.escolhida or (plano.modo == "pronto" and plano.arvore or nil)
	if not arvore or sincronizadas[arvore] then return end
	local id = "tree/" .. arvore
	if not Catalogo.POR_ID[id] or perfil.construcao.startingTreeId == id then return end
	sincronizadas[arvore] = true
	local construcao, motivo = Preset.comArvore(Catalogo, perfil.construcao, id)
	if not construcao then aviso("perigo", "Ficha", tostring(motivo)); return end
	construcao.nome = perfil.nome
	construcao.requestId = HttpService:GenerateGUID(false)
	pendenteArvore = { id = id, nome = Catalogo.POR_ID[id].data.name or arvore, desde = os.clock() }
	estado.deps.state.send("personagemPessoalCriar", construcao)
end

-- ---------------------------------------------------------------- API do menu
function Fluxo.novaExpedicao()
	local deps = estado.deps
	if not deps then return end
	if runAtiva() then deps.inicio.esconder(); return end
	if not estado.perfil then abrirCriacaoRapida(); return end
	task.spawn(function()
		consultarConta()
		if Conta.modosLiberados(estado.conta) then deps.inicio.abrirModos() else Fluxo.iniciarRun(nil) end
	end)
end

function Fluxo.iniciarRun(modo)
	local deps = estado.deps
	task.spawn(function()
		local ok, motivo = iniciarRunEsperando(modo)
		if ok then deps.inicio.esconder() else deps.inicio.aviso(tostring(motivo)) end
	end)
end

function Fluxo.rever()
	local deps = estado.deps
	if not deps then return end
	task.spawn(function()
		local ok, Cena = pcall(require, script.Parent.CenaAbertura)
		if not ok then return end
		deps.inicio.esconder()
		Cena.tocar()
		deps.inicio.abrir()
	end)
end

-- ---------------------------------------------------------------- partida
function Fluxo.start(state, deps)
	if estado.iniciado then return Fluxo end
	estado.iniciado = true
	deps.state = state
	estado.deps = deps
	local jogador = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.DisplayOrder, gui.ZIndexBehavior = "AberturaAvisos", false, 90, Enum.ZIndexBehavior.Sibling
	gui.Parent = jogador:WaitForChild("PlayerGui")
	avisos = gui
	deps.aparenciaFluxo = deps.aparenciaFluxo or require(script.Parent.AparenciaFluxo).start()
	rapida = require(script.Parent.CriacaoRapidaView).start({ aparenciaFluxo = deps.aparenciaFluxo })

	state.onPersonagemPessoal(function(perfil)
		estado.perfil, estado.perfilRecebido = perfil, true
		if perfil and pendenteArvore and perfil.construcao and perfil.construcao.startingTreeId == pendenteArvore.id then
			aviso("sucesso", "Novo caminho aprendido", "Sua ficha agora tem a árvore " .. tostring(pendenteArvore.nome) .. ".")
			pendenteArvore = nil
		end
		if perfil then aoCriarPerfil(perfil); sincronizarArvore(estado.run) end
	end)
	-- Erros do servidor só importam enquanto esperamos a criação (o histórico antigo é ignorado).
	state.onLog(function(evento)
		if evento.tone == "erro" and pendenteArvore and os.clock() - pendenteArvore.desde < 20 then
			aviso("perigo", "Ficha não atualizada", tostring(evento.text or "O servidor recusou a árvore."))
			sincronizadas[string.gsub(pendenteArvore.id, "^tree/", "")] = nil -- uma nova atualização da run tenta de novo
			pendenteArvore = nil
			return
		end
		if evento.tone ~= "erro" or not aguardandoCriacao then return end
		if os.clock() - aguardandoCriacao.desde > 25 then return end
		aguardandoCriacao = nil
		rapida.falhou(evento.text or "O servidor recusou a ficha.")
	end)
	task.spawn(function()
		runRemote = ReplicatedStorage:WaitForChild("RunJogo")
		runRemote.OnClientEvent:Connect(function(tipo, dado)
			if tipo ~= "run" or type(dado) ~= "table" then return end
			if dado.erro then
				if aguardandoRun then aguardandoRun(false, dado.erro) end
				return
			end
			estado.run = dado
			if aguardandoRun and runAtiva() then aguardandoRun(true) end
			sincronizarArvore(dado)
		end)
		runRemote:FireServer({ acao = "consultar" })
	end)
	task.spawn(function()
		contaRemote = ReplicatedStorage:WaitForChild("ContaJogo", 20)
		if not contaRemote then return end
		contaRemote.OnClientEvent:Connect(function(resposta)
			if type(resposta) ~= "table" or type(resposta.requestId) ~= "string" then return end
			local espera = pendenteConta
			if not espera or espera.requestId ~= resposta.requestId then return end
			pendenteConta = nil
			if resposta.ok == true and Conta.valida(resposta.conta) then espera.aoResponder(resposta.conta)
			else espera.aoResponder(nil, resposta.mensagem or "Conta indisponível.") end
		end)
	end)

	-- Sequência de abertura. O menu fica escondido até sabermos o que mostrar.
	deps.inicio.esconder()
	task.spawn(function()
		local Carregamento = require(script.Parent.Carregamento)
		local limite = os.clock() + 90
		while not Carregamento.pronto() and os.clock() < limite do task.wait(0.2) end
		while not contaRemote and os.clock() < limite do task.wait(0.1) end
		task.wait(1.4) -- fade do carregamento e câmera do mundo
		local conta = consultarConta()
		-- Ficha pessoal: o InicioView já consultou; repete se o servidor ainda não respondeu.
		local tentativas = 0
		while not estado.perfilRecebido and tentativas < 6 do
			state.send("personagemPessoalConsultar", {})
			local ate = os.clock() + 3
			while not estado.perfilRecebido and os.clock() < ate do task.wait(0.1) end
			tentativas += 1
		end
		if conta and not Conta.aberturaVista(conta) then
			local ok, Cena = pcall(require, script.Parent.CenaAbertura)
			if ok then
				Cena.tocar()
			else
				warn("[Abertura] CenaAbertura indisponível: " .. tostring(Cena))
			end
			-- Ver ou pular conta como vista; só avisa uma vez (o servidor é idempotente).
			pedirConta("aberturaVista", function(nova) if nova then estado.conta = nova end end)
		end
		if estado.perfilRecebido and estado.perfil == nil and not runAtiva() then
			abrirCriacaoRapida()
		else
			deps.inicio.abrir()
		end
	end)
	return Fluxo
end

return Fluxo
