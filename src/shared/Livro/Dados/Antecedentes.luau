-- GERADO por tools/gerar-catalogo.mts a partir do site do livro. Não edite: rode o gerador.
-- Domínio Antecedentes.
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
		id = "background/plebeu",
		kind = "background",
		sourceId = "plebeu",
		sourceRef = {
			path = "src/data/backgrounds.ts",
			symbol = "BACKGROUNDS",
			selector = "BACKGROUNDS[id=plebeu]",
		},
		data = {
			id = "plebeu",
			name = "Plebeu / Trabalhador Rural",
			rollRange = {
				1,
				15,
			},
			bonuses = {
				attributes = {
					vigor = 1,
				},
			},
			bonusSkillChoices = 2,
			startingGold = "2d4",
			traits = {
				"Suas 2 Perícias à escolha saem de trabalhos mundanos: Ofícios (Culinária, Carpintaria, Forja...), Lidar com Animais ou Natureza.",
				"+1 em Vigor, permanente — corpo calejado por uma infância inteira de trabalho braçal.",
			},
		},
	},
	{
		id = "background/orfao",
		kind = "background",
		sourceId = "orfao",
		sourceRef = {
			path = "src/data/backgrounds.ts",
			symbol = "BACKGROUNDS",
			selector = "BACKGROUNDS[id=orfao]",
		},
		data = {
			id = "orfao",
			name = "Órfão das Ruas",
			rollRange = {
				16,
				25,
			},
			bonuses = {
				attributes = {
					agilidade = 1,
				},
			},
			bonusSkillChoices = 2,
			startingGold = "1d4",
			traits = {
				"Suas 2 Perícias à escolha saem da sobrevivência urbana: Furtividade, Ladinagem, Enganação ou Acrobacia.",
				"+1 em Agilidade, permanente.",
				"Instinto de Rua: Vantagem em Percepção para notar armadilhas, emboscadas, bolsos alheios e vigias — ninguém sobrevive na rua sem aprender a ler uma esquina.",
			},
		},
	},
	{
		id = "background/crianca-selvagem",
		kind = "background",
		sourceId = "crianca-selvagem",
		sourceRef = {
			path = "src/data/backgrounds.ts",
			symbol = "BACKGROUNDS",
			selector = "BACKGROUNDS[id=crianca-selvagem]",
		},
		data = {
			id = "crianca-selvagem",
			name = "Criança Selvagem",
			rollRange = {
				26,
				35,
			},
			bonuses = {
				maxHp = 6,
				attributes = {
					vigor = 1,
				},
			},
			fixedSkills = {
				"Sobrevivência",
			},
			startingGold = "0",
			traits = {
				"+6 PV Máximos e +1 em Vigor, permanentes.",
				"Criado pelo mato: Vantagem Absoluta (Cap. 1, §4) em Sobrevivência para achar comida, água e abrigo.",
			},
		},
	},
	{
		id = "background/aprendiz-mercador",
		kind = "background",
		sourceId = "aprendiz-mercador",
		sourceRef = {
			path = "src/data/backgrounds.ts",
			symbol = "BACKGROUNDS",
			selector = "BACKGROUNDS[id=aprendiz-mercador]",
		},
		data = {
			id = "aprendiz-mercador",
			name = "Aprendiz de Mercador",
			rollRange = {
				36,
				45,
			},
			bonuses = {
				attributes = {
					intelecto = 1,
				},
			},
			fixedSkills = {
				"Intuição",
				"Lábia",
			},
			startingGold = "4d4+10",
			traits = {
				"+1 em Intelecto, permanente.",
				"Sexto Sentido Comercial: sempre sabe o preço justo de mercado de qualquer item comum, e tem Vantagem Absoluta (Cap. 1, §4) em Intuição pra perceber blefe numa negociação.",
			},
		},
	},
	{
		id = "background/treino-precoce",
		kind = "background",
		sourceId = "treino-precoce",
		sourceRef = {
			path = "src/data/backgrounds.ts",
			symbol = "BACKGROUNDS",
			selector = "BACKGROUNDS[id=treino-precoce]",
		},
		data = {
			id = "treino-precoce",
			name = "Treino Precoce / Escudeiro",
			rollRange = {
				46,
				55,
			},
			bonuses = {
				attributes = {
					forca = 1,
				},
			},
			fixedSkills = {
				"Atletismo",
			},
			startingGold = "2d4+2",
			grantsInitiativeAdvantage = true,
			traits = {
				"Vantagem em todas as rolagens de Iniciativa.",
				"+1 em Força, permanente — anos carregando a armadura de outra pessoa antes de vestir a própria.",
			},
		},
	},
	{
		id = "background/acolito",
		kind = "background",
		sourceId = "acolito",
		sourceRef = {
			path = "src/data/backgrounds.ts",
			symbol = "BACKGROUNDS",
			selector = "BACKGROUNDS[id=acolito]",
		},
		data = {
			id = "acolito",
			name = "Acólito / Filho do Templo",
			rollRange = {
				56,
				65,
			},
			bonuses = {
				attributes = {
					espirito = 1,
				},
				mpPerMagicRank = 1,
			},
			fixedSkills = {
				"Religião",
				"Medicina",
			},
			startingGold = "2d4",
			traits = {
				"+1 em Espírito e +1 PM Máximo por Bônus de Rank de magia, permanentes — a educação religiosa desperta uma afinidade latente com mana que nunca mais desaparece. Sem nenhuma escola de magia aberta, são 0 PM: a afinidade existe, mas não tem onde correr.",
			},
		},
	},
	{
		id = "background/sangue-nobre",
		kind = "background",
		sourceId = "sangue-nobre",
		sourceRef = {
			path = "src/data/backgrounds.ts",
			symbol = "BACKGROUNDS",
			selector = "BACKGROUNDS[id=sangue-nobre]",
		},
		data = {
			id = "sangue-nobre",
			name = "Sangue Nobre",
			rollRange = {
				66,
				72,
			},
			bonuses = {
				attributes = {
					espirito = 1,
				},
			},
			fixedSkills = {
				"Persuasão",
				"História",
			},
			startingGold = "6d4+20",
			traits = {
				"Vantagem Absoluta (Cap. 1, §4) em Persuasão ao lidar com autoridades.",
				"+1 em Espírito, permanente — comandar serviçais desde criança ensina presença antes de ensinar humildade.",
			},
		},
	},
	{
		id = "background/estudioso-precoce",
		kind = "background",
		sourceId = "estudioso-precoce",
		sourceRef = {
			path = "src/data/backgrounds.ts",
			symbol = "BACKGROUNDS",
			selector = "BACKGROUNDS[id=estudioso-precoce]",
		},
		data = {
			id = "estudioso-precoce",
			name = "Estudioso Precoce (Expansão)",
			rollRange = {
				73,
				80,
			},
			bonuses = {
				mpPerMagicRank = 2,
				attributes = {
					intelecto = 1,
				},
			},
			fixedSkills = {
				"Arcanismo",
			},
			startingGold = "2d4",
			traits = {
				"+2 PM Máximos por Bônus de Rank de magia e +1 em Intelecto, permanentes. Sem escola de magia aberta, o PM é 0.",
			},
		},
	},
	{
		id = "background/sobrevivente",
		kind = "background",
		sourceId = "sobrevivente",
		sourceRef = {
			path = "src/data/backgrounds.ts",
			symbol = "BACKGROUNDS",
			selector = "BACKGROUNDS[id=sobrevivente]",
		},
		data = {
			id = "sobrevivente",
			name = "Sobrevivente / Ex-Escravo",
			rollRange = {
				81,
				86,
			},
			bonuses = {
				attributes = {
					vigor = 1,
					espirito = 1,
				},
			},
			startingGold = "0",
			traits = {
				"Vantagem em resistência de Espírito (contra ficar Amedrontado) e de Vigor (contra Exaustão).",
				"+1 em Vigor e +1 em Espírito, permanentes — o corpo que sobreviveu ao pior já não se assusta com o segundo pior, e a vontade que o carregou até aqui não some junto com as cicatrizes.",
			},
		},
	},
	{
		id = "background/miko",
		kind = "background",
		sourceId = "miko",
		sourceRef = {
			path = "src/data/backgrounds.ts",
			symbol = "BACKGROUNDS",
			selector = "BACKGROUNDS[id=miko]",
		},
		data = {
			id = "miko",
			name = "Miko (Abençoada/Amaldiçoada)",
			rollRange = {
				87,
				91,
			},
			bonuses = {
				attributes = {
					espirito = 1,
				},
			},
			startingGold = "2d4",
			requiresSubtable = "miko",
			traits = {
				"+1 em Espírito, permanente — a anomalia de mana que produz a mutação não fica só no poder: ela engrossa a alma que o carrega.",
				"Role 1d8 na Tabela de Miko para definir a mutação mágica.",
			},
		},
	},
	{
		id = "background/fator-laplace",
		kind = "background",
		sourceId = "fator-laplace",
		sourceRef = {
			path = "src/data/backgrounds.ts",
			symbol = "BACKGROUNDS",
			selector = "BACKGROUNDS[id=fator-laplace]",
		},
		data = {
			id = "fator-laplace",
			name = "Fator Laplace / Linhagem Antiga",
			rollRange = {
				92,
				95,
			},
			bonuses = {},
			requiresSubtable = "laplace",
			startingGold = "1d4",
			traits = {
				"Role 1d4 na Tabela do Fator Laplace: a linhagem acordou de um jeito, e não é o mesmo em dois portadores. A mutação sorteada é permanente.",
				"Conjuração Silenciosa desde o nascimento (Cap. 2, seção 2): você manipula mana sem palavra alguma — ninguém te ensinou, você nunca soube fazer diferente. Sofre as penalidades normais do método (metade do dano, área reduzida em um terço); o único antecedente que nasce sem elas, em qualquer escola, é o Gênio.",
				"Vantagem em testes de resistência de Espírito contra Medo, Amedrontado e qualquer efeito que tente controlar sua mente: o que quer que exista na sua linhagem, não se deixa comandar.",
				"Desvantagem em Persuasão com desconhecidos — pessoas comuns sentem, mesmo sem saber o porquê, que algo em você quer distância.",
			},
		},
	},
	{
		id = "background/olho-mistico",
		kind = "background",
		sourceId = "olho-mistico",
		sourceRef = {
			path = "src/data/backgrounds.ts",
			symbol = "BACKGROUNDS",
			selector = "BACKGROUNDS[id=olho-mistico]",
		},
		data = {
			id = "olho-mistico",
			name = "Olho Místico Inato",
			rollRange = {
				96,
				98,
			},
			bonuses = {
				attributes = {
					intelecto = 1,
				},
				mpPerMagicRank = 1,
			},
			startingGold = "2d4",
			requiresSubtable = "olho",
			traits = {
				"+1 em Intelecto e +1 PM Máximo por Bônus de Rank de magia, permanentes — o olho não vem sozinho: o corpo que o carrega já nasce com a mana de sobra que ele consome. Sem escola de magia aberta, o olho roda só com a reserva base.",
				"Role 1d10 na Tabela de Olhos Místicos para definir o Magan.",
			},
		},
	},
	{
		id = "background/genio",
		kind = "background",
		sourceId = "genio",
		sourceRef = {
			path = "src/data/backgrounds.ts",
			symbol = "BACKGROUNDS",
			selector = "BACKGROUNDS[id=genio]",
		},
		data = {
			id = "genio",
			name = "Gênio (Conjuração Silenciosa)",
			rollRange = {
				99,
				100,
			},
			bonuses = {
				attributes = {
					intelecto = 1,
					espirito = 1,
				},
			},
			startingGold = "2d4",
			traits = {
				"Conjuração Silenciosa (Cap. 2, seção 2) sem sofrer a redução de dano nem a redução de área — você é o único que conjura em silêncio com o feitiço inteiro em QUALQUER escola desde a criação. Talentos e Maestrias que tiram essa penalidade valem só pra própria escola. O custo de Ação reduzido e o Bônus de Forma gratuito continuam valendo: você não perde nada e ganha os dois.",
				"Prodígio: a Conjuração Silenciosa gratuita da primeira magia de cada turno vale até o rank AVANÇADO, não só o Principiante (Cap. 2, §2). Todo outro conjurador tem essa cortesia só no Principiante, até uma Maestria de Imperador dizer o contrário.",
				"+1 em Intelecto e +1 em Espírito, permanentes — precisão e reserva ao mesmo tempo, que é o que fez de você um gênio antes de qualquer aula.",
			},
		},
	},
	{
		id = "subtable-entry/miko/forca-sobre-humana",
		kind = "subtable-entry",
		sourceId = "forca-sobre-humana",
		sourceRef = {
			path = "src/data/backgrounds.ts",
			symbol = "SUBTABLES",
			selector = "SUBTABLES.miko.entries[id=forca-sobre-humana]",
		},
		data = {
			id = "forca-sobre-humana",
			roll = 1,
			name = "Força Sobre-humana (Zanoba)",
			bonuses = {
				attributes = {
					forca = 2,
				},
			},
			traits = {
				"Abençoada: +2 em Força, permanente, e ataques desarmados causam 1d8 + Força (letal).",
				"Maldição: Desvantagem em testes de Vigor (sem resistência física).",
			},
			subtableId = "miko",
		},
	},
	{
		id = "subtable-entry/miko/leitura-memorias",
		kind = "subtable-entry",
		sourceId = "leitura-memorias",
		sourceRef = {
			path = "src/data/backgrounds.ts",
			symbol = "SUBTABLES",
			selector = "SUBTABLES.miko.entries[id=leitura-memorias]",
		},
		data = {
			id = "leitura-memorias",
			roll = 2,
			name = "Leitura de Memórias",
			bonuses = {},
			traits = {
				"Abençoada: 1 Ação de toque lê memórias superficiais e intenções (Vantagem em Intuição e Intimidação contra quem você tocou, até o fim da cena).",
				"Maldição: custa 3 PM por uso.",
			},
			subtableId = "miko",
		},
	},
	{
		id = "subtable-entry/miko/rebobinar-tempo",
		kind = "subtable-entry",
		sourceId = "rebobinar-tempo",
		sourceRef = {
			path = "src/data/backgrounds.ts",
			symbol = "SUBTABLES",
			selector = "SUBTABLES.miko.entries[id=rebobinar-tempo]",
		},
		data = {
			id = "rebobinar-tempo",
			roll = 3,
			name = "Rebobinar o Tempo",
			bonuses = {},
			traits = {
				"Abençoada: 1x/semana rebobina o estado de um objeto inanimado em até 24h.",
				"Maldição: gasta metade dos seus PM Máximos (arredondado pra cima), que precisam estar disponíveis na hora; não funciona em criaturas vivas.",
			},
			subtableId = "miko",
		},
	},
	{
		id = "subtable-entry/miko/telepatia",
		kind = "subtable-entry",
		sourceId = "telepatia",
		sourceRef = {
			path = "src/data/backgrounds.ts",
			symbol = "SUBTABLES",
			selector = "SUBTABLES.miko.entries[id=telepatia]",
		},
		data = {
			id = "telepatia",
			roll = 4,
			name = "Telepatia",
			bonuses = {},
			traits = {
				"Abençoada: lê pensamentos superficiais e fala telepaticamente num raio de 18m.",
				"Maldição: fisicamente muda; Desvantagem em Iniciativa. Muda não é impedida de conjurar: toda magia sua sai obrigatoriamente em Conjuração Silenciosa (Cap. 2, §2), pagando a penalidade dela — metade do dano e um terço menos de área. Você nunca ganha o Bônus de Recitação Perfeita, porque não há voz pra recitar. É o preço, e é caro.",
			},
			subtableId = "miko",
		},
	},
	{
		id = "subtable-entry/miko/confianca-absoluta",
		kind = "subtable-entry",
		sourceId = "confianca-absoluta",
		sourceRef = {
			path = "src/data/backgrounds.ts",
			symbol = "SUBTABLES",
			selector = "SUBTABLES.miko.entries[id=confianca-absoluta]",
		},
		data = {
			id = "confianca-absoluta",
			roll = 5,
			name = "Miko da Confiança Absoluta",
			bonuses = {},
			traits = {
				"Abençoada: Vantagem Absoluta em Persuasão e Lábia.",
				"Maldição: falha automaticamente em Intuição para perceber mentiras.",
			},
			subtableId = "miko",
		},
	},
	{
		id = "subtable-entry/miko/esquecimento",
		kind = "subtable-entry",
		sourceId = "esquecimento",
		sourceRef = {
			path = "src/data/backgrounds.ts",
			symbol = "SUBTABLES",
			selector = "SUBTABLES.miko.entries[id=esquecimento]",
		},
		data = {
			id = "esquecimento",
			roll = 6,
			name = "Maldição do Esquecimento",
			bonuses = {},
			traits = {
				"Abençoada: Vantagem Absoluta em Furtividade (presença nula).",
				"Maldição: 10 minutos depois de você sair do campo de visão de alguém, essa pessoa esquece seu rosto, seu nome e que você existiu. Só lembra quem já passou um Descanso Longo com você.",
			},
			subtableId = "miko",
		},
	},
	{
		id = "subtable-entry/miko/acumulo",
		kind = "subtable-entry",
		sourceId = "acumulo",
		sourceRef = {
			path = "src/data/backgrounds.ts",
			symbol = "SUBTABLES",
			selector = "SUBTABLES.miko.entries[id=acumulo]",
		},
		data = {
			id = "acumulo",
			roll = 7,
			name = "Maldição do Acúmulo",
			bonuses = {
				mpPerMagicRank = 3,
			},
			traits = {
				"Abençoada: +3 PM Máximos por Bônus de Rank de magia (reator infinito). No Imperador são +18; sem escola de magia aberta, 0.",
				"Enquanto você não tiver nenhuma escola de magia aberta, a maldição da liberação fica suspensa: a bênção e o preço chegam juntos, e não a maldição primeiro.",
				"Maldição: a mana precisa sair. Liberação é gastar 10 PM ou mais numa única cena. Se passar uma semana sem liberação, você ganha 1 nível de Exaustão por dia, até a morte, e toda essa Exaustão some na primeira liberação.",
			},
			subtableId = "miko",
		},
	},
	{
		id = "subtable-entry/miko/odio",
		kind = "subtable-entry",
		sourceId = "odio",
		sourceRef = {
			path = "src/data/backgrounds.ts",
			symbol = "SUBTABLES",
			selector = "SUBTABLES.miko.entries[id=odio]",
		},
		data = {
			id = "odio",
			roll = 8,
			name = "Maldição do Ódio",
			bonuses = {
				maxHp = 10,
				armorClass = 2,
			},
			traits = {
				"Abençoada: +2 na CA e +10 PV Máximos (aura primordial).",
				"Maldição: quem enxerga mana (todo Superd, todo mago Avançado ou superior) sente ódio instintivo ao te ver: começa hostil a você e, em combate, te escolhe como alvo prioritário.",
			},
			subtableId = "miko",
		},
	},
	{
		id = "subtable/miko",
		kind = "subtable",
		sourceId = "miko",
		sourceRef = {
			path = "src/data/backgrounds.ts",
			symbol = "SUBTABLES",
			selector = "SUBTABLES.miko",
		},
		data = {
			name = "Miko e Amaldiçoados",
			die = "1d8",
			entries = {
				"subtable-entry/miko/forca-sobre-humana",
				"subtable-entry/miko/leitura-memorias",
				"subtable-entry/miko/rebobinar-tempo",
				"subtable-entry/miko/telepatia",
				"subtable-entry/miko/confianca-absoluta",
				"subtable-entry/miko/esquecimento",
				"subtable-entry/miko/acumulo",
				"subtable-entry/miko/odio",
			},
		},
	},
	{
		id = "subtable-entry/olho/previsao",
		kind = "subtable-entry",
		sourceId = "previsao",
		sourceRef = {
			path = "src/data/backgrounds.ts",
			symbol = "SUBTABLES",
			selector = "SUBTABLES.olho.entries[id=previsao]",
		},
		data = {
			id = "previsao",
			roll = 1,
			name = "Olho da Previsão",
			bonuses = {},
			traits = {
				"1 Ação pra ativar, 3 PM/turno: vê 2s no futuro (Vantagem em ataques, oponentes têm Desvantagem contra você). Mais de 3 turnos seguidos deixa você Desequilibrado por 1 hora.",
			},
			subtableId = "olho",
		},
	},
	{
		id = "subtable-entry/olho/poder-magico",
		kind = "subtable-entry",
		sourceId = "poder-magico",
		sourceRef = {
			path = "src/data/backgrounds.ts",
			symbol = "SUBTABLES",
			selector = "SUBTABLES.olho.entries[id=poder-magico]",
		},
		data = {
			id = "poder-magico",
			roll = 2,
			name = "Olho do Poder Mágico",
			bonuses = {},
			traits = {
				"1 Ação, 2 PM/cena: vê fluxo de mana, invisíveis mágicos, identifica itens mágicos e nível de perigo.",
			},
			subtableId = "olho",
		},
	},
	{
		id = "subtable-entry/olho/clarividencia",
		kind = "subtable-entry",
		sourceId = "clarividencia",
		sourceRef = {
			path = "src/data/backgrounds.ts",
			symbol = "SUBTABLES",
			selector = "SUBTABLES.olho.entries[id=clarividencia]",
		},
		data = {
			id = "clarividencia",
			roll = 3,
			name = "Olho da Clarividência",
			bonuses = {},
			traits = {
				"1 Ação, 1 PM/km: visão telescópica tipo drone. Corpo físico fica Cego e indefeso (CA 10) enquanto em uso.",
			},
			subtableId = "olho",
		},
	},
	{
		id = "subtable-entry/olho/permeacao",
		kind = "subtable-entry",
		sourceId = "permeacao",
		sourceRef = {
			path = "src/data/backgrounds.ts",
			symbol = "SUBTABLES",
			selector = "SUBTABLES.olho.entries[id=permeacao]",
		},
		data = {
			id = "permeacao",
			roll = 4,
			name = "Olho de Permeação",
			bonuses = {},
			traits = {
				"1 Ação, 2 PM/cena: Raio-X através de paredes/roupas (9m). Não atravessa criaturas vivas ou materiais densos em mana.",
			},
			subtableId = "olho",
		},
	},
	{
		id = "subtable-entry/olho/identificacao",
		kind = "subtable-entry",
		sourceId = "identificacao",
		sourceRef = {
			path = "src/data/backgrounds.ts",
			symbol = "SUBTABLES",
			selector = "SUBTABLES.olho.entries[id=identificacao]",
		},
		data = {
			id = "identificacao",
			roll = 5,
			name = "Olho de Identificação",
			bonuses = {},
			traits = {
				"1 Ação, 1 PM/alvo: revela fraquezas, nome do feitiço e efeitos. Segredos divinos/de outros continentes aparecem como 'Desconhecido'.",
			},
			subtableId = "olho",
		},
	},
	{
		id = "subtable-entry/olho/absorcao",
		kind = "subtable-entry",
		sourceId = "absorcao",
		sourceRef = {
			path = "src/data/backgrounds.ts",
			symbol = "SUBTABLES",
			selector = "SUBTABLES.olho.entries[id=absorcao]",
		},
		data = {
			id = "absorcao",
			roll = 6,
			name = "Olho da Absorção",
			bonuses = {},
			traits = {
				"Reação, PM igual ao da magia absorvida: anula magia inimiga. Cobrir ou descobrir o olho custa 1 Ação. Lançar magia com o olho descoberto suga o próprio feitiço (perde as Ações, o PM e a magia falha).",
			},
			subtableId = "olho",
		},
	},
	{
		id = "subtable-entry/olho/tudo-veem",
		kind = "subtable-entry",
		sourceId = "tudo-veem",
		sourceRef = {
			path = "src/data/backgrounds.ts",
			symbol = "SUBTABLES",
			selector = "SUBTABLES.olho.entries[id=tudo-veem]",
		},
		data = {
			id = "tudo-veem",
			roll = 7,
			name = "Olhos Que Tudo Veem",
			bonuses = {},
			traits = {
				"Ritual de 10min, 10 PM, 1x/semana: rastreia alguém no globo ou revela planta de masmorra. A vista custa a voltar: você fica Desequilibrado pelo resto do dia.",
			},
			subtableId = "olho",
		},
	},
	{
		id = "subtable-entry/olho/vazio-absoluto",
		kind = "subtable-entry",
		sourceId = "vazio-absoluto",
		sourceRef = {
			path = "src/data/backgrounds.ts",
			symbol = "SUBTABLES",
			selector = "SUBTABLES.olho.entries[id=vazio-absoluto]",
		},
		data = {
			id = "vazio-absoluto",
			roll = 8,
			name = "Olho do Vazio Absoluto",
			bonuses = {},
			traits = {
				"1 Ação, 5 PM/turno mantido: esfera de repulsão de 9m de raio centrada em você. Criaturas e projéteis não entram na esfera; quem já estava dentro é empurrado para a borda, menos quem você escolher ao ativar. Não pode atacar ou se mover enquanto mantiver.",
			},
			subtableId = "olho",
		},
	},
	{
		id = "subtable-entry/olho/afeicao",
		kind = "subtable-entry",
		sourceId = "afeicao",
		sourceRef = {
			path = "src/data/backgrounds.ts",
			symbol = "SUBTABLES",
			selector = "SUBTABLES.olho.entries[id=afeicao]",
		},
		data = {
			id = "afeicao",
			roll = 9,
			name = "Olho de Afeição",
			bonuses = {},
			traits = {
				"1 Ação e 1 PM: uma criatura que te veja faz teste de resistência de Espírito contra CD 8 + seu Espírito + seu Maior Bônus de Rank; se falhar, por 1 hora não te ataca e te ajuda quando puder. O efeito acaba se você ou um aliado seu causar dano a ela. Maldição: enquanto o olho estiver descoberto, todo PdM que cruzar seu olhar faz o mesmo teste sem custo nenhum, e quem falha, em vez disso, fica obcecado por você (o Mestre conduz a obsessão). Cobrir ou descobrir o olho custa 1 Ação.",
			},
			subtableId = "olho",
		},
	},
	{
		id = "subtable-entry/olho/rastreador",
		kind = "subtable-entry",
		sourceId = "rastreador",
		sourceRef = {
			path = "src/data/backgrounds.ts",
			symbol = "SUBTABLES",
			selector = "SUBTABLES.olho.entries[id=rastreador]",
		},
		data = {
			id = "rastreador",
			roll = 10,
			name = "Olho Rastreador",
			bonuses = {},
			traits = {
				"1 Ação, 2 PM (recente) / 10 PM (décadas): revela rastros de vida, segue pegadas por continentes. Rastreio antigo tem cooldown de 1x/mês.",
			},
			subtableId = "olho",
		},
	},
	{
		id = "subtable/olho",
		kind = "subtable",
		sourceId = "olho",
		sourceRef = {
			path = "src/data/backgrounds.ts",
			symbol = "SUBTABLES",
			selector = "SUBTABLES.olho",
		},
		data = {
			name = "Olhos Demoníacos / Místicos",
			die = "1d10",
			entries = {
				"subtable-entry/olho/previsao",
				"subtable-entry/olho/poder-magico",
				"subtable-entry/olho/clarividencia",
				"subtable-entry/olho/permeacao",
				"subtable-entry/olho/identificacao",
				"subtable-entry/olho/absorcao",
				"subtable-entry/olho/tudo-veem",
				"subtable-entry/olho/vazio-absoluto",
				"subtable-entry/olho/afeicao",
				"subtable-entry/olho/rastreador",
			},
		},
	},
	{
		id = "subtable-entry/laplace/veias-abertas",
		kind = "subtable-entry",
		sourceId = "veias-abertas",
		sourceRef = {
			path = "src/data/backgrounds.ts",
			symbol = "SUBTABLES",
			selector = "SUBTABLES.laplace.entries[id=veias-abertas]",
		},
		data = {
			id = "veias-abertas",
			roll = 1,
			name = "Veias Abertas",
			bonuses = {
				attributes = {
					espirito = 1,
				},
			},
			traits = {
				"+1 em Espírito, permanente.",
				"A mana corre solta em você e não fica parada: ao terminar um Descanso Curto, recupere PM adicionais iguais ao seu Maior Bônus de Rank de magia, além do que o descanso já devolve.",
				"O corpo não fecha a torneira: você não consegue esconder que é um conjurador de quem enxerga mana (todo Superd, todo mago Avançado ou superior).",
			},
			subtableId = "laplace",
		},
	},
	{
		id = "subtable-entry/laplace/carne-que-lembra",
		kind = "subtable-entry",
		sourceId = "carne-que-lembra",
		sourceRef = {
			path = "src/data/backgrounds.ts",
			symbol = "SUBTABLES",
			selector = "SUBTABLES.laplace.entries[id=carne-que-lembra]",
		},
		data = {
			id = "carne-que-lembra",
			roll = 2,
			name = "Carne que Lembra",
			bonuses = {
				attributes = {
					vigor = 1,
				},
			},
			traits = {
				"+1 em Vigor, permanente.",
				"Uma vez por combate, ao chegar a 0 PV, você fica Estabilizado na hora, sem rolar o Fio da Vida (Cap. 4, §7) — a carne fecha antes de você decidir. Continua Inconsciente, e sofrer dano a 0 PV ainda dá Marca da Morte e tira o Estabilizado, como pra qualquer um.",
				"Toda cicatriz sua reabre quando a linhagem é mencionada em voz alta perto de você. Não causa dano; causa perguntas.",
			},
			subtableId = "laplace",
		},
	},
	{
		id = "subtable-entry/laplace/memoria-da-linhagem",
		kind = "subtable-entry",
		sourceId = "memoria-da-linhagem",
		sourceRef = {
			path = "src/data/backgrounds.ts",
			symbol = "SUBTABLES",
			selector = "SUBTABLES.laplace.entries[id=memoria-da-linhagem]",
		},
		data = {
			id = "memoria-da-linhagem",
			roll = 3,
			name = "Memória da Linhagem",
			bonuses = {
				attributes = {
					intelecto = 1,
				},
			},
			traits = {
				"+1 em Intelecto, permanente.",
				"Vantagem Absoluta (Cap. 1, §4) em Arcanismo e História sobre qualquer coisa anterior ao seu nascimento — você não deduz, você LEMBRA, e as lembranças não são suas.",
				"Nada disso vale pro presente: sobre o que aconteceu depois de você nascer, seus testes são normais como os de qualquer um.",
			},
			subtableId = "laplace",
		},
	},
	{
		id = "subtable-entry/laplace/presenca-errada",
		kind = "subtable-entry",
		sourceId = "presenca-errada",
		sourceRef = {
			path = "src/data/backgrounds.ts",
			symbol = "SUBTABLES",
			selector = "SUBTABLES.laplace.entries[id=presenca-errada]",
		},
		data = {
			id = "presenca-errada",
			roll = 4,
			name = "Presença Errada",
			bonuses = {
				attributes = {
					agilidade = 1,
				},
			},
			traits = {
				"+1 em Agilidade, permanente.",
				"Bestas, insetos gigantes e mortos-vivos sem mente não atacam você por iniciativa própria — algo neles reconhece o que você carrega e recua. Perdem o medo se você atacar primeiro, ou se alguém com mente os obrigar.",
				"Animais domésticos fogem de você. Cavalo não te aceita; cão late até você sair de vista.",
			},
			subtableId = "laplace",
		},
	},
	{
		id = "subtable/laplace",
		kind = "subtable",
		sourceId = "laplace",
		sourceRef = {
			path = "src/data/backgrounds.ts",
			symbol = "SUBTABLES",
			selector = "SUBTABLES.laplace",
		},
		data = {
			name = "Fator Laplace",
			die = "1d4",
			entries = {
				"subtable-entry/laplace/veias-abertas",
				"subtable-entry/laplace/carne-que-lembra",
				"subtable-entry/laplace/memoria-da-linhagem",
				"subtable-entry/laplace/presenca-errada",
			},
		},
	},
})
