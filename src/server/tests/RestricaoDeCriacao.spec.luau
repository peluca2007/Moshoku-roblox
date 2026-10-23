local Restricao = require(game:GetService("ReplicatedStorage").Shared.Regras.RestricaoDeCriacao)

return {
	["sem funcao registrada nao ha restricao"] = function(t)
		Restricao.definir(nil)
		local a, m = Restricao.consultar({})
		t.eq(a, nil)
		t.eq(m, nil)
	end,
	["arvore vira id do catalogo e mensagem bloqueia"] = function(t)
		Restricao.definir(function() return "agua" end)
		t.eq((Restricao.consultar({})), "tree/agua")
		Restricao.definir(function() return nil, "Escolha antes." end)
		local a, m = Restricao.consultar({})
		t.eq(a, nil)
		t.eq(m, "Escolha antes.")
		Restricao.definir(function() return nil end)
		local a2, m2 = Restricao.consultar({})
		t.eq(a2, nil)
		t.eq(m2, nil)
		Restricao.definir(nil)
	end,
	["erro na funcao da run bloqueia por seguranca"] = function(t)
		Restricao.definir(function() error("quebrou") end)
		local a, m = Restricao.consultar({})
		t.eq(a, nil)
		t.ok(m ~= nil)
		Restricao.definir(nil)
	end,
}
