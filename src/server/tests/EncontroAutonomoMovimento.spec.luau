local Movimento = require(game:GetService("ReplicatedStorage").Shared.EncontroAutonomoMovimento)

return {
	["destinos usam diagonal como uma casa e respeitam o limite"] = function(t)
		local destinos = Movimento.destinos(10, 10, {}, 2)
		t.ok(destinos["12:12"] ~= nil)
		t.eq(destinos["13:13"], nil)
		t.eq(destinos["0:10"], nil)
	end,
	["ocupantes bloqueiam destino e caminho"] = function(t)
		local atores = {
			{ id = "eu", x = 10, z = 10 },
			{ id = "bloqueio", x = 11, z = 10 },
		}
		local destino, erro = Movimento.validar(10, 10, 11, 10, atores, 6)
		t.eq(destino, nil)
		t.eq(erro, "Essa casa já está ocupada.")
		local perto = Movimento.validar(10, 10, 12, 10, atores, 2)
		t.ok(perto ~= nil, "há caminho alternativo ao redor do ator")
	end,
	["terreno bloqueia destino e rota sem impedir contorno"] = function(t)
		local bloqueadas = { ["11:10"] = true, ["11:11"] = true, ["11:9"] = true }
		local direto, erro = Movimento.validar(10, 10, 11, 10, {}, 4, bloqueadas)
		t.eq(direto, nil)
		t.eq(erro, "Essa casa está bloqueada pelo terreno.")
		local contorno = Movimento.validar(10, 10, 12, 10, {}, 4, bloqueadas)
		t.ok(contorno ~= nil, "rota contorna a faixa de rochas")
		for _, casa in contorno.rota do
			t.eq(bloqueadas[tostring(casa.x) .. ":" .. tostring(casa.z)], nil)
		end
	end,
	["terreno difícil cobra duas casas de deslocamento sem alterar a distância física"] = function(t)
		local dificeis = { ["11:10"] = true }
		local semOrcamento = Movimento.validar(10, 10, 11, 10, {}, 1, nil, dificeis)
		t.eq(semOrcamento, nil, "entrar em terreno difícil custa dois")
		local suficiente = Movimento.validar(10, 10, 11, 10, {}, 2, nil, dificeis)
		t.ok(suficiente ~= nil)
		t.eq(suficiente.casas, 1)
		t.eq(suficiente.custoMovimento, 2)
		local normal = Movimento.destinos(10, 10, {}, 1, nil, dificeis)
		t.eq(normal["11:11"].custoMovimento, 1, "diagonal normal mantém custo unitário")
	end,
	["rejeita origem, destino igual e coordenadas fora da grade"] = function(t)
		local semCasas = Movimento.destinos(10, 10, {}, -1)
		t.eq(semCasas, nil)
		local igual = Movimento.validar(10, 10, 10, 10, {}, 6)
		t.eq(igual, nil)
		local fora = Movimento.validar(10, 10, 21, 10, {}, 6)
		t.eq(fora, nil)
	end,
	["movimento retorna a rota sem incluir origem e termina no destino validado"] = function(t)
		local destino = Movimento.validar(10, 10, 12, 12, {}, 2)
		t.eq(#destino.rota, 2)
		t.eq(destino.rota[#destino.rota].x, destino.x)
		t.eq(destino.rota[#destino.rota].z, destino.z)
		t.eq(destino.rota[1].x == 10 and destino.rota[1].z == 10, false)
	end,
	["aproximacao escolhe destino acessivel que reduz distancia e desempata estavelmente"] = function(t)
		local ocupantes = {
			{ id = "criatura", x = 10, z = 14 },
			{ id = "obstaculo-ator", x = 10, z = 12 },
			{ id = "jogador", x = 10, z = 10 },
		}
		local alvo = { { id = "jogador", x = 10, z = 10 } }
		local destino = Movimento.aproximar(10, 14, ocupantes, alvo, 4)
		t.ok(destino ~= nil)
		t.ok(math.max(math.abs(destino.x - 10), math.abs(destino.z - 10)) < 4)
		t.eq(destino.x, 9)
		t.eq(destino.z, 11)
		t.eq(destino.casas, 3)
	end,
	["IA procura rota ao redor do terreno fixo"] = function(t)
		local ocupantes = { { id = "criatura", x = 10, z = 14 }, { id = "jogador", x = 10, z = 10 } }
		local alvos = { { id = "jogador", x = 10, z = 10 } }
		local bloqueadas = { ["10:13"] = true, ["10:12"] = true, ["10:11"] = true }
		local destino = Movimento.aproximar(10, 14, ocupantes, alvos, 4, bloqueadas)
		t.ok(destino ~= nil)
		t.ok(destino.distancia < 4)
		for _, casa in destino.rota do
			t.eq(bloqueadas[tostring(casa.x) .. ":" .. tostring(casa.z)], nil)
		end
	end,
	["IA escolhe casa alcançável considerando orçamento dobrado"] = function(t)
		local ocupantes = { { id = "criatura", x = 10, z = 14 }, { id = "jogador", x = 10, z = 10 } }
		local alvos = { { id = "jogador", x = 10, z = 10 } }
		local dificeis = { ["10:13"] = true, ["10:12"] = true, ["10:11"] = true }
		local destino = Movimento.aproximar(10, 14, ocupantes, alvos, 2, nil, dificeis)
		t.ok(destino ~= nil)
		t.ok(destino.custoMovimento <= 2)
		for _, casa in destino.rota do
			t.eq(dificeis[tostring(casa.x) .. ":" .. tostring(casa.z)], nil, "IA prefere contornar a barreira difícil")
		end
	end,
}
