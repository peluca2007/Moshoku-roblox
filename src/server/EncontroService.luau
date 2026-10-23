-- Encontros de jogo (J2): Luta (cooperativa, contra criaturas com IA) e Duelo
-- (PvP, cada jogador por si). Pedido do Pedro: "dá uma polida no jogo" e "foca no
-- PvP, daí meus amigos já testam".
--
-- - Cada jogador escolhe um personagem pronto (um por árvore inicial, gerado com as
--   regras do site: tools/fixtures/premontados.mts). A escolha vale para Treino,
--   Luta e Duelo.
-- - Luta: participantes da fila (até 4), com desafios 1/2/3.
-- - PvP: participantes da fila (até 32), equipes 1/2 ou cada dono por si.
-- - Recursos não voltam entre turnos; ao fim, todos se recuperam (descanso
--   automático: adaptação, ver docs/FIDELIDADE.md §7E).
-- - Com mais de um jogador, cada vez tem prazo: quem passa dele perde o resto da
--   vez (ninguém trava a partida dos outros).
-- O servidor decide tudo; a IA usa o mesmo caminho de dano das habilidades.
local Players = game:GetService("Players")
local Personagens = require(game:GetService("ReplicatedStorage").Shared.PersonagensProntos)
local Armas = require(game:GetService("ReplicatedStorage").Shared.Regras.Armas)
local Maestrias = require(game:GetService("ReplicatedStorage").Shared.Regras.Maestrias)
local Catalogo = require(game:GetService("ReplicatedStorage").Shared.Livro.Catalogo)
local Equipes = require(game:GetService("ReplicatedStorage").Shared.Regras.Equipes)
local Chefes = require(game:GetService("ReplicatedStorage").Shared.Regras.Chefes)
local ChefesService = require(script.Parent.ChefesService)
local TravaPartida = require(game:GetService("ReplicatedStorage").Shared.TravaPartida)
local Corpos = require(script.Parent.CorposDeCriatura)

local EncontroService = {}

-- Encontros por tamanho do grupo (criatura, casa). Um personagem sozinho não
-- aguenta o dano por turno do Apêndice G de vários inimigos.
local ENCONTROS = {
	goblin = { nome = "Um goblin batedor", criaturas = { { "creature/goblin-batedor", 10, 6 } } },
	goblins = { nome = "Dois goblins batedores", criaturas = { { "creature/goblin-batedor", 9, 6 }, { "creature/goblin-batedor", 12, 7 } } },
	lobo = { nome = "Lobo cinzento e goblin", criaturas = { { "creature/lobo-cinzento", 10, 5 }, { "creature/goblin-batedor", 7, 7 } } },
	bando = { nome = "Lobo, goblins e um bandido", criaturas = {
		{ "creature/lobo-cinzento", 10, 4 }, { "creature/goblin-batedor", 6, 6 }, { "creature/goblin-batedor", 14, 6 },
		{ "creature/bandido-de-estrada", 10, 7 } } },
}
local ENCONTRO_DO_GRUPO = { "goblin", "lobo", "bando", "bando" }
local CASAS_DO_GRUPO = { { 10, 15 }, { 7, 15 }, { 13, 15 }, { 10, 17 }, {4,15}, {16,15}, {4,17}, {7,17}, {13,17}, {16,17} }
-- Luta do mundo: inimigos da patrulha diante do grupo, mesma distância dos encontros da sala.
local CASAS_INIMIGAS = { { 10, 6 }, { 7, 6 }, { 13, 6 }, { 10, 4 }, { 4, 6 }, { 16, 6 }, { 7, 4 }, { 13, 4 } }
local ATRASO_DA_IA, ATRASO_APOS_AGIR = 0.9, 1.7
local PRAZO_DA_VEZ = 60 -- segundos, só com mais de um jogador
local PADRAO = "mago-de-fogo"
local PESSOAL = "personagem-pessoal"

local VALIDOS = {}
for _, p in Personagens do
	VALIDOS[p.id] = p
end

-- deps: handlers, tokens, combat, random, remote, habilidades() -> HabilidadeService,
-- avancarVez(id), mudou(), logAll(texto, tom), currentTurnId(), desligarTreino()
function EncontroService.start(deps)
	local handlers, tokens, combat = deps.handlers, deps.tokens, deps.combat
	local estado = { ativo = false, modo = nil :: string?, prazoFim = nil :: number?, prazoId = nil :: string?, mundo = nil :: any }
	-- Injetáveis para teste (duelo precisa de 2+ jogadores; o Studio via MCP abre 1).
	local jogadores = deps.jogadores or function()
		return Players:GetPlayers()
	end
	local agora = deps.agora or function()
		return workspace:GetServerTimeNow()
	end
	local esperaDoFim = deps.esperaDoFim or 1.2
	local escolhas: { [number]: string } = {}
	local armasEscolhidas: { [number]: string } = {}
	local montagemComArma
	-- HabilidadeService instala criarPremontado depois do start deste serviço.
	-- Instalação tardia mantém Treino/Luta/Duelo no mesmo caminho de montagem.
	local function instalarMontagem()
		if not handlers.criarPremontado or handlers.criarPremontado == montagemComArma then return end
		local montagemOriginal = handlers.criarPremontado
		montagemComArma = function(player, payload, master)
			if not master then return "Só o mestre cria personagens prontos." end
			if type(payload) ~= "table" then return "Pedido de personagem inválido." end
			local dono = payload.ownerUserId or player.UserId
			local idArma = payload.arma
			if idArma == nil and escolhas[dono] == payload.id then idArma = armasEscolhidas[dono] end
			local arma, erro = Armas.validar({ id = payload.id, arma = idArma })
			if not arma then return erro end
			local falha, criado = montagemOriginal(player, payload, master)
			if falha then return falha end
			local token = criado and tokens[criado.id]
			if token and token.ficha2 and token.ficha2.construction then
				local e = Armas.aplicar(token.ficha2, payload.id, arma.id)
				if e then return e end
				token.version += 1
			end
			return nil, criado
		end
		handlers.criarPremontado = montagemComArma
	end
	local fila: { [number]: string } = {}
	local equipesEscolhidas, equipesAtuais, ultimosPedidos = {}, {}, {}
	local chefeAtual, nivelAtual = nil, nil
	local depsChefes = table.clone(deps)
	depsChefes.secreto = deps.secreto or Corpos.secreto
	local chefes = ChefesService.start(depsChefes)
	local function limitar(player, comando)
		local chave = tostring(player.UserId) .. ":" .. comando
		local tempo = agora()
		if ultimosPedidos[chave] and tempo - ultimosPedidos[chave] < .6 then return "Espere um instante antes de repetir." end
		ultimosPedidos[chave] = tempo
		return nil
	end
	local geracao, participantesAtuais = 0, 0
	local montagem = deps.montagem or TravaPartida.new()
	local function participantes(modo, solicitante)
		if not deps.solicitanteParticipa or deps.solicitanteParticipa(solicitante) then fila[solicitante.UserId] = modo end
		local grupo = {}
		for _, p in jogadores() do
			if fila[p.UserId] == modo then table.insert(grupo, p) end
		end
		if #grupo > (if modo == "duelo" then 32 else deps.limiteGrupo or 4) then
			fila[solicitante.UserId] = nil
			return nil
		end
		return grupo
	end

	-- Luta do mundo: cada jogador entra com o personagem próprio da run, nunca o pronto da sala.
	local forcarPessoal = false
	local function personagemDe(player: Player): string
		instalarMontagem()
		if forcarPessoal then return PESSOAL end
		local id = escolhas[player.UserId]
		return if id == PESSOAL or (id and VALIDOS[id]) then id else PADRAO
	end

	-- Valida antes de qualquer limpeza da mesa. Não volta silenciosamente ao padrão.
	local function validarPersonagem(player)
		if personagemDe(player) ~= PESSOAL then return nil end
		if not deps.corpoPessoal then return "Crie um personagem próprio nesta sessão." end
		local corpo, erro = deps.corpoPessoal(player)
		return if corpo then nil else erro or "Personagem próprio indisponível."
	end
	local function validarGrupo(grupo)
		for _, p in grupo do
			local erro = validarPersonagem(p)
			if erro then return erro end
		end
		return nil
	end
	-- Chamado apenas pela montagem dos modos; nenhum remoto consulta ficha por dono.
	local function criarPersonagem(solicitante, dono, x, z)
		local id = personagemDe(dono)
		local posicao = { ownerUserId = dono.UserId, x = x, z = z }
		if id == PESSOAL then
			if not deps.corpoPessoal then return "Crie um personagem próprio nesta sessão." end
			local corpo, erro = deps.corpoPessoal(dono)
			if not corpo then return erro or "Personagem próprio indisponível." end
			local hab = deps.habilidades and deps.habilidades()
			if not hab or not hab.criarPersonagemPessoal then return "Montagem pessoal indisponível." end
			return hab.criarPersonagemPessoal(solicitante, corpo, posicao)
		end
		posicao.id = id
		return handlers.criarPremontado(solicitante, posicao, true)
	end

	local function vivo(t): boolean
		return not t.derrotado and t.pv > 0
	end
	local function inimigosVivos()
		local n = 0
		for _, t in tokens do
			if (t.ia or t.monstroDoMestre) and vivo(t) then
				n += 1
			end
		end
		return n
	end
	local function aliadosVivos()
		local n = 0
		for _, t in tokens do
			if t.kind == "jogador" and not t.ia and not t.boneco and vivo(t) then
				n += 1
			end
		end
		return n
	end
	-- PvP: lados com alguma ficha de pé, inclusive invocados do participante.
	local function donosDePe(): { string }
		return Equipes.dePe(tokens, equipesAtuais)
	end
	local function nomeDoLado(lado)
		if lado == "e:1" then return "Equipe 1" elseif lado == "e:2" then return "Equipe 2" end
		local dono = tonumber(string.sub(lado, 3))
		local nome, jogador = "?", "jogador"
		for _, p in jogadores() do if p.UserId == dono then jogador = p.DisplayName end end
		for _, t in tokens do if t.ownerUserId == dono and t.kind == "jogador" then nome = t.name; break end end
		return nome .. " (" .. jogador .. ")"
	end

	local function recuperar()
		for _, t in tokens do
			if t.kind == "jogador" and not t.ia then
				t.pv, t.mana = t.pvMax, t.manaMax
				t.pt = t.ptMax or t.pt
				t.derrotado = nil
				t.conditions = {}
				t.version += 1
			end
		end
	end

	local function terminar(resultado: string, vencedor: string?)
		if not estado.ativo then
			return
		end
		local modo = estado.modo
		local mundo = estado.mundo
		chefes.limpar(); chefeAtual, nivelAtual = nil, nil
		table.clear(equipesAtuais)
		estado.ativo, estado.modo, estado.prazoFim, estado.prazoId, estado.mundo = false, nil, nil, nil, nil
		handlers.combatEnd(nil, {}, true)
		if mundo then
			deps.logAll(if resultado == "vitoria" then "Vitória! O grupo volta ao caminho (PV, PM e PT cheios)."
				else "Derrota... O grupo recobra os sentidos onde caiu (PV, PM e PT cheios).", "sistema")
		elseif modo == "duelo" then
			deps.logAll(if vencedor then "Fim do duelo: " .. vencedor .. " venceu! Todos se recuperam." else "Fim do duelo: ninguém ficou de pé.", "sistema")
		elseif resultado == "vitoria" then
			deps.logAll("Vitória! Os inimigos foram derrotados. O grupo descansa e se recupera (PV, PM e PT cheios).", "sistema")
		else
			deps.logAll("Derrota... O grupo acorda na entrada do campo, ferido mas de pé (PV, PM e PT cheios).", "sistema")
		end
		recuperar()
		deps.remote:FireAllClients("encontro", { resultado = resultado, modo = modo, vencedor = vencedor, mundo = mundo ~= nil })
		deps.mudou()
		if mundo and mundo.aoTerminar then
			local ok, erro = pcall(mundo.aoTerminar, resultado)
			if not ok then warn("[Luta do mundo] Fim: " .. tostring(erro)) end
		end
	end

	-- Vigia o fim do encontro, inclusive quando o último golpe sai no meio de um turno.
	local function vigiar()
		local versao = geracao
		task.spawn(function()
			while estado.ativo and geracao == versao do
				task.wait(0.5)
				if not estado.ativo or geracao ~= versao then
					break
				end
				if estado.modo == "duelo" then
					local donos = donosDePe()
					if #donos <= 1 then
						task.wait(esperaDoFim) -- deixa a animação do golpe final terminar
						if not estado.ativo or geracao ~= versao then break end
						donos = donosDePe()
						if #donos > 1 then continue end
						local nome = if donos[1] then nomeDoLado(donos[1]) else nil
						terminar(if donos[1] then "duelo" else "empate", nome)
					end
				elseif inimigosVivos() == 0 then
					task.wait(esperaDoFim)
					if not estado.ativo or geracao ~= versao then break end
					terminar("vitoria")
				elseif aliadosVivos() == 0 then
					task.wait(esperaDoFim)
					if not estado.ativo or geracao ~= versao then break end
					terminar("derrota")
				end
			end
		end)
	end

	-- Quem pode começar: o mestre, ou qualquer um quando não há combate em andamento.
	local function podeComecar(master: boolean): string?
		if combat.active then
			return "Já há um combate em andamento; espere ele acabar."
		end
		return nil
	end

	-- Põe o personagem escolhido de cada jogador presente nas casas dadas.
	local function criarJogadores(player: Player, casas, grupo): (string?, { any }?)
		local entradas = {}
		for i, p in grupo do
			if i > #casas then
				break
			end
			local falha, criado = criarPersonagem(player, p, casas[i][1], casas[i][2])
			if falha then
				return falha, nil
			end
			local t = tokens[criado.id]
			t.balanceamentoJogo = true
			local bonus = t.ficha2 and t.ficha2.calculated.initiative and t.ficha2.calculated.initiative.bonus or 0
			table.insert(entradas, { id = t.id, initiative = deps.random:NextInteger(1, 20) + bonus })
		end
		return nil, entradas
	end

	-- Quem Se Move Primeiro (Deus da Espada): empates de Iniciativa são sempre dele.
	local function ordenarIniciativa(entradas)
		return Maestrias.ordenarEmpates(entradas, function(id)
			local t = tokens[id]
			return t ~= nil and t.ficha2 ~= nil and Maestrias.daFicha(t.ficha2, deps.catalogo or Catalogo).quemSeMovePrimeiro == true
		end)
	end

	local function prepararMesa(player: Player)
		geracao += 1
		chefes.limpar(); chefeAtual, nivelAtual = nil, nil
		table.clear(equipesAtuais)
		handlers.combatEnd(player, {}, true)
		handlers.tableClear(player, {}, true)
		deps.desligarTreino()
	end

	handlers.escolherPersonagem = function(player, payload, master)
		if type(payload) == "table" and payload.id == PESSOAL then
			for chave in payload do if chave ~= "id" then return "Escolha pessoal inválida." end end
			if not deps.corpoPessoal then return "Crie um personagem próprio nesta sessão." end
			local corpo, erro = deps.corpoPessoal(player)
			if not corpo then return erro or "Personagem próprio indisponível." end
			escolhas[player.UserId], armasEscolhidas[player.UserId] = PESSOAL, nil
			instalarMontagem()
			if deps.remote.FireClient then deps.remote:FireClient(player, "escolhaPersonagem", { id = PESSOAL }) end
			return nil
		end
		local arma, erro = Armas.validar(payload)
		if not arma then return erro end
		instalarMontagem()
		escolhas[player.UserId], armasEscolhidas[player.UserId] = payload.id, arma.id
		-- (jogador simulado das inspeções do Studio não é Instance: não recebe aviso)
		if deps.remote.FireClient and (typeof(player) == "Instance" or type(deps.remote) == "table") then
			deps.remote:FireClient(player, "escolhaPersonagem", { id = payload.id, arma = arma.id })
		end
		return nil
	end

	handlers.entrarFila = function(player, payload)
		local erro = Equipes.validarFila(payload)
		if erro then return erro end
		if combat.active or montagem.ocupada() then return "Espere a partida atual terminar." end
		if payload.equipe ~= nil then
			local limite = limitar(player, "equipe"); if limite then return limite end
			equipesEscolhidas[player.UserId] = payload.equipe
		end
		fila[player.UserId] = if payload.modo == "sair" then nil else payload.modo
		return nil
	end

	handlers.iniciarLuta = function(player, payload, master)
		local nivel, invalido = Chefes.validarNivel(payload, master)
		if invalido then return invalido end
		local falha = podeComecar(master)
		if falha then
			return falha
		end
		if payload.nivel ~= nil then local limite = limitar(player, "desafio"); if limite then return limite end end
		local grupo = participantes("luta", player)
		if not grupo then return "O grupo comporta até quatro jogadores." end
		if #grupo==0 then return "É preciso pelo menos um personagem." end
		local chave = master and type(payload) == "table" and type(payload.encontro) == "string" and ENCONTROS[payload.encontro] and payload.encontro or ENCONTRO_DO_GRUPO[math.min(#grupo,4)]
		-- Cenários existentes têm escala publicada de 1–4; todos os dez participantes
		-- são montados, sem inventar uma escala de chefe acima do catálogo.
		local escolhido = if nivel == 1 then ENCONTROS[chave] else Chefes.desafio(nivel, math.min(#grupo,4))
		local indisponivel = validarGrupo(grupo)
		if indisponivel then return indisponivel end
		prepararMesa(player)
		nivelAtual = nivel
		local erro, entradas = criarJogadores(player, CASAS_DO_GRUPO, grupo)
		if erro then
			return erro
		end
		-- Primeiro a Ver (Navegação e Liderança): o grupo chega numa marcha conduzida
		-- pelo Tático e soma o Bônus de Rank dele na Iniciativa (adaptação: vale no Desafio).
		local hab = deps.habilidades()
		if hab and hab.utilidades then
			local doGrupo = {}
			for _, e in entradas do if tokens[e.id] then table.insert(doGrupo, tokens[e.id]) end end
			local bonus = hab.utilidades.bonusDeIniciativa(nil, doGrupo)
			if bonus > 0 then
				for _, e in entradas do e.initiative += bonus end
				deps.logAll(string.format("Primeiro a Ver: o grupo soma +%d na Iniciativa.", bonus), "sistema")
			end
		end
		for _, c in escolhido.criaturas do
			local e, nova = handlers.criarCriatura(player, { creatureId = c[1], x = c[2], z = c[3] }, true)
			if e then
				return e
			end
			local inimigo = tokens[nova.id]
			inimigo.ia = not (deps.monstrosManuais and deps.monstrosManuais())
			inimigo.monstroDoMestre = not inimigo.ia
			if nivel == 3 and c[1] == Chefes.ID then chefeAtual = inimigo end
			inimigo.version += 1
			table.insert(entradas, { id = inimigo.id, initiative = deps.random:NextInteger(1, 20) + 1 })
		end
		estado.ativo, estado.modo = true, "luta"
		participantesAtuais = #grupo
		for _, p in grupo do fila[p.UserId] = nil end
		handlers.combatStart(player, { entries = ordenarIniciativa(entradas) }, true)
		deps.logAll("Encontro: " .. escolhido.nome .. (if deps.monstrosManuais and deps.monstrosManuais() then ". O mestre controla os monstros." else ". Os inimigos agem sozinhos."), "sistema")
		vigiar()
		return nil
	end

	handlers.iniciarDuelo = function(player, payload, master)
		local invalido = Equipes.validarDuelo(payload)
		if invalido then return invalido end
		local falha = podeComecar(master)
		if falha then
			return falha
		end
		if #jogadores() < 2 then
			return "Duelo precisa de pelo menos 2 jogadores no servidor."
		end
		local grupo = participantes("duelo", player)
		if not grupo then return "O PvP comporta até 32 jogadores nesta arena." end
		if #grupo < 2 then return nil end -- fila aparece no snapshot; não puxa recém-chegados
		if not Equipes.temOponentes(grupo, equipesEscolhidas) then return "Escolha pelo menos dois lados adversários." end
		local times = {}
		for _, p in grupo do times[p.UserId] = equipesEscolhidas[p.UserId] or 0 end
		local casas = Equipes.casas(grupo, times)
		local indisponivel = validarGrupo(grupo)
		if indisponivel then return indisponivel end
		prepararMesa(player)
		equipesAtuais = times
		local erro, entradas = criarJogadores(player, casas, grupo)
		if erro then
			return erro
		end
		estado.ativo, estado.modo = true, "duelo"
		participantesAtuais = #grupo
		for _, p in grupo do fila[p.UserId] = nil end
		handlers.combatStart(player, { entries = ordenarIniciativa(entradas) }, true)
		deps.logAll("PvP! O último lado de pé vence. Equipes mantidas até o fim; vez com prazo de " .. PRAZO_DA_VEZ .. " s.", "sistema")
		vigiar()
		return nil
	end

	local api = {}

	function api.ativo(): boolean
		return estado.ativo
	end

	function api.emDuelo(): boolean
		return estado.ativo and estado.modo == "duelo"
	end
	function api.equipeDe(token)
		return if api.emDuelo() then equipesAtuais[token.ownerUserId] else nil
	end
	function api.mesmaEquipe(a, b): boolean
		return api.emDuelo() and Equipes.aliados(a, b, equipesAtuais)
	end

	-- Luta do Modo História (PLANO §13): começa pelo servidor quando a patrulha encosta, sem fila nem
	-- objetos da sala. `criaturas` são IDs do catálogo; `opcoes` = { nome, aoTerminar(resultado) }.
	-- Mesmo caminho da Luta da sala: personagens pessoais, IA das criaturas e vigia de fim.
	function api.iniciarLutaDoMundo(grupo, criaturas, opcoes)
		if type(grupo) ~= "table" or #grupo == 0 or #grupo > #CASAS_DO_GRUPO then return "Grupo inválido para a luta." end
		if type(criaturas) ~= "table" or #criaturas == 0 or #criaturas > #CASAS_INIMIGAS then return "Inimigos inválidos para a luta." end
		if combat.active or estado.ativo then return "Já há um combate em andamento; espere ele acabar." end
		forcarPessoal = true
		local indisponivel = validarGrupo(grupo)
		forcarPessoal = false
		if indisponivel then return indisponivel end
		local solicitante = grupo[1]
		prepararMesa(solicitante)
		forcarPessoal = true
		local ok, erro, entradas = pcall(criarJogadores, solicitante, CASAS_DO_GRUPO, grupo)
		forcarPessoal = false
		if not ok then return tostring(erro) end
		if erro then return erro end
		for i, creatureId in criaturas do
			local casa = CASAS_INIMIGAS[i]
			local e, nova = handlers.criarCriatura(solicitante, { creatureId = creatureId, x = casa[1], z = casa[2] }, true)
			if e then return e end
			local inimigo = tokens[nova.id]
			inimigo.ia = true
			inimigo.version += 1
			table.insert(entradas, { id = inimigo.id, initiative = deps.random:NextInteger(1, 20) + 1 })
		end
		estado.ativo, estado.modo, estado.mundo = true, "luta", opcoes or {}
		participantesAtuais = #grupo
		for _, p in grupo do fila[p.UserId] = nil end
		handlers.combatStart(solicitante, { entries = ordenarIniciativa(entradas) }, true)
		deps.logAll("Encontro: " .. tostring(opcoes and opcoes.nome or "inimigos no caminho") .. ". Os inimigos agem sozinhos.", "sistema")
		vigiar()
		return nil
	end
	api.iniciarLutaDoMundo = montagem.proteger(api.iniciarLutaDoMundo)

	function api.desligar()
		geracao += 1
		local mundo = estado.mundo
		chefes.limpar(); chefeAtual, nivelAtual = nil, nil
		table.clear(equipesAtuais)
		estado.ativo, estado.modo, estado.prazoFim, estado.prazoId, estado.mundo = false, nil, nil, nil, nil
		-- Mesa limpa no meio da luta do mundo: o grupo não pode ficar preso na arena.
		if mundo and mundo.aoTerminar then
			local ok, erro = pcall(mundo.aoTerminar, "cancelada")
			if not ok then warn("[Luta do mundo] Cancelada: " .. tostring(erro)) end
		end
	end

	function api.sala(player)
		local luta, duelo = 0, 0
		local lados = { {}, {}, {} }
		for _, p in jogadores() do
			if fila[p.UserId] == "luta" then luta += 1 elseif fila[p.UserId] == "duelo" then duelo += 1 end
			if fila[p.UserId] == "duelo" then table.insert(lados[(equipesEscolhidas[p.UserId] or 0) + 1], p.UserId) end
		end
		return { suaFila = fila[player.UserId], luta = luta, duelo = duelo, equipe = equipesEscolhidas[player.UserId] or 0, lados = lados }
	end

	function api.remover(player)
		fila[player.UserId], escolhas[player.UserId], armasEscolhidas[player.UserId] = nil, nil, nil
		equipesEscolhidas[player.UserId] = nil
		for _, c in { "equipe", "desafio" } do ultimosPedidos[tostring(player.UserId) .. ":" .. c] = nil end
		if not estado.ativo then return end
		local perdeuVez = false
		for id, token in tokens do
			if token.ownerUserId == player.UserId then
				token.pv, token.derrotado = 0, true
				token.version += 1
				perdeuVez = perdeuVez or deps.currentTurnId() == id
			end
		end
		if perdeuVez then deps.avancarVez(deps.currentTurnId()) end
	end

	-- Desistir no meio da partida: as fichas do jogador caem, como na desconexão,
	-- mas a escolha de personagem fica. Devolve true se ele estava na partida.
	function api.desistir(player): boolean
		if not estado.ativo then return false end
		local estava, perdeuVez = false, false
		for id, token in tokens do
			if token.ownerUserId == player.UserId and not token.derrotado then
				estava = true
				token.pv, token.derrotado = 0, true
				token.version += 1
				perdeuVez = perdeuVez or deps.currentTurnId() == id
			end
		end
		fila[player.UserId] = nil
		if perdeuVez then deps.avancarVez(deps.currentTurnId()) end
		return estava
	end

	function api.personagemDe(player: Player): string
		return personagemDe(player)
	end
	api.validarPersonagem = validarPersonagem
	api.criarPersonagem = criarPersonagem

	-- Para o snapshot: modo atual e fim do prazo da vez (tempo do servidor).
	function api.publico()
		if not estado.ativo then
			return nil
		end
		return { modo = estado.modo, prazoFim = estado.prazoFim, prazoId = estado.prazoId,
			nivel = nivelAtual, equipes = table.clone(equipesAtuais), chefe = chefes.publico(chefeAtual) }
	end

	-- Início de uma vez: inimigo age; caído perde a vez; jogador ganha prazo.
	function api.aoTrocarVez(novoId: string?)
		estado.prazoFim, estado.prazoId = nil, nil
		if not estado.ativo or not novoId then
			return
		end
		local token = tokens[novoId]
		if not token then
			return
		end
		local turno = combat.turn
		local versao = geracao
		local function aindaEhAVez()
			return geracao == versao and estado.ativo and combat.active and combat.turn == turno and deps.currentTurnId() == novoId and tokens[novoId] == token
		end
		if token.ia then
			task.delay(ATRASO_DA_IA, function()
				if not aindaEhAVez() then
					return
				end
				local agiu = if token == chefeAtual then chefes.turno(token) else deps.habilidades().turnoDoInimigo(token)
				if not aindaEhAVez() then return end
				deps.mudou()
				task.delay(if agiu then ATRASO_APOS_AGIR else 0.2, function()
					if aindaEhAVez() then
						deps.avancarVez(novoId)
					end
				end)
			end)
		elseif token.pv <= 0 or token.derrotado then
			deps.logAll(token.name .. " está caído e perde a vez.", "sistema")
			task.delay(0.8, function()
				if aindaEhAVez() then
					deps.avancarVez(novoId)
				end
			end)
		elseif participantesAtuais > 1 then
			estado.prazoFim = agora() + PRAZO_DA_VEZ
			estado.prazoId = novoId
			task.delay(PRAZO_DA_VEZ, function()
				if aindaEhAVez() then
					deps.logAll("Tempo esgotado: " .. token.name .. " perde o resto da vez.", "sistema")
					deps.avancarVez(novoId)
				end
			end)
		end
	end

	-- Criar ficha pode ceder a execução no filtro de texto. Um segundo início
	-- não pode limpar/substituir a arena enquanto o primeiro ainda a monta.
	for _, comando in { "iniciarLuta", "iniciarDuelo" } do
		handlers[comando] = montagem.proteger(handlers[comando])
	end
	return api
end

return EncontroService
