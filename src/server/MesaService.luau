-- Mesa virtual: o servidor guarda fichas, iniciativa e rolagens; clientes só pedem.
-- Contrato completo em docs/MESA.md. O estado vive só enquanto o servidor existir.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local Protocol = require(ReplicatedStorage.Shared.MesaProtocol)
local Furtividade = require(ReplicatedStorage.Shared.VisibilidadeFurtiva)
local CondicaoRules = require(ReplicatedStorage.Shared.CondicaoRules)
local Condicoes = require(ReplicatedStorage.Shared.Condicoes)
local Dice = require(ReplicatedStorage.Shared.Dice)
local FichaImport = require(ReplicatedStorage.Shared.FichaImport)
local MesaSave = require(ReplicatedStorage.Shared.MesaSave)
local Persistence = require(script.Parent.MesaPersistence)
local AvatarFichas = require(script.Parent.AvatarFichas)
local CorposDeCriatura = require(script.Parent.CorposDeCriatura)
local FichaV2Import = require(script.Parent.FichaV2Import)
local HabilidadeService = require(script.Parent.HabilidadeService)
local ProgressaoService = require(script.Parent.ProgressaoService)
local TreinoService = require(script.Parent.TreinoService)
local TravaPartida = require(ReplicatedStorage.Shared.TravaPartida)
local EncontroService = require(script.Parent.EncontroService)
local Premontados = require(script.Parent.Premontados)
local FichaV2 = require(ReplicatedStorage.Shared.FichaV2)
local Catalogo = require(ReplicatedStorage.Shared.Livro.Catalogo)
local CriacaoPersonagem = require(ReplicatedStorage.Shared.Regras.CriacaoPersonagem)
local FichaPersonagemProprio = require(ReplicatedStorage.Shared.Regras.FichaPersonagemProprio)
local PersonagemSessao = require(script.Parent.PersonagemSessao)
local PersonagemPersistencia = require(script.Parent.PersonagemPersistencia)
local Roles = require(script.Parent.MesaRoles)
local World = require(script.Parent.MesaWorld)
local VozesNPCs = require(ReplicatedStorage.Shared.VozesNPCs)

local LIMITS = Protocol.LIMITS
local isInteger = Protocol.isInteger

local DEFAULT_COLORS = {
	jogador = Color3.fromRGB(70, 120, 200),
	npc = Color3.fromRGB(185, 74, 70),
}

local MesaService = {}

function MesaService.start(rng: Random?)
	local random = rng or Random.new()
	World.create()

	local remote = Instance.new("RemoteEvent")
	remote.Name = Protocol.REMOTE
	remote.Parent = ReplicatedStorage

	local tokens: { [string]: any } = {}
	-- Mesma tabela a vida toda (importState só a limpa): AvatarFichas guarda a referência.
	local tokenOrder: { string } = {}
	local combat = { active = false, round = 0, order = {} :: { string }, turnIndex = 0, turn = 0 }
	local montagemPartida = TravaPartida.new()
	-- Mapa (M4): chaves "x,z". terrain guarda o tipo da casa; fog as casas cobertas.
	local terrain: { [string]: string } = {}
	local fog: { [string]: boolean } = {}
	local function cellKey(x: number, z: number): string
		return x .. "," .. z
	end
	-- O avatar é a ficha: fichas de jogador usam o avatar do dono (AvatarFichas).
	local avatares = AvatarFichas.start({
		ativo = function() return combat.active end,
		fichas = function()
			local lista = {}
			for _, id in tokenOrder do
				table.insert(lista, tokens[id])
			end
			return lista
		end,
		centro = Protocol.cellCenter,
		secreto = function(token)
			return token.hidden == true or fog[cellKey(token.x, token.z)] == true or Furtividade.escondido(token)
		end,
		-- Fileira no chão do salão, à esquerda do tabuleiro, longe das casas.
		bastidor = function(indice: number): Vector3
			local board = Protocol.BOARD
			return Vector3.new(
				board.origin.X - board.width * board.cell / 2 - 14,
				0,
				board.origin.Z - board.height * board.cell / 2 + 6 + (indice - 1) * 6
			)
		end,
	})
	-- Criaturas ganham corpo no tabuleiro (CorposDeCriatura); fichas secretas não.
	local corpos = CorposDeCriatura.start({
		fichas = function()
			local lista = {}
			for _, id in tokenOrder do
				table.insert(lista, tokens[id])
			end
			return lista
		end,
		centro = Protocol.cellCenter,
		secreto = function(token)
			return token.hidden == true or fog[cellKey(token.x, token.z)] == true or Furtividade.escondido(token)
		end,
		catalogo = Catalogo,
	})
	local nextId = 0
	-- turn conta cada troca de vez; o cliente o devolve em nextTurn para evitar avanço duplo.
	local budgets: { [Player]: { tokens: number, stamp: number, lastRoll: number } } = {}

	-- Campanha salva (M2). changes conta mutações para saber se um salvamento
	-- que esperou o DataStore ainda reflete a mesa atual.
	local persistence = Persistence.new()
	-- slot = espaço escolhido; baseSlot/revision = espaço que esta sessão carregou
	-- ou salvou por último, única base que autoriza gravar sem force.
	local campaign = {
		slot = nil :: number?,
		baseSlot = nil :: number?,
		revision = 0,
		savedAt = nil :: number?,
		dirty = false,
		status = if persistence.store then "livre" else "indisponivel",
	}
	local changes = 0
	local campaignBusy, campaignLoading, closing = false, false, false
	local lastCampaignOp = -math.huge
	-- generation muda quando a mesa inteira é trocada (carregar, limpar); pedidos
	-- que esperaram o filtro de texto não podem cair na mesa nova.
	local generation = 0
	-- Importação da ficha v2 (FichaV2Import), ligada depois dos handlers básicos.
	local importacao
	-- Habilidades em combate (HabilidadeService, fatia A1), ligadas junto.
	local habilidades
	-- Modo Treino (TreinoService): bancada de teste de habilidades.
	local treino
	-- Modo Luta (EncontroService): encontro contra criaturas com IA.
	local encontro
	local salaConceitual
	-- Quem tinha a vez antes da troca atual (fim de turno para as durações).
	local vezAnterior: string? = nil

	-- Permissões e visibilidade ------------------------------------------------

	local function inFog(token): boolean
		return fog[cellKey(token.x, token.z)] == true
	end

	-- Mestre vê tudo. Os demais veem fichas não ocultas fora da névoa; a própria
	-- ficha continua visível ao dono mesmo dentro da névoa.
	local function canSee(player: Player, token): boolean
		if not Furtividade.podeVer(player.UserId, token) then return false end
		if Roles.isMaster(player) then
			return true
		end
		if token.hidden then
			return false
		end
		return not inFog(token) or token.ownerUserId == player.UserId
	end

	local function canSeeStats(player: Player, token): boolean
		if Roles.isMaster(player) then
			return true
		end
		return canSee(player, token) and (token.ownerUserId == player.UserId or token.showStats)
	end

	-- Depois de um yield (filtro de texto) o papel do solicitante pode ter mudado.
	local function stillMaster(player: Player): boolean
		return player.Parent == Players and Roles.isMaster(player)
	end

	local function currentTurnId(): string?
		if combat.active then
			return combat.order[combat.turnIndex]
		end
		return nil
	end

	-- Envio --------------------------------------------------------------------

	-- Condições são visíveis a quem vê a ficha; a nota, só ao mestre e ao dono.
	local function conditionsView(player: Player, token)
		if not token.conditions or #token.conditions == 0 then
			return nil
		end
		local private = Roles.isMaster(player) or token.ownerUserId == player.UserId
		local list = {}
		for _, condition in token.conditions do
			table.insert(list, { id = condition.id, stacks = condition.stacks, note = if private then condition.note else nil })
		end
		return list
	end

	local function tokenView(player: Player, token)
		local stats = canSeeStats(player, token)
		local master = Roles.isMaster(player)
		local amigo = token.ownerUserId == player.UserId
		if habilidades and not amigo then
			for _, propria in tokens do
				if propria.ownerUserId == player.UserId and not habilidades.hostil(propria, token) then amigo = true; break end
			end
		end
		return {
			id = token.id,
			name = token.name,
			olharX = token.olharX, olharZ = token.olharZ,
			hostilAoTurno = habilidades and tokens[currentTurnId()] and habilidades.hostil(tokens[currentTurnId()], token) or false,
			aliadoSeu = amigo,
			apoio = if habilidades and (amigo or master) then habilidades.suporteDe(token, function(outro) return canSee(player, outro) end) else nil,
			testeFurtivo = if habilidades and stats then habilidades.testeFurtivo(token) else nil,
			balanceamentoJogo = if stats then token.balanceamentoJogo else nil,
			kind = token.kind,
			ownerUserId = token.ownerUserId,
			x = token.x,
			z = token.z,
			color = token.color,
			hidden = if master then token.hidden else nil,
			showStats = if master then token.showStats else nil,
			pv = if stats then token.pv else nil,
			pvMax = if stats then token.pvMax else nil,
			mana = if stats then token.mana else nil,
			manaMax = if stats then token.manaMax else nil,
			pt = if stats then token.pt else nil,
			ptMax = if stats then token.ptMax else nil,
			pvTemp = if stats and (token.pvTemp or 0) > 0 then token.pvTemp else nil,
			sheet = if stats then token.sheet else nil,
			-- A ficha completa vem sob demanda (fichaDetalhe); aqui só a versão dela.
			ficha2Versao = if stats and token.ficha2 then tostring(generation) .. ":" .. token.version else nil,
			-- Habilidades executáveis: só para quem controla a ficha (dono ou mestre).
			habilidades = if habilidades and (master or token.ownerUserId == player.UserId) then habilidades.habilidadesDe(token) else nil,
			pactos = if habilidades and (master or token.ownerUserId == player.UserId) then habilidades.pactosDe(token) else nil,
			estadosCombate = if stats and habilidades then habilidades.estadosDe(token) else nil,
			criatura = if token.criatura then true else nil,
			-- Família sonora cosmética apenas em fichas que passaram canSee.
			vozNPC = if token.criatura then VozesNPCs.familia(token.criatura.catalogId) else nil,
			derrotado = if token.derrotado then true else nil,
			conditions = conditionsView(player, token),
			avatar = if avatares.ehAvatar(token) then true else nil,
			corpo = if corpos.tem(token) then true else nil,
			monstroDoMestre = token.monstroDoMestre==true,
		}
	end

	local function snapshotFor(player: Player)
		local list = {}
		for _, id in tokenOrder do
			local token = tokens[id]
			if canSee(player, token) then
				table.insert(list, tokenView(player, token))
			end
		end
		local order = {}
		for _, id in combat.order do
			if canSee(player, tokens[id]) then
				table.insert(order, id)
			end
		end
		local turnId = currentTurnId()
		local playerList = {}
		for _, other in Players:GetPlayers() do
			table.insert(playerList, { userId = other.UserId, name = other.DisplayName, master = Roles.isMaster(other) })
		end
		local jogo = if habilidades then habilidades.estado() else nil
		if jogo and jogo.acoes and not canSee(player, tokens[jogo.acoes.tokenId]) then jogo.acoes = nil end
		return {
			you = { userId = player.UserId, master = Roles.isMaster(player), admin = Roles.isAdmin(player), modoJogador = Roles.modoJogador(player), personagem = if encontro then encontro.personagemDe(player) else nil },
			sala = if encontro then encontro.sala(player) else nil,
			salaConceitual = if salaConceitual then salaConceitual.publico() else nil,
			tokens = list,
			combat = {
				active = combat.active,
				round = combat.round,
				turn = combat.turn,
				order = order,
				turnId = if turnId and canSee(player, tokens[turnId]) then turnId else nil,
				masterTurn = turnId ~= nil and not canSee(player, tokens[turnId]),
			},
			players = playerList,
			map = { terrain = terrain, fog = fog },
			-- Donos cujos avatares são fichas; o cliente esconde os que ele não pode ver.
			avatares = avatares.donosVinculados(),
			campaign = if Roles.isMaster(player)
				then {
					slot = campaign.slot,
					revision = if campaign.slot and campaign.slot == campaign.baseSlot then campaign.revision else nil,
					savedAt = if campaign.slot and campaign.slot == campaign.baseSlot then campaign.savedAt else nil,
					dirty = campaign.dirty,
					status = campaign.status,
				}
				else nil,
			fichaPropostas = if importacao and Roles.isMaster(player) then importacao.propostas() else nil,
			jogo = jogo,
			encontro = if encontro then encontro.publico() else nil,
		}
	end

	local function broadcast()
		avatares.sincronizar()
		corpos.sincronizar()
		for _, player in Players:GetPlayers() do
			remote:FireClient(player, "snapshot", snapshotFor(player))
		end
	end

	-- tone: "publica" | "secreta" | "sistema" | "erro"
	local function logTo(player: Player, text: string, tone: string)
		remote:FireClient(player, "log", { text = text, tone = tone, time = os.time() })
	end

	local function logWhere(filter: (Player) -> boolean, text: string, tone: string)
		for _, player in Players:GetPlayers() do
			if filter(player) then
				logTo(player, text, tone)
			end
		end
	end

	-- Evento só de apresentação (dados 3D no cliente); o registro continua sendo o texto oficial.
	local function sendRoll(filter: (Player) -> boolean, data)
		for _, player in Players:GetPlayers() do
			if filter(player) then
				remote:FireClient(player, "roll", data)
			end
		end
	end

	local function logAll(text: string, tone: string)
		logWhere(function()
			return true
		end, text, tone)
	end

	local function logAboutToken(token, text: string)
		logWhere(function(player)
			return canSee(player, token)
		end, text, if token.hidden or inFog(token) then "secreta" else "publica")
	end

	-- Utilidades ---------------------------------------------------------------

	local function filterText(text: string, fromUserId: number): string?
		local ok, result = pcall(function()
			return TextService:FilterStringAsync(text, fromUserId):GetNonChatStringForBroadcastAsync()
		end)
		if ok and type(result) == "string" then
			return result
		end
		-- Jogadores locais do Studio (UserId negativo) podem não ter filtro disponível.
		-- Fora do Studio, sem filtro o texto não é exibido.
		if RunService:IsStudio() then
			warn("[Mesa] filtro de texto indisponível no Studio; usando o texto original:", result)
			return text
		end
		return nil
	end

	local function default(value: any, fallback: any): any
		if value == nil then
			return fallback
		end
		return value
	end

	local function cleanName(value: any): string?
		if type(value) ~= "string" or utf8.len(value) == nil then
			return nil
		end
		local trimmed = string.match(value, "^%s*(.-)%s*$")
		if trimmed == "" or utf8.len(trimmed) > LIMITS.name then
			return nil
		end
		return trimmed
	end

	local function occupant(x: number, z: number, viewer: Player?, except: string?)
		for _, id in tokenOrder do
			local token = tokens[id]
			if id ~= except and token.x == x and token.z == z and (viewer == nil or canSee(viewer, token)) then
				return token
			end
		end
		return nil
	end

	local function freeCellNear(x: number, z: number): (number?, number?)
		local board = Protocol.BOARD
		for radius = 0, math.max(board.width, board.height) do
			for dx = -radius, radius do
				for dz = -radius, radius do
					local cx, cz = x + dx, z + dz
					if math.max(math.abs(dx), math.abs(dz)) == radius and Protocol.isCell(cx, cz) and not occupant(cx, cz) and terrain[cellKey(cx, cz)] ~= "parede" then
						return cx, cz
					end
				end
			end
		end
		return nil, nil
	end

	local function isPresentUser(userId: any): boolean
		if not isInteger(userId, -2 ^ 53, 2 ^ 53) or userId == 0 then
			return false
		end
		return Players:GetPlayerByUserId(userId) ~= nil
	end

	local function statLine(token): string
		return string.format("PV %d/%d, mana %d/%d", token.pv, token.pvMax, token.mana, token.manaMax)
	end

	local function removeFromCombat(id: string)
		local index = table.find(combat.order, id)
		if not index then
			return
		end
		table.remove(combat.order, index)
		if #combat.order == 0 then
			combat.active, combat.round, combat.turnIndex = false, 0, 0
			return
		end
		if index < combat.turnIndex then
			combat.turnIndex -= 1
		end
		if combat.turnIndex > #combat.order then
			combat.turnIndex = 1
			combat.round += 1
		end
	end

	local function announceTurn()
		local id = currentTurnId()
		if habilidades then
			habilidades.aoTrocarVez(vezAnterior, id)
		end
		vezAnterior = id
		if treino then
			treino.aoTrocarVez(id)
		end
		if encontro then
			encontro.aoTrocarVez(id)
		end
		if not id then
			return
		end
		local token = tokens[id]
		logWhere(function(player)
			return canSee(player, token)
		end, string.format("Rodada %d: vez de %s.", combat.round, token.name), "sistema")
		logWhere(function(player)
			return not canSee(player, token)
		end, string.format("Rodada %d: vez do mestre.", combat.round), "sistema")
		-- Condições não têm duração numérica (o livro escreve em prosa); a mesa
		-- só lembra o que cobrar no início do turno e como a condição termina.
		local reminders = {}
		for _, condition in token.conditions or {} do
			local entry = Condicoes.POR_ID[condition.id]
			-- Em Chamas já é cobrado sozinho no início do turno (HabilidadeService).
			if entry and condition.id ~= "em-chamas" and (entry.lembrete or entry.duracao) then
				local parts = {}
				if entry.lembrete then
					table.insert(parts, entry.lembrete)
				end
				if entry.duracao then
					table.insert(parts, "termina: " .. entry.duracao)
				end
				table.insert(reminders, entry.nome .. " (" .. table.concat(parts, "; ") .. ")")
			end
		end
		if #reminders > 0 then
			logWhere(function(player)
				return Roles.isMaster(player) or (token.ownerUserId == player.UserId and canSee(player, token))
			end, "Lembrete — " .. token.name .. ": " .. table.concat(reminders, " • "), "sistema")
		end
	end

	-- Comandos -----------------------------------------------------------------
	-- Cada handler recebe payload já confirmado como tabela e devolve
	-- uma mensagem de erro (enviada só a quem pediu) ou nil.

	local handlers: { [string]: (Player, { [any]: any }, boolean) -> string? } = {}
	local personagemSessao = PersonagemSessao.start({
		handlers = handlers,
		remote = remote,
		catalogo = Catalogo,
		calcular = CriacaoPersonagem.calcular,
		filtrarNome = function(player, nome) return filterText(nome, player.UserId) end,
		emCombate = function() return combat.active or montagemPartida.ocupada() end,
		conectado = function(player) return player.Parent == Players end,
		persistencia = PersonagemPersistencia.new(),
	})
	local lojaService = require(script.Parent.LojaService).start({
		handlers = handlers, remote = remote,
		consultar = function(player) return personagemSessao.consultar(player) end,
		comprar = function(player, itemId, sourceLocalId) return personagemSessao.comprarLoja(player, itemId, sourceLocalId) end,
		vender = function(player, sourceLocalId, categorias) return personagemSessao.venderLoja(player, sourceLocalId, categorias) end,
		emCombate = function() return combat.active or montagemPartida.ocupada() end,
	})
	local function corpoPessoal(player)
		local perfil = personagemSessao.consultar(player)
		if not perfil then
			if personagemSessao.estadoCarga(player) == "carregando" then return nil, "Sua ficha ainda está carregando. Tente novamente." end
			if personagemSessao.estadoCarga(player) == "erro" then return nil, "Não foi possível carregar sua ficha. Saia e entre novamente." end
			return nil, "Crie um personagem próprio antes de iniciar."
		end
		-- O adaptador de ficha recebe somente dados mecânicos; cosméticos vivem no perfil pessoal.
		perfil.aparencia = nil
		return FichaPersonagemProprio.construir(perfil, perfil.nome, Catalogo)
	end

	-- Perfil sem árvore (P2: antes da 1ª provação) não valida como ficha J1/J2 (falta o kit), mas já
	-- tem atributos e perícias calculados: os testes dos eventos de caminho (F8) só precisam disso.
	local function fichaParaTestes(player)
		local ficha = corpoPessoal(player)
		if ficha then return ficha end
		local perfil = personagemSessao.consultar(player)
		if not perfil or type(perfil.atributos) ~= "table" or type(perfil.pericias) ~= "table" then return nil end
		return { calculated = { attributes = perfil.atributos, skills = perfil.pericias } }
	end

	handlers.requestSnapshot = function(player)
		remote:FireClient(player, "snapshot", snapshotFor(player))
		return nil
	end

	handlers.roll = function(player, payload, master)
		local budget = budgets[player]
		if os.clock() - budget.lastRoll < 0.4 then
			return "Aguarde um instante entre rolagens."
		end
		if type(payload.formula) ~= "string" or #payload.formula > LIMITS.formula then
			return "Fórmula inválida."
		end
		local mode = default(payload.mode, "normal")
		if not Protocol.isOneOf(mode, Protocol.MODES) then
			return "Modo de rolagem inválido."
		end
		local visibility = default(payload.visibility, "publica")
		if not Protocol.isOneOf(visibility, Protocol.VISIBILITY) then
			return "Visibilidade inválida."
		end
		local spec, parseError = Dice.parse(payload.formula)
		if not spec then
			return parseError or "Fórmula inválida."
		end
		budget.lastRoll = os.clock()
		local result = Dice.roll(random, spec, mode)
		local text = string.format("%s rolou %s", player.DisplayName, result.text)
		local secret = visibility ~= "publica"
		local audience = if secret
			then function(other)
				return other == player or Roles.isMaster(other)
			end
			else function()
				return true
			end
		logWhere(audience, if secret then "[Secreta] " .. text else text, if secret then "secreta" else "publica")
		sendRoll(audience, {
			by = player.DisplayName,
			text = result.text,
			total = result.total,
			natural = result.natural,
			critical = result.critical,
			secret = secret,
		})
		return nil
	end

	handlers.move = function(player, payload, master)
		local token = type(payload.id) == "string" and tokens[payload.id]
		if not token or not canSee(player, token) then
			return "Ficha não encontrada."
		end
		if not master and token.ownerUserId ~= player.UserId then
			return "Você só pode mover a sua ficha."
		end
		if not master and combat.active and currentTurnId() ~= token.id then
			return "Aguarde a vez dessa ficha."
		end
		local x, z = payload.x, payload.z
		if not Protocol.isCell(x, z) then
			return "Casa inválida."
		end
		if x == token.x and z == token.z then
			return nil
		end
		-- Regras de movimento: sempre para jogadores; para o mestre, quando o pedido vem
		-- da interface de jogo (`andar = true`: botão Andar ou clique na própria ficha na
		-- vez dela). Sem a marca, o mestre posiciona fichas livremente (arbitragem).
		local regras = not master or (payload.andar == true and combat.active and currentTurnId() == token.id)
		if regras and terrain[cellKey(x, z)] == "parede" then
			return "Há uma parede nessa casa."
		end
		if regras and habilidades and habilidades.bloqueiaMovimento(x, z) then
			return "Há uma barreira nessa casa."
		end
		-- Fichas ocultas não bloqueiam jogadores: recusar revelaria a posição.
		if occupant(x, z, if master then nil else player, token.id) then
			return "Casa ocupada."
		end
		if regras and habilidades then
			local falha = habilidades.validarMovimento(token, x, z, true, player)
			if falha then return falha end
		end
		local cells = Protocol.distance(token.x, token.z, x, z)
		local deX, deZ = token.x, token.z
		token.x, token.z = x, z
		token.version += 1
		avatares.moveu(token)
		corpos.moveu(token)
		if habilidades then
			habilidades.moveu(token, deX, deZ)
		end
		logAboutToken(
			token,
			string.format(
				"%s moveu %d casa(s) (%s m).",
				token.name,
				cells,
				(string.gsub(string.format("%.1f", cells * Protocol.METERS_PER_CELL), "%.", ","))
			)
		)
		return nil
	end

	handlers.adjust = function(player, payload, master)
		local token = type(payload.id) == "string" and tokens[payload.id]
		if not token or not canSee(player, token) then
			return "Ficha não encontrada."
		end
		if not master and token.ownerUserId ~= player.UserId then
			return "Você só pode alterar a sua ficha."
		end
		local field = payload.field
		if field ~= "pv" and field ~= "mana" then
			return "Campo inválido."
		end
		if not isInteger(payload.delta, -LIMITS.delta, LIMITS.delta) or payload.delta == 0 then
			return "Valor inválido."
		end
		local maxField = if field == "pv" then "pvMax" else "manaMax"
		local before = token[field]
		token[field] = math.clamp(before + payload.delta, 0, token[maxField])
		token.version += 1
		local change = token[field] - before
		logWhere(function(other)
			return canSeeStats(other, token)
		end, string.format("%s: %s %+d (%s).", token.name, if field == "pv" then "PV" else "mana", change, statLine(token)), if token.hidden then "secreta" else "publica")
		return nil
	end

	handlers.createToken = function(player, payload, master)
		if not master then
			return "Só o mestre cria fichas."
		end
		-- Treino, Desafio e PvP criam fichas em nome do sistema (master = true) para
		-- jogadores comuns: a revalidação depois do filtro só vale para quem era
		-- mestre de verdade (senão nenhum amigo começa partida no jogo publicado).
		local eraMestre = Roles.isMaster(player)
		if #tokenOrder >= LIMITS.tokens then
			return "Limite de fichas na mesa atingido."
		end
		local name = cleanName(payload.name)
		if not name then
			return "Nome inválido (1 a " .. LIMITS.name .. " caracteres)."
		end
		local kind = default(payload.kind, "npc")
		if not Protocol.isOneOf(kind, Protocol.KINDS) then
			return "Tipo inválido."
		end
		local pvMax = default(payload.pvMax, 10)
		local manaMax = default(payload.manaMax, 0)
		if not isInteger(pvMax, 0, LIMITS.stat) or not isInteger(manaMax, 0, LIMITS.stat) then
			return "PV ou mana inválidos."
		end
		local owner = default(payload.ownerUserId, 0)
		if owner ~= 0 and not isPresentUser(owner) then
			return "Dono precisa ser um jogador presente."
		end
		if payload.hidden ~= nil and type(payload.hidden) ~= "boolean" then
			return "Campo oculto inválido."
		end
		if payload.color ~= nil and typeof(payload.color) ~= "Color3" then
			return "Cor inválida."
		end
		local x, z = payload.x, payload.z
		if x ~= nil or z ~= nil then
			if not Protocol.isCell(x, z) then
				return "Casa inválida."
			end
		else
			x, z = math.ceil(Protocol.BOARD.width / 2), math.ceil(Protocol.BOARD.height / 2)
		end

		local startGeneration = generation
		local filtered = filterText(name, player.UserId)
		if not filtered then
			return "Não foi possível verificar o nome. Tente novamente."
		end
		-- Revalida o que pode ter mudado durante o filtro.
		if eraMestre and not stillMaster(player) then
			return "Você não é mais mestre."
		end
		if generation ~= startGeneration or campaignLoading or closing then
			return "A mesa foi substituída ou está sendo carregada. Crie a ficha de novo."
		end
		if owner ~= 0 and not isPresentUser(owner) then
			return "Dono precisa ser um jogador presente."
		end
		if #tokenOrder >= LIMITS.tokens then
			return "Limite de fichas na mesa atingido."
		end
		if occupant(x, z) or terrain[cellKey(x, z)] == "parede" then
			x, z = freeCellNear(x, z)
			if not x then
				return "Não há casa livre."
			end
		end

		nextId += 1
		local token = {
			id = "t" .. nextId,
			name = filtered,
			kind = kind,
			ownerUserId = owner,
			x = x,
			z = z,
			pv = pvMax,
			pvMax = pvMax,
			mana = manaMax,
			manaMax = manaMax,
			hidden = payload.hidden == true,
			showStats = kind == "jogador",
			color = payload.color or DEFAULT_COLORS[kind],
			version = 0, -- incrementa a cada mudança; protege edições que esperaram o filtro
		}
		tokens[token.id] = token
		table.insert(tokenOrder, token.id)
		logAboutToken(token, token.name .. " entrou na mesa.")
		return nil, token.id
	end

	handlers.updateToken = function(player, payload, master)
		if not master then
			return "Só o mestre edita fichas."
		end
		local token = type(payload.id) == "string" and tokens[payload.id]
		if not token then
			return "Ficha não encontrada."
		end
		-- Valida tudo antes de aplicar qualquer campo.
		local name
		if payload.name ~= nil then
			name = cleanName(payload.name)
			if not name then
				return "Nome inválido (1 a " .. LIMITS.name .. " caracteres)."
			end
		end
		for _, field in { "pv", "pvMax", "mana", "manaMax" } do
			if payload[field] ~= nil and not isInteger(payload[field], 0, LIMITS.stat) then
				return "Valor inválido em " .. field .. "."
			end
		end
		for _, field in { "hidden", "showStats" } do
			if payload[field] ~= nil and type(payload[field]) ~= "boolean" then
				return "Valor inválido em " .. field .. "."
			end
		end
		if payload.kind ~= nil and not Protocol.isOneOf(payload.kind, Protocol.KINDS) then
			return "Tipo inválido."
		end
		if payload.ownerUserId ~= nil and payload.ownerUserId ~= 0 and not isPresentUser(payload.ownerUserId) then
			return "Dono precisa ser um jogador presente."
		end
		if payload.color ~= nil and typeof(payload.color) ~= "Color3" then
			return "Cor inválida."
		end
		if name and name ~= token.name then
			local version, startGeneration = token.version, generation
			name = filterText(name, player.UserId)
			if not name then
				return "Não foi possível verificar o nome. Tente novamente."
			end
			if not stillMaster(player) then
				return "Você não é mais mestre."
			end
			if generation ~= startGeneration or campaignLoading or closing or tokens[token.id] ~= token or token.version ~= version then
				return "A ficha mudou durante a edição. Confira e tente de novo."
			end
			if payload.ownerUserId ~= nil and payload.ownerUserId ~= 0 and not isPresentUser(payload.ownerUserId) then
				return "Dono precisa ser um jogador presente."
			end
		end

		local wasHidden = token.hidden
		for _, field in { "kind", "ownerUserId", "pvMax", "manaMax", "pv", "mana", "hidden", "showStats", "color" } do
			if payload[field] ~= nil then
				token[field] = payload[field]
			end
		end
		if name then
			token.name = name
		end
		token.version += 1
		token.pv = math.min(token.pv, token.pvMax)
		token.mana = math.min(token.mana, token.manaMax)
		if wasHidden and not token.hidden then
			-- Revelada mas ainda na névoa: só quem a vê recebe o nome (D-19).
			logAboutToken(token, token.name .. " foi revelado.")
		end
		return nil
	end

	handlers.removeToken = function(player, payload, master)
		if not master then
			return "Só o mestre remove fichas."
		end
		local token = type(payload.id) == "string" and tokens[payload.id]
		if not token then
			return "Ficha não encontrada."
		end
		local wasTurn = currentTurnId() == token.id
		tokens[token.id] = nil
		table.remove(tokenOrder, table.find(tokenOrder, token.id))
		removeFromCombat(token.id)
		logAboutToken(token, token.name .. " saiu da mesa.")
		if wasTurn then
			combat.turn += 1
			announceTurn()
		end
		return nil
	end

	handlers.combatStart = function(player, payload, master)
		if not master then
			return "Só o mestre inicia combate."
		end
		local entries = payload.entries
		if type(entries) ~= "table" or #entries == 0 or #entries > LIMITS.tokens then
			return "Informe a iniciativa de pelo menos uma ficha."
		end
		-- Exige lista densa 1..n sem chaves extras; ipairs pararia no primeiro buraco.
		local count = 0
		for key in entries do
			count += 1
			if not isInteger(key, 1, #entries) then
				return "Lista de iniciativa inválida."
			end
		end
		if count ~= #entries then
			return "Lista de iniciativa inválida."
		end
		local seen, list = {}, {}
		for index, entry in ipairs(entries) do
			if type(entry) ~= "table" or type(entry.id) ~= "string" or not tokens[entry.id] or seen[entry.id] then
				return "Lista de iniciativa inválida."
			end
			if not isInteger(entry.initiative, -LIMITS.initiative, LIMITS.initiative) then
				return "Iniciativa inválida."
			end
			seen[entry.id] = true
			table.insert(list, { id = entry.id, initiative = entry.initiative, index = index })
		end
		-- Empate mantém a ordem enviada pelo mestre.
		table.sort(list, function(a, b)
			if a.initiative ~= b.initiative then
				return a.initiative > b.initiative
			end
			return a.index < b.index
		end)
		combat.order = {}
		for _, entry in list do
			table.insert(combat.order, entry.id)
		end
		combat.active, combat.round, combat.turnIndex = true, 1, 1
		combat.turn += 1
		logAll("Combate iniciado.", "sistema")
		announceTurn()
		return nil
	end

	handlers.nextTurn = function(player, payload, master)
		local id = currentTurnId()
		if not id then
			return "Não há combate em andamento."
		end
		-- Mesma resposta para ficha oculta ou alheia: não revela de quem é a vez.
		if not master and (not canSee(player, tokens[id]) or tokens[id].ownerUserId ~= player.UserId) then
			return "Não é a vez da sua ficha."
		end
		-- Pedido repetido (clique duplo) chega com a vez já trocada e é ignorado.
		-- expectedTurn cobre combate com uma ficha só, em que o id se repete.
		if payload.expectedTurn ~= nil and payload.expectedTurn ~= combat.turn then
			return nil
		end
		if payload.expectedId ~= nil and payload.expectedId ~= id then
			return nil
		end
		combat.turn += 1
		combat.turnIndex += 1
		if combat.turnIndex > #combat.order then
			combat.turnIndex = 1
			combat.round += 1
		end
		announceTurn()
		return nil
	end

	-- Jogador comum sai da partida: o dono do treino encerra o treino; em luta ou
	-- duelo, desiste (as fichas dele caem e a partida segue para os outros).
	handlers.sairPartida = function(player, payload, master)
		if not combat.active then
			return "Não há partida em andamento."
		end
		if treino.ativo() then
			local t = tokens[treino.tokenDoJogador() or ""]
			if master or (t and t.ownerUserId == player.UserId) then
				handlers.combatEnd(player, {}, true)
				handlers.tableClear(player, {}, true)
				logAll(player.DisplayName .. " saiu do treino.", "sistema")
				return nil
			end
			return "O treino é de outro jogador."
		end
		if encontro.desistir(player) then
			logAll(player.DisplayName .. " desistiu da partida.", "sistema")
			return nil
		end
		if master then
			return handlers.combatEnd(player, {}, true)
		end
		return "Você não está nesta partida."
	end

	handlers.combatEnd = function(player, payload, master)
		if not master then
			return "Só o mestre encerra combate."
		end
		if not combat.active then
			return nil
		end
		combat.active, combat.round, combat.order, combat.turnIndex = false, 0, {}, 0
		vezAnterior = nil
		habilidades.combateEncerrado()
		treino.desligar()
		encontro.desligar()
		logAll("Combate encerrado.", "sistema")
		return nil
	end

	-- Campanhas (M2) -----------------------------------------------------------

	local CAMPAIGN_COOLDOWN = 5 -- segundos entre salvar/carregar manuais
	-- Margem sob o limite de 4 MiB por chave do DataStore (revisão, opId e envelope do registro).
	local SAVE_BYTES_MAX = 4000000

	local function logMasters(text: string, tone: string)
		logWhere(Roles.isMaster, text, tone)
	end

	local function exportState()
		local list = {}
		local ordem = {}; local indice = 0
		for i, id in combat.order do if tokens[id] and not tokens[id].invocado then table.insert(ordem, id); if i <= combat.turnIndex then indice = #ordem end end end
		for _, id in tokenOrder do
			if not tokens[id].invocado then table.insert(list, tokens[id]) end
		end
		return {
			nextId = nextId,
			tokens = list,
			map = { terrain = table.clone(terrain), fog = table.clone(fog) },
			combat = {
				active = combat.active,
				round = combat.round,
				order = ordem,
				turnIndex = indice,
				turn = combat.turn,
			},
		}
	end

	local function importState(state)
		table.clear(tokens)
		table.clear(tokenOrder)
		for _, token in state.tokens do
			tokens[token.id] = token
			table.insert(tokenOrder, token.id)
		end
		nextId = state.nextId
		table.clear(terrain)
		table.clear(fog)
		for key, kind in (state.map and state.map.terrain) or {} do
			terrain[key] = kind
		end
		for key in (state.map and state.map.fog) or {} do
			fog[key] = true
		end
		combat.active = state.combat.active
		combat.round = state.combat.round
		combat.order = table.clone(state.combat.order)
		combat.turnIndex = state.combat.turnIndex
		-- turn só cresce: um nextTurn antigo com expectedTurn não acerta a mesa nova.
		combat.turn = math.max(combat.turn, state.combat.turn) + 1
		generation += 1
		if importacao then
			importacao.descartarTudo()
		end
		if habilidades then
			habilidades.descartarTudo()
		end
		if treino then
			treino.desligar()
		end
		if encontro then
			encontro.desligar()
		end
		vezAnterior = nil
	end

	local function validSlot(value: any): boolean
		return isInteger(value, 1, 5)
	end

	-- Salvamento automático só para o espaço que esta sessão carregou ou salvou
	-- (revisão-base conhecida) e sem conflito pendente. Falha temporária não bloqueia.
	local function canAutosave(): boolean
		return campaign.baseSlot ~= nil
			and campaign.slot == campaign.baseSlot
			and campaign.dirty
			and campaign.status ~= "conflito"
			and not campaignBusy
	end

	-- Salva a mesa atual. Usado pelo comando, pelo automático e pelo fechamento.
	local function saveCampaign(slot: number, force: boolean): (boolean, string)
		campaignBusy = true
		local previous = campaign.status
		campaign.status = "salvando"
		broadcast()
		-- Só a revisão do próprio espaço-base autoriza gravar sem force; outro
		-- espaço precisa estar vazio (D-10).
		local expected = if slot == campaign.baseSlot then campaign.revision else 0
		local snapshotChanges = changes
		-- encode recusa estado inválido com erro; a mesa não pode ficar presa em "salvando".
		local encodedOk, encoded = pcall(MesaSave.encode, exportState())
		if not encodedOk then
			campaignBusy = false
			campaign.status = if previous == "conflito" then "conflito" else "indisponivel"
			warn("[Mesa] falha ao preparar o salvamento:", encoded)
			return false, "Não foi possível preparar o salvamento: " .. tostring(encoded)
		end
		local tamanhoOk, tamanho = pcall(function()
			return #HttpService:JSONEncode(encoded)
		end)
		if not tamanhoOk or tamanho > SAVE_BYTES_MAX then
			campaignBusy = false
			campaign.status = if previous == "conflito" then "conflito" else "indisponivel"
			return false, string.format("Campanha grande demais para salvar (%s bytes; limite %d). Remova fichas importadas que não usa.", if tamanhoOk then tostring(tamanho) else "?", SAVE_BYTES_MAX)
		end
		local outcome, info, savedAt = persistence:save(slot, encoded, expected, force)
		campaignBusy = false
		if outcome == "ok" then
			campaign.slot, campaign.baseSlot = slot, slot
			campaign.revision, campaign.savedAt = info, savedAt
			campaign.dirty = changes ~= snapshotChanges
			campaign.status = "ok"
			return true, string.format("Campanha salva no espaço %d (revisão %d).", slot, info)
		elseif outcome == "invalido" then
			campaign.slot = slot
			campaign.status = "conflito"
			return false, "Não foi possível salvar: " .. tostring(info)
		elseif outcome == "conflito" then
			campaign.slot = slot
			campaign.status = "conflito"
			return false,
				string.format(
					"O espaço %d já tem outra gravação (revisão %d). Carregue esse espaço ou salve mesmo assim.",
					slot,
					info
				)
		end
		campaign.status = if previous == "conflito" then "conflito" else "indisponivel"
		return false, "Não foi possível salvar: " .. tostring(info)
	end

	local function campaignCooldown(): string?
		if os.clock() - lastCampaignOp < CAMPAIGN_COOLDOWN then
			return "Aguarde alguns segundos entre operações de campanha."
		end
		return nil
	end

	handlers.campaignSave = function(player, payload, master)
		if not master then
			return "Só o mestre salva a campanha."
		end
		local slot = if payload.slot == nil then campaign.slot else payload.slot
		if not validSlot(slot) then
			return "Escolha um espaço de 1 a 5."
		end
		if payload.force ~= nil and type(payload.force) ~= "boolean" then
			return "Valor inválido em force."
		end
		if campaignBusy or closing then
			return "Aguarde a operação de campanha em andamento."
		end
		local waiting = campaignCooldown()
		if waiting then
			return waiting
		end
		lastCampaignOp = os.clock()
		local ok, message = saveCampaign(slot, payload.force == true)
		logMasters(message, if ok then "sistema" else "erro")
		return nil
	end

	handlers.campaignLoad = function(player, payload, master)
		if not master then
			return "Só o mestre carrega a campanha."
		end
		if not validSlot(payload.slot) then
			return "Escolha um espaço de 1 a 5."
		end
		if campaignBusy or closing then
			return "Aguarde a operação de campanha em andamento."
		end
		local waiting = campaignCooldown()
		if waiting then
			return waiting
		end
		lastCampaignOp = os.clock()
		campaignBusy, campaignLoading = true, true
		local previous = campaign.status
		campaign.status = "carregando"
		broadcast()

		local function finish(status: string)
			campaignBusy, campaignLoading = false, false
			campaign.status = status
		end

		local record, failure, invalid = persistence:load(payload.slot)
		if invalid then
			-- Espaço ilegível: seleciona-o em conflito para o painel oferecer a substituição.
			campaign.slot = payload.slot
			finish("conflito")
			logMasters("Não foi possível carregar: " .. tostring(failure), "erro")
			return nil
		elseif failure then
			-- A mesa atual e sua revisão-base continuam valendo; o automático segue tentando.
			finish(if previous == "conflito" then "conflito" else "indisponivel")
			logMasters("Não foi possível carregar: " .. failure, "erro")
			return nil
		end
		local state, warnings = MesaSave.decode(if record then record.mesa else MesaSave.encode({
			nextId = 0,
			tokens = {},
			combat = { active = false, round = 0, order = {}, turnIndex = 0, turn = 0 },
		}))
		if not state then
			local reason = tostring(warnings and warnings[1])
			-- Conteúdo corrompido: seleciona o espaço em conflito para permitir substituir.
			-- Gravado por versão mais nova do jogo: não oferece sobrescrever.
			if string.find(reason, "versão mais nova", 1, true) then
				finish(previous)
			else
				campaign.slot = payload.slot
				finish("conflito")
			end
			logMasters(string.format("Espaço %d ilegível: %s", payload.slot, reason), "erro")
			return nil
		end

		-- Nomes salvos são filtrados de novo em nome de quem carrega.
		local replaced = 0
		for _, token in state.tokens do
			local filtered = filterText(token.name, player.UserId)
			if not filtered then
				replaced += 1
			end
			token.name = filtered or ("Ficha " .. token.id)
			-- Notas de condição também são texto digitado: filtradas de novo (D-18).
			for _, condition in token.conditions or {} do
				if condition.note then
					local note = filterText(condition.note, player.UserId)
					if not note then
						replaced += 1
					end
					condition.note = note
				end
			end
			-- Textos da ficha v2 (inventário, proficiências...): sem filtro, a ficha v2 sai.
			if token.ficha2 then
				local filtrados = {}
				for _, ref in FichaV2.textos(token.ficha2) do
					local original = ref[1][ref[2]]
					filtrados[original] = filtrados[original] or filterText(original, player.UserId)
					if not filtrados[original] then
						replaced += 1
						token.ficha2 = nil
						break
					end
					ref[1][ref[2]] = filtrados[original]
				end
			end
		end
		if not stillMaster(player) then
			finish(previous)
			return "Você não é mais mestre."
		end

		importState(state)
		changes += 1
		campaign.slot, campaign.baseSlot = payload.slot, payload.slot
		campaign.revision = if record then record.revision else 0
		campaign.savedAt = if record then record.savedAt else nil
		campaign.dirty = false
		finish("ok")
		logAll(string.format("%s carregou a campanha do espaço %d.", player.DisplayName, payload.slot), "sistema")
		for _, warning in warnings do
			logMasters("Aviso do salvamento: " .. warning, "erro")
		end
		if replaced > 0 then
			logMasters(string.format("%d texto(s) não puderam ser verificados pelo filtro: nomes viraram \"Ficha tN\" e notas foram removidas.", replaced), "erro")
		end
		if combat.active then
			announceTurn()
		end
		return nil
	end

	handlers.tableClear = function(player, payload, master)
		if not master then
			return "Só o mestre limpa a mesa."
		end
		table.clear(tokens)
		table.clear(tokenOrder)
		combat.active, combat.round, combat.order, combat.turnIndex = false, 0, {}, 0
		combat.turn += 1
		generation += 1
		importacao.descartarTudo()
		habilidades.descartarTudo()
		treino.desligar()
		encontro.desligar()
		vezAnterior = nil
		logAll("A mesa foi limpa.", "sistema")
		return nil
	end

	-- Condições do livro (M5) e mapa (M4) ----------------------------------

	local CONDITION_LIMIT = 12
	local NOTE_LIMIT = 60
	local PAINT_LIMIT = 200
	local TERRAIN_KINDS = { "parede", "dificil", "agua" }
	local BRUSHES = { "parede", "dificil", "agua", "limpar", "nevoa", "revelar" }

	local function controls(player: Player, token, master: boolean): boolean
		return master or token.ownerUserId == player.UserId
	end

	handlers.conditionAdd = function(player, payload, master)
		local token = type(payload.id) == "string" and tokens[payload.id]
		if not token or not canSee(player, token) then
			return "Ficha não encontrada."
		end
		if not controls(player, token, master) then
			return "Você só pode marcar condições na sua ficha."
		end
		if type(payload.condition) ~= "string" or not Condicoes.POR_ID[payload.condition] then
			return "Condição desconhecida."
		end
		if payload.stacks ~= nil and not isInteger(payload.stacks, 1, 20) then
			return "Acúmulos inválidos."
		end
		local note = nil
		if payload.note ~= nil then
			if type(payload.note) ~= "string" or utf8.len(payload.note) == nil or utf8.len(payload.note) > NOTE_LIMIT then
				return "Nota inválida (até " .. NOTE_LIMIT .. " caracteres)."
			end
			note = string.match(payload.note, "^%s*(.-)%s*$")
			if note == "" then
				note = nil
			end
		end
		if note then
			local version, startGeneration = token.version, generation
			note = filterText(note, player.UserId)
			if not note then
				return "Não foi possível verificar a nota. Tente novamente."
			end
			if generation ~= startGeneration or campaignLoading or closing or tokens[token.id] ~= token or token.version ~= version then
				return "A ficha mudou durante o pedido. Tente de novo."
			end
			-- Quem pediu pode ter saído ou perdido o papel durante o filtro (D-20).
			local nowMaster = player.Parent == Players and Roles.isMaster(player)
			if player.Parent ~= Players or not canSee(player, token) or not controls(player, token, nowMaster) then
				return "Você não pode mais alterar esta ficha."
			end
		end
		local before = #(token.conditions or {})
		local list, failure, messages = CondicaoRules.add(token.conditions or {}, Condicoes, payload.condition, payload.stacks, note)
		if not list then
			return failure
		end
		if #list > CONDITION_LIMIT and #list > before then
			return "Limite de " .. CONDITION_LIMIT .. " condições por ficha."
		end
		token.conditions = list
		token.version += 1
		local labels = CondicaoRules.labels(list, Condicoes)
		logAboutToken(token, string.format("%s: %s.", token.name, if #labels > 0 then table.concat(labels, ", ") else "sem condições"))
		for _, message in messages do
			logAboutToken(token, message)
		end
		return nil
	end

	handlers.conditionRemove = function(player, payload, master)
		local token = type(payload.id) == "string" and tokens[payload.id]
		if not token or not canSee(player, token) then
			return "Ficha não encontrada."
		end
		if not controls(player, token, master) then
			return "Você só pode tirar condições da sua ficha."
		end
		if type(payload.condition) ~= "string" or not Condicoes.POR_ID[payload.condition] then
			return "Condição desconhecida."
		end
		if payload.stacks ~= nil and not isInteger(payload.stacks, 1, 20) then
			return "Acúmulos inválidos."
		end
		local list, failure, messages = CondicaoRules.remove(token.conditions or {}, Condicoes, payload.condition, payload.stacks)
		if not list then
			return failure
		end
		token.conditions = list
		token.version += 1
		local labels = CondicaoRules.labels(list, Condicoes)
		logAboutToken(token, string.format("%s: %s.", token.name, if #labels > 0 then table.concat(labels, ", ") else "sem condições"))
		for _, message in messages do
			logAboutToken(token, message)
		end
		return nil
	end

	handlers.paintCells = function(player, payload, master)
		if not master then
			return "Só o mestre edita o mapa."
		end
		local brush = payload.brush
		if not Protocol.isOneOf(brush, BRUSHES) then
			return "Pincel inválido."
		end
		local cells = payload.cells
		if type(cells) ~= "table" or #cells == 0 or #cells > PAINT_LIMIT then
			return "Informe de 1 a " .. PAINT_LIMIT .. " casas."
		end
		-- Lista densa 1..n sem chaves extras (D-21).
		local count = 0
		for key in cells do
			count += 1
			if not isInteger(key, 1, #cells) then
				return "Lista de casas inválida."
			end
		end
		if count ~= #cells then
			return "Lista de casas inválida."
		end
		-- Valida tudo antes de pintar qualquer casa.
		local keys = {}
		for index = 1, #cells do
			local cell = cells[index]
			if type(cell) ~= "table" or not Protocol.isCell(cell.x, cell.z) then
				return "Casa inválida."
			end
			table.insert(keys, cellKey(cell.x, cell.z))
		end
		for _, key in keys do
			if brush == "nevoa" then
				fog[key] = true
			elseif brush == "revelar" then
				fog[key] = nil
			elseif brush == "limpar" then
				terrain[key] = nil
			else
				terrain[key] = brush
			end
		end
		return nil
	end

	handlers.fogAll = function(player, payload, master)
		if not master then
			return "Só o mestre edita o mapa."
		end
		if type(payload.covered) ~= "boolean" then
			return "Valor inválido."
		end
		table.clear(fog)
		if payload.covered then
			for x = 1, Protocol.BOARD.width do
				for z = 1, Protocol.BOARD.height do
					fog[cellKey(x, z)] = true
				end
			end
		end
		logMasters(if payload.covered then "Tabuleiro coberto pela névoa." else "Névoa removida do tabuleiro.", "sistema")
		return nil
	end

	-- Fichas importadas do site (M3) -----------------------------------------
	-- Os valores chegam calculados pela ferramenta tools/ficha-para-mesa; aqui só
	-- se valida (FichaImport) e se reaproveita criar/editar, que já tratam filtro
	-- de nome, posição, dono e pedidos que esperam o filtro.

	local CODE_LIMIT = 1000

	handlers.importToken = function(player, payload, master)
		if not master then
			return "Só o mestre importa fichas."
		end
		local length = if type(payload.code) == "string" then utf8.len(payload.code) else nil
		if not length or length == 0 or length > CODE_LIMIT then
			return "Cole o código de ficha gerado pela ferramenta (até " .. CODE_LIMIT .. " caracteres)."
		end
		local decodedOk, decoded = pcall(function()
			return HttpService:JSONDecode(payload.code)
		end)
		if not decodedOk then
			return "Código de ficha ilegível: não é um JSON válido."
		end
		local data, failure, warnings = FichaImport.parse(decoded)
		if not data then
			return "Código de ficha recusado: " .. tostring(failure)
		end

		local id
		if payload.id ~= nil then
			if type(payload.id) ~= "string" or not tokens[payload.id] then
				return "Ficha não encontrada."
			end
			failure = handlers.updateToken(player, {
				id = payload.id,
				name = data.name,
				pvMax = data.pvMax,
				manaMax = data.manaMax,
				pv = data.pv,
				mana = data.mana,
			}, master)
			id = payload.id
		else
			failure, id = handlers.createToken(player, {
				name = data.name,
				kind = "jogador",
				pvMax = data.pvMax,
				manaMax = data.manaMax,
				ownerUserId = payload.ownerUserId,
				hidden = payload.hidden,
				x = payload.x,
				z = payload.z,
			}, master)
		end
		if failure then
			return failure
		end
		-- Sem yield desde o retorno de criar/editar: a ficha ainda é a mesma.
		local token = tokens[id]
		token.pv, token.mana = data.pv, data.mana
		token.sheet = data.sheet
		token.version += 1
		logMasters(string.format("Ficha importada: %s (%s).", token.name, statLine(token)), "sistema")
		for _, warning in warnings do
			logMasters("Aviso da importação: " .. warning, "erro")
		end
		return nil
	end

	handlers.rollInitiative = function(player, payload, master)
		if not master then
			return "Só o mestre rola a iniciativa."
		end
		local ids = payload.ids
		if type(ids) ~= "table" or #ids == 0 or #ids > LIMITS.tokens then
			return "Marque ao menos uma ficha para a iniciativa."
		end
		local count = 0
		for key in ids do
			count += 1
			if not isInteger(key, 1, #ids) then
				return "Lista de fichas inválida."
			end
		end
		if count ~= #ids then
			return "Lista de fichas inválida."
		end
		-- Valida a lista inteira antes de rolar: pedido recusado não consome dados.
		local chosen, seen = {}, {}
		for _, id in ipairs(ids) do
			local token = type(id) == "string" and tokens[id]
			if not token or seen[id] then
				return "Lista de fichas inválida."
			end
			seen[id] = true
			table.insert(chosen, token)
		end
		-- Mesmo intervalo das rolagens comuns (compartilhado com roll).
		local budget = budgets[player]
		if os.clock() - budget.lastRoll < 0.4 then
			return "Aguarde um instante entre rolagens."
		end
		budget.lastRoll = os.clock()
		local d20 = Dice.parse("1d20")
		local rolls = {}
		for index, token in chosen do
			local bonus = if token.sheet then token.sheet.iniciativa else 0
			local advantage = token.sheet ~= nil and token.sheet.vantagemIniciativa
			local result = Dice.roll(random, d20, if advantage then "vantagem" else "normal")
			table.insert(rolls, {
				token = token,
				bonus = bonus,
				total = result.total + bonus,
				index = index,
				text = result.text,
				natural = result.natural,
				critical = result.critical,
			})
		end
		for _, roll in rolls do
			logAboutToken(roll.token, string.format("Iniciativa de %s: %s; bônus %+d → %d.", roll.token.name, roll.text, roll.bonus, roll.total))
			sendRoll(function(other)
				return canSee(other, roll.token)
			end, {
				by = roll.token.name,
				label = "Iniciativa",
				text = roll.text,
				total = roll.total,
				natural = roll.natural,
				critical = roll.critical,
				secret = roll.token.hidden or inFog(roll.token),
				tokenId = roll.token.id,
			})
		end
		-- combatStart desempata pela ordem recebida; ordenar por bônus antes faz o
		-- desempate ser maior bônus e depois a ordem do mestre.
		table.sort(rolls, function(a, b)
			if a.bonus ~= b.bonus then
				return a.bonus > b.bonus
			end
			return a.index < b.index
		end)
		local entries = {}
		for _, roll in rolls do
			table.insert(entries, { id = roll.token.id, initiative = roll.total })
		end
		return handlers.combatStart(player, { entries = entries }, master)
	end

	importacao = FichaV2Import.start({
		remote = remote,
		handlers = handlers,
		tokens = tokens,
		catalogo = Catalogo,
		filterText = filterText,
		stillMaster = stillMaster,
		generation = function()
			return generation
		end,
		ocupado = function()
			return campaignLoading or closing
		end,
		isPresentUser = isPresentUser,
		canSeeStats = canSeeStats,
		logMasters = logMasters,
	})

	-- Criatura derrotada sai da mesa depois da animação (fora do despachante).
	local function removerFicha(id: string)
		local token = tokens[id]
		if not token then
			return
		end
		local wasTurn = currentTurnId() == id
		tokens[id] = nil
		table.remove(tokenOrder, table.find(tokenOrder, id))
		removeFromCombat(id)
		if wasTurn then
			combat.turn += 1
			announceTurn()
		end
		changes += 1
		campaign.dirty = true
		broadcast()
	end

	-- Mudança feita fora do despachante (tarefa atrasada): marca e envia.
	local function mudou()
		changes += 1
		campaign.dirty = true
		broadcast()
	end

	-- Passa a vez de quem a tem (usado pelo treino para pular os bonecos).
	local function avancarVez(esperadoId: string)
		if not combat.active or currentTurnId() ~= esperadoId then
			return
		end
		combat.turn += 1
		combat.turnIndex += 1
		if combat.turnIndex > #combat.order then
			combat.turnIndex = 1
			combat.round += 1
		end
		announceTurn()
		mudou()
	end

	treino = TreinoService.start({
		grupo = function() return salaConceitual and salaConceitual.grupoTreino() end,
		montagem = montagemPartida,
		combat = combat,
		personagemDe = function(player)
			return encontro.personagemDe(player)
		end,
		validarPersonagem = function(player) return encontro.validarPersonagem(player) end,
		criarPersonagem = function(player, dono, x, z) return encontro.criarPersonagem(player, dono, x, z) end,
		handlers = handlers,
		tokens = tokens,
		avancarVez = avancarVez,
		mudou = mudou,
		logAll = logAll,
	})

	encontro = EncontroService.start({
		corpoPessoal = corpoPessoal,
		abrirLoja = lojaService.abrir,
		limiteGrupo = 10,
		solicitanteParticipa = function(p) return not salaConceitual or salaConceitual.participa(p) end,
		monstrosManuais = function() return salaConceitual and salaConceitual.monstros() end,
		montagem = montagemPartida,
		handlers = handlers,
		tokens = tokens,
		combat = combat,
		random = random,
		remote = remote,
		habilidades = function()
			return habilidades
		end,
		avancarVez = avancarVez,
		mudou = mudou,
		logAll = logAll,
		currentTurnId = currentTurnId,
		desligarTreino = function()
			treino.desligar()
		end,
	})

	habilidades = HabilidadeService.start({
		remote = remote,
		handlers = handlers,
		tokens = tokens,
		tokenOrder = tokenOrder,
		combat = combat,
		random = random,
		catalogo = Catalogo,
		premontados = Premontados,
		canSee = canSee,
		currentTurnId = currentTurnId,
		logAboutToken = logAboutToken,
		terrain = terrain,
		cellKey = cellKey,
		removerFicha = removerFicha,
		-- Movimento feito por habilidade (investida, Passo de Vento, empurrão já
		-- move a ficha direto): avatar anda e o registro fica no recibo.
		moverFicha = function(token, x, z)
			local deX, deZ = token.x, token.z
			token.x, token.z = x, z
			token.version += 1
			avatares.moveu(token)
			corpos.moveu(token)
			if habilidades then
				habilidades.moveu(token, deX, deZ)
			end
		end,
		reviverBoneco = function(token)
			treino.reviver(token)
		end,
		virarPara = function(token, x, z)
			require(ReplicatedStorage.Shared.VisaoFurtiva).virar(token, x, z)
			corpos.olhar(token, x, z)
		end,
		emDuelo = function()
			return encontro ~= nil and encontro.emDuelo()
		end,
		mesmaEquipe = function(a, b) return encontro ~= nil and encontro.mesmaEquipe(a, b) end,
	})

	ProgressaoService.start({
		handlers = handlers,
		tokens = tokens,
		combat = combat,
		catalogo = Catalogo,
		canSee = canSee,
		logAboutToken = logAboutToken,
		emTreino = function()
			return treino.ativo()
		end,
	})

	-- Entrada ------------------------------------------------------------------

	local CAPACITY, REFILL = 8, 8 -- pedidos acumuláveis e recarga por segundo

	-- Comandos que podem mudar o que é salvo.
	local MUTATING = {
		move = true,
		adjust = true,
		createToken = true,
		updateToken = true,
		removeToken = true,
		combatStart = true,
		nextTurn = true,
		combatEnd = true,
		tableClear = true,
		importToken = true,
		rollInitiative = true,
		conditionAdd = true,
		conditionRemove = true,
		paintCells = true,
		fogAll = true,
		fichaImportApply = true,
		usarHabilidade = true,
		reagir = true,
		sairPartida = true,
		desenharFormula = true,
		continuarFormula = true,
		cancelarFormula = true,
		prepararFormula = true,
		ativarFormula = true,
		tocarFormula = true,
		apagarFogo = true,
		criarCriatura = true,
		criarPremontado = true,
		abrirRank = true,
		aprender = true,
		iniciarTreino = true,
		iniciarLuta = true,
		iniciarDuelo = true,
	}

	-- Comandos que não mudam o que os outros veem: sem snapshot para todos.
	local QUIET = {
		personagemPessoalConsultar = true,
		personagemPessoalCriar = true,
		personagemPessoalAprender = true,
		personagemPessoalEquiparArma = true,
		missaoAcao = true,
		salaOlhar = true,
		requestSnapshot = true,
		roll = true,
		fichaImportBegin = true,
		fichaImportPart = true,
		fichaImportAbort = true,
		fichaDetalhe = true,
	}

	local function allow(player: Player): boolean
		local budget = budgets[player]
		if not budget then
			return false
		end
		local now = os.clock()
		budget.tokens = math.min(CAPACITY, budget.tokens + (now - budget.stamp) * REFILL)
		budget.stamp = now
		if budget.tokens < 1 then
			return false
		end
		budget.tokens -= 1
		return true
	end

	-- Caminho único de todo comando: o remoto e a inspeção do Studio passam por
	-- aqui, com as mesmas recusas e o mesmo registro de mudanças (D-22).
	-- Devolve a mensagem de erro (ou nil). master = nil usa o papel real.
	salaConceitual = require(script.Parent.SalaService).start({handlers=handlers,combat=combat,random=random,mudou=mudou,logTo=logTo})
	Roles.vincularSala(salaConceitual.mestre)
	require(script.Parent.SalaWorld).create()
	require(script.Parent.SalaAvatares).start({sala=salaConceitual.publico,combat=combat})
	local function dispatch(player, command: any, payload: any, master: boolean?): string?
		local handler = type(command) == "string" and handlers[command]
		if not handler then
			return "Comando desconhecido."
		end
		if payload == nil then
			payload = {}
		elseif type(payload) ~= "table" then
			return "Pedido inválido."
		end
		-- Mudanças aceitas durante o carregamento seriam apagadas por ele (D-13).
		local recusado=salaConceitual.guardar(player,command)
		if recusado then return recusado end
		if MUTATING[command] and (campaignLoading or closing) then
			return "Aguarde: a campanha está sendo carregada ou o servidor está fechando."
		end
		local ok, failure = pcall(handler, player, payload, if master == nil then Roles.isMaster(player) else master)
		if not ok then
			warn("[Mesa] erro em", command, failure)
			return "Erro interno ao processar o pedido."
		end
		if not failure and MUTATING[command] then
			changes += 1
			campaign.dirty = true
		end
		if not QUIET[command] then
			broadcast()
		end
		return failure
	end

	remote.OnServerEvent:Connect(function(player: Player, command: any, payload: any)
		if type(command) ~= "string" or not handlers[command] or not allow(player) then
			return
		end
		if payload ~= nil and type(payload) ~= "table" then
			return
		end
		local failure = dispatch(player, command, payload)
		if failure then
			logTo(player, failure, "erro")
		end
	end)

	local adminCombate = require(script.Parent.AdminCombate).start({
		tokens = tokens, combat = combat, mudou = mudou,
		bloqueada = function(x, z) return terrain[cellKey(x,z)] == "parede" or habilidades.bloqueiaMovimento(x,z) end,
		pv = habilidades.adminPV, limpar = habilidades.adminLimpar, acoes = habilidades.adminAcoes,
		passar = function(player) return dispatch(player, "nextTurn", { expectedTurn = combat.turn }, true) end,
		mover = function(token, x, z)
			local deX, deZ = token.x, token.z
			token.x, token.z = x, z; token.version += 1
			avatares.moveu(token); corpos.moveu(token)
			habilidades.moveu(token, deX, deZ)
		end,
	})
	require(script.Parent.AdminService).start({
		tokens = tokens, combat = combat, isAdmin = Roles.isAdmin, mudou = mudou,
		sala = function(player,cmd) return salaConceitual.admin(player,cmd) end,
		combate = adminCombate,
		bloqueado = function() return campaignLoading or closing end,
		encerrar = function(player) return dispatch(player, "combatEnd", {}, true) end,
		-- Troca de papel não suja a campanha: só reenvia a visão de cada um.
		definirModoJogador = function(player, ativo)
			if salaConceitual.publico() then return "O mestre da sala é escolhido pela mesa. Use Pessoas e equipes no escudo para transferir o posto." end
			Roles.definirModoJogador(player, ativo); broadcast()
		end,
		-- Diversão não pode marcar onde está um avatar furtivo, oculto ou na névoa.
		avatarSecreto = function(player)
			for _, token in tokens do
				if token.ownerUserId == player.UserId and avatares.ehAvatar(token)
					and (token.hidden == true or fog[cellKey(token.x, token.z)] == true or Furtividade.escondido(token)) then
					return true
				end
			end
			return false
		end,
		auditar = function(player, comando) print("[Admin]", player.UserId, comando) end,
	})

	local function playerAdded(player: Player)
		budgets[player] = { tokens = CAPACITY, stamp = os.clock(), lastRoll = 0 }
		Roles.added(player)
		salaConceitual.entrar(player)
		broadcast()
		logAll(player.DisplayName .. " entrou na mesa.", "sistema")
		task.spawn(function()
			local ok, motivo = personagemSessao.carregar(player)
			if not ok and player.Parent == Players then
				logTo(player, motivo, "erro")
			end
		end)
	end

	Players.PlayerAdded:Connect(playerAdded)
	for _, player in Players:GetPlayers() do
		playerAdded(player)
	end

	local function autosave(reason: string)
		if canAutosave() then
			local ok, message = saveCampaign(campaign.baseSlot, false)
			logMasters(reason .. ": " .. message, if ok then "sistema" else "erro")
			broadcast()
		end
	end

	task.spawn(function()
		while true do
			task.wait(60)
			if not closing then
				-- Um erro inesperado não pode encerrar o laço do salvamento automático.
				local ok, failure = pcall(autosave, "Salvamento automático")
				if not ok then
					warn("[Mesa] salvamento automático falhou:", failure)
				end
			end
		end
	end)

	-- Fechamento: bloqueia novas mudanças, espera a operação em andamento e grava
	-- o estado final. O Roblox dá cerca de 30 s ao BindToClose (D-11).
	-- Inspeção só no Studio, para testes automáticos (tools/playtest): mostra a
	-- mesa como um jogador comum a veria. ServerStorage não chega aos clientes,
	-- e fora do Studio este objeto nem é criado.
	if RunService:IsStudio() then
		local debug = Instance.new("BindableFunction")
		debug.Name = "MesaDebug"
		debug.OnInvoke = function(action: string, ...)
			if action == "snapshotOf" then
				-- Visão de um jogador real (ex.: o mestre do teste).
				local player = ...
				return snapshotFor(player)
			elseif action == "snapshotAs" then
				local userId = ...
				return snapshotFor({ UserId = userId } :: any)
			elseif action == "commandAs" then
				-- Executa um comando como jogador comum (sem papel de mestre) e
				-- devolve o erro, se houver. Não passa pelo limite de frequência.
				local userId, command, payload = ...
				local fake = { UserId = userId, DisplayName = "Teste" .. userId, Parent = Players } :: any
				budgets[fake] = { tokens = CAPACITY, stamp = os.clock(), lastRoll = 0 }
				local failure = dispatch(fake, command, payload, false)
				budgets[fake] = nil
				return failure
			elseif action == "setOwner" then
				local id, userId = ...
				if tokens[id] then
					tokens[id].ownerUserId = userId
					tokens[id].version += 1
					changes += 1
					campaign.dirty = true
					broadcast()
					return true
				end
			end
			return nil
		end
		debug.Parent = game:GetService("ServerStorage")
	end

	game:BindToClose(function()
		closing = true
		local deadline = os.clock() + 20
		while campaignBusy and os.clock() < deadline do
			task.wait(0.25)
		end
		autosave("Servidor fechando")
	end)

	Players.PlayerRemoving:Connect(function(player)
		personagemSessao.remover(player)
		encontro.remover(player)
		budgets[player] = nil
		Roles.removed(player)
		salaConceitual.sair(player)
		-- Fichas do jogador ficam na mesa; o mestre pode trocar o dono.
		task.defer(function()
			broadcast()
			logAll(player.DisplayName .. " saiu da mesa.", "sistema")
		end)
	end)

	-- Dependências privadas para outros modos do jogo; não expõe ficha em remoto.
	return table.freeze({
		registrarHandler = function(nome, handler)
			if type(nome) ~= "string" or type(handler) ~= "function" or handlers[nome] ~= nil then return false end
			handlers[nome] = handler
			return true
		end,
		acaoMissaoPessoal = function(player, acao, missaoId)
			return personagemSessao.acaoMissao(player, acao, missaoId)
		end,
		sincronizarArvoresRun = personagemSessao.sincronizarArvoresRun,
		observarPerfilPessoal = personagemSessao.observarPerfil,
		alterarAparenciaPessoal = personagemSessao.alterarAparencia,
		consultarPerfilPessoal = function(player)
			return personagemSessao.consultar(player)
		end,
		avisarPessoal = function(player, texto)
			if player and type(texto) == "string" then logTo(player, texto, "sistema") end
		end,
		corpoPessoal = corpoPessoal,
		fichaParaTestes = fichaParaTestes,
		descansarPessoal = function(player, tipo)
			return personagemSessao.descansar(player, tipo)
		end,
		consumirItemPessoal = function(player, itemId, sourceLocalId)
			return personagemSessao.consumirItem(player, itemId, sourceLocalId)
		end,
		recompensarEncontroPessoal = function(player, encounterId, moedas, marcoId, pa)
			return personagemSessao.recompensarEncontro(player, encounterId, moedas, marcoId, pa)
		end,
		atualizarDojoPessoal = function(player, estado)
			return personagemSessao.atualizarDojo(player, estado)
		end,
		consultarDojoPessoal = function(player)
			return personagemSessao.consultar(player)
		end,
		emCombate = function() return combat.active or montagemPartida.ocupada() end,
		-- Modo História (PLANO §13): luta da patrulha no tabuleiro da mesa, iniciada só pelo servidor.
		iniciarLutaDoMundo = function(grupo, criaturas, opcoes)
			return encontro.iniciarLutaDoMundo(grupo, criaturas, opcoes)
		end,
	})
end

return MesaService
