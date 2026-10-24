-- Ponte do Modo História (PLANO §13): toda luta do mundo (patrulha, marco, guardião da run, provação do
-- dojo) acontece na arena da mesa (EncontroService), com o cenário da região; no fim, volta ao mesmo ponto do mapa.
-- O avatar é a ficha (AvatarFichas): o grupo é posto na entrada da arena, dá os últimos passos até
-- as casas e, no fim, volta ao ponto exato do contato.
-- Servidor decide grupo, inimigos e recompensa; nenhum remoto chega aqui.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EncontrosPorZona = require(ReplicatedStorage.Shared.EncontrosPorZona)
local Recompensa = require(ReplicatedStorage.Shared.Regras.RecompensaEncontro)
local Arenas = require(ReplicatedStorage.Shared.Mundo.ArenasDados)
local Protocol = require(ReplicatedStorage.Shared.MesaProtocol)

local LutaDoMundo = {}

local RAIO_GRUPO = 40 -- studs: quem está perto do contato entra junto
-- Depois de uma luta o grupo volta ao mesmo ponto; sem trégua, a patrulha vizinha o puxava na hora.
LutaDoMundo.TREGUA_SEGUNDOS = 12
LutaDoMundo.LIMITE_GRUPO = 4

local function raiz(player)
	local personagem = player and player.Character
	local r = personagem and personagem:FindFirstChild("HumanoidRootPart")
	local h = personagem and personagem:FindFirstChildOfClass("Humanoid")
	if r and r:IsA("BasePart") and h and h.Health > 0 then return r end
	return nil
end

-- deps: iniciarLuta(grupo, criaturas, opcoes) -> erro?, corpoPessoal(player), recompensar(player, id, moedas, marco, pa),
-- cenario { aplicar(arenaId?) }, jogadores(), aoEncerrar(encontro, estado), rng(), limiteGrupo(),
-- avisarRecompensa(player, { ouro, pa, total? }) depois de creditar a vitória
function LutaDoMundo.start(deps)
	local jogadores = deps.jogadores or function() return Players:GetPlayers() end
	local rng = deps.rng or function() return math.random() end
	local agora = deps.agora or os.clock
	local treguaAte = {} -- userId -> instante
	local cacadas
	local ativa = nil -- { grupo, criaturas, ancorados, encounterId, patrulha?, patrulhaId?, marco, pagar }
	local api = {}

	function api.definirCacadas(c) cacadas = c end
	function api.ativa() return ativa ~= nil end

	-- A trégua só segura as patrulhas (início automático); chefe, marco e dojo são pedidos do jogador.
	local function emTregua(player) return (treguaAte[player.UserId] or 0) > agora() end
	local function temFicha(player)
		if not deps.corpoPessoal then return false end
		local ok, corpo = pcall(deps.corpoPessoal, player)
		local atual = ok and corpo and corpo.session and corpo.session.current
		return ok and corpo ~= nil and (not atual or not atual.pv or atual.pv > 0)
	end

	local function montarGrupo(player, automatico)
		local centro = raiz(player)
		if not centro then return nil end
		local limite = (deps.limiteGrupo and deps.limiteGrupo()) or LutaDoMundo.LIMITE_GRUPO
		local grupo = { player }
		local outros = table.clone(jogadores())
		table.sort(outros, function(a, b) return a.UserId < b.UserId end)
		for _, outro in outros do
			if #grupo >= limite then break end
			local r = outro ~= player and raiz(outro)
			if r and (r.Position - centro.Position).Magnitude <= RAIO_GRUPO and temFicha(outro) and not (automatico and emTregua(outro)) then
				table.insert(grupo, outro)
			end
		end
		return grupo
	end

	-- Beira sul do tabuleiro, de frente para os inimigos: a caminhada da mesa (14 studs/s) cobre só
	-- alguns passos, em vez dos ~1000 studs entre o mapa e a arena.
	local function entradaDaArena(i)
		local board = Protocol.BOARD
		local ponto = board.origin + Vector3.new((i - 2.5) * board.cell, 3, board.height * board.cell / 2 + board.cell)
		return CFrame.lookAt(ponto, ponto - Vector3.zAxis)
	end

	local function ancorar(grupo)
		local ancorados = {}
		for i, p in grupo do
			local r = raiz(p)
			if r then
				ancorados[p.UserId] = { parte = r, cframe = r.CFrame, antes = r.Anchored }
				r.Anchored = true
				r.CFrame = entradaDaArena(i)
			end
		end
		return ancorados
	end

	local function soltar(ancorados)
		for _, a in ancorados do
			if a.parte.Parent then
				a.parte.CFrame = a.cframe
				a.parte.Anchored = a.antes
			end
		end
	end

	local function idDe(criatura) return if type(criatura) == "table" then criatura.id else criatura end

	local function pagar(luta)
		local valores = {}
		for _, criatura in luta.criaturas do
			local valor = Recompensa.daCriatura(idDe(criatura))
			if valor then
				if type(criatura) == "table" and criatura.papel then valor.papel = criatura.papel end
				table.insert(valores, valor)
			end
		end
		local premio = Recompensa.gerar(valores, rng)
		local moedas = premio.moedas or 0
		for _, tralha in premio.tralhas or {} do
			if type(tralha.preco) == "number" and tralha.preco > 0 then moedas += math.floor(tralha.preco) end
		end
		for _, p in luta.grupo do
			if p.Parent ~= Players then continue end
			local bonus, pa = 0, 0
			local patrulhaId = luta.patrulhaId
			if cacadas and patrulhaId then bonus, pa = cacadas.bonus(p, patrulhaId) end
			local ok, sucesso, total = pcall(deps.recompensar, p, luta.encounterId, moedas + bonus, luta.marco, pa)
			if ok and sucesso and cacadas and patrulhaId and bonus > 0 then
				cacadas.concluir(p, patrulhaId, luta.encounterId)
			end
			-- A tela de vitória já abriu (o fim da luta chega antes do pagamento); o ouro vem depois.
			if ok and sucesso and deps.avisarRecompensa then
				pcall(deps.avisarRecompensa, p, { ouro = moedas + bonus, pa = pa, total = if type(total) == "number" then total else nil })
			end
		end
	end

	-- Mesmo formato mínimo dos encontros J2 que a run e o dojo já leem no fim (participantes por UserId).
	local function encontroDoFim(luta)
		local porJogador, ordem, porId = {}, {}, {}
		for _, p in luta.grupo do
			local atorId = "jogador:" .. p.UserId
			porJogador[p.UserId] = atorId
			table.insert(ordem, atorId)
			porId[atorId] = { userId = p.UserId }
		end
		return { atoresPorJogador = porJogador, ordemInicial = ordem, atoresPorId = porId }
	end

	local function terminar(luta, resultado)
		if ativa ~= luta then return end
		ativa = nil
		for _, p in luta.grupo do treguaAte[p.UserId] = agora() + LutaDoMundo.TREGUA_SEGUNDOS end
		if deps.cenario then pcall(deps.cenario.aplicar, nil) end
		soltar(luta.ancorados)
		if resultado == "vitoria" then
			if luta.patrulha and luta.patrulha.derrotada then luta.patrulha.derrotada() end
			if luta.pagar then pagar(luta) end
		end
		if luta.patrulha then luta.patrulha.ocupar(false) end
		if deps.aoEncerrar then
			local fase = if resultado == "vitoria" then "victory" elseif resultado == "derrota" then "defeat" else "fled"
			pcall(deps.aoEncerrar, encontroDoFim(luta), { phase = fase, encounterId = luta.encounterId })
		end
	end

	-- Início comum: ancora o grupo na entrada da arena, veste o cenário e pede a Luta à mesa.
	-- info: { arena, nome, marco, pagar, patrulha?, patrulhaId? }. Devolve encounterId ou nil, erro.
	local function comecar(grupo, criaturas, info)
		if ativa then return nil, "Já há uma luta em andamento." end
		if type(criaturas) ~= "table" or #criaturas == 0 then return nil, "Sem inimigos para esta luta." end
		local luta = {
			grupo = grupo, criaturas = criaturas, patrulha = info.patrulha, patrulhaId = info.patrulhaId,
			marco = info.marco, pagar = info.pagar ~= false,
			encounterId = "mundo-" .. string.gsub(HttpService:GenerateGUID(false), "[^%w]", ""),
		}
		ativa = luta
		luta.ancorados = ancorar(grupo)
		if deps.cenario then pcall(deps.cenario.aplicar, info.arena) end
		local erro = deps.iniciarLuta(grupo, criaturas, {
			nome = info.nome,
			aoTerminar = function(resultado) terminar(luta, resultado) end,
		})
		if erro then
			warn("[Luta do mundo] Início recusado: " .. tostring(erro))
			ativa = nil
			if deps.cenario then pcall(deps.cenario.aplicar, nil) end
			soltar(luta.ancorados)
			return nil, erro
		end
		return luta.encounterId
	end

	-- Chamado pela patrulha no contato. Devolve true se a luta começou (a patrulha fica ocupada).
	function api.iniciar(player, patrulha, definicao)
		if ativa or type(definicao) ~= "table" then return false end
		if emTregua(player) or not temFicha(player) then return false end
		local grupo = montarGrupo(player, true)
		if not grupo then return false end
		-- Patrulhas antigas da clareira/ruínas não têm id: um goblin batedor por jogador.
		local criaturas = if definicao.id then EncontrosPorZona.elencoPatrulha(definicao.id, math.min(#grupo, 4)) else nil
		if not definicao.id then
			criaturas = {}
			for _ = 1, math.min(#grupo, 4) do table.insert(criaturas, "creature/goblin-batedor") end
		end
		if not criaturas then return false end
		return comecar(grupo, criaturas, { arena = Arenas.daPatrulha(definicao), nome = definicao.nome,
			marco = definicao.marco, patrulha = patrulha, patrulhaId = definicao.id }) ~= nil
	end

	-- Marco do mundo (ProximityPrompt já validado pelo serviço de encontros): elenco do marco para o grupo próximo.
	function api.iniciarMarco(player, areaId)
		if ativa then return false, "Já há uma luta em andamento." end
		if not temFicha(player) then return false, "Sua ficha precisa estar carregada e de pé." end
		local grupo = montarGrupo(player)
		if not grupo then return false, "Seu personagem precisa estar no mapa." end
		local zona = EncontrosPorZona.elegivel(areaId, math.min(#grupo, 4))
		if not zona then return false, "Este marco não está elegível para o tamanho do grupo." end
		local id, erro = comecar(grupo, zona.elenco, { arena = Arenas.daMarco(areaId), nome = zona.nome or "Encontro do marco", marco = areaId })
		return id ~= nil, erro
	end

	-- Luta do guardião da run (RunServico escolhe o grupo perto do guardião). Devolve encounterId ou nil, erro.
	function api.iniciarChefe(grupo, luta)
		if type(grupo) ~= "table" or #grupo == 0 or #grupo > 4 then return nil, "O grupo da run é inválido." end
		for _, p in grupo do
			if not raiz(p) then return nil, "Todos os jogadores precisam estar vivos e com avatar carregado." end
			if not temFicha(p) then return nil, "Um personagem da run está sem PV na ficha pessoal." end
		end
		local composicao, erro = EncontrosPorZona.paraRun(luta, #grupo)
		if not composicao then return nil, erro end
		local criaturas = {}
		for i, id in composicao.elenco do
			table.insert(criaturas, if composicao.papeis[i] then { id = id, papel = composicao.papeis[i] } else id)
		end
		return comecar(grupo, criaturas, { arena = Arenas.daMarco(luta.areaId), nome = "Guardião da run", marco = luta.areaId })
	end

	-- Provação do dojo do Hanzo (vila): um lobo cinzento, sem ouro; o dojo dá a própria recompensa.
	function api.iniciarProvaDojo(player)
		if ativa then return nil, "Já existe um encontro ativo." end
		if not raiz(player) or not temFicha(player) then return nil, "Termine a partida atual antes de iniciar a provação." end
		return comecar({ player }, { "creature/lobo-cinzento" }, { arena = "cidade", nome = "Provação do dojo",
			marco = "region/encounter/clearing", pagar = false })
	end

	-- Quem sai no meio da luta não deixa o personagem preso na âncora quando voltar.
	Players.PlayerRemoving:Connect(function(player)
		if ativa and ativa.ancorados[player.UserId] then ativa.ancorados[player.UserId] = nil end
		treguaAte[player.UserId] = nil
	end)
	return api
end

return LutaDoMundo
