local Shared = game:GetService("ReplicatedStorage").Shared
local Personagens = require(Shared.PersonagensProntos)
local Armas = require(Shared.Regras.Armas)
local Arma = require(Shared.Regras.Arma)
-- Índice dos dados reais, sem o loader de Instances do Catalogo.
local Catalogo = { POR_ID = {}, POR_ESPECIE = { rank = {} } }
for _, lista in {
	require(Shared.Livro.Dados.Arvores.fogo), require(Shared.Livro.Dados.Arvores.agua),
	require(Shared.Livro.Dados.Arvores.vento), require(Shared.Livro.Dados.Arvores.terra),
	require(Shared.Livro.Dados.Arvores.cura), require(Shared.Livro.Dados.Arvores.desintoxicacao),
	require(Shared.Livro.Dados.Arvores.teorica), require(Shared.Livro.Dados.Arvores.invocacao),
	require(Shared.Livro.Dados.Arvores.deus_da_espada), require(Shared.Livro.Dados.Arvores.deus_da_agua_corpo),
	require(Shared.Livro.Dados.Arvores.deus_do_norte), require(Shared.Livro.Dados.Arvores.armas_pesadas),
	require(Shared.Livro.Dados.Arvores.cavalaria_e_escudos), require(Shared.Livro.Dados.Arvores.arquearia),
	require(Shared.Livro.Dados.Arvores.furtividade_e_armadilhas), require(Shared.Livro.Dados.Arvores.bardo_e_interacao),
	require(Shared.Livro.Dados.Arvores.navegacao_e_lideranca),
} do
	for _, e in lista do
		Catalogo.POR_ID[e.id] = e
		if e.kind == "rank" then table.insert(Catalogo.POR_ESPECIE.rank, e) end
	end
end

local function ficha(id)
	local p = Armas.personagem(id)
	return { construction = {
		unlockedRankIds = table.clone(p.ranks), purchasedIds = {},
		inventory = { { sourceLocalId = "kit", name = p.armaPadrao, type = "arma", baseDie = p.armas[1].dado, equipped = true },
			{ sourceLocalId = "armadura", name = "Armadura Leve", type = "armadura", armorClassBonus = 1, equipped = true } },
	}, calculated = { armorClass = p.ca } }
end

return {
	["17 listas respeitam os grupos das arvores e o kit padrao"] = function(t)
		t.eq(#Personagens, 17)
		for _, p in Personagens do
			local grupos = Catalogo.POR_ID["tree/" .. p.arvore].data.proficiencies.gruposDeArma or {}
			local vistos = {}
			t.eq(p.armas[1].id, p.armaPadrao)
			for _, a in p.armas do
				t.ok(not vistos[a.id]); vistos[a.id] = true
				if a.id ~= p.armaPadrao then t.ok(table.find(grupos, a.grupo) ~= nil, p.id .. ": " .. a.nome) end
				t.ok(a.grupo ~= "escudos")
			end
			if #grupos == 0 then t.eq(#p.armas, 1) end
		end
		t.eq(#Armas.personagem("espadachim").armas, 5)
		t.eq(#Armas.personagem("mago-de-fogo").armas, 1)
		t.eq(#Armas.personagem("arqueira").armas, 5)
	end,
	["valida arma ausente outra arvore tipos tamanho UTF8 e campos extras"] = function(t)
		local arma = Armas.validar({ id = "espadachim" })
		t.eq(arma.id, "Espada Longa")
		for _, p in { {}, { id = "x" }, { id = 1 }, { id = "espadachim", arma = "Besta" },
			{ id = "espadachim", arma = 6 }, { id = "espadachim", arma = {} },
			{ id = "espadachim", arma = false }, { id = "espadachim", arma = "" },
			{ id = "espadachim", arma = string.rep("a", 97) }, { id = "espadachim", arma = "\255" },
			{ id = "espadachim", dano = 999 }, { id = "mago-de-fogo", arma = "desarmado" } } do
			local a, e = Armas.validar(p); t.eq(a, nil); t.eq(type(e), "string")
		end
		for _, p in { false, 5, "espadachim" } do t.eq(Armas.validar(p), nil) end
	end,
	["montante muda dado preserva CA armadura e nao duplica arma"] = function(t)
		local f = ficha("espadachim")
		local antigo = f.construction.inventory
		t.eq(Armas.aplicar(f, "espadachim", "Espadão / Montante"), nil)
		local a = Arma.daFicha(f, Catalogo)
		t.eq(a.base, "d10"); t.eq(a.dado, "d12"); t.eq(a.aviso, nil)
		t.eq(f.calculated.armorClass, Armas.personagem("espadachim").ca)
		t.eq(antigo[1].name, "Espada Longa"); t.eq(antigo[1].equipped, true)
		local equipadas = 0
		for _, item in f.construction.inventory do
			if item.type == "arma" and item.equipped then equipadas += 1 end
			if item.type == "armadura" then t.eq(item.equipped, true); t.eq(item.armorClassBonus, 1) end
		end
		t.eq(equipadas, 1)
		t.eq(Armas.aplicar(f, "espadachim", "Espadão / Montante"), nil)
		t.eq(#f.construction.inventory, 2)
	end,
	["Lutador de punhos usa d6 com degrau sem aviso de referencia"] = function(t)
		local f = ficha("brutamontes")
		t.eq(Armas.aplicar(f, "brutamontes", "desarmado"), nil)
		for _, i in f.construction.inventory do t.ok(i.type ~= "arma" or not i.equipped) end
		local a = Arma.daFicha(f, Catalogo)
		t.eq(a.nome, "Punhos (desarmado)"); t.eq(a.base, "d6"); t.eq(a.dado, "d8")
		t.eq(a.desarmado, true); t.eq(a.aviso, nil)
	end,
	["Norte nao recebe d6 de soco inventado sem regra publicada"] = function(t)
		local p = Armas.personagem("guerreiro-do-norte")
		local punhos
		for _, a in p.armas do if a.desarmado then punhos = a end end
		t.ok(punhos); t.eq(punhos.dado, "não definido")
		t.eq(Armas.validar({ id = p.id, arma = punhos.id }), nil)
	end,
	["Arqueira troca disparo conserva reserva e dado correto"] = function(t)
		local f = ficha("arqueira")
		table.insert(f.construction.inventory, { sourceLocalId = "reserva", name = "Funda / Dardo", type = "arma", baseDie = "d4", equipped = false })
		t.eq(Armas.aplicar(f, "arqueira", "Besta"), nil)
		local a = Arma.daFicha(f, Catalogo, true)
		t.eq(a.nome, "Besta"); t.eq(a.base, "d10"); t.eq(a.dado, "d12")
		local reserva = false
		for _, i in f.construction.inventory do if i.name == "Funda / Dardo" then reserva = true end end
		t.ok(reserva)
		t.eq(Armas.aplicar(f, "arqueira", "Azagaia"), nil)
		t.eq(Arma.daFicha(f, Catalogo, true).nome, "Azagaia")
	end,
	["improvisado trava em d6 salvo Norte"] = function(t)
		local f = ficha("brutamontes")
		t.eq(Armas.aplicar(f, "brutamontes", "Objeto Improvisado"), nil)
		t.eq(Arma.daFicha(f, Catalogo).dado, "d6")
		local n = ficha("guerreiro-do-norte")
		t.eq(Armas.aplicar(n, "guerreiro-do-norte", "Objeto Improvisado"), nil)
		t.eq(Arma.daFicha(n, Catalogo).dado, "d8")
		table.insert(n.construction.unlockedRankIds, "rank/deus-da-espada/Principiante")
		table.insert(n.construction.unlockedRankIds, "rank/deus-da-espada/Intermedi%C3%A1rio")
		t.eq(Arma.daFicha(n, Catalogo).dado, "d6", "Norte menor não libera escala do improvisado")
	end,
}
