local Terreno = require(game:GetService("ReplicatedStorage").Shared.EncontroAutonomoTerreno)

return {
	["somente o bosque recebe quatro celulas de obstaculo"] = function(t)
		local bosque = Terreno.celulas("region/encounter/forest")
		t.eq(#bosque, 4)
		t.eq(Terreno.chaves("region/encounter/forest")["6:8"], true)
		t.eq(Terreno.chaves("region/encounter/forest")["15:13"], true)
		t.eq(#Terreno.celulas("region/encounter/clearing"), 0)
		local sombria = Terreno.celulas("region/encounter/dark-forest")
		t.eq(#sombria, 4)
		t.eq(Terreno.chaves("region/encounter/dark-forest")["7:5"], true)
		t.eq(Terreno.chaves("region/encounter/dark-forest")["15:15"], true)
	end,
	["retorno clona lista e coordenadas do layout"] = function(t)
		local primeira = Terreno.celulas("region/encounter/forest")
		primeira[1].x = 20
		t.eq(Terreno.celulas("region/encounter/forest")[1].x, 6)
		local sombria = Terreno.celulas("region/encounter/dark-forest")
		sombria[1].x = 20
		t.eq(Terreno.celulas("region/encounter/dark-forest")[1].x, 7)
	end,
	["normaliza apenas coordenadas inteiras dentro da grade"] = function(t)
		local chaves = Terreno.chavesDe({ { x = 2, z = 3 }, { x = 21, z = 3 }, { x = 4.5, z = 5 }, "ruim" })
		t.eq(chaves["2:3"], true)
		t.eq(chaves["21:3"], nil)
		t.eq(chaves["4.5:5"], nil)
	end,
	["rochas e muros bloqueiam linha entre casas mas não os pontos extremos"] = function(t)
		local rochas = { { x = 6, z = 8 } }
		t.eq(Terreno.visaoLivre(5, 8, 7, 8, rochas), false)
		t.eq(Terreno.visaoLivre(5, 8, 6, 8, rochas), true, "a casa de destino é o ponto observado")
		t.eq(Terreno.visaoLivre(5, 8, 7, 9, rochas), false, "supercobertura fecha diagonal no canto")
		local muro = { { abilityId = "ability/fogo/Principiante/muro-de-chamas", x = 6, z = 8 } }
		t.eq(Terreno.visaoLivre(5, 8, 7, 8, {}, muro), false)
	end,
	["Muro de Terra bloqueia visão e movimento até a expiração da centésima rodada"] = function(t)
		local muro = "ability/terra/Principiante/muro-de-terra"
		local perigos = {
			{ abilityId = muro, x = 6, z = 8, expiresTurn = 101 },
			{ abilityId = muro, x = 6, z = 9, expiresTurn = 101 },
		}
		local bloqueadas = Terreno.celulasBloqueantes(perigos, 100)
		t.eq(#bloqueadas, 2)
		t.eq(Terreno.chavesDe(bloqueadas)["6:8"], true)
		t.eq(Terreno.visaoLivre(5, 8, 7, 8, {}, perigos), false)
		t.eq(#Terreno.celulasBloqueantes(perigos, 101), 0)
		t.eq(Terreno.visaoLivre(5, 8, 7, 8, {}, { { abilityId = muro, x = 6, z = 8, expiresTurn = 100 } }, 100), true)
	end,
	["Anteparo bloqueia movimento mas não visão nem magia"] = function(t)
		local anteparo = "ability/teorica/Principiante/anteparo-teorico"
		local perigos = {
			{ abilityId = anteparo, x = 6, z = 8, expiresTurn = 11 },
			{ abilityId = anteparo, x = 6, z = 9, expiresTurn = 11 },
		}
		local bloqueadas = Terreno.celulasBloqueantes(perigos, 1)
		t.eq(#bloqueadas, 2)
		t.eq(Terreno.visaoLivre(5, 8, 7, 8, bloqueadas, perigos, 1), true)
		t.eq(#Terreno.celulasBloqueantes(perigos, 11), 0)
	end,
	["Escudo de Água concede cobertura na linha, protege a casa do aliado e expira"] = function(t)
		local id = "ability/agua/Principiante/escudo-de-agua"
		local perigos = {
			{ abilityId = id, x = 6, z = 8, coverage = 5, expiresTurn = 11 },
			{ abilityId = id, x = 6, z = 9, coverage = 5, expiresTurn = 11 },
		}
		t.eq(#Terreno.celulasBloqueantes(perigos, 1), 0, "o escudo não bloqueia movimento")
		t.eq(Terreno.visaoLivre(5, 8, 7, 8, {}, perigos, 1), true, "o escudo não bloqueia visão")
		t.eq(Terreno.coberturaNaLinha(5, 8, 7, 8, perigos, 1), 5)
		t.eq(Terreno.coberturaNaLinha(5, 8, 5, 10, perigos, 1), 0, "linha que não cruza a zona")
		t.eq(Terreno.coberturaNaLinha(5, 8, 6, 8, perigos, 1), 5, "aliado na casa da zona recebe cobertura")
		t.eq(Terreno.coberturaNaLinha(5, 8, 7, 8, perigos, 11), 0, "zona expirada não protege")
	end,
	["Escudo reduz dano ígneo só quando uma célula ativa cruza a linha"] = function(t)
		local id = "ability/agua/Principiante/escudo-de-agua"
		local perigos = {
			{ abilityId = id, x = 6, z = 8, reduzIgneo = true, expiresTurn = 11 },
			{ abilityId = id, x = 6, z = 9, reduzIgneo = true, expiresTurn = 11 },
		}
		t.eq(Terreno.reduzIgneoNaLinha(5, 8, 7, 8, perigos, 1), true)
		t.eq(Terreno.reduzIgneoNaLinha(5, 8, 6, 8, perigos, 1), false, "destino observado não cruza a barreira")
		t.eq(Terreno.reduzIgneoNaLinha(5, 8, 7, 8, perigos, 11), false, "zona expirada não reduz")
		t.eq(Terreno.reduzIgneoNaLinha(5, 8, 7, 8, {
			{ abilityId = id, x = 6, z = 8, expiresTurn = 11 },
		}, 1), false, "flag ausente não infere redução")
		t.eq(Terreno.reduzIgneoNaLinha(5, 8, 7, 9, {
			{ abilityId = id, x = 6, z = 9, reduzIgneo = true, expiresTurn = 11 },
		}, 1), true, "supercobertura inclui célula tocada no canto")
	end,
	["Névoa Densa corta visão sem bloquear movimento e só cega dentro da zona ativa"] = function(t)
		local id = "ability/agua/Principiante/nevoa-densa"
		local perigos = {
			{ abilityId = id, x = 6, z = 8, expiresTurn = 51 },
			{ abilityId = id, x = 6, z = 9, expiresTurn = 51 },
		}
		t.eq(#Terreno.celulasBloqueantes(perigos, 1), 0)
		t.eq(Terreno.visaoLivre(5, 8, 7, 8, {}, perigos, 1), false, "célula intermediária obscurece")
		t.eq(Terreno.visaoLivre(6, 8, 7, 8, {}, perigos, 1), true, "a zona não bloqueia o próprio ponto de observação")
		t.eq(Terreno.atorNaNevoa(6, 9, perigos, 1), true)
		t.eq(Terreno.atorNaNevoa(7, 9, perigos, 1), false)
		t.eq(Terreno.atorNaNevoa(6, 9, perigos, 51), false, "condição virtual expira junto da zona")
		t.eq(Terreno.visaoLivre(5, 8, 7, 8, {}, perigos, 51), true)
	end,
}
