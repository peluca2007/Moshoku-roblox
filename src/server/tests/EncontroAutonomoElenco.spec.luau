local Elenco = require(game:GetService("ReplicatedStorage").Shared.EncontroAutonomoElenco)

local function deps()
	local conectados = { [11] = true, [22] = true }
	return {
		conectado = function(player) return conectados[player.UserId] == true end,
		corpoPessoal = function(player)
			return {
				name = "Aventureiro " .. player.UserId,
				calculated = { initiative = { bonus = player.UserId == 11 and 3 or 1, advantage = player.UserId == 11 }, movementMeters = 9 },
			}
		end,
		criatura = function(id) return { catalogId = id, nome = "Criatura " .. id } end,
	}
end

return {
	["monta ate quatro jogadores e duas ou tres criaturas com iniciativa derivada"] = function(t)
		local atores, erro = Elenco.montar({ { UserId = 11 }, { UserId = 22 } }, { "lobo", "goblin" }, deps())
		t.eq(erro, nil)
		t.eq(#atores, 4)
		t.eq(atores[1].userId, 11)
		t.eq(atores[1].bonus, 3)
		t.eq(atores[1].advantage, true)
		t.eq(atores[1].movementCasas, 6)
		t.eq(atores[2].userId, 22)
		t.eq(atores[2].bonus, 1)
		t.eq(atores[3].bonus, 0)
		t.eq(atores[3].advantage, false)
		t.eq(atores[4].id, "criatura:2")
	end,
	["recusa grupo fora dos limites jogador repetido ou ausente"] = function(t)
		local d = deps()
		local atores = Elenco.montar({}, { "lobo", "goblin" }, d)
		t.eq(atores, nil)
		atores = Elenco.montar({ { UserId = 11 }, { UserId = 11 } }, { "lobo", "goblin" }, d)
		t.eq(atores, nil)
		atores = Elenco.montar({ { UserId = 11 } }, {}, d)
		t.eq(atores, nil)
		atores = Elenco.montar({ { UserId = 99 } }, { "lobo", "goblin" }, d)
		t.eq(atores, nil)
	end,
	["recusa ficha sem iniciativa e criatura que nao veio do catalogo"] = function(t)
		local d = deps()
		d.corpoPessoal = function() return { name = "Inválida", calculated = { initiative = { bonus = 0 } } } end
		local atores = Elenco.montar({ { UserId = 11 } }, { "lobo", "goblin" }, d)
		t.eq(atores, nil)
		d = deps()
		d.criatura = function() return nil end
		atores = Elenco.montar({ { UserId = 11 } }, { "lobo", "goblin" }, d)
		t.eq(atores, nil)
	end,
	["deriva limite de casas do deslocamento calculado da ficha"] = function(t)
		local d = deps()
		d.corpoPessoal = function()
			return { name = "Aventureira", calculated = { initiative = { bonus = 0, advantage = false }, movementMeters = 7.5 } }
		end
		local atores = Elenco.montar({ { UserId = 11 } }, { "lobo", "goblin" }, d)
		t.eq(atores[1].movementCasas, 5)
	end,
	["aceita encontro solo com uma criatura calculada pelo orçamento"] = function(t)
		local atores, erro = Elenco.montar({ { UserId = 11 } }, { "creature/goblin-batedor" }, deps())
		t.eq(erro, nil)
		t.eq(#atores, 2)
	end,
	["classifica respiração apenas para personagens e criaturas atuais conhecidas"] = function(t)
		local atores = Elenco.montar({ { UserId = 11 } },
			{ "creature/goblin-batedor", "creature/lobo-cinzento" }, deps())
		t.eq(atores[1].respira, true)
		t.eq(atores[2].respira, true)
		t.eq(atores[3].respira, true)
		local criaturaDesconhecida = Elenco.montar({ { UserId = 11 } },
			{ "creature/sem-traco", "creature/outro" }, deps())
		t.eq(criaturaDesconhecida[2].respira, false, "não infere respiração de espécime sem metadado")
	end,
	["catalogo de recompensa e fixo por criatura canonica J2"] = function(t)
		local atores = Elenco.montar({ { UserId = 11 } },
			{ "creature/goblin-batedor", "creature/lobo-cinzento", "creature/treant-anciao" }, deps())
		t.eq(atores[2].recompensa.patamar, 1); t.eq(atores[2].recompensa.papel, "lacaio")
		t.eq(atores[2].recompensa.arquetipo, "agil"); t.eq(atores[2].recompensa.subArquetipo, "humanoide")
		t.eq(atores[3].recompensa.subArquetipo, "besta")
		t.eq(atores[4].recompensa.papel, "chefe"); t.eq(atores[4].recompensa.arquetipo, "bruto")
	end,
}
