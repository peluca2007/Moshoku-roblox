local Shared = game:GetService("ReplicatedStorage").Shared
local G = require(Shared.Regras.ExpedicaoGerador)
local H = require(Shared.Regras.RunHistoria)
local Sessao = require(Shared.Regras.RunSessao)
local Esgoto = require(Shared.Mundo.ExpedicaoEsgoto)
local AREA = Esgoto.AREA

local function rngFixo(n) return { NextInteger = function(_, lo, hi) return math.clamp(n, lo, hi) end } end

-- Sessão de expedição com armazenamento em memória (`dados` compartilhado permite testar o retomar).
local function nova(semente, dados)
	dados = dados or {}
	local deps = {
		rng = rngFixo(semente or 7), guardar = function(k, v) dados[k] = v end, carregar = function(k) return dados[k] end,
		historiaDaSemente = function(s) return G.gerar(AREA, s) end, objetivo = G.OBJETIVO, area = AREA,
	}
	return Sessao.new(deps), dados
end

local function votar(t, s, opcao)
	local ok, r = s:votar(1, opcao)
	t.ok(ok and type(r) == "table" and r.avancou, opcao .. ": " .. tostring(r))
end

local function ganhar(t, s)
	t.eq(s:visao(1).fase, "luta")
	t.eq((s:lutaTerminou("victory")), true)
	t.eq(s:visao(1).fase, "acampamento")
end

local function achar(lista, id) for _, o in lista do if o.id == id then return o end end end

local function igual(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return a == b end
	for k, v in a do if not igual(v, b[k]) then return false end end
	for k in b do if a[k] == nil then return false end end
	return true
end

return {
	["o gerador e deterministico e valido para varias sementes"] = function(t)
		for semente = 1, 40 do
			local h = G.gerar(AREA, semente)
			local ok, problemas = H.validar(h)
			t.ok(ok, semente .. ": " .. table.concat(problemas, "; ")) -- validar também exige todos os nós alcançáveis
			t.ok(igual(h, G.gerar(AREA, semente)), "mesma semente, mesma história")
		end
		local diferentes = false
		for semente = 2, 40 do
			if not igual(G.gerar(AREA, 1), G.gerar(AREA, semente)) then diferentes = true end
		end
		t.ok(diferentes, "sementes diferentes variam os encontros")
	end,
	["estrutura: salas, alternativas distintas, custos de voltar e retomadas"] = function(t)
		local h = G.gerar(AREA, 11)
		t.eq(h.nos["cidade"].tipo, "hub")
		t.eq(achar(h.nos["cidade"].opcoes, "entrar-esgoto").dias, 1)
		t.eq(achar(h.nos["cidade"].opcoes, "entrar-esgoto").para, "esgoto-1")
		t.eq(#h.nos["cidade"].opcoes, 1 + 9) -- entrar + uma retomada por sala (1 + 4*2)
		local r = achar(h.nos["cidade"].opcoes, "retomar-esgoto-esgoto-3a")
		t.eq(r.dias, 1 + 3 * 0.5)
		t.eq(r.exige.flag, "vencido/esgoto-3a")
		for passo = 2, 5 do
			local a, b = h.nos["esgoto-" .. passo .. "a"], h.nos["esgoto-" .. passo .. "b"]
			t.eq(a.passo, passo)
			t.eq(a.total, 5)
			t.eq(a.area, "esgoto")
			t.ok(a.luta.criaturas[1] ~= b.luta.criaturas[1], "alternativas com encontros diferentes")
			t.eq(achar(a.opcoes, "voltar-a-cidade").dias, math.max(1, passo * 0.5))
			t.eq(achar(a.opcoes, "voltar-a-cidade").exige.flag, "vencido/esgoto-" .. passo .. "a")
		end
		local primeira = h.nos["esgoto-1"]
		t.eq(achar(primeira.opcoes, "caminho-a").para, "esgoto-2a")
		t.ok(achar(primeira.opcoes, "caminho-a").dica ~= nil)
		t.eq(achar(primeira.opcoes, "voltar-a-cidade").dias, 1)
		t.eq(achar(h.nos["esgoto-5b"].opcoes, "enfrentar-o-chefe").para, "esgoto-chefe")
		t.eq(h.nos["esgoto-chefe"].tipo, "chefe")
		t.eq(h.nos["final-esgoto"].cumpreObjetivo, true)
	end,
	["percurso completo: lutas, descanso limitado, chefe e final cumprem o objetivo"] = function(t)
		local s = nova()
		t.eq((s:iniciar("g", { { userId = 1 } })), true)
		t.eq(s:visao(1).area, nil)
		votar(t, s, "entrar-esgoto")
		local v = s:visao(1)
		t.eq(v.passo, 1)
		t.eq(v.totalPassos, 5)
		t.eq(v.area, "esgoto")
		t.eq(v.fase, "luta")
		t.eq(#v.opcoes, 0)
		t.eq((s:descansarNoAcampamento(1)), false) -- em luta não descansa
		ganhar(t, s)
		v = s:visao(1)
		t.eq(v.descansos.usados, 0)
		t.eq(v.descansos.max, 2)
		t.eq(achar(v.opcoes, "caminho-a").dias, 0)
		t.ok(achar(v.opcoes, "caminho-b").dica ~= nil)
		t.eq(s.run.dia, 1)
		t.eq((s:descansarNoAcampamento(1)), true)
		t.eq((s:descansarNoAcampamento(1)), true)
		t.eq((s:descansarNoAcampamento(1)), false) -- limite por área
		t.eq(s.run.dia, 2)
		t.eq(s:visao(1).descansos.usados, 2)
		for passo = 2, 5 do
			votar(t, s, if passo % 2 == 0 then "caminho-a" else "caminho-b")
			t.eq(s:visao(1).passo, passo)
			ganhar(t, s)
		end
		votar(t, s, "enfrentar-o-chefe")
		t.eq(s:visao(1).tipoDoNo, "chefe")
		ganhar(t, s)
		votar(t, s, "voltar-com-a-recompensa")
		local r = s:resumo(1)
		t.eq(r.status, "final")
		t.eq(r.objetivoCumprido, true)
		t.eq(s.run.flags["expedicao/esgoto/concluida"], true)
	end,
	["voltar a cidade custa pelo passo; so a retomada mais funda aparece e nao repete luta"] = function(t)
		local s = nova()
		s:iniciar("g", { { userId = 1 } })
		votar(t, s, "entrar-esgoto")
		ganhar(t, s)
		votar(t, s, "caminho-a")
		ganhar(t, s)
		votar(t, s, "caminho-a")
		ganhar(t, s)
		t.eq(s.run.dia, 1)
		votar(t, s, "voltar-a-cidade")
		t.eq(s.run.galho, "cidade")
		t.eq(s.run.dia, 2.5) -- passo 3: 1,5 dia
		local v = s:visao(1)
		t.eq(#v.opcoes, 2)
		t.ok(achar(v.opcoes, "entrar-esgoto") ~= nil)
		local retomada = achar(v.opcoes, "retomar-esgoto-esgoto-3a")
		t.ok(retomada ~= nil and retomada.liberada, "a retomada mais funda")
		t.eq(retomada.dias, 2.5)
		t.eq(v.fase, nil)
		votar(t, s, "retomar-esgoto-esgoto-3a")
		t.eq(s.run.dia, 5)
		t.eq(s:visao(1).fase, "acampamento")
		t.eq(s:lutaPendente(), nil)
		-- Voltar e entrar de novo na primeira sala (já vencida) também não luta.
		votar(t, s, "voltar-a-cidade")
		votar(t, s, "entrar-esgoto")
		t.eq(s:visao(1).fase, "acampamento")
	end,
	["derrota na expedicao volta a cidade sem encerrar a run nem vencer a sala"] = function(t)
		local s = nova()
		s:iniciar("g", { { userId = 1 } })
		votar(t, s, "entrar-esgoto")
		ganhar(t, s)
		votar(t, s, "caminho-a")
		local no = s.run.galho
		local ouro = s.run.ouroViagem
		t.eq(no, "esgoto-2a")
		t.eq((s:lutaTerminou("defeat")), true)
		t.eq(s.run.fim, nil)
		t.eq(s.run.galho, "cidade")
		t.eq(s.run.dia, 2) -- entrar 1 + voltar do passo 2 (1)
		t.ok(not s.run.jogadores[1].caido)
		t.eq(s.run.flags["vencido/" .. no], nil)
		t.eq(s.run.ouroViagem, ouro)
		t.eq(s.luta, nil)
		t.eq(s:visao(1).tipoDoNo, "hub")
		t.ok(achar(s:visao(1).opcoes, "retomar-esgoto-esgoto-1").liberada) -- o progresso do passo 1 segue
	end,
	["salvar e retomar no meio regenera a mesma historia"] = function(t)
		local s, dados = nova(123)
		s:iniciar("g", { { userId = 1 } })
		votar(t, s, "entrar-esgoto")
		ganhar(t, s)
		votar(t, s, "caminho-b")
		local s2 = nova(999, dados) -- rng diferente: a história vem da semente salva
		t.eq((s2:retomar("g")), true)
		t.ok(igual(s.historia, s2.historia))
		t.eq(s2.run.galho, "esgoto-2b")
		t.eq(s2:visao(1).fase, "luta")
		t.eq((s2:lutaTerminou("victory")), true)
		t.eq(s2:visao(1).fase, "acampamento")
	end,
}
