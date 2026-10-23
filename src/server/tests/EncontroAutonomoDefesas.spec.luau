local Defesas = require(game:GetService("ReplicatedStorage").Shared.EncontroAutonomoDefesas)

return {
	["PV temporários absorvem dano antes dos PV reais"] = function(t)
		local resultado = Defesas.aplicarDano(20, { valor = 8, expiraNoTurno = 20 }, 5, 3)
		t.eq(resultado.pv, 20)
		t.eq(resultado.pvTemporarios.valor, 3)
		t.eq(resultado.pvTemporarios.expiraNoTurno, 20)
		t.eq(resultado.danoAbsorvido, 5)
		t.eq(resultado.danoNosPv, 0)
	end,
	["dano acima dos PV temporários só reduz o excedente dos PV reais"] = function(t)
		local resultado = Defesas.aplicarDano(20, { valor = 4, expiraNoTurno = 20 }, 9, 3)
		t.eq(resultado.pv, 15)
		t.eq(resultado.pvTemporarios, nil)
		t.eq(resultado.danoAbsorvido, 4)
		t.eq(resultado.danoNosPv, 5)
	end,
	["PV temporários expirados não absorvem dano"] = function(t)
		local resultado = Defesas.aplicarDano(20, { valor = 8, expiraNoTurno = 3 }, 5, 3)
		t.eq(resultado.pv, 15)
		t.eq(resultado.pvTemporarios, nil)
		t.eq(resultado.danoAbsorvido, 0)
	end,
	["conservar o maior valor não soma nem renova uma proteção menor"] = function(t)
		local atuais = { valor = 10, expiraNoTurno = 40 }
		local novo, alterado = Defesas.concederPvTemporarios(atuais, 7, 12, 100)
		t.eq(alterado, false)
		t.eq(novo.valor, 10)
		t.eq(novo.expiraNoTurno, 40)
		t.eq(atuais.expiraNoTurno, 40, "o estado original não é mutado")
	end,
	["proteção maior substitui a menor com o prazo próprio de cem rodadas"] = function(t)
		local novo, alterado = Defesas.concederPvTemporarios({ valor = 7, expiraNoTurno = 40 }, 12, 12, 100)
		t.eq(alterado, true)
		t.eq(novo.valor, 12)
		t.eq(novo.expiraNoTurno, 112)
	end,
	["proteção expirada é substituída e remove não muta a entrada"] = function(t)
		local antiga = { valor = 12, expiraNoTurno = 3 }
		local nova, alterado = Defesas.concederPvTemporarios(antiga, 8, 3, 100)
		t.eq(alterado, true)
		t.eq(nova.valor, 8)
		t.eq(nova.expiraNoTurno, 103)
		local limpa, expirou = Defesas.expirarPvTemporarios(nova, 103)
		t.eq(limpa, nil)
		t.eq(expirou, true)
		t.eq(nova.valor, 8)
	end,
	["entradas inválidas não criam proteção nem alteram os PV"] = function(t)
		local novo, alterado, erro = Defesas.concederPvTemporarios(nil, -1, 1, 100)
		t.eq(novo, nil)
		t.eq(alterado, false)
		t.ok(type(erro) == "string")
		local dano, falha = Defesas.aplicarDano(20, nil, -1, 1)
		t.eq(dano, nil)
		t.ok(type(falha) == "string")
	end,
}
