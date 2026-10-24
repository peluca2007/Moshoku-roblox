local Shared = game:GetService("ReplicatedStorage").Shared
local Layout = require(Shared.Mundo.RuinasLayout)
local Props = require(Shared.Mundo.PropsLayout)
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
