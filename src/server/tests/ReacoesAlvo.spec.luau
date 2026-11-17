-- REA1: reação do alvo por habilidade/tipo/resultado (pura).
local R = require(game:GetService("ReplicatedStorage").Shared.ReacoesAlvo)
local CB = "ability/deus-da-espada/Principiante/corte-de-braco"
return {
	["tipo do alvo pelo nome"] = function(t)
		t.eq(R.tipoDoAlvo("Lobo Cinzento"), "quadrupede")
		t.eq(R.tipoDoAlvo("Rato Gigante"), "quadrupede")
		t.eq(R.tipoDoAlvo("Aranha da Floresta"), "aracnideo")
		t.eq(R.tipoDoAlvo("Bandido de Estrada"), "humanoide")
		t.eq(R.tipoDoAlvo("Goblin Batedor"), "humanoide")
		t.eq(R.tipoDoAlvo(nil), "humanoide")
	end,
	["Corte de Braço: falhou no Vigor e tem arma: a arma cai"] = function(t)
		local d = R.decidir(CB, "humanoide", true, { acertou = true, passou = false, dano = 6, largouArma = true })
		t.eq(d.reacao, "larga-arma")
		t.ok(d.solta)
	end,
	["Corte de Braço: sem arma no modelo nada cai, o membro cede"] = function(t)
		local lobo = R.decidir(CB, "quadrupede", false, { acertou = true, passou = false, dano = 6 })
		t.eq(lobo.reacao, "membro-atingido")
		t.eq(lobo.membro, "pata")
		t.ok(not lobo.solta)
		local homem = R.decidir(CB, "humanoide", false, { acertou = true, passou = false, dano = 6 })
		t.eq(homem.membro, "braco")
	end,
	["Corte de Braço: passou no Vigor só recua forte; servidor negando a queda vence"] = function(t)
		local d = R.decidir(CB, "humanoide", true, { acertou = true, passou = true, dano = 6 })
		t.eq(d.reacao, "recuo-forte")
		t.ok(not d.solta)
		local n = R.decidir(CB, "humanoide", true, { acertou = true, passou = false, dano = 6, largouArma = false })
		t.ok(not n.solta, "o servidor diz que nada caiu")
	end,
	["erro vira esquiva, crítico cambaleia, golpe normal recua"] = function(t)
		t.eq(R.decidir(CB, "humanoide", true, { acertou = false }).reacao, "esquiva")
		t.eq(R.decidir("mesa/ataque-basico", "humanoide", true, { acertou = true, critico = true, dano = 9 }).reacao, "cambaleio")
		local n = R.decidir("mesa/ataque-basico", "quadrupede", false, { acertou = true, dano = 4 })
		t.eq(n.reacao, "recuo")
		t.ok(not n.solta)
		t.eq(R.decidir("mesa/ataque-basico", "humanoide", true, { acertou = true, dano = 0 }).reacao, "bloqueio")
	end,
}
