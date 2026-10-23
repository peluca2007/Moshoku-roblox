-- SOMENTE STUDIO: contato físico, raycast e integração de iniciativa no serviço.
local Server = script.Parent.Parent
local Regiao = require(Server.RegiaoInicial)
local Service = require(Server.EncontroAutonomoService)

local function comLimpeza(mundo, corpo)
	local ok, erro = pcall(corpo)
	mundo:Destroy()
	if not ok then error(erro, 0) end
end

local function patrulha(encontrar)
	local mundo = Instance.new("WorldModel")
	mundo.Parent = workspace
	local regiao = Instance.new("Folder")
	regiao.Name, regiao.Parent = "RegiaoInicial", mundo
	local char = Instance.new("Model")
	char.Parent = mundo
	local root = Instance.new("Part")
	root.Name, root.Anchored, root.Parent = "HumanoidRootPart", true, char
	local hum = Instance.new("Humanoid")
	hum.Parent = char
	local player = { UserId = 101, Character = char }
	local tempo, contatos = 10, {}
	local api = Regiao.iniciarPatrulha({ workspace = mundo, agora = function() return tempo end,
		elegivel = function() return true end, ocupado = function() return false end,
		jogadores = function() return { player } end,
		encontrar = function(p, origem)
			table.insert(contatos, origem.contextoContato(p))
			return if encontrar then encontrar(p, origem) else true
		end })
	return api, player, root, mundo, contatos, function(delta) tempo += delta end
end

local function servico(surpreendente, condicao)
	local player = { UserId = 101 }
	local envios = {}
	local api = Service.start({ remote = {}, localizarJogador = function() return player end,
		conectado = function(p) return p == player end,
		novoId = function() return "r2b-surpresa" end,
		agora = function() return 10 end, agendarPrazo = function() end, cancelarPrazo = function() end,
		rng = { NextInteger = function() return 10 end },
		emitir = function(_, tipo, dados) table.insert(envios, { tipo = tipo, dados = dados }) end })
	local atores = {
		{ id = "c", kind = "criatura", bonus = 10, advantage = false, condicoes = condicao and { desprevenido = condicao } or {} },
		{ id = "p", kind = "jogador", userId = 101, bonus = 0, advantage = false },
	}
	local arena = { surpreendente = surpreendente, bloqueadas = {}, validarInicio = function() return true end }
	local id = api.criarComIniciativa(atores, nil, arena)
	return api, id, player, envios, atores
end

return {
	["contato real liga percepção à arena, iniciativa e condição do snapshot"] = function(t)
		local service, id
		local api, player, root, mundo = patrulha(function(p, origem)
			local ok, encontroId = service.iniciarPorPatrulha(p, origem)
			id = encontroId
			return ok
		end)
		comLimpeza(mundo, function()
		local piso = Instance.new("Part")
		piso.Size, piso.Position, piso.Anchored, piso.Parent = Vector3.new(120, 2, 120), Vector3.new(54, -1, 43), true, mundo
		local snapshot
		service = Service.start({ remote = {}, workspace = mundo, criarPatrulha = function() return api end,
			localizarJogador = function() return player end, conectado = function(p) return p == player end,
			agora = function() return 10 end, novoId = function() return "r2b-integrado" end,
			agendarPrazo = function() end, cancelarPrazo = function() end,
			corpoPessoal = function() return { name = "Teste", calculated = {
				initiative = { bonus = 0, advantage = false }, movementMeters = 9 } } end,
			emitir = function(_, tipo, dados) if tipo == "estado" then snapshot = dados end end })
		root.Position = api.corpo.Position + Vector3.new(0, 1, 3)
		api.atualizar(0.1)
		t.ok(id ~= nil, "contato deve criar encontro")
		t.eq(snapshot.isMyTurn, true)
		local encontrou = false
		for _, ator in ipairs(snapshot.actors) do
			if ator.kind == "criatura" then
				t.eq(ator.conditions.desprevenido, true)
				encontrou = true
			end
		end
		t.ok(encontrou)
		t.ok(mundo:FindFirstChild("Encontro da patrulha") ~= nil)
		end)
	end,
	["contato pelas costas produz contexto privado sem detecção"] = function(t)
		local api, player, root, mundo, contatos = patrulha()
		comLimpeza(mundo, function()
		root.Position = api.corpo.Position + Vector3.new(0, 1, 3)
		api.atualizar(0.1)
		t.eq(#contatos, 1)
		t.eq(contatos[1].visto, false)
		t.eq(contatos[1].iniciouPeloJogador, true)
		t.eq(api.contextoContato(player), nil)
		t.eq(api.corpo.Transparency, 1)
		end)
	end,
	["contato frontal durante janela de percepção não dá surpresa"] = function(t)
		local api, _, root, mundo, contatos, avancar = patrulha()
		comLimpeza(mundo, function()
		root.Position = api.corpo.Position + Vector3.new(0, 1, 12)
		api.atualizar(0.1)
		t.eq(api.alvo(), nil)
		root.Position = api.corpo.Position + api.corpo.CFrame.LookVector * 3 + Vector3.new(0, 1, 0)
		avancar(0.1)
		api.atualizar(0.1)
		t.eq(#contatos, 1)
		t.eq(contatos[1].visto, true)
		t.eq(contatos[1].iniciouPeloJogador, false)
		end)
	end,
	["perseguido que contorna o goblin não ganha surpresa"] = function(t)
		local api, _, root, mundo, contatos, avancar = patrulha()
		comLimpeza(mundo, function()
		root.Position = api.corpo.Position + Vector3.new(0, 1, -12)
		api.atualizar(0.1)
		root.Position = api.corpo.Position - api.corpo.CFrame.LookVector * 3 + Vector3.new(0, 1, 0)
		avancar(0.3)
		api.atualizar(0.1)
		t.eq(contatos[1].visto, true)
		end)
	end,
	["parede impede contato pelas costas"] = function(t)
		local api, _, root, mundo, contatos = patrulha()
		comLimpeza(mundo, function()
		root.Position = api.corpo.Position + Vector3.new(0, 1, 4)
		local parede = Instance.new("Part")
		parede.Size, parede.Anchored = Vector3.new(6, 8, 1), true
		parede.Position, parede.Parent = api.corpo.Position + Vector3.new(0, 1, 2), mundo
		api.atualizar(0.1)
		t.eq(#contatos, 0)
		end)
	end,
	["surpresa prioriza jogador só na rodada um e expira ao inimigo agir"] = function(t)
		local api, id, player, envios, atores = servico("jogadores")
		t.ok(id ~= nil)
		t.eq(api.estado(id).currentActorId, "p")
		t.eq(api.atores(id)[2].condicoes.desprevenido, true)
		t.eq(atores[1].condicoes.desprevenido, nil)
		api.solicitarFimTurno(player, { encounterId = id, expectedVersion = 1, requestId = "fim-surpresa" })
		t.eq(api.estado(id).turn, 2)
		t.eq(api.estado(id).currentActorId, "p")
		local viuInimigoPrimeiro = false
		for _, envio in ipairs(envios) do
			if envio.tipo == "estado" and envio.dados.turn == 2 and envio.dados.currentActorId == "c" then
				viuInimigoPrimeiro = true
			end
		end
		t.ok(viuInimigoPrimeiro, "RB-13 restaura inimigo antes do jogador na rodada dois")
		t.eq(api.atores(id)[2].condicoes.desprevenido, nil)
	end,
	["sem surpresa mantém iniciativa e não cria condição"] = function(t)
		local api, id, _, envios = servico(nil)
		t.eq(envios[1].dados.currentActorId, "c")
		t.eq(api.atores(id)[1].condicoes.desprevenido, nil)
	end,
	["expiração preserva Desprevenido preexistente"] = function(t)
		local api, id, player = servico("jogadores", "outra-origem")
		api.solicitarFimTurno(player, { encounterId = id, expectedVersion = 1, requestId = "fim-preexistente" })
		t.eq(api.atores(id)[2].condicoes.desprevenido, "outra-origem")
	end,
}
