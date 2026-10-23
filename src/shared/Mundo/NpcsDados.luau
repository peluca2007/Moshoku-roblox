-- NPCs da vila em dados puros: quem são, onde ficam (em frente à porta do prédio,
-- voltados à praça) e o que dizem. As falas só descrevem o que o jogo já faz.
local VilaLayout = require(game:GetService("ReplicatedStorage").Shared.Mundo.VilaLayout)

local NpcsDados = {}

local function aparencia(rosto, pele, olho, cabelo, cabeloId, barba, camisa, calca, roupas)
	return {
		versao = 1,
		rosto = { olhos = rosto[1], sobrancelhas = rosto[2], nariz = rosto[3], boca = rosto[4] },
		cores = { pele = pele, olho = olho, cabelo = cabelo, camisa = camisa, calca = calca },
		cabelo = cabeloId, barba = barba, roupas = roupas or {},
	}
end

NpcsDados.DISTANCIA_PORTA = 4 -- studs à frente da porta, rumo à praça
NpcsDados.COOLDOWN = 2 -- segundos entre falas para o mesmo jogador/NPC
NpcsDados.DURACAO_BALAO = 7

NpcsDados.LISTA = {
	{
		id = "taverneira", nome = "Dona Brisa", edificio = "taverna",
		raceId = "race/humano", pose = "acolher",
		aparencia = aparencia({ "OlhoFeliz", "SobrancelhaArqueada", "NarizPequeno", "BocaSorriso" }, "PeleClara", "OlhoCastanho", "CabeloCastanho", "CabeloLongo1", "BarbaNenhum", "CamisaVermelha", "CalcaMarrom", { corpo = "RoupaTunica1", cintura = "RoupaCinto1" }),
		falas = {
			"Bem-vindo à Taverna do Caminho! Quem volta do bosque chega sem fôlego e sem mana.",
			"Quer se recuperar? A fogueira do acampamento, ao norte da estrada, serve para descansar.",
			"Dois descansos curtos entre cada descanso longo: depois disso, só o sono de verdade.",
		},
	},
	{
		id = "ferreiro", nome = "Mestre Torr", edificio = "ferreiro",
		raceId = "race/anao", pose = "forjar",
		aparencia = aparencia({ "OlhoQuadrado", "SobrancelhaGrossa", "NarizLargo", "BocaReta" }, "PeleMedia", "OlhoCastanho", "CabeloPreto", "CabeloCurto1", "BarbaLonga1", "CamisaPreta", "CalcaPreta", { corpo = "RoupaTunica1", cintura = "RoupaCinto1" }),
		falas = {
			"A forja está acesa, mas o estoque ainda está chegando. Volte em breve.",
			"Goblins e lobos rondam o bosque ao norte. Vá em grupo e leve uma poção.",
		},
	},
	{
		id = "mestre-dojo", nome = "Mestre Hanzo", edificio = "dojo",
		raceId = "race/humano", pose = "cruzados",
		aparencia = aparencia({ "OlhoRetangular", "SobrancelhaSeria", "NarizReto", "BocaReta" }, "PeleOliva", "OlhoCastanho", "CabeloPreto", "CabeloTrancado1", "BarbaNenhum", "CamisaAzul", "CalcaPreta", { corpo = "RoupaTunica1", cintura = "RoupaCinto1" }),
		falas = {
			"O dojo ensina novas árvores a quem provar valor. O salão ainda está sendo preparado.",
			"Antes de aprender algo novo, domine o que já tem. Treine no campo e volte.",
		},
	},
}

local function destino(edificio)
	-- Sentido da fachada: do centro do prédio para a porta, normalizado.
	local porta = VilaLayout.porta(edificio)
	local dx, dz = porta.x - edificio.x, porta.z - edificio.z
	local n = math.sqrt(dx * dx + dz * dz)
	return porta, dx / n, dz / n
end

local function edificioPorId(id)
	for _, e in ipairs(VilaLayout.EDIFICIOS) do
		if e.id == id then return e end
	end
	return nil
end

-- Posição (x, z) à frente da porta e direção para a qual olhar (rumo à praça).
function NpcsDados.posicao(npc)
	local e = edificioPorId(npc.edificio)
	if not e then return nil end
	local porta, nx, nz = destino(e)
	return { x = porta.x + nx * NpcsDados.DISTANCIA_PORTA, z = porta.z + nz * NpcsDados.DISTANCIA_PORTA, olharX = -nx, olharZ = -nz }
end

-- Fala escolhida pelo contador do jogador (rotaciona sem repetir enquanto houver outra).
function NpcsDados.fala(npc, contador)
	local total = #npc.falas
	if total == 0 then return nil end
	return npc.falas[((math.max(contador, 1) - 1) % total) + 1]
end

function NpcsDados.validar()
	local problemas, ids = {}, {}
	for _, npc in ipairs(NpcsDados.LISTA) do
		if ids[npc.id] then table.insert(problemas, npc.id .. " duplicado") end
		ids[npc.id] = true
		local p = NpcsDados.posicao(npc)
		if not p then
			table.insert(problemas, npc.id .. " edificio inexistente")
		else
			for _, e in ipairs(VilaLayout.EDIFICIOS) do
				if VilaLayout.sobrepoe({ x = p.x, z = p.z, sx = 1.5, sz = 1.5 }, VilaLayout.ocupacao(e)) then
					table.insert(problemas, npc.id .. " dentro de " .. e.id)
				end
			end
			if not VilaLayout.contem(VilaLayout.SOLO, { x = p.x, z = p.z, sx = 1.5, sz = 1.5 }) then
				table.insert(problemas, npc.id .. " fora do solo")
			end
		end
		if #npc.falas == 0 then table.insert(problemas, npc.id .. " sem falas") end
		for _, fala in ipairs(npc.falas) do
			if #fala > 140 then table.insert(problemas, npc.id .. " fala longa demais") end
		end
	end
	return problemas
end

return NpcsDados
