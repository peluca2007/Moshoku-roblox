-- Regra do jogo: visão curta de 90 graus, 4 casas (6 m), com obstáculos.
-- Puro; servidor e prévia usam a mesma geometria. Direção só muda no servidor.
local Combate = require(game:GetService("ReplicatedStorage").Shared.Regras.Combate)
local V = { ALCANCE = 4 }
function V.terrenoBloqueia(terreno, x, z): boolean
	return terreno[x .. "," .. z] == "parede"
end
function V.direcao(t): (number, number)
	if t.olharX and t.olharZ and t.olharX * t.olharX + t.olharZ * t.olharZ > 0 then return t.olharX, t.olharZ end
	local dx, dz = Combate.direcao8(10 - t.x, 10 - t.z)
	return if dx == 0 and dz == 0 then 0 else dx, if dx == 0 and dz == 0 then -1 else dz
end
function V.virar(t, x, z)
	local dx, dz = Combate.direcao8(x - t.x, z - t.z)
	if dx ~= 0 or dz ~= 0 then t.olharX, t.olharZ = dx, dz end
end
function V.contem(t, x, z, bloqueia): boolean
	if bloqueia(x, z) then return false end
	if t.derrotado or (t.pv ~= nil and t.pv <= 0) then return false end
	for _, c in t.conditions or {} do if c.id == "cego" or c.id == "inconsciente" then return false end end
	local dx, dz = x - t.x, z - t.z
	local d2 = dx * dx + dz * dz
	if d2 > V.ALCANCE ^ 2 then return false end
	local fx, fz = V.direcao(t)
	if d2 > 0 and (dx * fx + dz * fz) / math.sqrt(d2 * (fx * fx + fz * fz)) < math.sqrt(.5) - 1e-6 then return false end
	local px, pz = t.x, t.z
	for _, casa in Combate.linha(t.x, t.z, x, z) do
		local cx, cz = casa[1], casa[2]
		if bloqueia(cx, cz) then return false end
		if cx ~= px and cz ~= pz and (bloqueia(cx, pz) or bloqueia(px, cz)) then return false end
		px, pz = cx, cz
	end
	return true
end
return table.freeze(V)
