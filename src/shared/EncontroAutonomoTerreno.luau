-- Células fixas por arena e projeções de bloqueio para zonas dinâmicas J2.
local Terreno = {}
local Combate = require(game:GetService("ReplicatedStorage").Shared.Regras.Combate)
local MURO_DE_CHAMAS = "ability/fogo/Principiante/muro-de-chamas"
local MURO_DE_TERRA = "ability/terra/Principiante/muro-de-terra"
local ANTEPARO_TEORICO = "ability/teorica/Principiante/anteparo-teorico"
local ESCUDO_DE_AGUA = "ability/agua/Principiante/escudo-de-agua"
local NEVOA_DENSA = "ability/agua/Principiante/nevoa-densa"

local POR_AREA = {
	["region/encounter/forest"] = {
		{ x = 6, z = 8 }, { x = 6, z = 9 },
		{ x = 15, z = 12 }, { x = 15, z = 13 },
	},
	["region/encounter/dark-forest"] = {
		{ x = 7, z = 5 }, { x = 7, z = 6 },
		{ x = 14, z = 15 }, { x = 15, z = 15 },
	},
}

-- Conservador: qualquer sobreposi??o da casa com a base do prop bloqueia.
-- Colunas perif?ricas podem tocar a grade; o altar central nunca ? piso livre.
local function bloqueiosRuinas()
 local Shared = game:GetService("ReplicatedStorage").Shared
 local Layout = require(Shared.Mundo.RuinasLayout)
 local Props = require(Shared.Mundo.PropsLayout)
 local retangulos = {}
 for _, p in ipairs(Layout.pecas()) do
  if p[3] == "altar" or p[3] == "coluna" or p[3] == "colunaquebrada" then
   local r = Props.retangulo(p)
   local f = Props.FAMILIAS[p[3]]
   local sx, sz = f.base[1] * f.escala * p[4], f.base[2] * f.escala * p[4]
   local cos, sen = math.abs(math.cos(math.rad(p[5]))), math.abs(math.sin(math.rad(p[5])))
   r.sx, r.sz = math.max(r.sx, sx * cos + sz * sen), math.max(r.sz, sx * sen + sz * cos)
   table.insert(retangulos, r)
  end
 end
 local arena, lista = Layout.ARENA, {}
 for x = 1, 20 do
  for z = 1, 20 do
   local px, pz = arena.x + (x - 10.5) * arena.passo, arena.z + (z - 10.5) * arena.passo
   for _, r in ipairs(retangulos) do
    if math.abs(px - r.x) < (r.sx + arena.passo) / 2
     and math.abs(pz - r.z) < (r.sz + arena.passo) / 2 then
     table.insert(lista, { x = x, z = z }); break
    end
   end
  end
 end
 return lista
end

function Terreno.celulas(areaId, amostradas)
	local origem = amostradas or POR_AREA[areaId]
	if not origem and areaId == "region/encounter/ruinas" then
  POR_AREA[areaId] = bloqueiosRuinas()
  origem = POR_AREA[areaId]
 end
	if not origem then return {} end
	local copia = table.create(#origem)
	for indice, celula in ipairs(origem) do
		copia[indice] = { x = celula.x, z = celula.z }
	end
	return copia
end

function Terreno.chaves(areaId, amostradas)
	return Terreno.chavesDe(Terreno.celulas(areaId, amostradas))
end

function Terreno.chavesDe(celulas)
	local resultado = {}
	if type(celulas) ~= "table" then return resultado end
	for _, celula in ipairs(celulas) do
		if type(celula) ~= "table" or type(celula.x) ~= "number" or celula.x % 1 ~= 0
			or celula.x < 1 or celula.x > 20 or type(celula.z) ~= "number" or celula.z % 1 ~= 0
			or celula.z < 1 or celula.z > 20
		then continue end
		resultado[tostring(celula.x) .. ":" .. tostring(celula.z)] = true
	end
	return resultado
end

-- Recusa antes de criar estado ou ancorar avatares; nunca nasce em casa bloqueada.
function Terreno.posicoesIniciaisLivres(atores, celulas)
 local ocupadas = Terreno.chavesDe(celulas)
 for _, ator in ipairs(atores) do
  local x, z = ator.x, ator.z
  if type(x) ~= "number" or type(z) ~= "number" or x % 1 ~= 0 or z % 1 ~= 0
   or x < 1 or x > 20 or z < 1 or z > 20 then return false end
  local chave = tostring(x) .. ":" .. tostring(z)
  if ocupadas[chave] then return false end
  ocupadas[chave] = true
 end
 return true
end

-- Projeção pura do ponto de entrada na borda livre mais próxima. Corpos de
-- jogadores caídos ocupam casa; criaturas removidas e fugitivos não ocupam.
function Terreno.bordaLivre(x, z, atores, bloqueadas)
 if type(x) ~= "number" or type(z) ~= "number" or x ~= x or z ~= z
  or math.abs(x) == math.huge or math.abs(z) == math.huge then return nil end
 local ocupadas = Terreno.chavesDe(bloqueadas)
 for _, ator in ipairs(atores or {}) do
  if not ator.fled and not (ator.kind == "criatura" and ator.defeated) then
   ocupadas[tostring(ator.x) .. ":" .. tostring(ator.z)] = true
  end
 end
 local melhor, distancia
 for cx = 1, 20 do
  for cz = 1, 20 do
   if (cx == 1 or cx == 20 or cz == 1 or cz == 20) and not ocupadas[cx .. ":" .. cz] then
    local d = (cx - x) ^ 2 + (cz - z) ^ 2
    if not distancia or d < distancia then melhor, distancia = { x = cx, z = cz }, d end
   end
  end
 end
 return melhor
end

function Terreno.celulasBloqueantes(perigos, turno)
	local resultado = {}
	for _, perigo in ipairs(perigos or {}) do
		if type(perigo) ~= "table" or (perigo.abilityId ~= MURO_DE_TERRA and perigo.abilityId ~= ANTEPARO_TEORICO)
			or (type(perigo.expiresTurn) == "number" and type(turno) == "number" and turno >= perigo.expiresTurn)
		then continue end
		if type(perigo.x) == "number" and type(perigo.z) == "number" then
			table.insert(resultado, { x = perigo.x, z = perigo.z })
		end
	end
	return resultado
end

function Terreno.visaoLivre(ax, az, bx, bz, celulas, perigos, turno)
	local bloqueadas = Terreno.chavesDe(celulas)
	for _, perigo in ipairs(perigos or {}) do
		if type(perigo) ~= "table" or (type(perigo.expiresTurn) == "number" and type(turno) == "number"
			and turno >= perigo.expiresTurn) or type(perigo.x) ~= "number" or type(perigo.z) ~= "number"
		then continue end
		local chave = tostring(perigo.x) .. ":" .. tostring(perigo.z)
		if perigo.abilityId == MURO_DE_CHAMAS or perigo.abilityId == MURO_DE_TERRA then
			bloqueadas[chave] = true
		elseif perigo.abilityId == NEVOA_DENSA then
			bloqueadas[chave] = true
		elseif perigo.abilityId == ANTEPARO_TEORICO then
			-- O Anteparo barra corpos/projéteis, mas permite visão e magia.
			bloqueadas[chave] = nil
		end
	end
	return Combate.temVisao(ax, az, bx, bz, function(x, z)
		return bloqueadas[tostring(x) .. ":" .. tostring(z)] == true
	end)
end

function Terreno.atorNaNevoa(x, z, perigos, turno)
	if type(x) ~= "number" or type(z) ~= "number" then return false end
	for _, perigo in ipairs(perigos or {}) do
		if type(perigo) == "table" and perigo.abilityId == NEVOA_DENSA
			and perigo.x == x and perigo.z == z
			and (type(perigo.expiresTurn) ~= "number" or type(turno) ~= "number" or turno < perigo.expiresTurn)
		then return true end
	end
	return false
end

-- Cobertura do Escudo é aplicada à jogada, sem bloquear visão ou absorver dano.
function Terreno.coberturaNaLinha(ax, az, bx, bz, perigos, turno)
	local celulas, bonus = {}, 0
	for _, perigo in ipairs(perigos or {}) do
		if type(perigo) == "table" and perigo.abilityId == ESCUDO_DE_AGUA
			and (type(perigo.expiresTurn) ~= "number" or type(turno) ~= "number" or turno < perigo.expiresTurn)
			and type(perigo.x) == "number" and type(perigo.z) == "number"
		then
			celulas[tostring(perigo.x) .. ":" .. tostring(perigo.z)] = true
			if type(perigo.coverage) == "number" and perigo.coverage > bonus then bonus = perigo.coverage end
		end
	end
	if bonus <= 0 then return 0 end
	local cruzou = not Combate.temVisao(ax, az, bx, bz, function(x, z)
		return celulas[tostring(x) .. ":" .. tostring(z)] == true
	end)
	-- A zona também protege um aliado que ocupa uma de suas casas.
	cruzou = cruzou or celulas[tostring(bx) .. ":" .. tostring(bz)] == true
	return if cruzou then bonus else 0
end

-- Escudo não bloqueia a linha mágica, mas reduz parcelas ígneas que cruzam
-- suas células. Usa a mesma supercobertura de visão para diagonais e cantos.
function Terreno.reduzIgneoNaLinha(ax, az, bx, bz, perigos, turno)
	local celulas = {}
	for _, perigo in ipairs(perigos or {}) do
		if type(perigo) == "table" and perigo.abilityId == ESCUDO_DE_AGUA
			and perigo.reduzIgneo == true
			and (type(perigo.expiresTurn) ~= "number" or type(turno) ~= "number" or turno < perigo.expiresTurn)
			and type(perigo.x) == "number" and type(perigo.z) == "number"
		then
			celulas[tostring(perigo.x) .. ":" .. tostring(perigo.z)] = true
		end
	end
	if next(celulas) == nil then return false end
	return not Combate.temVisao(ax, az, bx, bz, function(x, z)
		return celulas[tostring(x) .. ":" .. tostring(z)] == true
	end)
end

return Terreno
