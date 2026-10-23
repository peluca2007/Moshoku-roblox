-- GERADO por tools/gerar-catalogo.mts a partir do site do livro. Não edite: rode o gerador.
-- Domínio Pericias.
local function congelar(t)
	for _, v in t do
		if type(v) == "table" and not table.isfrozen(v) then
			congelar(v)
		end
	end
	return table.freeze(t)
end
return congelar({
	{
		id = "skill/atletismo",
		kind = "skill",
		sourceId = "Atletismo",
		sourceRef = {
			path = "src/data/skills.ts",
			symbol = "SKILLS",
			selector = "SKILLS[pericias=Atletismo]",
		},
		data = {
			name = "Atletismo",
			attribute = "forca",
			description = "Escalar, nadar, arrombar, forçar, saltar.",
		},
	},
	{
		id = "skill/acrobacia",
		kind = "skill",
		sourceId = "Acrobacia",
		sourceRef = {
			path = "src/data/skills.ts",
			symbol = "SKILLS",
			selector = "SKILLS[pericias=Acrobacia]",
		},
		data = {
			name = "Acrobacia",
			attribute = "agilidade",
			description = "Equilíbrio e esquiva acrobática.",
		},
	},
	{
		id = "skill/furtividade",
		kind = "skill",
		sourceId = "Furtividade",
		sourceRef = {
			path = "src/data/skills.ts",
			symbol = "SKILLS",
			selector = "SKILLS[pericias=Furtividade]",
		},
		data = {
			name = "Furtividade",
			attribute = "agilidade",
			description = "Esconder-se e mover-se sem ser notado.",
		},
	},
	{
		id = "skill/ladinagem",
		kind = "skill",
		sourceId = "Ladinagem",
		sourceRef = {
			path = "src/data/skills.ts",
			symbol = "SKILLS",
			selector = "SKILLS[pericias=Ladinagem]",
		},
		data = {
			name = "Ladinagem",
			attribute = "agilidade",
			description = "Agilidade manual — bater carteira, soltar algemas, plantar um item.",
		},
	},
	{
		id = "skill/arcanismo",
		kind = "skill",
		sourceId = "Arcanismo",
		sourceRef = {
			path = "src/data/skills.ts",
			symbol = "SKILLS",
			selector = "SKILLS[pericias=Arcanismo]",
		},
		data = {
			name = "Arcanismo",
			attribute = "intelecto",
			description = "Teoria mágica e itens encantados.",
		},
	},
	{
		id = "skill/historia",
		kind = "skill",
		sourceId = "História",
		sourceRef = {
			path = "src/data/skills.ts",
			symbol = "SKILLS",
			selector = "SKILLS[pericias=História]",
		},
		data = {
			name = "História",
			attribute = "intelecto",
			description = "Fatos do passado e linhagens.",
		},
	},
	{
		id = "skill/investigacao",
		kind = "skill",
		sourceId = "Investigação",
		sourceRef = {
			path = "src/data/skills.ts",
			symbol = "SKILLS",
			selector = "SKILLS[pericias=Investigação]",
		},
		data = {
			name = "Investigação",
			attribute = "intelecto",
			description = "Deduzir pistas e ligar evidências.",
		},
	},
	{
		id = "skill/medicina",
		kind = "skill",
		sourceId = "Medicina",
		sourceRef = {
			path = "src/data/skills.ts",
			symbol = "SKILLS",
			selector = "SKILLS[pericias=Medicina]",
		},
		data = {
			name = "Medicina",
			attribute = "intelecto",
			description = "Primeiros socorros e diagnóstico físico. Com um Kit de Primeiros Socorros, cuida dos ferimentos do grupo no Descanso Curto (Cap. 4, §7).",
		},
	},
	{
		id = "skill/natureza",
		kind = "skill",
		sourceId = "Natureza",
		sourceRef = {
			path = "src/data/skills.ts",
			symbol = "SKILLS",
			selector = "SKILLS[pericias=Natureza]",
		},
		data = {
			name = "Natureza",
			attribute = "intelecto",
			description = "Fauna, flora e clima.",
		},
	},
	{
		id = "skill/oficios",
		kind = "skill",
		sourceId = "Ofícios",
		sourceRef = {
			path = "src/data/skills.ts",
			symbol = "SKILLS",
			selector = "SKILLS[pericias=Ofícios]",
		},
		data = {
			name = "Ofícios",
			attribute = "intelecto",
			description = "Um ofício manual específico, escolhido ao adquirir (Forja, Culinária, Alquimia, Carpintaria...). É o saber; a ferramenta do ofício é proficiência à parte.",
		},
	},
	{
		id = "skill/religiao",
		kind = "skill",
		sourceId = "Religião",
		sourceRef = {
			path = "src/data/skills.ts",
			symbol = "SKILLS",
			selector = "SKILLS[pericias=Religião]",
		},
		data = {
			name = "Religião",
			attribute = "intelecto",
			description = "Doutrina, templos e o Continente Divino.",
		},
	},
	{
		id = "skill/atuacao",
		kind = "skill",
		sourceId = "Atuação",
		sourceRef = {
			path = "src/data/skills.ts",
			symbol = "SKILLS",
			selector = "SKILLS[pericias=Atuação]",
		},
		data = {
			name = "Atuação",
			attribute = "espirito",
			description = "Performance, música, oratória de palco.",
		},
	},
	{
		id = "skill/enganacao",
		kind = "skill",
		sourceId = "Enganação",
		sourceRef = {
			path = "src/data/skills.ts",
			symbol = "SKILLS",
			selector = "SKILLS[pericias=Enganação]",
		},
		data = {
			name = "Enganação",
			attribute = "espirito",
			description = "Mentir e disfarçar intenção.",
		},
	},
	{
		id = "skill/intimidacao",
		kind = "skill",
		sourceId = "Intimidação",
		sourceRef = {
			path = "src/data/skills.ts",
			symbol = "SKILLS",
			selector = "SKILLS[pericias=Intimidação]",
		},
		data = {
			name = "Intimidação",
			attribute = "forca",
			description = "Impor medo pela presença física. (Força desde 2026-09-26: o Espírito governava 8 das 20 perícias e a Força só 1.)",
		},
	},
	{
		id = "skill/intuicao",
		kind = "skill",
		sourceId = "Intuição",
		sourceRef = {
			path = "src/data/skills.ts",
			symbol = "SKILLS",
			selector = "SKILLS[pericias=Intuição]",
		},
		data = {
			name = "Intuição",
			attribute = "espirito",
			description = "Perceber mentira e prever intenção.",
		},
	},
	{
		id = "skill/labia",
		kind = "skill",
		sourceId = "Lábia",
		sourceRef = {
			path = "src/data/skills.ts",
			symbol = "SKILLS",
			selector = "SKILLS[pericias=Lábia]",
		},
		data = {
			name = "Lábia",
			attribute = "espirito",
			description = "Convencer rápido, pechinchar, tagarelar.",
		},
	},
	{
		id = "skill/lidar-com-animais",
		kind = "skill",
		sourceId = "Lidar com Animais",
		sourceRef = {
			path = "src/data/skills.ts",
			symbol = "SKILLS",
			selector = "SKILLS[pericias=Lidar com Animais]",
		},
		data = {
			name = "Lidar com Animais",
			attribute = "espirito",
			description = "Acalmar e comandar animais.",
		},
	},
	{
		id = "skill/percepcao",
		kind = "skill",
		sourceId = "Percepção",
		sourceRef = {
			path = "src/data/skills.ts",
			symbol = "SKILLS",
			selector = "SKILLS[pericias=Percepção]",
		},
		data = {
			name = "Percepção",
			attribute = "espirito",
			description = "Notar detalhes com os sentidos.",
		},
	},
	{
		id = "skill/persuasao",
		kind = "skill",
		sourceId = "Persuasão",
		sourceRef = {
			path = "src/data/skills.ts",
			symbol = "SKILLS",
			selector = "SKILLS[pericias=Persuasão]",
		},
		data = {
			name = "Persuasão",
			attribute = "espirito",
			description = "Convencer com argumento sincero.",
		},
	},
	{
		id = "skill/sobrevivencia",
		kind = "skill",
		sourceId = "Sobrevivência",
		sourceRef = {
			path = "src/data/skills.ts",
			symbol = "SKILLS",
			selector = "SKILLS[pericias=Sobrevivência]",
		},
		data = {
			name = "Sobrevivência",
			attribute = "espirito",
			description = "Rastrear, orientar-se e sobreviver no ermo.",
		},
	},
})
