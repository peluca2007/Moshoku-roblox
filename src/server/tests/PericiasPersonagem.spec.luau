local Shared = game:GetService("ReplicatedStorage").Shared
local PericiasPersonagem = require(Shared.Regras.PericiasPersonagem)

local function catalogo()
	local porId = {
			["race/humano"] = { kind = "race", data = { fixedSkills = { "Medicina" } } },
			["background/plebeu"] = { kind = "background", data = { fixedSkills = { "Medicina" } } },
			["tree/agua"] = { kind = "tree", data = {
				id = "agua",
				grantedSkills = { fixed = { "Arcanismo" }, choose = {
					count = 1,
					from = { "Medicina", "Percepção" },
				} },
			} },
			["tree/furtividade-e-armadilhas"] = { kind = "tree", data = {
				id = "furtividade-e-armadilhas",
				masterySkillsWhenNotFirst = { "Furtividade", "Percepção" },
				proficiencies = { periciasCobertas = { "Percepção" } },
			} },
			["tree/tatico"] = { kind = "tree", data = {
				id = "tatico",
				proficiencies = { periciasCobertas = { "Percepção" } },
			} },
			["rank/agua/Principiante"] = { kind = "rank", data = { treeId = "agua" } },
			["rank/furtividade-e-armadilhas/Principiante"] = { kind = "rank", data = { treeId = "furtividade-e-armadilhas", rank = "Principiante" } },
			["rank/furtividade-e-armadilhas/Intermediário"] = { kind = "rank", data = { treeId = "furtividade-e-armadilhas", rank = "Intermediário" } },
			["rank/tatico/Intermediário"] = { kind = "rank", data = { treeId = "tatico", rank = "Intermediário" } },
			["skill/medicina"] = { id = "skill/medicina", kind = "skill", data = { name = "Medicina", attribute = "intelecto" } },
			["skill/percepcao"] = { id = "skill/percepcao", kind = "skill", data = { name = "Percepção", attribute = "espirito" } },
			["skill/oficios"] = { id = "skill/oficios", kind = "skill", data = { name = "Ofícios", attribute = "intelecto" } },
			["ability/norte/Principiante/primeiros-socorros"] = { kind = "ability", data = {
				grantsSkills = { "Medicina" },
			} },
			["talent/norte/Principiante/medicina"] = { kind = "talent", data = {
				grantsSkills = { "Ofícios" },
			} },
		}
	return {
		POR_ID = porId,
		POR_ESPECIE = {
			skill = { porId["skill/medicina"], porId["skill/percepcao"], porId["skill/oficios"] },
			tree = { porId["tree/agua"], porId["tree/furtividade-e-armadilhas"], porId["tree/tatico"] },
		},
	}
end

return {
	["árvore inicial concede fixas e só a quantidade escolhida"] = function(t)
		local skills = PericiasPersonagem.concedidas({
			startingTreeId = "tree/agua",
			treeSkillChoiceIds = { "skill/medicina", "skill/percepcao" },
		}, catalogo())
		t.eq(#skills, 2)
		t.eq(skills[1], "Arcanismo")
		t.eq(skills[2], "Medicina")
	end,
	["opção inválida ocupa a posição limitada antes do filtro, como no site"] = function(t)
		local skills = PericiasPersonagem.concedidas({
			startingTreeId = "tree/agua",
			treeSkillChoiceIds = { "skill/oficios", "skill/percepcao" },
		}, catalogo())
		t.eq(#skills, 1)
		t.eq(skills[1], "Arcanismo")
	end,
	["maestria só vem de outra árvore com rank aberto e remove duplicatas"] = function(t)
		local skills = PericiasPersonagem.concedidas({
			startingTreeId = "tree/agua",
			unlockedRankIds = {
				"rank/agua/Principiante",
				"rank/furtividade-e-armadilhas/Principiante",
			},
			treeSkillChoiceIds = { "skill/percepcao" },
		}, catalogo())
		t.eq(#skills, 3)
		t.eq(skills[1], "Arcanismo")
		t.eq(skills[2], "Percepção")
		t.eq(skills[3], "Furtividade")
	end,
	["habilidades compradas concedem perícias, talentos e habilidades não compradas não"] = function(t)
		local skills = PericiasPersonagem.concedidas({
			purchasedIds = {
				"ability/norte/Principiante/primeiros-socorros",
				"talent/norte/Principiante/medicina",
			},
	}, catalogo())
		t.eq(#skills, 1)
		t.eq(skills[1], "Medicina")
	end,
	["bônus treinado soma atributo e maior bônus coberto, sem empilhar árvores"] = function(t)
		local resultado = PericiasPersonagem.calcularBonus({
			skillIds = { "skill/percepcao" },
			unlockedRankIds = {
				"rank/furtividade-e-armadilhas/Principiante",
				"rank/furtividade-e-armadilhas/Intermediário",
				"rank/tatico/Intermediário",
			},
		}, catalogo(), "Percepção", 3, { Principiante = 1, ["Intermediário"] = 2 })
		t.eq(resultado.treinada, true)
		t.eq(resultado.bonusDeRank, 2)
		t.eq(resultado.total, 5)
	end,
	["perícia não treinada não recebe bônus de rank e nome desconhecido não calcula"] = function(t)
		local resultado = PericiasPersonagem.calcularBonus({
			unlockedRankIds = { "rank/tatico/Intermediário" },
		}, catalogo(), "Percepção", 3, { ["Intermediário"] = 2 })
		t.eq(resultado.treinada, false)
		t.eq(resultado.bonusDeRank, 0)
		t.eq(resultado.total, 3)
		t.eq(PericiasPersonagem.calcularBonus({}, catalogo(), "Desconhecida", 0, {}), nil)
	end,
	["perícia fixa da raça ou antecedente conta como treinada"] = function(t)
		local resultado = PericiasPersonagem.calcularBonus({
			backgroundId = "background/plebeu",
			unlockedRankIds = { "rank/furtividade-e-armadilhas/Intermediário" },
		}, catalogo(), "Medicina", 4, { ["Intermediário"] = 2 })
		t.eq(resultado.treinada, true)
		t.eq(resultado.total, 4)
	end,
	["calculadora produz entradas skillId/bonus/trained sem alterar a construção"] = function(t)
		local construcao = { skillIds = { "skill/medicina" } }
		local calculadas = PericiasPersonagem.calcularTodas(
			construcao,
			catalogo(),
			{ intelecto = 4 },
			{}
		)
		t.eq(#calculadas, 3)
		t.eq(calculadas[1].skillId, "skill/medicina")
		t.eq(calculadas[1].bonus, 4)
		t.eq(calculadas[1].trained, true)
		t.eq(calculadas[2].bonus, 0)
		t.eq(calculadas[2].trained, false)
		t.eq(#construcao.skillIds, 1)
	end,
}
