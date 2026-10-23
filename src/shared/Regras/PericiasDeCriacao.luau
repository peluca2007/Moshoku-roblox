-- Perícias que já vêm da escolha inicial; a UI e a validação usam a mesma lista.
local PericiasDeCriacao = {}

local function porId(catalogo, id, especie)
	local entrada = type(id) == "string" and catalogo.POR_ID[id]
	return entrada and entrada.kind == especie and entrada or nil
end

local function marcarNomes(saida, catalogo, nomes)
	for _, nome in nomes or {} do
		if type(nome) ~= "string" then continue end
		for _, pericia in catalogo.POR_ESPECIE.skill or {} do
			if pericia.data.name == nome then
				saida[pericia.id] = true
				break
			end
		end
	end
end

function PericiasDeCriacao.idsJaConcedidos(catalogo, raceId, backgroundId, startingTreeId, treeSkillChoiceIds)
	local resultado = {}
	if type(catalogo) ~= "table" or type(catalogo.POR_ID) ~= "table"
		or type(catalogo.POR_ESPECIE) ~= "table" or type(catalogo.POR_ESPECIE.skill) ~= "table"
	then return resultado end
	local raca = porId(catalogo, raceId, "race")
	local antecedente = porId(catalogo, backgroundId, "background")
	local arvore = porId(catalogo, startingTreeId, "tree")
	marcarNomes(resultado, catalogo, raca and raca.data.fixedSkills)
	marcarNomes(resultado, catalogo, antecedente and antecedente.data.fixedSkills)
	local concessoes = arvore and arvore.data.grantedSkills
	marcarNomes(resultado, catalogo, concessoes and concessoes.fixed)
	for _, id in treeSkillChoiceIds or {} do
		if porId(catalogo, id, "skill") then resultado[id] = true end
	end
	return resultado
end

return PericiasDeCriacao
