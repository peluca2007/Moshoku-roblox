-- Geometria pura V1. Coordenadas XZ em studs; nenhuma Instance, RNG global ou math.noise.
local Shared = game:GetService("ReplicatedStorage").Shared
local Regiao = require(Shared.Mundo.RegiaoLayout)
local Vila = require(Shared.Mundo.VilaLayout)
local Floresta = require(Shared.Mundo.FlorestaLayout)
local Ruinas = require(Shared.Mundo.RuinasLayout)
local Sala = require(Shared.SalaEspaco)

local T = {}
T.PASSAGEM = require(Shared.Mundo.PassagemLayout)
T.naPassagem = T.PASSAGEM.contem
T.RESOLUCAO = 4
T.BASE = -16
T.RAMPA = 32
T.NEVE = 168 -- altura onde começa a neve (variada por ruído)
-- SalaWorld ainda não exporta dimensões puras. Reserva conservadora da caixa física
-- (inclui paredes): nunca gerar voxels nessa caixa, nem abaixo do piso de madeira.
T.INTERIOR = { x = Sala.CENTRO.X, z = Sala.CENTRO.Z, sx = 44, sz = 40 }
T.ZONAS_PLANAS = {}
local function zona(id, r, material, margem, giro)
	local z = { id = id, x = r.x, z = r.z, sx = r.sx + (margem or 0) * 2,
		sz = r.sz + (margem or 0) * 2, giro = giro or 0, material = material }
	-- Cache para amostragem de centenas de milhares de colunas.
	z.cos, z.sin = math.cos(math.rad(z.giro)), math.sin(math.rad(z.giro))
	table.insert(T.ZONAS_PLANAS, z)
	return z
end
local function ponto(id, p, raio)
	return zona(id, { x = p.x, z = p.z, sx = raio * 2, sz = raio * 2 }, "Grass")
end
for i, a in ipairs(Regiao.ARENAS) do
	zona("arena-inicial-" .. i, { x = a[1], z = a[2], sx = a[3], sz = a[4] }, "Grass")
end
zona("acampamento", Regiao.ACAMPAMENTO, "Grass")
ponto("fogueira", Regiao.FOGUEIRA, 6)
ponto("entrada", Regiao.ENTRADA, 14)
zona("clareira-floresta", Floresta.CLAREIRA, "Grass")
ponto("marco-floresta", Floresta.MARCO, 6)
ponto("nascimento-vila", Vila.NASCIMENTO, 6)
ponto("nascimento-ruinas", Ruinas.NASCIMENTO, 8)
ponto("arco-ruinas", Ruinas.ARCO, 8)
-- Os marcos iniciais usam centro da grade 8 studs adiante; seus retângulos
-- de arena já cobrem a grade inteira. A câmara cobre os 36x36 da grade das ruínas.
zona("camara", { x = Ruinas.CAMARA.x, z = Ruinas.CAMARA.z,
	sx = Ruinas.CAMARA.raio * 2, sz = Ruinas.CAMARA.raio * 2 }, "Grass")
for _, e in ipairs(Vila.EDIFICIOS) do zona("predio-" .. e.id, Vila.ocupacao(e), "Grass", 4) end
for _, e in ipairs(Vila.BARRACAS) do zona(e.id, Vila.ocupacao(e), "Grass", 4) end
zona("poco", Vila.POCO, "Grass", 4)
-- V6: casas novas assentam em chão plano (pegada + 2 de folga). O poço do quintal fica de
-- fora: está perto do lago e a rampa dele invadiria a margem; ele usa fundação de pedra.
for _, e in ipairs(Vila.CASAS_NOVAS) do zona("casa-" .. e.id, Vila.ocupacao(e), "Grass", 2) end
for i, p in ipairs(Vila.POSTES) do ponto("poste-" .. i, p, 4) end
zona("praca", Vila.PRACA, "Cobblestone")
-- Pátio do treinador Ladino (TreinadoresLayout.ZONA_PLANA_NECESSARIA). Números repetidos
-- porque TreinadoresLayout depende deste módulo; o spec confere os dois.
zona("patio-ladino", { x = 65, z = -252, sx = 44, sz = 56 }, "Grass")
-- Pintura de caminhos tem prioridade sobre os outros pisos.
for i, a in ipairs(Regiao.TRILHAS) do
	local z = zona("trilha-inicial-" .. i, { x = a[1], z = a[2], sx = a[3], sz = a[4] }, "Ground", 0, a[5])
	z.trilha = a
end
zona("estrada", Vila.ESTRADA, "Ground")
zona("trilha-vila", Vila.TRILHA_FLORESTA, "Ground")
zona("trilha-floresta", Floresta.TRILHA, "Ground")
zona("caminho-ruinas", Ruinas.CAMINHO, "Slate")
local acesso = Regiao.TRILHAS[1]
ponto("porta-sala", { x = acesso[1] + acesso[3] / 2, z = acesso[2] }, 8)
-- Mantém montanhas afastadas das paredes e teto da sala.
zona("entorno-sala", T.INTERIOR, "Grass", 8)

T.AREAS_JOGAVEIS = { Regiao.CAMPO, Vila.SOLO, Floresta.SOLO, Ruinas.SOLO,
	T.INTERIOR, { x = acesso[1], z = acesso[2], sx = acesso[3], sz = acesso[4] } }
-- Cobertura derivada: COBERTURA studs além de qualquer área de jogo (as cristas ficam
-- dentro dela, então o horizonte nunca mostra o vazio). Retângulos disjuntos no mesmo
-- grid 4; não há fenda entre continente e vale.
T.COBERTURA = 340
do
	local xmin, xmax, zmin, zmax = math.huge, -math.huge, math.huge, -math.huge
	for _, r in ipairs(T.AREAS_JOGAVEIS) do
		xmin, xmax = math.min(xmin, r.x - r.sx / 2), math.max(xmax, r.x + r.sx / 2)
		zmin, zmax = math.min(zmin, r.z - r.sz / 2), math.max(zmax, r.z + r.sz / 2)
	end
	local c = T.COBERTURA
	xmin, xmax = math.floor((xmin - c) / 4) * 4, math.ceil((xmax + c) / 4) * 4
	zmin, zmax = math.floor((zmin - c) / 4) * 4, math.ceil((zmax + c) / 4) * 4
	local divisao = math.ceil((Regiao.CAMPO.x + Regiao.CAMPO.sx / 2 + c) / 4) * 4
	T.BLOCOS = {
		{ x = (xmin + divisao) / 2, z = (zmin + zmax) / 2, sx = divisao - xmin, sz = zmax - zmin, resolucao = 4 },
		{ x = (divisao + xmax) / 2, z = (zmin + zmax) / 2, sx = xmax - divisao, sz = zmax - zmin, resolucao = 4 },
	}
end
-- Lago de contorno irregular a oeste da vila: fora das zonas planas e das trilhas
-- (a vila só tem zonas planas em x >= -50). Contorno = elipse de semieixos ax/bz
-- deformada por três harmônicas; o relevo desce até o nível da água ao longo de `praia` studs.
T.AGUA = { {
	x = Vila.SOLO.x - 175, z = Vila.SOLO.z - 5, ax = 66, bz = 46, nivel = -2, fundo = -9,
	harmonicas = { { 2, 0.16, 0.7 }, { 3, 0.11, 2.1 }, { 5, 0.06, 4.0 } }, praia = 70,
} }
T.CORES_MATERIAL = {
	Grass = { 112, 132, 72 }, LeafyGrass = { 62, 88, 54 }, Ground = { 139, 111, 77 },
	Mud = { 105, 88, 64 }, Cobblestone = { 151, 140, 122 }, Rock = { 119, 112, 102 },
	Slate = { 100, 105, 103 }, Sand = { 183, 160, 111 }, Snow = { 224, 218, 204 },
}

local function smooth(v)
	v = math.clamp(v, 0, 1)
	return v * v * (3 - 2 * v)
end
local function hash(x, z)
	-- Produtos inteiros abaixo de 2^53, módulo primo: igual no Luau CLI e Roblox.
	local n = (x * 73856093 + z * 19349663 + 20261016) % 2147483647
	n = (n * 48271) % 2147483647
	return n / 2147483647
end
local function noise(x, z)
	local ix, iz = math.floor(x), math.floor(z)
	local u, v = smooth(x - ix), smooth(z - iz)
	local a, b, c, d = hash(ix, iz), hash(ix + 1, iz), hash(ix, iz + 1), hash(ix + 1, iz + 1)
	return (a + (b - a) * u) * (1 - v) + (c + (d - c) * u) * v
end
local function fbm(x, z)
	local h, peso, total = 0, 1, 0
	for _ = 1, 4 do
		h += noise(x, z) * peso
		total += peso
		x, z, peso = x * 2 + 17, z * 2 - 31, peso * 0.5
	end
	return h / total
end

-- Ruído "ridged": 1 nas cristas (onde o ruído cruza 0.5) e 0 nos vales; ao quadrado
-- afina as cristas. Dá espinhas de montanha em vez de morros arredondados.
local function ridged(x, z)
	local h, peso, total = 0, 1, 0
	for _ = 1, 4 do
		local n = 1 - math.abs(2 * noise(x, z) - 1)
		h += n * n * peso
		total += peso
		x, z, peso = x * 2 + 17, z * 2 - 31, peso * 0.5
	end
	return h / total
end

function T.distanciaZona(x, z, r)
	local dx, dz = x - r.x, z - r.z
	local c, s = r.cos or 1, r.sin or 0
	local a = math.max(math.abs(dx * c - dz * s) - r.sx / 2, 0)
	local b = math.max(math.abs(dx * s + dz * c) - r.sz / 2, 0)
	return math.sqrt(a * a + b * b)
end
function T.distanciaJogavel(x, z)
	local d = T.PASSAGEM.distancia(x, z)
	for _, r in ipairs(T.AREAS_JOGAVEIS) do d = math.min(d, T.distanciaZona(x, z, r)) end
	return d
end
function T.distanciaPlana(x, z)
	local d = T.PASSAGEM.distancia(x, z)
	for _, r in ipairs(T.ZONAS_PLANAS) do
		-- Usa o mesmo contrato dos retângulos girados do scatter existente.
		if r.trilha and Regiao.dentroDaTrilha(x, z, r.trilha, 0) then return 0 end
		d = math.min(d, T.distanciaZona(x, z, r))
		if d == 0 then return 0 end
	end
	return d
end
-- Distância (aprox., em studs) ao contorno do lago: negativa dentro, positiva fora.
local function distanciaLago(a, x, z)
	local dx, dz = (x - a.x) / a.ax, (z - a.z) / a.bz
	local rn = math.sqrt(dx * dx + dz * dz)
	local borda = 1
	if rn > 0 then
		local theta = math.atan2(dz, dx)
		for _, h in ipairs(a.harmonicas) do borda += h[2] * math.sin(h[1] * theta + h[3]) end
		-- Raio real por unidade de rn naquela direção.
		return (rn - borda) * math.sqrt((dx * a.ax)^2 + (dz * a.bz)^2) / rn
	end
	return -borda * math.min(a.ax, a.bz)
end
T.distanciaLago = function(x, z, i) return distanciaLago(T.AGUA[i or 1], x, z) end

-- Jardim na margem leste: terraço seco por cima da borda rasa do lago.
-- A caixa fica inteira a oeste da paliçada; o braço oeste da grade recebe a bica.
do
 local lago = T.AGUA[1]
 local borda = lago.x
 for x = lago.x + math.ceil(lago.ax * 2), lago.x, -0.25 do
  if distanciaLago(lago,x,lago.z)<=0 then borda=x; break end
 end
 T.PROVACAO_AGUA = zona("provacao-agua", {x=borda-10, z=lago.z, sx=32, sz=40}, "Grass")
end

function T.agua(x, z)
	-- Guarda também uma borda de voxel para não alagar caminhos por interpolação.
	for _, a in ipairs(T.AGUA) do
		local sd = distanciaLago(a, x, z)
		if sd > 0 then continue end
		local livre = true
        for _, zona in ipairs(T.ZONAS_PLANAS) do
         local margem = if zona == T.PROVACAO_AGUA then 4 else 8
         if T.distanciaZona(x,z,zona) <= margem then livre=false; break end
        end
        if sd <= 0 and livre then return a, sd end
	end
	return nil
end
function T.excluido(x, z, margem)
	local r = T.INTERIOR
	-- Interseção com área positiva: uma célula só tangente à parede pode
	-- encostar por fora. Excluir tangência também abriria um buraco na porta.
	return math.abs(x - r.x) < r.sx / 2 + (margem or 0)
		and math.abs(z - r.z) < r.sz / 2 + (margem or 0)
end

-- Centro aproximado do mundo, só para variar a altura das cordilheiras por direção.
local CENTRO_X, CENTRO_Z = 330, -240
local DEGRAU = 14
local FADE = 60 -- largura da comporta entre a rampa das zonas planas e o sopé/montanha
-- Cordilheira bruta (sem fade): amplitude por direção, cristas ridged, picos esparsos,
-- rugosidade fina e degraus parciais para encostas escalonadas em vez de paredes lisas.
local function cordilheira(x, z)
	local theta = math.atan2(z - CENTRO_Z, x - CENTRO_X)
	local direcao = noise(math.cos(theta) * 1.6 + 11, math.sin(theta) * 1.6 - 7)
	local massa = 100 + 75 * direcao
	local larga = 0.7 + 0.7 * fbm(x / 320 + 5, z / 320 - 9)
	local m = massa * (0.55 + 0.6 * ridged(x / 210, z / 210)) * larga
	m += 60 * smooth((noise(x / 160 + 9, z / 160 - 4) - 0.6) / 0.42)
	m += 6 * ridged(x / 28 + 3, z / 28 - 5)
	local q = m / DEGRAU
	local f = q - math.floor(q)
	local degrau = (math.floor(q) + smooth((f - 0.3) / 0.7)) * DEGRAU
	return m * 0.82 + degrau * 0.18
end

function T.altura(x, z)
	local dj = T.distanciaJogavel(x, z)
	-- Longe das áreas de jogo nenhuma zona plana interfere (todas estão a <= 14 studs
	-- delas); evita varrer as zonas para centenas de milhares de colunas. O corte
	-- (RAMPA + FADE + 14) é onde a comporta abaixo já saturou, então não há degrau.
	local d = if dj >= T.RAMPA + FADE + 14 then dj - 14 else math.max(0, T.distanciaPlana(x, z) - T.RESOLUCAO)
 local jardim = T.distanciaZona(x,z,T.PROVACAO_AGUA)
 -- A margem do jardim desce desde a borda, sem o halo plano de um voxel.
 if d < 1e-8 and jardim > 0 and jardim < 28 then
  local outra=math.huge
  for _,zona in ipairs(T.ZONAS_PLANAS) do
   if zona~=T.PROVACAO_AGUA then outra=math.min(outra,T.distanciaZona(x,z,zona)) end
  end
  if outra>T.RESOLUCAO then d=jardim end
 end
	if d < 1e-8 then return 0 end
	local h = 3 + 7 * fbm(x / 100, z / 100)
	-- Sopé: colinas de 15-35 studs logo fora da área jogável. Cordilheira: começa a
	-- ~80 studs da área jogável e sobe ao longo de ~210. A comporta mantém as encostas
	-- longe das rampas das zonas planas (que já descem 32 studs sozinhas).
	local comporta = smooth((d - T.RAMPA) / FADE)
	if comporta > 0 then
		local relevo = 0
		if dj > 4 then relevo += (14 + 22 * fbm(x / 60 + 3, z / 60 - 5)) * smooth((dj - 4) / 64) end
		local t = smooth((dj - 80) / 210)
		if t > 0 then relevo += cordilheira(x, z) * t end
		h += relevo * comporta
	end
	h = math.min(230, h) * smooth(d / T.RAMPA)
	-- Lago: fundo plano em -fundo, margem no nível e praia suave até o relevo.
	for _, a in ipairs(T.AGUA) do
		local sd = distanciaLago(a, x, z)
		if sd < a.praia then
			local lago = if sd <= 0 then a.nivel + (a.fundo - a.nivel) * smooth(-sd / 14)
				else a.nivel + (h - a.nivel) * smooth(sd / a.praia)
			-- Sem degrau perto das zonas planas: o efeito do lago some até 20 studs delas.
            if jardim < 28 then
             -- Talude: 0 até o nível (-2) em quatro studs, depois até o leito.
             lago = math.max(lago, a.nivel + (a.fundo-a.nivel)*smooth((jardim-4)/24))
             h += (lago-h)*smooth(jardim/4)
            else
             h += (lago - h) * smooth((d - 4) / 16)
            end
		end
	end
	-- Paredes do desfiladeiro: preserva rampas suaves nos primeiros 36 studs,
	-- depois ergue rocha dos dois lados. Não invade o halo das zonas anteriores.
	local dp = T.PASSAGEM.distancia(x, z)
	if dp > 36 and dp < 190 then
		local antigo = math.huge
		for _, r in ipairs(T.ZONAS_PLANAS) do antigo = math.min(antigo, T.distanciaZona(x, z, r)) end
		local parede = 64 * smooth((dp - 36) / 80) * (1 - smooth((dp - 120) / 70))
		h = math.max(h, parede * smooth((antigo - 36) / 48))
	end
	return h
end
function T.material(x, z, altura, inclinacao)
	if T.naPassagem(x, z) then return if x < 460 then "Ground" else "Slate" end
	local dp = T.PASSAGEM.distancia(x, z)
	if dp > 36 and dp < 150 and altura >= 20 then return "Rock" end
	for i = #T.ZONAS_PLANAS, 1, -1 do
		local r = T.ZONAS_PLANAS[i]
		local d = T.distanciaZona(x, z, r)
		if d == 0 then return r.material end
		if r.material == "Ground" and d < 1 + 3 * noise(x / 7, z / 7) then return "Mud" end
	end
	for _, a in ipairs(T.AGUA) do
		local sd = distanciaLago(a, x, z)
		if sd < 14 then return if altura < -4 then "Mud" else "Sand" end
		if sd < 24 and noise(x / 6, z / 6) > 0.5 then return "Sand" end
	end
	-- inclinacao é gradiente (stud vertical/stud horizontal), não graus.
	if altura > T.NEVE + 12 * noise(x / 35 + 3, z / 35) and inclinacao < 1.1 then return "Snow" end
	-- Nas colinas baixas o limite sobe (0.95): só encostas de verdade viram pedra.
	if inclinacao > 0.65 + 0.3 * (1 - smooth(altura / 40)) then return if noise(x / 18, z / 18) > 0.5 then "Rock" else "Slate" end
	if altura > 40 + 26 * noise(x / 45, z / 45) then return "Rock" end
	if T.distanciaZona(x, z, Floresta.SOLO) == 0 then
		return if noise(x / 15, z / 15) < 0.26 then "Mud" else "LeafyGrass"
	end
	return "Grass"
end
return T
