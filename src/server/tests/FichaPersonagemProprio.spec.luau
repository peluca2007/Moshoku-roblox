local Shared = game:GetService("ReplicatedStorage").Shared
local FichaPersonagemProprio = require(Shared.Regras.FichaPersonagemProprio)
local CriacaoPersonagem = require(Shared.Regras.CriacaoPersonagem)
local FichaV2 = require(Shared.FichaV2)

local function fixture(tier, subgrupo)
	local porId = {
		["race/humano"] = { id = "race/humano", kind = "race", data = {
			tier = tier or "comum", attributeChoices = 1,
		} },
		["background/plebeu"] = { id = "background/plebeu", kind = "background", data = {} },
		["tree/agua"] = { id = "tree/agua", kind = "tree", data = {
			id = "agua", category = "magia", subgroup = subgrupo or "Magia Ofensiva",
			ranks = { "rank/agua/Principiante" },
		} },
		["rank/agua/Principiante"] = { id = "rank/agua/Principiante", kind = "rank", data = {
			treeId = "agua", rank = "Principiante", hpDiceFormula = "1d6+1", abilities = { "ability/agua/Principiante/onda" },
		} },
		["ability/agua/Principiante/onda"] = { id = "ability/agua/Principiante/onda", kind = "ability", data = {
			treeId = "agua", rank = "Principiante", name = "Onda", paCost = 1,
		} },
		["skill/medicina"] = { id = "skill/medicina", kind = "skill", data = { name = "Medicina", attribute = "intelecto" } },
		["weapon-group/desarmado-e-improvisado"] = {
			id = "weapon-group/desarmado-e-improvisado", kind = "weapon-group", data = {},
		},
	}
	local catalogo = { POR_ID = porId, POR_ESPECIE = {
		skill = { porId["skill/medicina"] }, ability = { porId["ability/agua/Principiante/onda"] },
	} }
	local perfil, erro = CriacaoPersonagem.calcular({
		raceId = "race/humano", backgroundId = "background/plebeu", startingTreeId = "tree/agua",
		attributeBase = { forca = 2, agilidade = 0, vigor = 0, intelecto = 0, espirito = 0 },
		raceAttributeChoices = { "agilidade" }, freeSkillChoiceIds = {}, treeSkillChoiceIds = {},
	}, catalogo)
	assert(perfil, erro)
	perfil.nome = "Aria"
	return perfil, catalogo
end

return {
	["árvore adicional chega à ficha J2 e sobrevive à validação fechada"] = function(t)
		local perfil, cat = fixture()
		cat.POR_ID["tree/fogo"] = {id="tree/fogo",kind="tree",data={id="fogo",category="magia"}}
		cat.POR_ID["rank/fogo/Principiante"] = {id="rank/fogo/Principiante",kind="rank",data={treeId="fogo",rank="Principiante",hpDiceFormula="1d6+1",abilities={}}}
		local Arvores = require(Shared.Regras.ArvoresAprendidas)
		perfil = Arvores.aplicar(perfil, {"tree/fogo"}, cat)
		local corpo, erro = FichaPersonagemProprio.construir(perfil, "Aria", cat)
		t.ok(corpo, erro)
		t.eq(corpo.construction.startingTreeId, "tree/agua")
		t.eq(corpo.construction.unlockedRankIds[2], "rank/fogo/Principiante")
		perfil.construcao.unlockedRankIds[2] = "rank/invalido/Principiante"
		t.eq(FichaPersonagemProprio.construir(perfil, "Aria", cat), nil)
	end,
	["constrói corpo inicial validado com recursos cheios e kit sem equipamento automático"] = function(t)
		local perfil, cat = fixture()
		local corpo, erro = FichaPersonagemProprio.construir(perfil, "Aria", cat)
		t.ok(corpo, erro)
		t.eq(erro, nil)
		t.eq(corpo.name, "Aria")
		t.eq(corpo.constructionComplete, true)
		t.eq(corpo.construction.raceId, "race/humano")
		t.eq(corpo.construction.unlockedRankIds[1], "rank/agua/Principiante")
		t.eq(corpo.construction.weaponGroupIds[1], "weapon-group/desarmado-e-improvisado")
		t.eq(#corpo.construction.inventory, #perfil.inventarioInicial)
		t.eq(corpo.construction.inventory[1].name, "Cajado / Foco Arcano")
		t.eq(corpo.construction.inventory[1].baseDie, "d6")
		t.eq(corpo.construction.inventory[1].equipped, false)
		t.eq(corpo.calculated.attributes.agilidade, 1)
		t.eq(corpo.calculated.maxima.pv, 22)
		t.eq(corpo.calculated.maxima.pm, 12)
		t.eq(corpo.calculated.armorClass, 11)
		t.eq(corpo.calculated.highestRankBonus, 1)
		t.eq(corpo.calculated.skills[1].skillId, "skill/medicina")
		for _, recurso in { "pv", "pm", "pt", "pp" } do
			t.eq(corpo.session.current[recurso], corpo.calculated.maxima[recurso])
		end
		t.eq(corpo.construction.gold, 0)
		t.eq(corpo.construction.bonusHp, 0)
		t.eq(#corpo.construction.purchasedIds, 0)
		t.eq(#corpo.construction.racialUpgradeIds, 0)
		t.eq(#corpo.session.conditions, 0)
		t.eq(corpo.session.shortRests, 0)
		t.eq(corpo.compatibility, nil)
		t.eq(corpo.mesa, nil)
	end,
	["preserva o PA gasto pela raça em todos os tiers"] = function(t)
		for tier, custo in { comum = 1, incomum = 1, rara = 2, lendaria = 3, mitica = 3 } do
			local perfil, cat = fixture(tier)
			local corpo, erro = FichaPersonagemProprio.construir(perfil, "Aria", cat)
			t.ok(corpo, erro)
			t.eq(corpo.calculated.paSpent, custo, tier)
			t.eq(3 - corpo.calculated.paSpent, perfil.pontosAprimoramento.restantes)
		end
	end,
	["round-trip do corpo e projeção de mesa preservam campos derivados"] = function(t)
		local perfil, cat = fixture()
		local corpo = FichaPersonagemProprio.construir(perfil, "Aria", cat)
		local validado, erro, avisos = FichaV2.validarCorpo(corpo, cat)
		t.ok(validado, erro)
		t.eq(#avisos, 0)
		t.eq(validado.exporterVersion, "ficha-v2/personagem-proprio-1")
		t.eq(validado.calculated.paSpent, 1)
		local mesa = FichaV2.paraMesa(validado)
		t.eq(mesa.pv, 22)
		t.eq(mesa.mana, 12)
		t.eq(mesa.sheet.ca, 11)
		t.eq(mesa.sheet.agilidade, 1)
		t.eq(#mesa.conditions, 0)
	end,
	["converte compra validada da sessão em purchasedIds do corpo de combate"] = function(t)
		local perfil, cat = fixture()
		perfil.habilidadesCompradas = { "ability/agua/Principiante/onda" }
		local corpo, erro = FichaPersonagemProprio.construir(perfil, "Aria", cat)
		t.ok(corpo, erro)
		t.eq(corpo.construction.purchasedIds[1], "ability/agua/Principiante/onda")
		perfil.habilidadesCompradas = { "ability/agua/Principiante/desconhecida" }
		t.eq(FichaPersonagemProprio.construir(perfil, "Aria", cat), nil)
	end,
	["não compartilha tabelas com perfil nem entre recursos atuais e máximos"] = function(t)
		local perfil, cat = fixture()
		local corpo = FichaPersonagemProprio.construir(perfil, "Aria", cat)
		corpo.calculated.attributes.agilidade = 20
		corpo.construction.inventory[1].name = "Alterado"
		corpo.session.current.pv = 0
		t.eq(perfil.atributos.agilidade, 1)
		t.eq(perfil.inventarioInicial[1].name, "Cajado / Foco Arcano")
		t.eq(corpo.calculated.maxima.pv, 22)
	end,
	["recusa ausência de qualquer seção essencial do perfil"] = function(t)
		for _, chave in { "construcao", "atributos", "pericias", "estatisticas", "pontosAprimoramento", "kitInicial", "inventarioInicial" } do
			local perfil, cat = fixture()
			perfil[chave] = nil
			local corpo, erro = FichaPersonagemProprio.construir(perfil, "Aria", cat)
			t.eq(corpo, nil, chave)
			t.ok(type(erro) == "string", chave)
		end
	end,
	["recusa subgrupo sem kit e inventário parcial ou equipado fora do recorte"] = function(t)
		local perfil, cat = fixture()
		cat.POR_ID["tree/agua"].data.subgroup = "Sem mapping"
		t.eq(FichaPersonagemProprio.construir(perfil, "Aria", cat), nil)
		for _, alterar in {
			function(p) table.remove(p.inventarioInicial, 1) end,
			function(p) p.inventarioInicial[1].equipped = true end,
			function(p) p.kitInicial.itens = {} end,
		} do
			perfil, cat = fixture()
			alterar(perfil)
			t.eq(FichaPersonagemProprio.construir(perfil, "Aria", cat), nil)
		end
	end,
	["recusa dados calculados alternativos ou adulterados e PA inconsistente"] = function(t)
		for _, alterar in {
			function(p) p.calculated = { maxima = { pv = 999 } } end,
			function(p) p.session = { current = { pv = 999 } } end,
			function(p) p.estatisticas.maxima.pv = 999 end,
			function(p) p.atributos.forca = 30 end,
			function(p) p.pericias = {} end,
			function(p) p.pontosAprimoramento.restantes = 3 end,
			function(p) p.construcao.pontosAprimoramento.custoEscolhaRaca = 0 end,
			function(p) p.construcao.purchasedIds = {} end,
		} do
			local perfil, cat = fixture()
			alterar(perfil)
			local corpo, erro = FichaPersonagemProprio.construir(perfil, "Aria", cat)
			t.eq(corpo, nil)
			t.ok(type(erro) == "string")
		end
	end,
	["recusa nome estruturalmente inválido e catálogo ausente ou incompleto com erro seguro"] = function(t)
		local perfil, cat = fixture()
		for _, nome in { "", "   ", "Aria\n", string.rep("a", 33), false } do
			local corpo, erro = FichaPersonagemProprio.construir(perfil, nome, cat)
			t.eq(corpo, nil)
			t.ok(type(erro) == "string")
		end
		t.eq(FichaPersonagemProprio.construir(perfil, "Aria", nil), nil)
		cat.POR_ID["race/humano"] = nil
		t.eq(FichaPersonagemProprio.construir(perfil, "Aria", cat), nil)
		local corpo, erro = FichaPersonagemProprio.construir(false, "Aria", cat)
		t.eq(corpo, nil)
		t.eq(erro, "Perfil inicial incompleto ou incompatível.")
	end,
	["nome filtrado precisa corresponder ao nome guardado no perfil"] = function(t)
		local perfil, cat = fixture()
		local corpo = FichaPersonagemProprio.construir(perfil, "Outra", cat)
		t.eq(corpo, nil)
		local nomeFiltrado = "Ária"
		perfil.nome = nomeFiltrado
		corpo = FichaPersonagemProprio.construir(perfil, nomeFiltrado, cat)
		t.eq(corpo.name, nomeFiltrado)
	end,
	["recursos e contador de descanso persistidos alimentam somente a sessão da ficha"] = function(t)
		local perfil, cat = fixture()
		local atuais = { pv = math.min(3, perfil.estatisticas.maxima.pv), pm = math.min(2, perfil.estatisticas.maxima.pm),
			pt = math.min(1, perfil.estatisticas.maxima.pt), pp = math.min(1, perfil.estatisticas.maxima.pp) }
		perfil.descanso = { atuais = atuais, descansosCurtos = 2 }
		local corpo = FichaPersonagemProprio.construir(perfil, "Aria", cat)
		for chave, valor in atuais do t.eq(corpo.session.current[chave], valor) end
		t.eq(corpo.session.shortRests, 2)
	end,
	["estado de missão valida contra catálogo e migra perfil antigo para estado vazio"] = function(t)
		local perfil, cat = fixture()
		local corpo = FichaPersonagemProprio.construir(perfil, "Aria", cat)
		t.ok(corpo ~= nil)
		perfil.missoes = { desconhecida = { estado = "aceita", progresso = 0 } }
		t.eq(FichaPersonagemProprio.construir(perfil, "Aria", cat), nil)
	end,
}
