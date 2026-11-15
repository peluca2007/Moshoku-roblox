local Shared = game:GetService("ReplicatedStorage").Shared
local E = require(Shared.Regras.ExaustaoRun)
local G = require(Shared.Regras.ExpedicaoGerador)
local Sessao = require(Shared.Regras.RunSessao)
local Esgoto = require(Shared.Mundo.ExpedicaoEsgoto)
local Tela = require(Shared.Regras.ExpedicaoTela)

local function rngFixo(n) return { NextInteger = function(_, lo, hi) return math.clamp(n, lo, hi) end } end
local function nova(dados)
	dados = dados or {}
	return Sessao.new({
		rng = rngFixo(7), carregar = function(k) return dados[k] end,
		guardar = function(k, v) if dados.falhar then error("fora do ar") end; dados[k] = v end,
		historiaDaSemente = function(s) return G.gerar(Esgoto.AREA, s) end, objetivo = G.OBJETIVO, area = Esgoto.AREA,
	}), dados
end
local function votar(t, s, opcao)
	local ok, r = s:votar(1, opcao)
	t.ok(ok and type(r) == "table" and r.avancou, opcao .. ": " .. tostring(r))
end
local DE_PE = { [1] = { caiu = false } }

return {
	["primeira luta sem exaustão; cada luta seguinte +1; cair soma +1"] = function(t)
		local e = E.aoFimDaLuta({}, DE_PE)
		t.eq(E.nivel(e, 1), 0)
		e = E.aoFimDaLuta(e, DE_PE)
		t.eq(E.nivel(e, 1), 1)
		e = E.aoFimDaLuta(e, { [1] = { caiu = true } })
		t.eq(E.nivel(e, 1), 3)
		t.eq(E.nivel(E.aoFimDaLuta({}, { [2] = { caiu = true } }), 2), 1) -- caiu na primeira: só o Fio da Vida
	end,
	["teto no nível 5 (nível 6 do livro pendente) e descansar zera"] = function(t)
		local e = {}
		for _ = 1, 10 do e = E.aoFimDaLuta(e, DE_PE) end
		t.eq(E.nivel(e, 1), E.MAX)
		t.eq(E.MAX, 5)
		e = E.descansar(e, { 1 })
		t.eq(E.nivel(e, 1), 0)
		t.eq(E.nivel(E.aoFimDaLuta(e, DE_PE), 1), 0) -- primeira depois do descanso
	end,
	["zerar a sequência mantém o nível"] = function(t)
		local e = E.aoFimDaLuta(E.aoFimDaLuta({}, DE_PE), DE_PE)
		e = E.zerarSequencia(e)
		t.eq(E.nivel(e, 1), 1)
		t.eq(E.nivel(E.aoFimDaLuta(e, DE_PE), 1), 1) -- primeira luta depois de entrar na área
	end,
	["serializa como texto plano e restaura com o tipo do id"] = function(t)
		local e = { [1] = { nivel = 2, lutas = 3 }, ["x"] = { nivel = 1, lutas = 0 } }
		local texto = E.serializar(e)
		t.eq(type(texto), "string")
		local de = assert(E.restaurar(texto))
		t.eq(de[1].nivel, 2); t.eq(de[1].lutas, 3); t.eq(de.x.nivel, 1)
		t.eq(next(assert(E.restaurar(nil))), nil)
		t.eq((E.restaurar("lixo")), nil)
		t.eq((E.restaurar("n1=9/0")), nil) -- acima do teto
		local so = assert(E.restaurar(texto, { [1] = {} })) -- quem saiu da run é ignorado
		t.eq(so.x, nil)
	end,
	["efeitos: só a marca Exausto é aplicada (nível 3+); o resto fica pendente com o texto do livro"] = function(t)
		t.eq(#E.efeitosNaLuta(2).condicoes, 0)
		t.eq(#E.efeitosNaLuta(2).pendentes, 2)
		local tres = E.efeitosNaLuta(3)
		t.eq(tres.condicoes[1], "exausto")
		t.eq(#tres.pendentes, 3)
		t.eq(E.efeitosNaLuta(nil).nivel, 0)
	end,
	["sessão: exaustão conta na expedição, aparece na visão, salva e o acampamento zera"] = function(t)
		local s, dados = nova()
		s:iniciar("g", { { userId = 1 } })
		votar(t, s, "entrar-esgoto")
		t.eq((s:lutaTerminou("victory", DE_PE)), true)
		t.eq(s:visao(1).exaustao, 0) -- primeira luta da área
		votar(t, s, "caminho-a")
		t.eq(s:lutaPendente().exaustao[1], nil)
		t.eq((s:lutaTerminou("victory", DE_PE)), true)
		t.eq(s:visao(1).exaustao, 1)
		votar(t, s, "caminho-a")
		t.eq(s:lutaPendente().exaustao[1], 1) -- o servidor aplica no início da luta
		t.eq((s:lutaTerminou("fled", { [1] = { caiu = true } })), true) -- fuga também conta (e a queda)
		t.eq(s:visao(1).exaustao, 3)
		t.ok(s.luta ~= nil, "fuga mantém a luta pendente")
		local s2 = nova(dados)
		t.eq((s2:retomar("g")), true)
		t.eq(s2:visao(1).exaustao, 3) -- salvo com a run
		t.eq((s2:lutaTerminou("victory", DE_PE)), true)
		t.eq(s2:visao(1).exaustao, 4)
		t.eq(Tela.decidir(s2:visao(1), {}).exaustao, "Exaustão 4")
		t.eq((s2:descansarNoAcampamento(1)), true)
		t.eq(s2:visao(1).exaustao, 0)
		t.eq(Tela.decidir(s2:visao(1), {}).exaustao, nil)
	end,
	["sessão: derrota volta à cidade, zera a sequência e falha de save desfaz"] = function(t)
		local s, dados = nova()
		s:iniciar("g", { { userId = 1 } })
		votar(t, s, "entrar-esgoto")
		t.eq((s:lutaTerminou("victory", DE_PE)), true)
		votar(t, s, "caminho-a")
		dados.falhar = true
		t.eq((s:lutaTerminou("defeat", { [1] = { caiu = true } })), false)
		t.eq(s:visao(1).exaustao, 0) -- desfeito
		dados.falhar = false
		t.eq((s:lutaTerminou("defeat", { [1] = { caiu = true } })), true)
		t.eq(s:visao(1).tipoDoNo, "hub")
		t.eq(s:visao(1).exaustao, 2) -- segunda luta seguida + queda
		votar(t, s, "retomar-esgoto-esgoto-1")
		votar(t, s, "caminho-a")
		t.eq((s:lutaTerminou("victory", DE_PE)), true)
		t.eq(s:visao(1).exaustao, 2) -- primeira luta depois de entrar de novo na área: não soma
		t.eq((s:lutaTerminou("x", DE_PE)), false)
	end,
	["sessão: ids fora da run e lutas sem participantes não mexem na exaustão"] = function(t)
		local s = nova()
		s:iniciar("g", { { userId = 1 } })
		votar(t, s, "entrar-esgoto")
		t.eq((s:lutaTerminou("victory", { [99] = { caiu = true } })), true)
		t.eq(E.nivel(s.exaustao, 99), 0)
		votar(t, s, "caminho-a")
		t.eq((s:lutaTerminou("victory")), true) -- sem participantes (servidor antigo)
		t.eq(s:visao(1).exaustao, 0)
	end,
}
