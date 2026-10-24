-- Patrulhas visíveis e marcos de encontro do mundo (PLANO §13). Contato com a patrulha ou "segurar E"
-- num marco abre a luta na arena da mesa (LutaDoMundoServico). Herdou do antigo serviço J2 as validações:
-- jogador conectado e de pé, fora de combate, perto e visível; uma tentativa por intervalo.
-- Nenhum remoto chega aqui: patrulha é callback do servidor e o marco usa ProximityPrompt.Triggered.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EncontrosPorZona = require(ReplicatedStorage.Shared.EncontrosPorZona)

local PatrulhasDoMundo = {}

local INTERVALO_INICIO = 1 -- segundos entre tentativas de começar pela patrulha
local INTERVALO_MARCO = 2 -- segundos entre pedidos do mesmo jogador num marco
local CONTATO_STUDS = 5

local function raizViva(player)
	local personagem = player and player.Character
	local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
	local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")
	if raiz and raiz:IsA("BasePart") and humanoide and humanoide.Health > 0 then return raiz end
	return nil
end

-- deps: lutaNaArena(player, patrulha, definicao) -> bool, lutaNoMarco(player, areaId) -> ok, motivo,
-- lutaAtiva() -> bool, emCombate(player) -> bool, corpoPessoal(player), avisar(player, texto),
-- cacadas (definido depois por definirCacadas), workspace, agora, heartbeat, jogadores()
function PatrulhasDoMundo.start(deps)
	local mundo = deps.workspace or workspace
	local agora = deps.agora or os.clock
	local jogadores = deps.jogadores or function() return Players:GetPlayers() end
	local emCombate = deps.emCombate or function() return false end
	local patrulhas = {} -- adaptador -> definição (tabela de EncontrosPorZona ou marco das patrulhas antigas)
	local inicioEmCurso, ultimaTentativa = false, -math.huge
	local cacadas
	local api = {}

	local function conectado(player)
		return player ~= nil and player.Parent == Players and Players:GetPlayerByUserId(player.UserId) == player
	end

	local function definicaoDe(patrulha)
		local definicao = patrulhas[patrulha]
		if type(definicao) == "table" then return definicao end
		-- Patrulhas antigas da clareira e das Ruínas guardam só o marco.
		local ruinas = definicao == "region/encounter/ruinas"
		return { nome = "Patrulha", marco = definicao, arena = if ruinas then "ruinas" else "campo",
			zona = if ruinas then "region/ruinas-do-vale" else "region/clareira-inicial" }
	end

	-- Callback do adaptador no contato. Devolve true se a luta começou (a patrulha fica ocupada).
	function api.encontrar(player, patrulha)
		if not patrulhas[patrulha] or patrulha.alvo() ~= player or inicioEmCurso or deps.lutaAtiva() then return false end
		local tempo = agora()
		if tempo - ultimaTentativa < INTERVALO_INICIO then return false end
		ultimaTentativa = tempo
		local raiz = raizViva(player)
		if not conectado(player) or emCombate(player) or not raiz or not patrulha.corpo:IsDescendantOf(mundo)
			or (raiz.Position - patrulha.corpo.Position).Magnitude > CONTATO_STUDS or not patrulha.visivel(player)
		then
			return false
		end
		inicioEmCurso = true
		local ok, comecou = pcall(deps.lutaNaArena, player, patrulha, definicaoDe(patrulha))
		inicioEmCurso = false
		if not ok then warn("[Patrulha] Arena recusada: " .. tostring(comecou)) end
		return ok and comecou == true
	end

	function api.definirCacadas(c) cacadas = c end

	local function elegivel(player)
		if not conectado(player) or emCombate(player) then return false end
		local ficha = deps.corpoPessoal and deps.corpoPessoal(player)
		local atuais = ficha and ficha.session and ficha.session.current
		return ficha ~= nil and (not atuais or not atuais.pv or atuais.pv > 0)
	end

	local config = {
		workspace = mundo, agora = agora,
		tempoMundo = function() return ReplicatedStorage:GetAttribute("RunTempoDecorrido") or 0 end,
		reaparecerSegundos = EncontrosPorZona.REAPARECER_SEGUNDOS,
		jogadores = jogadores,
		ocupado = function() return inicioEmCurso or deps.lutaAtiva() end,
		elegivel = elegivel,
		encontrar = api.encontrar,
		heartbeat = deps.heartbeat or game:GetService("RunService").Heartbeat,
	}

	function api.criarPatrulhas()
		local adaptador = require(script.Parent.Mundo.PatrulhaVisivel)
		local pasta = Instance.new("Folder")
		pasta.Name, pasta.Parent = "Patrulhas do mundo", mundo
		for _, d in EncontrosPorZona.patrulhas() do
			local c = table.clone(config)
			c.regiao, c.nome, c.modelo, c.criatura = pasta, d.nome, d.modelo, d.criatura
			c.reaparecimento = function(derrotar)
				if cacadas then return cacadas.reaparecimento(d.id, derrotar) end
				return nil, nil
			end
			c.pontos = { Vector3.new(d.x - d.raio, 1.5, d.z - d.raio), Vector3.new(d.x + d.raio, 1.5, d.z - d.raio),
				Vector3.new(d.x + d.raio, 1.5, d.z + d.raio), Vector3.new(d.x - d.raio, 1.5, d.z + d.raio) }
			local nova = adaptador.criar(c)
			if nova then patrulhas[nova] = d end
		end
		local clareira = require(script.Parent.RegiaoInicial).iniciarPatrulha(config)
		if clareira then patrulhas[clareira] = "region/encounter/clearing" end
		local ruinas = require(script.Parent.Mundo.Ruinas).iniciarPatrulha(config)
		if ruinas then patrulhas[ruinas] = "region/encounter/ruinas" end
	end

	-- Marco: o prompt já exige distância; o servidor confere de novo, com linha de visão se pedida.
	local function pertoDoMarco(player, marco, prompt)
		local raiz = raizViva(player)
		if not raiz or not prompt.Enabled then return false end
		if (raiz.Position - marco.Position).Magnitude > prompt.MaxActivationDistance + 2 then return false end
		if not prompt.RequiresLineOfSight then return true end
		local parametros = RaycastParams.new()
		parametros.FilterType = Enum.RaycastFilterType.Exclude
		parametros.FilterDescendantsInstances = { player.Character }
		parametros.IgnoreWater = true
		local resultado = mundo:Raycast(raiz.Position, marco.Position - raiz.Position, parametros)
		return resultado ~= nil and resultado.Instance == marco
	end

	function api.ligarMarcos()
		local ultimoPedido = {}
		for _, item in mundo:GetDescendants() do
			local areaId = item:GetAttribute("EncounterId")
			local prompt = item:FindFirstChildWhichIsA("ProximityPrompt")
			if item:IsA("BasePart") and item:GetAttribute("AreaRole") == "encounter-trigger" and prompt
				and type(areaId) == "string" and EncontrosPorZona.consultar(areaId) ~= nil
			then
				prompt.Triggered:Connect(function(player)
					local tempo = agora()
					if ultimoPedido[player] and tempo - ultimoPedido[player] < INTERVALO_MARCO then return end
					ultimoPedido[player] = tempo
					if not conectado(player) or emCombate(player) or not pertoDoMarco(player, item, prompt) then return end
					local ok, comecou, motivo = pcall(deps.lutaNoMarco, player, areaId)
					if (not ok or not comecou) and deps.avisar then
						deps.avisar(player, if ok and motivo then motivo else "Não foi possível iniciar o encontro.")
					end
				end)
			end
		end
		Players.PlayerRemoving:Connect(function(player) ultimoPedido[player] = nil end)
	end

	return api
end

return PatrulhasDoMundo
