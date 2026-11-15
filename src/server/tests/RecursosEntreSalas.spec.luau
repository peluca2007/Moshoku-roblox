local R = require(game:GetService("ReplicatedStorage").Shared.Regras.RecursosEntreSalas)

local MAX = { pv = 20, pm = 10, pt = 4, pp = 3 }

return {
	["o que foi gasto na luta segue para a próxima sala"] = function(t)
		local r = assert(R.resolver({ luta = { pv = 7, pm = 2, pt = 1, pp = 3 }, anteriores = MAX, maximos = MAX }))
		t.eq(r.atuais.pv, 7); t.eq(r.atuais.pm, 2); t.eq(r.atuais.pt, 1); t.eq(r.atuais.pp, 3)
		t.eq(r.caiu, false)
	end,
	["caído a 0 PV volta com 1 PV (estabilizado) e avisa a queda"] = function(t)
		local r = assert(R.resolver({ luta = { pv = 0, pm = 0 }, anteriores = { pv = 9, pm = 5, pt = 2, pp = 1 }, maximos = MAX }))
		t.eq(r.atuais.pv, 1); t.eq(r.caiu, true)
		t.eq(r.atuais.pm, 0)
		t.eq(r.atuais.pt, 2) -- PT/PP não lidos na luta ficam como estavam
		t.eq(r.atuais.pp, 1)
	end,
	["valores fora do intervalo ficam entre 0 e o máximo, inteiros"] = function(t)
		local r = assert(R.resolver({ luta = { pv = 99, pm = -3, pt = 2.7, pp = 0 / 0 }, maximos = MAX }))
		t.eq(r.atuais.pv, 20); t.eq(r.atuais.pm, 0); t.eq(r.atuais.pt, 2); t.eq(r.atuais.pp, 3)
	end,
	["lê a ficha da mesa: mana vira PM"] = function(t)
		local l = R.doToken({ pv = 5, mana = 4, pt = 1 })
		t.eq(l.pv, 5); t.eq(l.pm, 4); t.eq(l.pt, 1); t.eq(l.pp, nil)
		t.eq(R.doToken(nil), nil)
	end,
	["descanso completo do acampamento enche tudo"] = function(t)
		local a = assert(R.descansoCompleto(MAX))
		t.eq(a.pv, 20); t.eq(a.pm, 10); t.eq(a.pt, 4); t.eq(a.pp, 3)
		t.eq((R.descansoCompleto({ pv = 1 })), nil)
	end,
	["entrada inválida é recusada"] = function(t)
		t.eq((R.resolver(nil)), nil)
		t.eq((R.resolver({ luta = {}, maximos = { pv = -1, pm = 0, pt = 0, pp = 0 } })), nil)
	end,
}
