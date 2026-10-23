-- Organização de PvP; adaptação de jogo, sem estado Roblox.
local Equipes = {}
local function fechado(p, chaves)
	if type(p) ~= "table" then return false end
	for k in p do if not chaves[k] then return false end end
	return true
end
function Equipes.validarFila(p)
	if not fechado(p, { modo = true, equipe = true }) then return "Pedido de fila inválido." end
	if p.modo ~= "luta" and p.modo ~= "duelo" and p.modo ~= "sair" then return "Escolha uma fila válida." end
	if p.equipe ~= nil and (p.modo ~= "duelo" or (p.equipe ~= 0 and p.equipe ~= 1 and p.equipe ~= 2)) then
		return "Equipe deve ser 0, 1 ou 2 no PvP."
	end
	return nil
end
function Equipes.validarDuelo(p)
	return if fechado(p, {}) then nil else "Pedido de PvP inválido."
end
function Equipes.lado(token, equipes)
	local dono = token and token.ownerUserId
	if dono == nil or dono == 0 or equipes[dono] == nil then return nil end
	return if equipes[dono] == 0 then "j:" .. tostring(dono) else "e:" .. tostring(equipes[dono])
end
function Equipes.aliados(a, b, equipes)
	local lado = Equipes.lado(a, equipes)
	return lado ~= nil and lado == Equipes.lado(b, equipes)
end
function Equipes.dePe(tokens, equipes)
	local vivos, vistos = {}, {}
	for _, t in tokens do
		local lado = Equipes.lado(t, equipes)
		if lado and not t.ia and not t.boneco and not t.derrotado and t.pv > 0 and not vistos[lado] then
			vistos[lado] = true; table.insert(vivos, lado)
		end
	end
	table.sort(vivos)
	return vivos
end
function Equipes.temOponentes(grupo, escolhas)
	local lados = {}
	for _, p in grupo do
		lados[Equipes.lado({ ownerUserId = p.UserId }, { [p.UserId] = escolhas[p.UserId] or 0 })] = true
	end
	local n = 0; for _ in lados do n += 1 end
	return n >= 2
end
-- 32 casas disjuntas por lado; 60 fichas é o teto existente da mesa.
function Equipes.casas(grupo, equipes)
	local usadas, casas = { [0] = 0, [1] = 0, [2] = 0 }, {}
	for _, p in grupo do
		local equipe = equipes[p.UserId] or 0
		usadas[equipe] += 1
		local i = usadas[equipe] - 1
		if equipe == 0 then
			table.insert(casas, { 3 + (i % 8) * 2, 3 + math.floor(i / 8) * 4 })
		else
			table.insert(casas, { (if equipe == 1 then 2 else 15) + (i % 4), 2 + math.floor(i / 4) * 2 })
		end
	end
	return casas
end
return Equipes
