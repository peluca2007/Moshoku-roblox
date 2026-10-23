-- GERADO por tools/gerar-catalogo.mts a partir do site do livro. Não edite: rode o gerador.
-- Constantes de regra lidas do site (bônus de rank, Ações de magia, Ações por turno, moldes e arquétipos do Apêndice G) e vetores das funções do site para os testes diferenciais.
local function congelar(t)
	for _, v in t do
		if type(v) == "table" and not table.isfrozen(v) then
			congelar(v)
		end
	end
	return table.freeze(t)
end
return congelar({
	bonusDeRank = {
		Principiante = 1,
		["Intermediário"] = 2,
		["Avançado"] = 3,
		Santo = 4,
		Rei = 5,
		Imperador = 6,
		Deus = 7,
	},
	ordemDosRanks = {
		"Principiante",
		"Intermediário",
		"Avançado",
		"Santo",
		"Rei",
		"Imperador",
		"Deus",
	},
	requisitosDeRank = {
		Principiante = {
			knowledgeRequired = 0,
			paCost = 0,
		},
		["Intermediário"] = {
			knowledgeRequired = 3,
			paCost = 1,
		},
		["Avançado"] = {
			knowledgeRequired = 6,
			paCost = 2,
		},
		Santo = {
			knowledgeRequired = 9,
			paCost = 2,
		},
		Rei = {
			knowledgeRequired = 12,
			paCost = 3,
		},
		Imperador = {
			knowledgeRequired = 15,
			paCost = 3,
		},
		Deus = {
			knowledgeRequired = 18,
			paCost = 4,
		},
	},
	acoesDeMagia = {
		Principiante = {
			normal = 2,
			encurtada = 1,
			silenciosa = 1,
		},
		["Intermediário"] = {
			normal = 2,
			encurtada = 1,
			silenciosa = 1,
		},
		["Avançado"] = {
			normal = 3,
			encurtada = 2,
			silenciosa = 1,
		},
		Santo = {
			normal = 3,
			encurtada = 2,
			silenciosa = 2,
		},
		Rei = {
			normal = 4,
			encurtada = 3,
			silenciosa = 3,
		},
		Imperador = {
			normal = 4,
			silenciosa = 3,
		},
		Deus = {
			normal = 4,
			silenciosa = 3,
		},
	},
	acoesPorTurno = 3,
	escadaDeDados = {
		"d4",
		"d6",
		"d8",
		"d10",
		"d12",
		"2d8",
		"2d10",
		"2d12",
		"3d10",
		"3d12",
		"4d10",
		"4d12",
		"5d10",
		"5d12",
	},
	excessoPorDegrau = 2,
	moldesDeCriatura = {
		{
			patamar = 1,
			titulo = "Comum",
			pv = 64,
			ca = 12,
			bonusAtaque = 3,
			danoPorTurno = 16,
			cdResistencia = 11,
		},
		{
			patamar = 2,
			titulo = "Perigosa",
			pv = 68,
			ca = 14,
			bonusAtaque = 4,
			danoPorTurno = 21,
			cdResistencia = 13,
		},
		{
			patamar = 3,
			titulo = "Ameaça",
			pv = 121,
			ca = 16,
			bonusAtaque = 6,
			danoPorTurno = 29,
			cdResistencia = 15,
		},
		{
			patamar = 4,
			titulo = "Elite",
			pv = 152,
			ca = 18,
			bonusAtaque = 8,
			danoPorTurno = 38,
			cdResistencia = 17,
		},
		{
			patamar = 5,
			titulo = "Terror",
			pv = 210,
			ca = 20,
			bonusAtaque = 10,
			danoPorTurno = 48,
			cdResistencia = 19,
		},
		{
			patamar = 6,
			titulo = "Lenda",
			pv = 332,
			ca = 22,
			bonusAtaque = 12,
			danoPorTurno = 50,
			cdResistencia = 21,
		},
	},
	arquetiposDeCriatura = {
		{
			id = "bruto",
			principal = "Força",
			bom = "Vigor",
			comum = {
				"Agilidade",
			},
			fraco = {
				"Intelecto",
				"Espírito",
			},
			deslocamento = 6,
		},
		{
			id = "agil",
			principal = "Agilidade",
			bom = "Vigor",
			comum = {
				"Força",
			},
			fraco = {
				"Intelecto",
				"Espírito",
			},
			deslocamento = 12,
		},
		{
			id = "fortaleza",
			principal = "Vigor",
			bom = "Força",
			comum = {
				"Espírito",
			},
			fraco = {
				"Agilidade",
				"Intelecto",
			},
			deslocamento = 6,
		},
		{
			id = "conjurador",
			principal = "Intelecto",
			bom = "Espírito",
			comum = {
				"Agilidade",
				"Vigor",
			},
			fraco = {
				"Força",
			},
			deslocamento = 9,
		},
		{
			id = "mente",
			principal = "Espírito",
			bom = "Intelecto",
			comum = {
				"Agilidade",
				"Vigor",
			},
			fraco = {
				"Força",
			},
			deslocamento = 9,
		},
	},
	vetores = {
		aplicarPapel = {
			{
				patamar = 1,
				papel = "lacaio",
				saida = {
					pv = 32,
					danoPorTurno = 8,
				},
			},
			{
				patamar = 1,
				papel = "padrao",
				saida = {
					pv = 64,
					danoPorTurno = 16,
				},
			},
			{
				patamar = 1,
				papel = "chefe",
				saida = {
					pv = 160,
					danoPorTurno = 24,
				},
			},
			{
				patamar = 2,
				papel = "lacaio",
				saida = {
					pv = 34,
					danoPorTurno = 11,
				},
			},
			{
				patamar = 2,
				papel = "padrao",
				saida = {
					pv = 68,
					danoPorTurno = 21,
				},
			},
			{
				patamar = 2,
				papel = "chefe",
				saida = {
					pv = 170,
					danoPorTurno = 32,
				},
			},
			{
				patamar = 3,
				papel = "lacaio",
				saida = {
					pv = 61,
					danoPorTurno = 15,
				},
			},
			{
				patamar = 3,
				papel = "padrao",
				saida = {
					pv = 121,
					danoPorTurno = 29,
				},
			},
			{
				patamar = 3,
				papel = "chefe",
				saida = {
					pv = 303,
					danoPorTurno = 44,
				},
			},
			{
				patamar = 4,
				papel = "lacaio",
				saida = {
					pv = 76,
					danoPorTurno = 19,
				},
			},
			{
				patamar = 4,
				papel = "padrao",
				saida = {
					pv = 152,
					danoPorTurno = 38,
				},
			},
			{
				patamar = 4,
				papel = "chefe",
				saida = {
					pv = 380,
					danoPorTurno = 57,
				},
			},
			{
				patamar = 5,
				papel = "lacaio",
				saida = {
					pv = 105,
					danoPorTurno = 24,
				},
			},
			{
				patamar = 5,
				papel = "padrao",
				saida = {
					pv = 210,
					danoPorTurno = 48,
				},
			},
			{
				patamar = 5,
				papel = "chefe",
				saida = {
					pv = 525,
					danoPorTurno = 72,
				},
			},
			{
				patamar = 6,
				papel = "lacaio",
				saida = {
					pv = 166,
					danoPorTurno = 25,
				},
			},
			{
				patamar = 6,
				papel = "padrao",
				saida = {
					pv = 332,
					danoPorTurno = 50,
				},
			},
			{
				patamar = 6,
				papel = "chefe",
				saida = {
					pv = 830,
					danoPorTurno = 75,
				},
			},
		},
		atributosDaCriatura = {
			{
				patamar = 1,
				saida = {
					principal = 2,
					bom = 1,
					comum = 0,
					fraco = -1,
				},
			},
			{
				patamar = 2,
				saida = {
					principal = 2,
					bom = 1,
					comum = 0,
					fraco = -1,
				},
			},
			{
				patamar = 3,
				saida = {
					principal = 3,
					bom = 2,
					comum = 1,
					fraco = -1,
				},
			},
			{
				patamar = 4,
				saida = {
					principal = 4,
					bom = 2,
					comum = 1,
					fraco = -1,
				},
			},
			{
				patamar = 5,
				saida = {
					principal = 5,
					bom = 3,
					comum = 2,
					fraco = -1,
				},
			},
			{
				patamar = 6,
				saida = {
					principal = 6,
					bom = 3,
					comum = 2,
					fraco = -1,
				},
			},
		},
		bonusResistencia = {
			{
				patamar = 1,
				saida = 2,
			},
			{
				patamar = 2,
				saida = 2,
			},
			{
				patamar = 3,
				saida = 3,
			},
			{
				patamar = 4,
				saida = 4,
			},
			{
				patamar = 5,
				saida = 5,
			},
			{
				patamar = 6,
				saida = 6,
			},
		},
		escalarDado = {
			{
				dado = "d4",
				degraus = 0,
				saida = "d4",
			},
			{
				dado = "d4",
				degraus = 1,
				saida = "d6",
			},
			{
				dado = "d4",
				degraus = 2,
				saida = "d8",
			},
			{
				dado = "d4",
				degraus = 3,
				saida = "d10",
			},
			{
				dado = "d4",
				degraus = 5,
				saida = "2d8",
			},
			{
				dado = "d4",
				degraus = 9,
				saida = "3d12",
			},
			{
				dado = "d6",
				degraus = 0,
				saida = "d6",
			},
			{
				dado = "d6",
				degraus = 1,
				saida = "d8",
			},
			{
				dado = "d6",
				degraus = 2,
				saida = "d10",
			},
			{
				dado = "d6",
				degraus = 3,
				saida = "d12",
			},
			{
				dado = "d6",
				degraus = 5,
				saida = "2d10",
			},
			{
				dado = "d6",
				degraus = 9,
				saida = "4d10",
			},
			{
				dado = "d8",
				degraus = 0,
				saida = "d8",
			},
			{
				dado = "d8",
				degraus = 1,
				saida = "d10",
			},
			{
				dado = "d8",
				degraus = 2,
				saida = "d12",
			},
			{
				dado = "d8",
				degraus = 3,
				saida = "2d8",
			},
			{
				dado = "d8",
				degraus = 5,
				saida = "2d12",
			},
			{
				dado = "d8",
				degraus = 9,
				saida = "4d12",
			},
			{
				dado = "d10",
				degraus = 0,
				saida = "d10",
			},
			{
				dado = "d10",
				degraus = 1,
				saida = "d12",
			},
			{
				dado = "d10",
				degraus = 2,
				saida = "2d8",
			},
			{
				dado = "d10",
				degraus = 3,
				saida = "2d10",
			},
			{
				dado = "d10",
				degraus = 5,
				saida = "3d10",
			},
			{
				dado = "d10",
				degraus = 9,
				saida = "5d10",
			},
			{
				dado = "d12",
				degraus = 0,
				saida = "d12",
			},
			{
				dado = "d12",
				degraus = 1,
				saida = "2d8",
			},
			{
				dado = "d12",
				degraus = 2,
				saida = "2d10",
			},
			{
				dado = "d12",
				degraus = 3,
				saida = "2d12",
			},
			{
				dado = "d12",
				degraus = 5,
				saida = "3d12",
			},
			{
				dado = "d12",
				degraus = 9,
				saida = "5d12",
			},
			{
				dado = "2d8",
				degraus = 0,
				saida = "2d8",
			},
			{
				dado = "2d8",
				degraus = 1,
				saida = "2d10",
			},
			{
				dado = "2d8",
				degraus = 2,
				saida = "2d12",
			},
			{
				dado = "2d8",
				degraus = 3,
				saida = "3d10",
			},
			{
				dado = "2d8",
				degraus = 5,
				saida = "4d10",
			},
			{
				dado = "2d8",
				degraus = 9,
				saida = "5d12+2",
			},
			{
				dado = "2d10",
				degraus = 0,
				saida = "2d10",
			},
			{
				dado = "2d10",
				degraus = 1,
				saida = "2d12",
			},
			{
				dado = "2d10",
				degraus = 2,
				saida = "3d10",
			},
			{
				dado = "2d10",
				degraus = 3,
				saida = "3d12",
			},
			{
				dado = "2d10",
				degraus = 5,
				saida = "4d12",
			},
			{
				dado = "2d10",
				degraus = 9,
				saida = "5d12+4",
			},
			{
				dado = "2d12",
				degraus = 0,
				saida = "2d12",
			},
			{
				dado = "2d12",
				degraus = 1,
				saida = "3d10",
			},
			{
				dado = "2d12",
				degraus = 2,
				saida = "3d12",
			},
			{
				dado = "2d12",
				degraus = 3,
				saida = "4d10",
			},
			{
				dado = "2d12",
				degraus = 5,
				saida = "5d10",
			},
			{
				dado = "2d12",
				degraus = 9,
				saida = "5d12+6",
			},
			{
				dado = "3d10",
				degraus = 0,
				saida = "3d10",
			},
			{
				dado = "3d10",
				degraus = 1,
				saida = "3d12",
			},
			{
				dado = "3d10",
				degraus = 2,
				saida = "4d10",
			},
			{
				dado = "3d10",
				degraus = 3,
				saida = "4d12",
			},
			{
				dado = "3d10",
				degraus = 5,
				saida = "5d12",
			},
			{
				dado = "3d10",
				degraus = 9,
				saida = "5d12+8",
			},
			{
				dado = "3d12",
				degraus = 0,
				saida = "3d12",
			},
			{
				dado = "3d12",
				degraus = 1,
				saida = "4d10",
			},
			{
				dado = "3d12",
				degraus = 2,
				saida = "4d12",
			},
			{
				dado = "3d12",
				degraus = 3,
				saida = "5d10",
			},
			{
				dado = "3d12",
				degraus = 5,
				saida = "5d12+2",
			},
			{
				dado = "3d12",
				degraus = 9,
				saida = "5d12+10",
			},
			{
				dado = "4d10",
				degraus = 0,
				saida = "4d10",
			},
			{
				dado = "4d10",
				degraus = 1,
				saida = "4d12",
			},
			{
				dado = "4d10",
				degraus = 2,
				saida = "5d10",
			},
			{
				dado = "4d10",
				degraus = 3,
				saida = "5d12",
			},
			{
				dado = "4d10",
				degraus = 5,
				saida = "5d12+4",
			},
			{
				dado = "4d10",
				degraus = 9,
				saida = "5d12+12",
			},
			{
				dado = "4d12",
				degraus = 0,
				saida = "4d12",
			},
			{
				dado = "4d12",
				degraus = 1,
				saida = "5d10",
			},
			{
				dado = "4d12",
				degraus = 2,
				saida = "5d12",
			},
			{
				dado = "4d12",
				degraus = 3,
				saida = "5d12+2",
			},
			{
				dado = "4d12",
				degraus = 5,
				saida = "5d12+6",
			},
			{
				dado = "4d12",
				degraus = 9,
				saida = "5d12+14",
			},
			{
				dado = "5d10",
				degraus = 0,
				saida = "5d10",
			},
			{
				dado = "5d10",
				degraus = 1,
				saida = "5d12",
			},
			{
				dado = "5d10",
				degraus = 2,
				saida = "5d12+2",
			},
			{
				dado = "5d10",
				degraus = 3,
				saida = "5d12+4",
			},
			{
				dado = "5d10",
				degraus = 5,
				saida = "5d12+8",
			},
			{
				dado = "5d10",
				degraus = 9,
				saida = "5d12+16",
			},
			{
				dado = "5d12",
				degraus = 0,
				saida = "5d12",
			},
			{
				dado = "5d12",
				degraus = 1,
				saida = "5d12+2",
			},
			{
				dado = "5d12",
				degraus = 2,
				saida = "5d12+4",
			},
			{
				dado = "5d12",
				degraus = 3,
				saida = "5d12+6",
			},
			{
				dado = "5d12",
				degraus = 5,
				saida = "5d12+10",
			},
			{
				dado = "5d12",
				degraus = 9,
				saida = "5d12+18",
			},
		},
	},
})
