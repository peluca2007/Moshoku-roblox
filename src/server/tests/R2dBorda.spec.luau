local Terreno = require(game:GetService("ReplicatedStorage").Shared.EncontroAutonomoTerreno)

local function igualCelula(t, resultado, esperado, mensagem)
	t.ok(resultado ~= nil, mensagem or "deve haver uma casa livre")
	t.eq(resultado.x, esperado.x)
	t.eq(resultado.z, esperado.z)
end

return {
	["escolhe casa livre mais proxima sem considerar obstaculo"] = function(t)
		local atores = { { x = 4, z = 4 }, { x = 8, z = 8 } }
		local bloqueadas = { { x = 5, z = 4 } }
		igualCelula(t, Terreno.bordaLivre(5.1, 4.2, atores, bloqueadas), { x = 5, z = 1 })
		t.eq(atores[1].x, 4)
		t.eq(bloqueadas[1].x, 5)
	end,
	["distancia euclidiana e desempate por x depois z sao estaveis"] = function(t)
		local escolhido = Terreno.bordaLivre(10.5, 10.5, {}, {})
		igualCelula(t, escolhido, { x = 1, z = 10 }, "origem equidistante escolhe menor x e depois menor z")
	end,
	["ocupacao e bloqueios retiram celulas da borda"] = function(t)
		local atores = { { x = 1, z = 10 }, { x = 20, z = 10 } }
		local bloqueadas = { { x = 2, z = 10 }, { x = 3, z = 10 } }
		igualCelula(t, Terreno.bordaLivre(1, 10, atores, bloqueadas), { x = 1, z = 9 })
	end,
	["fugitivo nao ocupa celula ao escolher a borda"] = function(t)
		local atores = { { x = 1, z = 10, kind = "jogador", fled = true } }
		igualCelula(t, Terreno.bordaLivre(1, 10, atores, {}), { x = 1, z = 10 })
	end,
	["borda totalmente ocupada ou bloqueada retorna nil"] = function(t)
		local tudo = {}
		for x = 1, 20 do
			for z = 1, 20 do
				if x == 1 or x == 20 or z == 1 or z == 20 then
					table.insert(tudo, { x = x, z = z })
				end
			end
		end
		t.eq(Terreno.bordaLivre(10, 10, {}, tudo), nil)
		t.eq(Terreno.bordaLivre(10, 10, tudo, {}), nil)
	end,
	["resolver nao modifica atores nem bloqueios"] = function(t)
		local atores = { { x = 2, z = 2, id = "a" } }
		local bloqueadas = { { x = 3, z = 3 } }
		local snapshotAtor, snapshotBloqueio = table.clone(atores[1]), table.clone(bloqueadas[1])
		Terreno.bordaLivre(7.25, 8.75, atores, bloqueadas)
		for chave, valor in snapshotAtor do t.eq(atores[1][chave], valor) end
		for chave, valor in snapshotBloqueio do t.eq(bloqueadas[1][chave], valor) end
		t.eq(#atores, 1)
		t.eq(#bloqueadas, 1)
	end,
}
