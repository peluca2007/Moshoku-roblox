local Descanso = require(game:GetService("ReplicatedStorage").Shared.Regras.DescansoAcampamento)
return {
	["curto aplica 25% arredondado para baixo e limita a dois"] = function(t)
		local entrada = { tipo = "curto", maximos = { pv = 11, pm = 7, pt = 3, pp = 5 }, descansosCurtos = 0 }
		local um = assert(Descanso.resolver(entrada))
		t.eq(um.ganho.pv, 2); t.eq(um.ganho.pm, 1); t.eq(um.ganho.pt, 3); t.eq(um.ganho.pp, 1); t.eq(um.descansosCurtos, 1)
		entrada.atuais, entrada.descansosCurtos = um.atuais, 1
		local dois = assert(Descanso.resolver(entrada)); t.eq(dois.descansosCurtos, 2)
		entrada.descansosCurtos = 2
		local negado = Descanso.resolver(entrada); t.eq(negado, nil)
	end,
	["longo restaura recursos, soma sono e zera curtos"] = function(t)
		local r = assert(Descanso.resolver({ tipo = "longo", maximos = { pv = 20, pm = 9, pt = 4, pp = 6 },
			atuais = { pv = 1, pm = 0, pt = 0, pp = 0 }, descansosCurtos = 2, vigor = 3, maiorBonus = 2 }))
		t.eq(r.atuais.pv, 13); t.eq(r.atuais.pm, 9); t.eq(r.atuais.pt, 4); t.eq(r.atuais.pp, 6); t.eq(r.descansosCurtos, 0)
	end,
	["valida tipo e estado de recursos antes de alterar"] = function(t)
		local r, erro = Descanso.resolver({ tipo = "downtime", maximos = { pv = 1, pm = 1, pt = 1, pp = 1 } })
		t.eq(r, nil); t.ok(erro ~= nil)
	end,
}
