-- SOMENTE STUDIO: contrato real do EncontroService e fichas v2 do servidor.
local Encontro = require(script.Parent.Parent.EncontroService)
local Premontados = require(script.Parent.Parent.Premontados)
local Shared = game:GetService("ReplicatedStorage").Shared
local FichaV2 = require(Shared.FichaV2)
local Catalogo = require(Shared.Livro.Catalogo)
local Arma = require(Shared.Regras.Arma)
local Http = game:GetService("HttpService")

local function mesa(tardia)
	local handlers, tokens, confirmacoes = {}, {}, {}
	local p = { UserId = 101, DisplayName = "Autor" }
	local combat = { active = false }
	local api = Encontro.start({ handlers = handlers, tokens = tokens, combat = combat,
		remote = { FireClient = function(_, player, tipo, dados)
			table.insert(confirmacoes, { player = player, tipo = tipo, dados = dados })
		end }, jogadores = function() return { p } end })
	local function criar(_, payload)
		local f, erro = FichaV2.validar(Http:JSONDecode(Premontados[payload.id]), Catalogo)
		if not f then return erro end
		tokens.t = { id = "t", ficha2 = f, version = 1, ownerUserId = payload.ownerUserId }
		return nil, { id = "t" }
	end
	if not tardia then handlers.criarPremontado = criar end
	return { api = api, handlers = handlers, tokens = tokens, p = p, criar = criar,
		combat = combat, confirmacoes = confirmacoes }
end

return {
	["escolha atomica recusa payload hostil e confirma apenas ao dono"] = function(t)
		local m = mesa()
		t.eq(m.handlers.escolherPersonagem(m.p, { id = "brutamontes", arma = "desarmado" }), nil)
		for _, payload in { { id = "espadachim", arma = "Besta" }, { id = "espadachim", arma = false },
			{ id = "espadachim", arma = string.rep("x", 100) }, { id = "brutamontes", dado = "d100" }, false } do
			t.eq(type(m.handlers.escolherPersonagem(m.p, payload)), "string")
		end
		t.eq(m.api.personagemDe(m.p), "brutamontes"); t.eq(#m.confirmacoes, 1)
		t.eq(m.confirmacoes[1].player, m.p); t.eq(m.confirmacoes[1].dados.arma, "desarmado")
		t.eq(m.handlers.criarPremontado(m.p, { id = m.api.personagemDe(m.p), ownerUserId = 101 }, true), nil)
		t.eq(Arma.daFicha(m.tokens.t.ficha2, Catalogo).dado, "d8")
		t.ok(FichaV2.validarCorpo(m.tokens.t.ficha2, Catalogo) ~= nil, "ficha continua no contrato v2")
	end,
	["montagem tardia cobre Treino e escolha durante partida so muda a proxima"] = function(t)
		local m = mesa(true)
		m.handlers.criarPremontado = m.criar -- mesma ordem do MesaService/HabilidadeService
		t.eq(m.handlers.escolherPersonagem(m.p, { id = "espadachim", arma = "Espadão / Montante" }), nil)
		t.eq(m.handlers.criarPremontado(m.p, { id = m.api.personagemDe(m.p), ownerUserId = 101 }, true), nil)
		local atual = m.tokens.t.ficha2
		t.eq(Arma.daFicha(atual, Catalogo).dado, "d12")
		m.combat.active = true
		t.eq(m.handlers.escolherPersonagem(m.p, { id = "espadachim", arma = "Katana" }), nil)
		t.eq(Arma.daFicha(atual, Catalogo).nome, "Espadão / Montante")
		m.handlers.criarPremontado(m.p, { id = m.api.personagemDe(m.p), ownerUserId = 101 }, true)
		t.eq(Arma.daFicha(m.tokens.t.ficha2, Catalogo).nome, "Katana")
		t.eq(Arma.daFicha(m.tokens.t.ficha2, Catalogo).dado, "d10")
	end,
	["ausencia volta ao kit e nao herda arma de outra arvore"] = function(t)
		local m = mesa()
		m.handlers.escolherPersonagem(m.p, { id = "espadachim", arma = "Katana" })
		m.handlers.escolherPersonagem(m.p, { id = "mago-de-fogo" })
		m.handlers.criarPremontado(m.p, { id = m.api.personagemDe(m.p), ownerUserId = 101 }, true)
		t.eq(Arma.daFicha(m.tokens.t.ficha2, Catalogo).nome, "Cajado / Foco Arcano")
		m.api.remover(m.p)
		t.eq(m.api.personagemDe(m.p), "mago-de-fogo")
		t.eq(type(m.handlers.criarPremontado(m.p, { id = "espadachim", arma = "Besta" }, true)), "string")
		t.eq(type(m.handlers.criarPremontado(m.p, { id = "espadachim" }, false)), "string")
	end,
}
