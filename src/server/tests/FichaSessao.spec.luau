local FichaSessao = require(game:GetService("ReplicatedStorage").Shared.FichaSessao)

local function token()
	return {
		name = "Nome da mesa", pv = 7, pvMax = 30, mana = 4, manaMax = 15,
		conditions = { { id = "apontado", stacks = 1, note = "nota privada" } },
		ficha2 = {
			name = "Nome importado", construction = { purchasedIds = { "ability/agua/Principiante/bola-de-agua" } },
			calculated = { maxima = { pv = 22, pm = 12, pt = 5, pp = 2 } },
			session = { current = { pv = 22, pm = 12, pt = 3, pp = 1 }, conditions = {}, shortRests = 1 },
		},
	}
end

return {
	["recursos e nome acompanham alterações da mesa"] = function(t)
		local ficha = FichaSessao.projetar(token(), true)
		t.eq(ficha.name, "Nome da mesa")
		t.eq(ficha.session.current.pv, 7)
		t.eq(ficha.session.current.pm, 4)
		t.eq(ficha.calculated.maxima.pv, 30)
		t.eq(ficha.calculated.maxima.pm, 15)
	end,
	["PT PP e descanso mantêm o estado disponível"] = function(t)
		local ficha = FichaSessao.projetar(token(), true)
		t.eq(ficha.session.current.pt, 3)
		t.eq(ficha.session.current.pp, 1)
		t.eq(ficha.calculated.maxima.pt, 5)
		t.eq(ficha.session.shortRests, 1)
	end,
	["condições atuais incluem notas somente quando autorizado"] = function(t)
		local privado = FichaSessao.projetar(token(), true)
		local publico = FichaSessao.projetar(token(), false)
		t.eq(privado.session.conditions[1].conditionId, "condition/apontado")
		t.eq(privado.session.conditions[1].note, "nota privada")
		t.eq(publico.session.conditions[1].note, nil)
		t.eq(publico.session.conditions[1].stacks, 1)
	end,
	["remoção de condição não reapresenta condição importada"] = function(t)
		local origem = token()
		origem.ficha2.session.conditions = { { conditionId = "condition/cego", stacks = 1 } }
		origem.conditions = {}
		t.eq(#FichaSessao.projetar(origem, true).session.conditions, 0)
	end,
	["projeção não compartilha tabelas nem modifica a origem"] = function(t)
		local origem = token()
		local ficha = FichaSessao.projetar(origem, true)
		ficha.construction.purchasedIds[1] = "alterado"
		ficha.session.conditions[1].note = "alterado"
		t.eq(origem.ficha2.session.current.pv, 22)
		t.eq(origem.ficha2.calculated.maxima.pv, 22)
		t.eq(origem.conditions[1].note, "nota privada")
		t.eq(origem.ficha2.construction.purchasedIds[1], "ability/agua/Principiante/bola-de-agua")
	end,
	["ficha v1 continua sem corpo v2"] = function(t)
		t.eq(FichaSessao.projetar({ name = "V1" }, true), nil)
	end,
}
