-- Regra pura de descanso do Cap. 4, §7. Sem Instances/rede; RNG não é necessário
-- neste recorte, mas permanece injetável para compatibilidade com consequências futuras.
local Descanso = {}
Descanso.CURTOS_POR_DIA = 2

local function piso(v) return math.floor(v * 0.25) end
local function ganho(maximos, tipo, vigor, maiorBonus, rng)
	if type(maximos) ~= "table" then return nil, "reservas inválidas" end
	for _, k in { "pv", "pm", "pt", "pp" } do
		if type(maximos[k]) ~= "number" or maximos[k] < 0 or maximos[k] % 1 ~= 0 then return nil, "reservas inválidas" end
	end
	if tipo == "curto" then
		return { pv = piso(maximos.pv), pm = piso(maximos.pm), pt = maximos.pt, pp = piso(maximos.pp) }
	elseif tipo == "longo" then
		if type(vigor) ~= "number" or type(maiorBonus) ~= "number" then return nil, "atributos inválidos" end
		return { pv = piso(maximos.pv) + math.max(1, vigor + 2 * maiorBonus), pm = maximos.pm, pt = maximos.pt, pp = maximos.pp }
	end
	return nil, "tipo de descanso inválido"
end

function Descanso.resolver(entrada, rng)
	if type(entrada) ~= "table" then return nil, "entrada inválida" end
	local count = entrada.descansosCurtos or 0
	if type(count) ~= "number" or count % 1 ~= 0 or count < 0 or count > 2 then return nil, "contador inválido" end
	if entrada.tipo == "curto" and count >= Descanso.CURTOS_POR_DIA then return nil, "limite de descansos curtos atingido" end
	local g, erro = ganho(entrada.maximos, entrada.tipo, entrada.vigor, entrada.maiorBonus, rng)
	if not g then return nil, erro end
	local atuais = entrada.atuais or entrada.maximos
	local novos = {}
	for _, k in { "pv", "pm", "pt", "pp" } do
		if type(atuais[k]) ~= "number" or atuais[k] < 0 or atuais[k] % 1 ~= 0 then return nil, "recursos atuais inválidos" end
		novos[k] = math.min(entrada.maximos[k], atuais[k] + g[k])
	end
	return { atuais = novos, descansosCurtos = if entrada.tipo == "longo" then 0 else count + 1, ganho = g }
end

return table.freeze(Descanso)
