local Shared = game:GetService("ReplicatedStorage").Shared
local H = require(Shared.Regras.RunHistoria)
local Run = require(Shared.Regras.Run)
local V1 = require(Shared.Mundo.HistoriaV1)

local function nova()
	return Run.nova({ jogadores = { "ana" }, objetivo = V1.OBJETIVO, regiao = "vila", galho = V1.HISTORIA.inicio })
end

local function mini(muda)
	local h = { inicio = "a", nos = {
		a = { tipo = "vila", opcoes = { { id = "x", para = "b" } } },
		b = { tipo = "final" },
	} }
	if muda then muda(h) end
	return h
end

return {
	["a historia da v1 e valida e todos os nos sao alcancaveis"] = function(t)
		local ok, problemas = H.validar(V1.HISTORIA)
		t.ok(ok, table.concat(problemas, "; "))
		t.eq(#problemas, 0)
	end,
	["validador acusa destino inexistente, no sem saida, final com opcoes e inalcancavel"] = function(t)
		t.eq((H.validar(mini())), true)
		local ok, p = H.validar(mini(function(h) h.nos.a.opcoes[1].para = "zzz" end))
		t.eq(ok, false)
		t.ok(#p >= 1)
		t.eq((H.validar(mini(function(h) h.nos.a.opcoes = {} end))), false)
		t.eq((H.validar(mini(function(h) h.nos.b.opcoes = { { id = "y", para = "a" } } end))), false)
		t.eq((H.validar(mini(function(h) h.nos.c = { tipo = "final" } end))), false) -- inalcançável
		t.eq((H.validar(mini(function(h) h.inicio = "q" end))), false)
		t.eq((H.validar(mini(function(h) h.nos.a.tipo = "estranho" end))), false)
		t.eq((H.validar(mini(function(h) h.nos.a.opcoes[1].dias = 0.3 end))), false)
		t.eq((H.validar(mini(function(h) table.insert(h.nos.a.opcoes, { id = "x", para = "b" }) end))), false) -- id repetido
		t.eq((H.validar(nil)), false)
	end,
	["luta so em no chefe, com criaturas e area; a v1 declara as duas lutas"] = function(t)
		t.eq(type(V1.HISTORIA.nos["chefe-floresta"].luta.criaturas[1]), "string")
		t.eq(type(V1.HISTORIA.nos["chefe-ruinas"].luta.areaId), "string")
		local function com(muda)
			local h = { inicio = "a", nos = { a = { tipo = "chefe", opcoes = { { id = "x", para = "b" } },
				luta = { criaturas = { "creature/x" }, areaId = "region/encounter/y" } }, b = { tipo = "final" } } }
			muda(h)
			return (H.validar(h))
		end
		t.eq(com(function() end), true)
		t.eq(com(function(h) h.nos.a.tipo = "regiao" end), false)
		t.eq(com(function(h) h.nos.a.luta.criaturas = {} end), false)
		t.eq(com(function(h) h.nos.a.luta.areaId = 5 end), false)
	end,
	["sem final alcancavel e recusado"] = function(t)
		local h = { inicio = "a", nos = {
			a = { tipo = "vila", opcoes = { { id = "x", para = "b" } } },
			b = { tipo = "regiao", opcoes = { { id = "y", para = "a" } } },
		} }
		local ok, p = H.validar(h)
		t.eq(ok, false)
		t.ok(table.concat(p, ";"):find("final") ~= nil)
	end,
	["opcoes mostram tranca fechada com motivo e liberam ao abrir a flag"] = function(t)
		local function achar(lista, id) for _, o in lista do if o.id == id then return o end end end
		local run = Run.moverPara(nova(), "ruinas-do-vale", "ruinas-do-vale")
		local o = H.opcoes(V1.HISTORIA, run)
		t.eq(#o, 3)
		t.eq(achar(o, "entrar-na-camara").liberada, false)
		t.ok(achar(o, "entrar-na-camara").motivo ~= nil)
		t.eq(achar(o, "forcar-a-passagem").liberada, true)
		t.eq(achar(o, "voltar").liberada, true)
		local aberta = Run.definirFlag(run, "passagem-aberta")
		t.eq(achar(H.opcoes(V1.HISTORIA, aberta), "entrar-na-camara").liberada, true)
		t.eq(#H.opcoes(V1.HISTORIA, Run.moverPara(nova(), "vila", "final-selo")), 0)
	end,
	["forcar a passagem abre a camara por escolha da historia e custa um dia"] = function(t)
		local run = Run.moverPara(nova(), "ruinas-do-vale", "ruinas-do-vale")
		local depois = H.avancar(V1.HISTORIA, run, "forcar-a-passagem")
		t.eq(depois.galho, "ruinas-do-vale")
		t.eq(depois.dia, 1)
		t.eq(Run.temFlag(depois, "passagem-aberta"), true)
		t.ok(H.avancar(V1.HISTORIA, depois, "entrar-na-camara") ~= nil)
	end,
	["avancar recusa opcao trancada sem gastar prazo"] = function(t)
		local run = Run.moverPara(nova(), "ruinas-do-vale", "ruinas-do-vale")
		local r, _, motivo = H.avancar(V1.HISTORIA, run, "entrar-na-camara")
		t.eq(r, nil)
		t.ok(motivo ~= nil)
		t.eq(run.dia, 0)
		t.eq((H.avancar(V1.HISTORIA, run, "inexistente")), nil)
	end,
	["percurso completo pela floresta termina em final e cabe no prazo"] = function(t)
		local run = nova()
		local passos = { "rumo-a-floresta", "enfrentar-o-guardiao", "pegar-o-selo", "entregar-o-selo" }
		for _, id in passos do
			if id == "pegar-o-selo" then
				-- Sem vencer a luta do chefe o Selo continua trancado.
				t.eq((H.avancar(V1.HISTORIA, run, id)), nil)
				run = Run.definirFlag(run, "vencido/chefe-floresta")
			end
			local novo, _, motivo = H.avancar(V1.HISTORIA, run, id)
			t.ok(novo ~= nil, id .. ": " .. tostring(motivo))
			run = novo
		end
		t.eq(Run.encerrada(run), true)
		t.eq(run.fim.motivo, "final")
		t.eq(run.fim.final, "final-selo")
		t.eq(run.dia, 2)
		t.eq(run.objetivo.status, "cumprido") -- o final do Selo cumpre o objetivo
		t.eq(Run.regioesVisitadas(run), 1)
		t.eq(Run.temFlag(run, "selo-obtido"), true)
		t.eq((H.avancar(V1.HISTORIA, run, "voltar")), nil) -- run terminada
	end,
	["percurso pelas ruinas exige abrir a passagem e estourar o prazo expira o objetivo"] = function(t)
		local run = H.avancar(V1.HISTORIA, nova(), "rumo-as-ruinas")
		t.eq(run.galho, "ruinas-do-vale")
		t.eq((H.avancar(V1.HISTORIA, run, "entrar-na-camara")), nil)
		run = Run.definirFlag(run, "passagem-aberta")
		-- Gasta o prazo quase todo andando em círculos entre a vila e as ruínas.
		local atual = run
		for _ = 1, 5 do
			atual = H.avancar(V1.HISTORIA, atual, "voltar")
			atual = H.avancar(V1.HISTORIA, atual, "rumo-as-ruinas")
		end
		t.eq(atual.dia, 11)
		local atras, antes = H.avancar(V1.HISTORIA, atual, "voltar")
		t.eq(atras.dia, 12)
		t.eq(antes, true) -- W1b: zero tempo restante já expirou
		t.eq(atras.objetivo.status, "expirado")
		local depois, expirou = H.avancar(V1.HISTORIA, atras, "rumo-as-ruinas")
		t.eq(expirou, false) -- a transição já foi sinalizada ao atingir o limite
		t.eq(depois.objetivo.status, "expirado")
		-- Prazo vencido não encerra a run: o grupo ainda chega ao final (consequências são da história).
		local camara = H.avancar(V1.HISTORIA, depois, "entrar-na-camara")
		t.eq(camara.galho, "chefe-ruinas")
		local volta = H.avancar(V1.HISTORIA, Run.definirFlag(camara, "vencido/chefe-ruinas"), "pegar-o-selo")
		local fim = H.avancar(V1.HISTORIA, volta, "entregar-o-selo")
		t.eq(fim.fim.final, "final-selo")
		t.eq(fim.objetivo.status, "expirado")
	end,
}
