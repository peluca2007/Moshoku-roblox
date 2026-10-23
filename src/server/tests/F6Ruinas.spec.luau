local Shared = game:GetService("ReplicatedStorage").Shared
local Layout = require(Shared.Mundo.RuinasLayout)
local Props = require(Shared.Mundo.PropsLayout)
local Terreno = require(Shared.EncontroAutonomoTerreno)
local Elenco = require(Shared.EncontroAutonomoElenco)
local Zonas = require(Shared.EncontrosPorZona)

local Historia = require(Shared.Mundo.HistoriaV1)

local AREA = "region/encounter/ruinas"

local function deps()
	return {
		conectado = function() return true end,
		corpoPessoal = function(player)
			return { name = "Aventureiro", calculated = {
				initiative = { bonus = 0, advantage = false }, movementMeters = 9,
			} }
		end,
		criatura = function(id) return { catalogId = id, nome = id } end,
	}
end

local function jogador(id)
	return { UserId = id }
end

local function sobrepoe(a, b)
	return math.abs(a.x - b.x) <= (a.sx + b.sx) / 2
		and math.abs(a.z - b.z) <= (a.sz + b.sz) / 2
end

local function casaDentroDoRetangulo(x, z, ret)
	return x >= ret.x - ret.sx / 2 and x <= ret.x + ret.sx / 2
		and z >= ret.z - ret.sz / 2 and z <= ret.z + ret.sz / 2
end

return {
	["arena F6 ocupa a camara e mantem os quatro cantos dentro do quadrado de 36"] = function(t)
		local arena = Layout.ARENA
		t.eq(arena.id, AREA)
		t.eq(arena.marco, "region/ruinas-do-vale/encontro/marco")
		t.eq(arena.x, 600); t.eq(arena.z, -262); t.eq(arena.passo, 1.8)
		for _, canto in { { -10, -10 }, { -10, 10 }, { 10, -10 }, { 10, 10 } } do
			local x = arena.x + canto[1] * arena.passo
			local z = arena.z + canto[2] * arena.passo
			t.ok(math.abs(x - Layout.CAMARA.x) <= Layout.CAMARA.raio)
			t.ok(math.abs(z - Layout.CAMARA.z) <= Layout.CAMARA.raio)
			t.ok((x - Layout.CAMARA.x)^2 + (z - Layout.CAMARA.z)^2 <= Layout.CAMARA.raio^2)
		end
	end,
	["altar bloqueia sua ocupacao e colunas projetam casas cobertas pelos retangulos"] = function(t)
		local bloqueadas = Terreno.celulas(AREA)
		local chaves = Terreno.chaves(AREA)
		t.ok(chaves["10:10"], "centro do altar precisa ser bloqueado")
		local pecas = Layout.pecas()
		local altar
		for _, peca in pecas do if peca[3] == "altar" then altar = Props.retangulo(peca) end end
		t.ok(altar ~= nil)
		local centroX = Layout.ARENA.x + (10 - 10.5) * Layout.ARENA.passo
		local centroZ = Layout.ARENA.z + (10 - 10.5) * Layout.ARENA.passo
		t.ok(casaDentroDoRetangulo(centroX, centroZ, altar), "centro da casa 10:10 fica no altar")
		local projetadas = 0
		for _, peca in pecas do
			if peca[3] == "coluna" or peca[3] == "colunaquebrada" then
				local ret = Props.retangulo(peca)
				for x = 1, 20 do
					for z = 1, 20 do
						local cx = Layout.ARENA.x + (x - 10.5) * Layout.ARENA.passo
						local cz = Layout.ARENA.z + (z - 10.5) * Layout.ARENA.passo
						if casaDentroDoRetangulo(cx, cz, ret) then
							projetadas += 1
							t.ok(chaves[x .. ":" .. z], "coluna sem bloqueio projetado em " .. x .. ":" .. z)
						end
					end
				end
			end
		end
		t.ok(projetadas > 0, "colunas devem projetar bloqueios na grade de 1.8")
		for _, celula in bloqueadas do
			t.ok(celula.x >= 1 and celula.x <= 20 and celula.z >= 1 and celula.z <= 20)
		end
	end,
	["patrulha cruza trecho sem intersecao com retangulos de props"] = function(t)
		local patrulha = Layout.PATRULHA
		t.eq(#patrulha, 2)
		t.eq(patrulha[1].x, 600); t.eq(patrulha[1].z, -166)
		t.eq(patrulha[2].x, 600); t.eq(patrulha[2].z, -192)
		local segmento = { x = 600, z = -179, sx = 2, sz = 28 }
		for i, peca in Layout.pecas() do
			local familia = peca[3]
			if familia == "coluna" or familia == "colunaquebrada" or familia == "muro"
				or familia == "altar" then
				t.ok(not sobrepoe(segmento, Props.retangulo(peca)), "rota interceptada por prop " .. i)
			end
		end
	end,
	["formacao de ruinas gera posicoes livres e unicas para grupos de um a quatro"] = function(t)
		local depsFake = deps()
		depsFake.areaId = AREA
		local bloqueadas = Terreno.celulas(AREA)
		for n = 1, 4 do
			local jogadores = {}
			for i = 1, n do jogadores[i] = jogador(100 + i) end
			local criaturas = {}
			for i = 1, n * 2 do criaturas[i] = "creature/goblin-batedor" end
			local atores, erro = Elenco.montar(jogadores, criaturas, depsFake)
			t.eq(erro, nil)
			t.eq(#atores, n * 3)
			local iniciais = {}
			for i = 1, #atores do iniciais[i] = atores[i] end
			t.ok(Terreno.posicoesIniciaisLivres(iniciais, bloqueadas), "grupo " .. n .. " nasce livre")
			local vistos = {}
			for _, ator in iniciais do
				local chave = ator.x .. ":" .. ator.z
				t.ok(not vistos[chave], "posicao inicial repetida: " .. chave)
				vistos[chave] = true
			end
		end
	end,
	["catalogo de ruinas mantem dois goblins por jogador e ameaca moderada"] = function(t)
		local zona = Zonas.consultar(AREA)
		t.ok(zona ~= nil)
		t.eq(zona.ameaca, "moderada")
		t.eq(zona.marco, Layout.ARENA.marco)
		t.eq(zona.zona, Layout.ID)
		local elegivel = Zonas.elegivel(AREA, 3)
		t.eq(elegivel.ameaca, "moderada")
		t.eq(#elegivel.elenco, 6)
		for _, id in elegivel.elenco do t.eq(id, "creature/goblin-batedor") end
		local luta = { no = "chefe-ruinas", titulo = "Guardiao", areaId = AREA,
			criaturas = { "creature/goblin-batedor" } }
		t.eq(Historia.HISTORIA.nos["chefe-ruinas"].luta.areaId, AREA)
		local resultado = Zonas.paraRun(luta, 4)
		t.eq(#resultado.elenco, 8)
		t.eq(resultado.peso, 4); t.eq(resultado.orcamento, 4); t.eq(resultado.razao, 1)
		for _, id in resultado.elenco do t.eq(id, "creature/goblin-batedor") end
	end,
}
