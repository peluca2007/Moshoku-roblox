-- GERADO por tools/gerar-catalogo.mts a partir do site do livro. Não edite: rode o gerador.
-- Domínio MagiasCombinadas.
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
		id = "combined-spell/barreira-incandescente",
		kind = "combined-spell",
		sourceId = "barreira-incandescente",
		sourceRef = {
			path = "src/data/combinedSpells.ts",
			symbol = "COMBINED_SPELLS",
			selector = "COMBINED_SPELLS[id=barreira-incandescente]",
		},
		data = {
			id = "barreira-incandescente",
			name = "Barreira Incandescente",
			requires = {
				{
					treeId = "teorica",
					rank = "Avançado",
				},
				{
					treeId = "fogo",
					rank = "Intermediário",
				},
			},
			paCost = 3,
			pmCost = 11,
			range = "Pessoal",
			actions = 2,
			damage = "—",
			effect = "Muro de 9m que combina escudo mágico com fogo. Aliados atrás ganham Cobertura Total, e o muro causa 2d10 ígneo a quem atravessar. Dura 1 minuto ou 60 PV.",
		},
	},
	{
		id = "combined-spell/muralha-de-espinhos",
		kind = "combined-spell",
		sourceId = "muralha-de-espinhos",
		sourceRef = {
			path = "src/data/combinedSpells.ts",
			symbol = "COMBINED_SPELLS",
			selector = "COMBINED_SPELLS[id=muralha-de-espinhos]",
		},
		data = {
			id = "muralha-de-espinhos",
			name = "Muralha de Espinhos",
			requires = {
				{
					treeId = "terra",
					rank = "Avançado",
				},
				{
					treeId = "fogo",
					rank = "Intermediário",
				},
			},
			paCost = 3,
			pmCost = 6,
			range = "Linha de 18 metros",
			actions = 2,
			damage = "6d6 perfurante + Em Chamas",
			effect = "Muro de videiras espinhosas que crescem e queimam. Dura 1 minuto. Quem atravessar sofre 6d6 perfurante e fica Em Chamas, e o muro e o chão até 3m de cada lado dele são terreno difícil.",
		},
	},
	{
		id = "combined-spell/fera-da-ventania",
		kind = "combined-spell",
		sourceId = "fera-da-ventania",
		sourceRef = {
			path = "src/data/combinedSpells.ts",
			symbol = "COMBINED_SPELLS",
			selector = "COMBINED_SPELLS[id=fera-da-ventania]",
		},
		data = {
			id = "fera-da-ventania",
			name = "Fera da Ventania",
			requires = {
				{
					treeId = "invocacao",
					rank = "Avançado",
				},
				{
					treeId = "vento",
					rank = "Intermediário",
				},
			},
			paCost = 3,
			pmCost = 5,
			range = "18 metros",
			actions = 2,
			damage = "+2d6 cortante por acerto do invocado",
			effect = "Você sopra uma ventania dentro de um invocado seu (numa Alcateia ou Legião, só uma das criaturas). Por 1 minuto, ele ganha +3m de Deslocamento, e cada ataque dele que acertar causa +2d6 cortante e deixa o alvo Desequilibrado. Se ele cair a 0 PV antes disso, o vento se solta num estouro: toda criatura a até 3m faz teste de Força (CD 8 + BC) ou é empurrada 3m.",
		},
	},
	{
		id = "combined-spell/chuva-purificadora",
		kind = "combined-spell",
		sourceId = "chuva-purificadora",
		sourceRef = {
			path = "src/data/combinedSpells.ts",
			symbol = "COMBINED_SPELLS",
			selector = "COMBINED_SPELLS[id=chuva-purificadora]",
		},
		data = {
			id = "chuva-purificadora",
			name = "Chuva Purificadora",
			requires = {
				{
					treeId = "desintoxicacao",
					rank = "Avançado",
				},
				{
					treeId = "agua",
					rank = "Intermediário",
				},
			},
			paCost = 3,
			pmCost = 5,
			range = "Esfera de 9m, centrada a até 18 metros",
			actions = 2,
			damage = "—",
			effect = "Chuva fina de água limpa. Aliados na área deixam de estar Envenenados, e venenos e doenças de rank Intermediário ou inferior neles são purgados. Toda criatura na área, aliada ou não, fica Molhada, sem teste — o preço da limpeza e o começo do combo de gelo.",
		},
	},
	{
		id = "combined-spell/magma",
		kind = "combined-spell",
		sourceId = "magma",
		sourceRef = {
			path = "src/data/combinedSpells.ts",
			symbol = "COMBINED_SPELLS",
			selector = "COMBINED_SPELLS[id=magma]",
		},
		data = {
			id = "magma",
			name = "Magma",
			requires = {
				{
					treeId = "fogo",
					rank = "Avançado",
				},
				{
					treeId = "terra",
					rank = "Avançado",
				},
			},
			paCost = 4,
			pmCost = 12,
			range = "18 metros",
			actions = 3,
			damage = "4d10 ígneo + 4d10 contundente",
			effect = "Muro de rocha derretida. Teste de Agilidade (CD 8 + BC) ou sofre o dano cheio e a área fica Em Chamas por 1 minuto. Estruturas de madeira queimam.",
		},
	},
	{
		id = "combined-spell/gelo-tempestuoso",
		kind = "combined-spell",
		sourceId = "gelo-tempestuoso",
		sourceRef = {
			path = "src/data/combinedSpells.ts",
			symbol = "COMBINED_SPELLS",
			selector = "COMBINED_SPELLS[id=gelo-tempestuoso]",
		},
		data = {
			id = "gelo-tempestuoso",
			name = "Gelo Tempestuoso",
			requires = {
				{
					treeId = "agua",
					rank = "Avançado",
				},
				{
					treeId = "vento",
					rank = "Avançado",
				},
			},
			paCost = 4,
			pmCost = 13,
			range = "Cone de 18 metros",
			actions = 3,
			damage = "3d8 perfurante + 3d8 frio + 3d8 sônico",
			effect = "Rajada de cristais carregados por vento cortante. Teste de Agilidade (CD 8 + BC) pra metade. Alvos no cone ficam Molhados e Desequilibrados por 1 turno — as duas condições que as escolas-mãe cobram.",
		},
	},
	{
		id = "combined-spell/panico",
		kind = "combined-spell",
		sourceId = "panico",
		sourceRef = {
			path = "src/data/combinedSpells.ts",
			symbol = "COMBINED_SPELLS",
			selector = "COMBINED_SPELLS[id=panico]",
		},
		data = {
			id = "panico",
			name = "Pânico",
			requires = {
				{
					treeId = "fogo",
					rank = "Santo",
				},
				{
					treeId = "vento",
					rank = "Avançado",
				},
			},
			paCost = 5,
			pmCost = 13,
			range = "Cone de 27 metros",
			actions = 3,
			damage = "—",
			effect = "Onda de calor e vento que espalha pânico. Teste de Espírito (CD 8 + BC) ou Amedrontado por 1 minuto. Falha crítica: corre em linha reta pra longe de você, pelo caminho mais longo, por 3 turnos.",
		},
	},
	{
		id = "combined-spell/relampago-santo",
		kind = "combined-spell",
		sourceId = "relampago-santo",
		sourceRef = {
			path = "src/data/combinedSpells.ts",
			symbol = "COMBINED_SPELLS",
			selector = "COMBINED_SPELLS[id=relampago-santo]",
		},
		data = {
			id = "relampago-santo",
			name = "Relâmpago Santo",
			requires = {
				{
					treeId = "agua",
					rank = "Santo",
				},
				{
					treeId = "cura",
					rank = "Avançado",
				},
			},
			paCost = 5,
			pmCost = 14,
			range = "Linha de 36 metros",
			actions = 4,
			damage = "6d10 elétrico",
			effect = "Um único relâmpago que mescla eletricidade e mana curativa. Inimigos na linha fazem teste de Agilidade (CD 8 + BC) ou sofrem o dano cheio. Escolha um inimigo atingido: um aliado na linha cura metade do dano causado a ele.",
		},
	},
	{
		id = "combined-spell/tempestade-de-cura",
		kind = "combined-spell",
		sourceId = "tempestade-de-cura",
		sourceRef = {
			path = "src/data/combinedSpells.ts",
			symbol = "COMBINED_SPELLS",
			selector = "COMBINED_SPELLS[id=tempestade-de-cura]",
		},
		data = {
			id = "tempestade-de-cura",
			name = "Tempestade de Cura",
			requires = {
				{
					treeId = "cura",
					rank = "Santo",
				},
				{
					treeId = "agua",
					rank = "Avançado",
				},
			},
			paCost = 5,
			pmCost = 14,
			range = "Esfera de 18m",
			actions = 3,
			damage = "—",
			effect = "Chuva morna com mana curativa. Aliados na área curam 1d8 + BC de PV e ficam Molhados — e regeneram 1d4 PV no fim de cada turno por 3 turnos.",
		},
	},
	{
		id = "combined-spell/nevasca-curativa",
		kind = "combined-spell",
		sourceId = "nevasca-curativa",
		sourceRef = {
			path = "src/data/combinedSpells.ts",
			symbol = "COMBINED_SPELLS",
			selector = "COMBINED_SPELLS[id=nevasca-curativa]",
		},
		data = {
			id = "nevasca-curativa",
			name = "Nevasca Curativa",
			requires = {
				{
					treeId = "agua",
					rank = "Rei",
				},
				{
					treeId = "cura",
					rank = "Santo",
				},
			},
			paCost = 7,
			pmCost = 14,
			range = "Esfera de 30m",
			actions = 3,
			damage = "—",
			effect = "Tempestade de neve com mana restauradora. Aliados na área curam 1d8 + BC por turno durante 3 turnos e ficam imunes a frio não-mágico. Inimigos fazem teste de Vigor (CD 8 + BC) ou têm o Deslocamento reduzido à metade enquanto durar.",
		},
	},
	{
		id = "combined-spell/meteoro",
		kind = "combined-spell",
		sourceId = "meteoro",
		sourceRef = {
			path = "src/data/combinedSpells.ts",
			symbol = "COMBINED_SPELLS",
			selector = "COMBINED_SPELLS[id=meteoro]",
		},
		data = {
			id = "meteoro",
			name = "Meteoro",
			requires = {
				{
					treeId = "fogo",
					rank = "Rei",
				},
				{
					treeId = "terra",
					rank = "Avançado",
				},
			},
			paCost = 8,
			pmCost = 25,
			range = "120 metros",
			actions = 6,
			damage = "14d10 ígneo + 7d10 contundente",
			costNote = "GRANDE OBRA — 6 Ações e Ritual (Cap. 2, §3), a única entre as Combinadas. Um meteoro não é uma magia que se lança: é uma coisa que alguém vê chegando. Vale aqui tudo que vale nas outras cinco Grandes Obras, inclusive o Ponto de Não Retorno — a partir da segunda Ação o céu muda de cor sobre a área inteira, e todo mundo tem um turno pra decidir se sai de baixo. Interrompido, perde os 25 PM inteiros.",
			effect = "Você chama uma rocha flamejante do céu. Teste de Agilidade (CD 8 + BC) pra metade, em área de 9m. O epicentro vira cratera: terreno difícil permanente. Não pode ser Encurtado nem Silenciado.",
		},
	},
})
