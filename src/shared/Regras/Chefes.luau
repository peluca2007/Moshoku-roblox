-- Padrões e desafios de arena. Fichas vêm do catálogo; padrões são adaptação.
local Chefes = {}
Chefes.ID = "creature/treant-anciao"
Chefes.NOME = "Treant Ancião"
function Chefes.validarNivel(p, master)
	if type(p) ~= "table" then return nil, "Pedido de desafio inválido." end
	for k in p do
		if k ~= "nivel" and not (k == "encontro" and master) then return nil, "Campo de desafio inválido." end
	end
	local nivel = if p.nivel == nil then 1 else p.nivel
	if nivel ~= 1 and nivel ~= 2 and nivel ~= 3 then return nil, "Escolha nível 1, 2 ou 3." end
	return nivel, nil
end
function Chefes.desafio(nivel, jogadores)
	if (nivel ~= 1 and nivel ~= 2 and nivel ~= 3) or type(jogadores) ~= "number" or jogadores % 1 ~= 0 or jogadores < 1 or jogadores > 4 then return nil end
	if nivel == 1 then return { nivel = 1 } end -- preserva ENCONTROS atuais
	local criaturas = {}
	if nivel == 2 then
		table.insert(criaturas, { "creature/urso-de-presas-vermelhas", 10, 5 })
		for i = 1, jogadores do table.insert(criaturas, { "creature/goblin-batedor", 5 + i * 2, 8 }) end
		if jogadores >= 3 then table.insert(criaturas, { "creature/lobo-cinzento", 14, 5 }) end
		return { nivel = 2, nome = "Presas vermelhas", criaturas = criaturas }
	end
	table.insert(criaturas, { Chefes.ID, 10, 5 })
	-- Escala pelo apoio; não multiplica a ficha de chefe do Apêndice G.
	for i = 2, jogadores do table.insert(criaturas, { "creature/lobo-cinzento", 3 + i * 3, 8 }) end
	return { nivel = 3, nome = Chefes.NOME, criaturas = criaturas }
end
function Chefes.fase(pv, maximo)
	local r = if maximo > 0 then pv / maximo else 0
	return if r > .6 then 1 elseif r > .3 then 2 else 3
end
-- Centro congelado no aviso; sair da área evita o especial quando o gancho existir.
function Chefes.preparar(chefe, alvo, vez, largura, altura)
	local fase = Chefes.fase(chefe.pv, chefe.pvMax)
	local raio = if fase == 3 then 2 else 1
	local cruz = fase == 2
	local casas = {}
	for x = math.max(1, alvo.x - raio), math.min(largura, alvo.x + raio) do
		for z = math.max(1, alvo.z - raio), math.min(altura, alvo.z + raio) do
			if not cruz or x == alvo.x or z == alvo.z then table.insert(casas, { x, z }) end
		end
	end
	return { id = tostring(vez), fase = fase, nome = if fase == 1 then "Raízes despertas" elseif fase == 2 then "Ruptura da terra" else "Fúria da floresta", casas = casas, x = alvo.x, z = alvo.z }
end
function Chefes.alvos(aviso, tokens)
	local atingidos = {}
	for _, t in tokens do
		if t.ownerUserId and t.ownerUserId ~= 0 and not t.ia and not t.boneco and not t.derrotado and t.pv > 0 then
			for _, c in aviso.casas do
				if t.x == c[1] and t.z == c[2] then table.insert(atingidos, t); break end
			end
		end
	end
	table.sort(atingidos, function(a,b) return a.id < b.id end)
	return atingidos
end
return Chefes
