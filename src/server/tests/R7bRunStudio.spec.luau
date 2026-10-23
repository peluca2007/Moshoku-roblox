-- SOMENTE STUDIO: fronteira J1/arena/J2/callback e pagamento, com dependências controladas.
local Service = require(script.Parent.Parent.EncontroAutonomoService)
local function fixture(n, alterar)
	local pasta = Instance.new("Folder")
	local grupo, fichas, envios, terminais, pagos = {}, {}, {}, {}, {}
	for i = 1, n do
		local ch = Instance.new("Model"); ch.Parent = pasta
		local hum = Instance.new("Humanoid"); hum.Parent = ch
		local root = Instance.new("Part"); root.Name = "HumanoidRootPart"
		root.Position = Vector3.new(9000, 30, 9000); root.Parent = ch
		grupo[i] = { UserId = 700 + i, Character = ch }
		fichas[700+i] = { name = "Run " .. i,
			calculated = { attributes = { forca = 0, vigor = 0 }, skills = {}, initiative = { bonus = 50, advantage = false }, movementMeters = 9,
				maxima = { pv = 100, pm = 0 }, armorClass = 20 }, session = { current = { pv = 100 } } }
	end
	local tempo = 0
	local deps = { remote = {}, workspace = pasta,
		conectado = function(p) return table.find(grupo, p) ~= nil end,
		localizarJogador = function(id) for _, p in grupo do if p.UserId == id then return p end end end,
		corpoPessoal = function(p) return fichas[p.UserId], "Crie sua ficha pessoal antes de lutar." end,
		emitir = function(_, tipo, dado) if tipo == "estado" then table.insert(envios, dado) end end,
		agora = function() tempo += 1; return tempo end,
		agendarPrazo = function() end, cancelarPrazo = function() end,
		rng = { NextInteger = function(_, a) return a end, NextNumber = function() return 0 end },
		aoEncerrar = function(_, estado) table.insert(terminais, estado) end,
		recompensarEncontro = function(_, id, moedas) table.insert(pagos, {id=id, moedas=moedas}); return true, moedas end,
	}
	if alterar then alterar(deps, grupo, fichas) end
	return Service.start(deps), grupo, fichas, pasta, terminais, pagos
end
local function luta()
	return { no = "chefe-floresta", titulo = "Guardião", areaId = "region/encounter/dark-forest",
		criaturas = { "creature/urso-de-presas-vermelhas" } }
end
return {
	["inicia um a quatro longe de marco com arena elenco e papeis corretos"] = function(t)
		for n = 1, 4 do
			local api, grupo, _, pasta = fixture(n)
			local id = api.criarEncontroDaRun(grupo, luta()); t.ok(id)
			local lista = api.atores(id); local vistos, jogadores = {}, 0
			for _, a in lista do
				local chave = a.x .. ":" .. a.z; t.eq(vistos[chave], nil); vistos[chave] = true
				if a.kind == "jogador" then jogadores += 1; t.eq(a.z, 10)
				elseif a.fichaCriatura.catalogId == "creature/urso-de-presas-vermelhas" then
					t.eq(a.fichaCriatura.papel, if n == 1 then "lacaio" else "padrao")
					t.eq(a.recompensa.papel, a.fichaCriatura.papel); t.eq(a.respira, true)
				end
			end
			t.eq(jogadores, n); t.eq(api.criarEncontroDaRun(grupo, luta()), nil)
			pasta:Destroy()
		end
	end,
	["ficha ausente em qualquer integrante recusa atomicamente"] = function(t)
		local api, grupo, _, pasta = fixture(2, function(_, _, f) f[702] = nil end)
		local id, erro = api.criarEncontroDaRun(grupo, luta())
		t.eq(id, nil); t.eq(erro, "Crie sua ficha pessoal antes de lutar."); t.eq(api.emEncontroAtivo(), false)
		pasta:Destroy()
	end,
	["recusa morto fisico PV zero duplicata desconexao e legado"] = function(t)
		for _, alterar in {
			function(_, g) g[1].Character:FindFirstChildOfClass("Humanoid").Health = 0 end,
			function(_, _, f) f[701].session.current.pv = 0 end,
			function(_, g) g[2] = g[1] end,
			function(d) d.conectado = function() return false end end,
			function(d) d.emCombate = function() return true end end,
		} do
			local api, grupo, _, pasta = fixture(2, alterar)
			local id, erro = api.criarEncontroDaRun(grupo, luta()); t.eq(id, nil); t.ok(type(erro) == "string")
			t.eq(api.emEncontroAtivo(), false); pasta:Destroy()
		end
	end,
	["revalida encontro concorrente depois de carregar ficha"] = function(t)
		local api, entrou
		local grupo, pasta
		api, grupo, _, pasta = fixture(1, function(d)
			local original = d.corpoPessoal
			d.corpoPessoal = function(p)
				if not entrou then entrou = true; api.criar({
					{ id = "outro", userId = 701, kind = "jogador" }, { id = "npc", kind = "criatura" } }) end
				return original(p)
			end
		end)
		t.eq(api.criarEncontroDaRun(grupo, luta()), nil); pasta:Destroy()
	end,
	["IA espera chamador registrar ID mesmo se primeiro golpe derrubar jogador"] = function(t)
		local idRegistrado, idRecebido
		local api, g, _, pasta, fim = fixture(1, function(d, _, fichas)
			fichas[701].calculated.initiative.bonus = -50
			fichas[701].session.current.pv = 1
			d.rng.NextInteger = function(_, _, maximo) return maximo end
			d.aoEncerrar = function(_, estado)
				idRecebido = estado.encounterId
			end
		end)
		-- Callback dedicado: não depender do escopo de locais ainda em inicialização.
		-- A ausência de terminal antes de retornar prova o contrato com RunServico.
		idRegistrado = api.criarEncontroDaRun(g, luta())
		t.eq(api.estado(idRegistrado).phase, "active")
		task.wait()
		t.eq(api.estado(idRegistrado).phase, "defeat")
		t.eq(idRecebido, idRegistrado)
		pasta:Destroy()
	end,

	["vitoria notifica e paga N6 uma vez com o papel solo"] = function(t)
		local api, g, _, pasta, fim, pagos = fixture(1, function(d, _, fichas)
			fichas[701].construction = { unlockedRankIds = {}, purchasedIds = {} }
			fichas[701].calculated.attributes = { forca = 50, agilidade = 0 }
			d.rng.NextInteger = function(_, _, maximo) return maximo end
		end)
		local id = api.criarEncontroDaRun(g, luta()); local e = api.estado(id)
		local pedido = { command = "basic-attack", encounterId = id, expectedVersion = e.version,
			requestId = "r7b-vitoria", targetId = "criatura:1" }
		t.ok(api.solicitarAtaqueBasico(g[1], pedido))
		t.ok(api.solicitarAtaqueBasico(g[1], pedido))
		t.eq(#fim, 1); t.eq(fim[1].encounterId, id); t.eq(fim[1].phase, "victory")
		t.eq(#pagos, 1); t.eq(pagos[1].id, id); t.eq(pagos[1].moedas, 10)
		pasta:Destroy()
	end,
	["fuga total chama callback uma vez sem pagar PO"] = function(t)
		local api, g, _, pasta, fim, pagos = fixture(1, function(d)
			d.rng.NextInteger = function(_, _, maximo) return maximo end
		end)
		local id = api.criarEncontroDaRun(g, luta())
		for i, x in { 4, 1 } do
			local e = api.estado(id)
			t.ok(api.solicitarMovimento(g[1], { command = "move", encounterId = id,
				expectedVersion = e.version, requestId = "r7b-borda" .. i, x = x, z = 10 }))
		end
		local e = api.estado(id)
		local pedido = { command = "flee-encounter", encounterId = id,
			expectedVersion = e.version, requestId = "r7b-fuga" }
		t.ok(api.solicitarFuga(g[1], pedido)); t.ok(api.solicitarFuga(g[1], pedido))
		t.eq(#fim, 1); t.eq(fim[1].encounterId, id); t.eq(fim[1].phase, "fled"); t.eq(#pagos, 0)
		pasta:Destroy()
	end,

	["derrota notifica uma vez com ID fase e sem PO"] = function(t)
		local api, g, _, pasta, fim, pagos = fixture(1)
		local id = api.criarEncontroDaRun(g, luta()); local e = api.estado(id)
		local pedido = { command = "abandon-encounter", encounterId = id, expectedVersion = e.version, requestId = "r7b-queda" }
		t.ok(api.solicitarDesistencia(g[1], pedido)); t.ok(api.solicitarDesistencia(g[1], pedido))
		t.eq(#fim, 1); t.eq(fim[1].encounterId, id); t.eq(fim[1].phase, "defeat"); t.eq(#pagos, 0)
		pasta:Destroy()
	end,
}
