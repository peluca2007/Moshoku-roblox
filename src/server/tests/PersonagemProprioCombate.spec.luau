-- SOMENTE STUDIO: integração dos serviços reais, sem usar a mesa da sessão.
local Shared = game:GetService("ReplicatedStorage").Shared
local Encontro = require(script.Parent.Parent.EncontroService)
local Treino = require(script.Parent.Parent.TreinoService)
local Habilidade = require(script.Parent.Parent.HabilidadeService)
local Sessao = require(script.Parent.Parent.PersonagemSessao)
local Criacao = require(Shared.Regras.CriacaoPersonagem)
local Adaptador = require(Shared.Regras.FichaPersonagemProprio)
local FichaV2 = require(Shared.FichaV2)

local function corpoInicial(armaSelecionada, subgrupo)
	local cat = { POR_ID = {}, POR_ESPECIE = { skill = {} } }
	for id, item in {
		["race/humano"] = { kind = "race", data = { tier = "comum" } },
		["background/plebeu"] = { kind = "background", data = {} },
		["tree/agua"] = { kind = "tree", data = { id = "agua", category = "magia", subgroup = subgrupo or "Magia Ofensiva", ranks = { "rank/agua/Principiante" } } },
		["rank/agua/Principiante"] = { kind = "rank", data = { treeId = "agua", rank = "Principiante", hpDiceFormula = "1d6+1" } },
		["weapon-group/desarmado-e-improvisado"] = { kind = "weapon-group", data = {} },
	} do item.id = id; cat.POR_ID[id] = item end
	local perfil, erro = Criacao.calcular({ raceId = "race/humano", backgroundId = "background/plebeu", startingTreeId = "tree/agua",
		attributeBase = { forca = 2, agilidade = 0, vigor = 0, intelecto = 0, espirito = 0 },
		raceAttributeChoices = {}, freeSkillChoiceIds = {}, treeSkillChoiceIds = {} }, cat)
	assert(perfil, erro)
	perfil.nome = "Aventureiro"
	perfil.armaInicialSourceLocalId = armaSelecionada
	local corpo, falha = Adaptador.construir(perfil, "Aventureiro", cat)
	assert(corpo, falha)
	return corpo, cat
end

local function ambiente()
	local p, outro = { UserId = 101 }, { UserId = 202 }
	local d = { handlers = {}, tokens = { antiga = {} }, combat = { active = false },
		remote = { FireClient = function() end }, jogadores = function() return { p, outro } end }
	local habilidades
	d.habilidades = function() return habilidades end
	d.definirHabilidades = function(api) habilidades = api end
	local limpa = 0
	d.handlers.criarPremontado = function() return "Não deveria montar premontado." end
	d.handlers.combatEnd = function() end
	d.handlers.tableClear = function() limpa += 1 end
	d.corpoPessoal = function(player) return if player.UserId == 101 then {} else nil, "Perfil ausente." end
	local api = Encontro.start(d)
	return d, api, p, outro, function() return limpa end
end

return {
	["getter pessoal devolve copia e nao consulta outro dono por payload"] = function(t)
		local handlers = {}
		local api = Sessao.start({ handlers = handlers, remote = { FireClient = function() end }, calcular = function() return { atributos = { vigor = 3 }, construcao = { raceId = "race/humano" } } end,
			filtrarNome = function(_, nome) return nome end,
			emCombate = function() return false end, conectado = function() return true end })
		local p = { UserId = 101 }
		t.eq(handlers.personagemPessoalCriar(p, { requestId = "criacao-teste", nome = "Teste" }), nil)
		local perfil = api.consultar(p); perfil.atributos.vigor = 999
		t.eq(api.consultar(p).atributos.vigor, 3)
		t.eq(api.consultar({ UserId = 202 }), nil)
		t.ok(handlers.personagemPessoalConsultar(p, { ownerUserId = 202 }) ~= nil)
	end,
	["selecao pessoal recusa corpo dono arma e perfil ausente sem mudar escolha"] = function(t)
		local d, api, p, outro = ambiente()
		for _, extra in { { ownerUserId = 202 }, { ficha = {} }, { arma = "Espada" } } do
			extra.id = "personagem-pessoal"
			t.ok(d.handlers.escolherPersonagem(p, extra) ~= nil)
		end
		t.ok(d.handlers.escolherPersonagem(outro, { id = "personagem-pessoal" }) ~= nil)
		t.eq(api.personagemDe(p), "mago-de-fogo")
		t.eq(d.handlers.escolherPersonagem(p, { id = "personagem-pessoal" }), nil)
		t.eq(api.personagemDe(p), "personagem-pessoal")
		t.eq(api.personagemDe(outro), "mago-de-fogo")
	end,
	["perfil perdido impede Treino Luta e Duelo antes da limpeza"] = function(t)
		for _, comando in { "iniciarTreino", "iniciarLuta", "iniciarDuelo" } do
			local d, api, p, outro, limpezas = ambiente()
			t.eq(d.handlers.escolherPersonagem(p, { id = "personagem-pessoal" }), nil)
			d.corpoPessoal = function() return nil, "Perfil ausente." end
			if comando == "iniciarTreino" then
				Treino.start({ handlers = d.handlers, tokens = d.tokens, combat = d.combat, personagemDe = api.personagemDe, validarPersonagem = api.validarPersonagem })
			elseif comando == "iniciarDuelo" then
				d.handlers.entrarFila(outro, { modo = "duelo" })
			end
			t.eq(d.handlers[comando](p, {}, true), "Perfil ausente.")
			t.eq(limpezas(), 0)
			t.ok(d.tokens.antiga ~= nil)
		end
	end,
	["montagem interna usa corpo do servidor e preserva contrato de habilidades"] = function(t)
		local corpo, cat = corpoInicial()
		local d, encontro, p = ambiente()
		d.corpoPessoal = function() return corpo end
		d.handlers.createToken = function(_, pedido)
			d.tokens.nova = { id = "nova", name = pedido.name, ownerUserId = pedido.ownerUserId, pvMax = pedido.pvMax, manaMax = pedido.manaMax, version = 1 }
			return nil, "nova"
		end
		local hab = Habilidade.start({ handlers = d.handlers, tokens = d.tokens, tokenOrder = {}, combat = d.combat, catalogo = cat,
			terrain = {}, cellKey = function(x, z) return x .. ":" .. z end, remote = d.remote, random = Random.new(1),
			canSee = function() return true end, currentTurnId = function() return nil end, logAboutToken = function() end })
		d.definirHabilidades(hab)
		t.eq(d.handlers.escolherPersonagem(p, { id = "personagem-pessoal" }), nil)
		t.eq(encontro.criarPersonagem(p, p, 4, 5), nil)
		local token = d.tokens.nova
		t.eq(token.name, "Aventureiro"); t.eq(token.ownerUserId, 101)
		t.eq(token.pv, corpo.calculated.maxima.pv); t.eq(token.mana, corpo.calculated.maxima.pm)
		t.eq(token.ficha2.construction.inventory[1].equipped, false)
		t.ok(FichaV2.validarCorpo(token.ficha2, cat) ~= nil)
		t.eq(d.handlers.criarPersonagemPessoal, nil, "nao existe remoto que aceite corpo")
		t.ok(d.handlers.criarPremontado(p, { id = "personagem-pessoal", ownerUserId = 101 }, true) ~= nil, "nem mestre usa remoto para buscar perfil pessoal")
		t.ok(d.handlers.criarPremontado(p, { id = "personagem-pessoal", ownerUserId = 202 }, false) ~= nil)
	end,
	["arma corpo a corpo escolhida do kit equipa na ficha e o perfil antigo segue desequipado"] = function(t)
		local antiga = corpoInicial()
		local arma, cat = corpoInicial("kit-inicial-01")
		t.eq(antiga.construction.inventory[1].equipped, false)
		t.eq(arma.construction.inventory[1].sourceLocalId, "kit-inicial-01")
		t.eq(arma.construction.inventory[1].name, "Cajado / Foco Arcano")
		t.eq(arma.construction.inventory[1].equipped, true)
		t.ok(FichaV2.validarCorpo(arma, cat) ~= nil)
	end,
	["arma de distância escolhida vai primeiro sem equipar arma corpo a corpo"] = function(t)
		local corpo, cat = corpoInicial("kit-inicial-02", "Arqueiro")
		local inventario = corpo.construction.inventory
		t.eq(inventario[1].sourceLocalId, "kit-inicial-02")
		t.eq(inventario[1].name, "Funda / Dardo")
		t.eq(inventario[1].equipped, false)
		t.eq(inventario[2].name, "Arco Curto")
		t.eq(inventario[2].equipped, false)
		t.ok(FichaV2.validarCorpo(corpo, cat) ~= nil)
	end,
	["arma fora do kit e item geral nao podem virar arma escolhida"] = function(t)
		local _, cat = corpoInicial()
		local perfil = Criacao.calcular({ raceId = "race/humano", backgroundId = "background/plebeu", startingTreeId = "tree/agua",
			attributeBase = { forca = 2, agilidade = 0, vigor = 0, intelecto = 0, espirito = 0 },
			raceAttributeChoices = {}, freeSkillChoiceIds = {}, treeSkillChoiceIds = {} }, cat)
		perfil.nome = "Aventureiro"
		perfil.armaInicialSourceLocalId = "kit-inicial-99"
		local arma, erro = Adaptador.construir(perfil, "Aventureiro", cat)
		t.eq(arma, nil); t.eq(erro, "Perfil inicial incompleto ou incompatível.")
		perfil.armaInicialSourceLocalId = "kit-inicial-02"
		arma = Adaptador.construir(perfil, "Aventureiro", cat)
		t.eq(arma, nil)
	end,
}
