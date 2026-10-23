-- Planejamento puro de apresentação sobre snapshots/recibos já filtrados.
local V = {}
local familias = {
	["creature/goblin-batedor"] = "npc__goblin-batedor",
	["creature/lobo-cinzento"] = "npc__lobo-cinzento",
	["creature/bandido-de-estrada"] = "npc__bandido-de-estrada",
	["creature/urso-de-presas-vermelhas"] = "npc__urso-de-presas-vermelhas",
	["creature/treant-anciao"] = "boss__treant-anciao",
}
local validas = {}
for _, v in familias do validas[v] = true end
local especiais = { [1] = "raizes", [2] = "ruptura", [3] = "furia" }
function V.familia(catalogId) return familias[catalogId] end
function V.novo() return { vistos = {}, mortos = {}, baixos = {}, avisos = {}, execucoes = {}, fase = {}, recibos = setmetatable({}, { __mode = "k" }) } end
function V.valido(token) return token ~= nil and validas[token.vozNPC] == true end
local function pedido(out, token, situacao, prioridade)
	if V.valido(token) then table.insert(out, { tokenId = token.id, familia = token.vozNPC, prefixo = token.vozNPC .. "__" .. situacao .. "__", prioridade = prioridade }) end
end
local function vivo(t) return not t.derrotado and (type(t.pv) ~= "number" or t.pv > 0) end
function V.snapshot(mem, s)
	local out = {}
	if not s or not s.combat or not s.combat.active then return out end
	local presentes = {}
	for _, token in s.tokens or {} do
		presentes[token.id] = token
		if not V.valido(token) then continue end
		if not vivo(token) then
			if mem.vistos[token.id] and not mem.mortos[token.id] then pedido(out, token, "derrota", 5) end
			mem.mortos[token.id] = true
		elseif not mem.vistos[token.id] then
			local situacao = if token.vozNPC == "boss__treant-anciao" or token.vozNPC == "npc__urso-de-presas-vermelhas" then "entrada" elseif token.vozNPC == "npc__lobo-cinzento" then "ameaca" else "avistar"
			pedido(out, token, situacao, if token.vozNPC == "boss__treant-anciao" then 4 else 1)
		end
		mem.vistos[token.id] = true
		if vivo(token) and type(token.pv) == "number" and type(token.pvMax) == "number" and token.pvMax > 0 and token.pv / token.pvMax <= .25 and not mem.baixos[token.id] then
			mem.baixos[token.id] = true
			if token.vozNPC ~= "boss__treant-anciao" then pedido(out, token, "pouca-vida", 3) end
		end
	end
	local chefe = s.encontro and s.encontro.chefe
	local token = chefe and presentes[chefe.id]
	if V.valido(token) and token.vozNPC == "boss__treant-anciao" and vivo(token) then
		local fase = chefe.fase
		if mem.fase[token.id] and fase ~= mem.fase[token.id] and (fase == 2 or fase == 3) then pedido(out, token, "fase-" .. fase, 4) end
		mem.fase[token.id] = fase
		local aviso = chefe.aviso
		if aviso and especiais[aviso.fase] and mem.avisos[token.id] ~= aviso.id then
			mem.avisos[token.id] = aviso.id
			pedido(out, token, especiais[aviso.fase] .. "-aviso", 4.5)
		end
	end
	return out
end
function V.efeito(mem, s, r)
	local out, tokens = {}, {}
	if not s or not s.combat or not s.combat.active or type(r) ~= "table" or mem.recibos[r] then return out end
	mem.recibos[r] = true
	for _, t in s.tokens or {} do tokens[t.id] = t end
	local caster = tokens[r.casterId]
	if V.valido(caster) and vivo(caster) and r.habilidadeId == "criatura/ataque" and r.estilo ~= "raizes" then pedido(out, caster, "ataque", 1) end
	local vistos = {}
	for _, a in r.alvos or {} do
		local t = tokens[a.id]
		if V.valido(t) and vivo(t) and not vistos[a.id] and type(a.dano) == "number" and a.dano > 0 then
			vistos[a.id] = true
			pedido(out, t, if a.critico then "dor-forte" else "dor-leve", 2)
		end
	end
	return out
end
function V.especial(mem, s, d)
	local out = {}
	local chefe = s and s.combat and s.combat.active and s.encontro and s.encontro.chefe
	if type(d) ~= "table" or not chefe or d.id ~= chefe.id or d.agiu ~= true or type(d.aviso) ~= "table" or not especiais[d.aviso.fase] or d.aviso.id == nil then return out end
	for _, t in s.tokens or {} do
		if t.id == d.id and t.vozNPC == "boss__treant-anciao" and vivo(t) and mem.execucoes[t.id] ~= d.aviso.id then
			mem.execucoes[t.id] = d.aviso.id
			pedido(out, t, especiais[d.aviso.fase] .. "-execucao", 4.5)
		end
	end
	return out
end
return V
