-- GERADO por tools/gerar-catalogo.mts a partir do site do livro. Não edite: rode o gerador.
-- Domínio Condicoes.
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
		id = "condition/agarrado",
		kind = "condition",
		sourceId = "agarrado",
		sourceRef = {
			path = "src/data/condicoes.ts",
			symbol = "CONDICOES",
			selector = "CONDICOES[id=agarrado]",
		},
		data = {
			id = "agarrado",
			nome = "Agarrado",
			efeito = "Deslocamento reduzido a 0. Desvantagem em ataques contra qualquer criatura que não seja quem te agarrou. Termina se quem te agarrou for incapacitado, ou gastando 1 Ação num teste de Força ou Agilidade (Disputa) contra quem segura.",
			mecanica = {
				deslocamento = "zero",
			},
			duracaoPadrao = "Até se soltar",
		},
	},
	{
		id = "condition/amedrontado",
		kind = "condition",
		sourceId = "amedrontado",
		sourceRef = {
			path = "src/data/condicoes.ts",
			symbol = "CONDICOES",
			selector = "CONDICOES[id=amedrontado]",
		},
		data = {
			id = "amedrontado",
			nome = "Amedrontado",
			efeito = "Desvantagem em testes de atributo e em ataques enquanto a fonte do medo estiver visível. Não pode se mover voluntariamente pra mais perto dela. No fim de cada turno seu, repita o teste de resistência: um sucesso encerra a condição.",
			mecanica = {
				desvantagemEmAtaques = true,
				desvantagemEmTestes = true,
			},
			duracaoPadrao = "Novo teste no fim de cada turno",
		},
	},
	{
		id = "condition/apontado",
		kind = "condition",
		sourceId = "apontado",
		sourceRef = {
			path = "src/data/condicoes.ts",
			symbol = "CONDICOES",
			selector = "CONDICOES[id=apontado]",
		},
		data = {
			id = "apontado",
			nome = "Apontado",
			efeito = "A Ordem de Tiro do Tático (Cap. 3). O primeiro ataque que ACERTAR o alvo Apontado — do Tático ou de um aliado — causa +1d6 de dano por patamar que o Tático possua em Navegação e Liderança, e o próprio Tático soma o Bônus de Rank dele no acerto e no dano contra esse alvo. Dura até o próximo turno de quem apontou. Se ninguém acertar nesse intervalo, ele pode apontar o mesmo alvo de novo e o bônus acumula outro 1d6, até o dobro do patamar dele.",
			duracaoPadrao = "Até o próximo turno de quem apontou",
		},
	},
	{
		id = "condition/atolado",
		kind = "condition",
		sourceId = "atolado",
		sourceRef = {
			path = "src/data/condicoes.ts",
			symbol = "CONDICOES",
			selector = "CONDICOES[id=atolado]",
		},
		data = {
			id = "atolado",
			nome = "Atolado",
			efeito = "Deslocamento reduzido à metade. Dura até o fim do seu próximo turno, ou antes, se você gastar 1 Ação e passar num teste de Força (CD 8 + BC de quem te atolou). Não afeta ataques nem testes.",
			mecanica = {
				deslocamento = "metade",
			},
			duracaoPadrao = "Até o fim do próximo turno",
		},
	},
	{
		id = "condition/dose",
		kind = "condition",
		sourceId = "dose",
		sourceRef = {
			path = "src/data/condicoes.ts",
			symbol = "CONDICOES",
			selector = "CONDICOES[id=dose]",
		},
		data = {
			id = "dose",
			nome = "Dose",
			efeito = "Acumulável até 3, e só os venenos da Magia de Desintoxicação a aplicam. Com 1 Dose, nada ainda: o veneno está se instalando. Com 2 Doses, o alvo está Envenenado. A 3ª Dose é o Colapso: as Doses saem todas e o alvo fica Atordoado até o fim do próximo turno dele. Transbordo: quem cai a 0 PV com Dose passa as Doses dele, sem teste, para o aliado dele mais próximo a até 9 m (se chegar a 3, é o Colapso deste). Dura até o fim do combate (1 minuto fora dele), ou até ser purgada ou Invertida (Cap. 2, Desintoxicação). Construtos, mortos-vivos e quem não respira não recebem Dose.",
			mecanica = {
				acumulavel = true,
				tetoFixo = 3,
				noTetoVira = "atordoado",
				aPartirDe = {
					{
						acumulos = 2,
						rotulo = "Dose ×2 (Envenenado)",
						mecanica = {
							desvantagemEmAtaques = true,
							desvantagemEmTestes = true,
						},
					},
				},
			},
			duracaoPadrao = "Até o fim do combate",
			sinonimos = {
				"Doses",
			},
		},
	},
	{
		id = "condition/atordoado",
		kind = "condition",
		sourceId = "atordoado",
		sourceRef = {
			path = "src/data/condicoes.ts",
			symbol = "CONDICOES",
			selector = "CONDICOES[id=atordoado]",
		},
		data = {
			id = "atordoado",
			nome = "Atordoado",
			efeito = "Perde todas as Ações e a Reação até o fim do próximo turno. Ataques contra você têm Vantagem, e você falha automaticamente em testes de resistência de Força e Agilidade.",
			mecanica = {
				semAcoes = true,
				vantagemParaQuemAtaca = true,
			},
			duracaoPadrao = "Até o fim do próximo turno",
		},
	},
	{
		id = "condition/caido",
		kind = "condition",
		sourceId = "caido",
		sourceRef = {
			path = "src/data/condicoes.ts",
			symbol = "CONDICOES",
			selector = "CONDICOES[id=caido]",
		},
		data = {
			id = "caido",
			nome = "Caído",
			efeito = "Desvantagem em qualquer ataque que você faça. Ataques corpo a corpo contra você têm Vantagem; ataques à distância contra você têm Desvantagem. Levantar-se gasta metade do Deslocamento de um Andar; com a outra metade, a mesma Ação ainda te move.",
			mecanica = {
				desvantagemEmAtaques = true,
				vantagemCorpoACorpo = true,
				desvantagemADistancia = true,
			},
			duracaoPadrao = "Até se levantar",
		},
	},
	{
		id = "condition/cego",
		kind = "condition",
		sourceId = "cego",
		sourceRef = {
			path = "src/data/condicoes.ts",
			symbol = "CONDICOES",
			selector = "CONDICOES[id=cego]",
		},
		data = {
			id = "cego",
			nome = "Cego",
			efeito = "Falha automaticamente em qualquer teste que dependa de visão. Seus ataques têm Desvantagem; ataques contra você têm Vantagem.",
			mecanica = {
				desvantagemEmAtaques = true,
				vantagemParaQuemAtaca = true,
			},
			duracaoPadrao = "Até o fim do próximo turno",
		},
	},
	{
		id = "condition/congelado",
		kind = "condition",
		sourceId = "congelado",
		sourceRef = {
			path = "src/data/condicoes.ts",
			symbol = "CONDICOES",
			selector = "CONDICOES[id=congelado]",
		},
		data = {
			id = "congelado",
			nome = "Congelado",
			efeito = "Deslocamento reduzido a 0 e Desvantagem em testes de resistência de Agilidade, até quebrar o gelo (1 Ação, teste de Força CD 8 + BC de quem congelou) ou sofrer dano de fogo.",
			mecanica = {
				deslocamento = "zero",
			},
			duracaoPadrao = "Até quebrar o gelo",
		},
	},
	{
		id = "condition/desequilibrado",
		kind = "condition",
		sourceId = "desequilibrado",
		sourceRef = {
			path = "src/data/condicoes.ts",
			symbol = "CONDICOES",
			selector = "CONDICOES[id=desequilibrado]",
		},
		data = {
			id = "desequilibrado",
			nome = "Desequilibrado",
			efeito = "Deslocamento reduzido à metade, e não pode usar Reação nenhuma — nem ataque de oportunidade, nem bloqueio. Dura até o fim do próximo turno do alvo, salvo instrução contrária da habilidade.",
			mecanica = {
				deslocamento = "metade",
			},
			duracaoPadrao = "Até o fim do próximo turno",
		},
	},
	{
		id = "condition/em-chamas",
		kind = "condition",
		sourceId = "em-chamas",
		sourceRef = {
			path = "src/data/condicoes.ts",
			symbol = "CONDICOES",
			selector = "CONDICOES[id=em-chamas]",
		},
		data = {
			id = "em-chamas",
			nome = "Em Chamas",
			efeito = "No início de cada um dos seus turnos, sofre 1d6 de dano ígneo (ou o valor que a habilidade que ateou o fogo especificar). Apaga submergindo em água, ficando Molhado, ou gastando 1 Ação inteira rolando no chão (teste de Agilidade CD 10).",
			mecanica = {
				danoPorTurno = "1d6",
			},
			duracaoPadrao = "Até apagar",
		},
	},
	{
		id = "condition/envenenado",
		kind = "condition",
		sourceId = "envenenado",
		sourceRef = {
			path = "src/data/condicoes.ts",
			symbol = "CONDICOES",
			selector = "CONDICOES[id=envenenado]",
		},
		data = {
			id = "envenenado",
			nome = "Envenenado",
			efeito = "Desvantagem em ataques e em testes de atributo enquanto durar.",
			mecanica = {
				desvantagemEmAtaques = true,
				desvantagemEmTestes = true,
			},
			duracaoPadrao = "Até o fim do próximo turno",
		},
	},
	{
		id = "condition/incapacitado",
		kind = "condition",
		sourceId = "incapacitado",
		sourceRef = {
			path = "src/data/condicoes.ts",
			symbol = "CONDICOES",
			selector = "CONDICOES[id=incapacitado]",
		},
		data = {
			id = "incapacitado",
			nome = "Incapacitado",
			efeito = "Não pode tomar Ações nem Reações. Mais severo que Atordoado: não termina sozinho no fim do turno — só quando a fonte específica disser como remover.",
			mecanica = {
				semAcoes = true,
			},
			duracaoPadrao = "Até a fonte remover",
		},
	},
	{
		id = "condition/marcado",
		kind = "condition",
		sourceId = "marcado",
		sourceRef = {
			path = "src/data/condicoes.ts",
			symbol = "CONDICOES",
			selector = "CONDICOES[id=marcado]",
		},
		data = {
			id = "marcado",
			nome = "Marcado",
			efeito = "Quem te marcou sabe seu PV aproximado, suas resistências e se você veste Touki, e ignora Cobertura parcial ao te atacar. Dura até o fim do combate, salvo instrução contrária da habilidade que marcou.",
			duracaoPadrao = "Até o fim do combate",
		},
	},
	{
		id = "condition/molhado",
		kind = "condition",
		sourceId = "molhado",
		sourceRef = {
			path = "src/data/condicoes.ts",
			symbol = "CONDICOES",
			selector = "CONDICOES[id=molhado]",
		},
		data = {
			id = "molhado",
			nome = "Molhado",
			efeito = "Vulnerável a frio: dano de frio contra você é dobrado (Cap. 4, §6). Desvantagem em testes de resistência contra magias que causem dano de frio, se forem de quem te molhou. Dura 1 minuto, ou até você sofrer dano ígneo: o dano entra normalmente, não acende Em Chamas, e seca a água.",
			duracaoPadrao = "1 minuto, ou até sofrer dano ígneo",
		},
	},
	{
		id = "condition/paralisado",
		kind = "condition",
		sourceId = "paralisado",
		sourceRef = {
			path = "src/data/condicoes.ts",
			symbol = "CONDICOES",
			selector = "CONDICOES[id=paralisado]",
		},
		data = {
			id = "paralisado",
			nome = "Paralisado",
			efeito = "Incapaz de agir e de se mover; falha automaticamente em testes de resistência de Força e Agilidade. Ataques contra você têm Vantagem, e os corpo a corpo são críticos automáticos se o atacante estiver adjacente.",
			mecanica = {
				semAcoes = true,
				deslocamento = "zero",
				vantagemParaQuemAtaca = true,
			},
		},
	},
	{
		id = "condition/petrificado",
		kind = "condition",
		sourceId = "petrificado",
		sourceRef = {
			path = "src/data/condicoes.ts",
			symbol = "CONDICOES",
			selector = "CONDICOES[id=petrificado]",
		},
		data = {
			id = "petrificado",
			nome = "Petrificado",
			efeito = "Vira pedra (ou material equivalente): Incapacitado, imune a veneno e doença, e Resistência a todo dano enquanto durar. Reverter exige a fonte específica que petrificou, ou Desintoxicação de rank igual ou superior ao da aflição que petrificou (Cap. 4, §8). Magia de Cura não reverte petrificação em rank nenhum.",
			mecanica = {
				semAcoes = true,
				deslocamento = "zero",
			},
			duracaoPadrao = "Até a fonte reverter",
		},
	},
	{
		id = "condition/soterrado",
		kind = "condition",
		sourceId = "soterrado",
		sourceRef = {
			path = "src/data/condicoes.ts",
			symbol = "CONDICOES",
			selector = "CONDICOES[id=soterrado]",
		},
		data = {
			id = "soterrado",
			nome = "Soterrado",
			efeito = "A segunda metade da identidade da Terra, e o pagamento de Atolado: só pode ser aplicada a um alvo que já esteja Atolado, Preso ou Caído. Deslocamento 0, Preso, não enxerga nem conjura com gesto, e sofre 2d10 de sufocamento no início de cada turno se precisar respirar. Sai gastando 1 Ação num teste de Força (CD 8 + BC de quem soterrou), ou quando 30 de dano forem causados à terra que o cobre.",
			mecanica = {
				deslocamento = "zero",
				danoPorTurno = "2d10",
			},
			duracaoPadrao = "Até sair",
		},
	},
	{
		id = "condition/preso",
		kind = "condition",
		sourceId = "preso",
		sourceRef = {
			path = "src/data/condicoes.ts",
			symbol = "CONDICOES",
			selector = "CONDICOES[id=preso]",
		},
		data = {
			id = "preso",
			nome = "Preso",
			efeito = "Deslocamento reduzido a 0. Ataques contra você têm Vantagem; seus ataques têm Desvantagem. Solta-se gastando 1 Ação num teste (Atributo e CD definidos por quem prendeu).",
			mecanica = {
				deslocamento = "zero",
				desvantagemEmAtaques = true,
				vantagemParaQuemAtaca = true,
			},
			duracaoPadrao = "Até se soltar",
		},
	},
	{
		id = "condition/quebrantado",
		kind = "condition",
		sourceId = "quebrantado",
		sourceRef = {
			path = "src/data/condicoes.ts",
			symbol = "CONDICOES",
			selector = "CONDICOES[id=quebrantado]",
		},
		data = {
			id = "quebrantado",
			nome = "Quebrantado",
			efeito = "Acumulável: cada acúmulo dá −1 na CA e −1 no dano de todos os seus ataques, até o máximo do Bônus de Rank de quem aplicou — o DOBRO disso se quem aplicou tiver a Maestria Nada Segura (Lutador, Avançado). Não é ferimento — magia de Cura não remove. Dura até o fim do combate (ou até um Descanso Curto, se foi aplicado fora de combate).",
			mecanica = {
				acumulavel = true,
			},
			duracaoPadrao = "Até o fim do combate",
		},
	},
	{
		id = "condition/surpreso",
		kind = "condition",
		sourceId = "surpreso",
		sourceRef = {
			path = "src/data/condicoes.ts",
			symbol = "CONDICOES",
			selector = "CONDICOES[id=surpreso]",
		},
		data = {
			id = "surpreso",
			nome = "Surpreso",
			efeito = "Na primeira rodada do combate você tem só 1 Ação e nenhuma Reação. Acaba no fim do seu primeiro turno. Fica Surpreso quem não percebeu a ameaça antes de a luta começar — na dúvida, a Furtividade de quem embosca contra a Percepção de cada alvo.",
			duracaoPadrao = "Até o fim do seu primeiro turno",
		},
	},
	{
		id = "condition/surdo",
		kind = "condition",
		sourceId = "surdo",
		sourceRef = {
			path = "src/data/condicoes.ts",
			symbol = "CONDICOES",
			selector = "CONDICOES[id=surdo]",
		},
		data = {
			id = "surdo",
			nome = "Surdo",
			efeito = "Falha automaticamente em testes que dependam de audição. Não consegue usar Conjuração Padrão nem Encurtada (exigem cântico verbal) — só Conjuração Silenciosa continua funcionando pra você.",
			duracaoPadrao = "Até o fim do próximo turno",
		},
	},
	{
		id = "condition/conjurando",
		kind = "condition",
		sourceId = "conjurando",
		sourceRef = {
			path = "src/data/condicoes.ts",
			symbol = "ESTADOS_DE_REGRA",
			selector = "ESTADOS_DE_REGRA[id=conjurando]",
		},
		data = {
			id = "conjurando",
			nome = "Conjurando",
			efeito = "Do primeiro gasto de Ação de um cântico até a magia sair (Cap. 2, §6). Sofrer dano pede o Teste de Concentração; ficar sem gastar ao menos 1 Ação no cântico por turno é Perda de Foco (Cap. 4, §3).",
			duracaoPadrao = "Até a magia sair ou ser interrompida",
		},
	},
	{
		id = "condition/desprevenido",
		kind = "condition",
		sourceId = "desprevenido",
		sourceRef = {
			path = "src/data/condicoes.ts",
			symbol = "ESTADOS_DE_REGRA",
			selector = "ESTADOS_DE_REGRA[id=desprevenido]",
		},
		data = {
			id = "desprevenido",
			nome = "Desprevenido",
			efeito = "O alvo ainda não agiu neste combate, está Surpreso, ou não sabe onde você está. É o gatilho de técnicas como o Dano Furtivo e o Primeiro Golpe, que dizem o que ganham com ele.",
		},
	},
	{
		id = "condition/escondido",
		kind = "condition",
		sourceId = "escondido",
		sourceRef = {
			path = "src/data/condicoes.ts",
			symbol = "ESTADOS_DE_REGRA",
			selector = "ESTADOS_DE_REGRA[id=escondido]",
		},
		data = {
			id = "escondido",
			nome = "Escondido",
			efeito = "Se Esconder custa 1 Ação e exige Cobertura, escuridão ou estar fora da vista; teste de Agilidade (Furtividade) contra 10 + Espírito de cada inimigo que possa te procurar. Enquanto Escondido, seus ataques têm Vantagem e o alvo conta como Desprevenido. Atacar, falar alto ou sair do esconderijo revela você no fim daquela Ação.",
			duracaoPadrao = "Até atacar, falar alto ou sair do esconderijo",
		},
	},
	{
		id = "condition/estabilizado",
		kind = "condition",
		sourceId = "estabilizado",
		sourceRef = {
			path = "src/data/condicoes.ts",
			symbol = "ESTADOS_DE_REGRA",
			selector = "ESTADOS_DE_REGRA[id=estabilizado]",
		},
		data = {
			id = "estabilizado",
			nome = "Estabilizado",
			efeito = "A 0 PV, mas fora de perigo imediato: para de rolar o Fio da Vida e acorda com 1 PV em 1d4 horas, ou na hora com qualquer cura. Sofrer dano tira o Estabilizado e dá 1 Marca da Morte (2 se for crítico). Qualquer um estabiliza alguém com 1 Ação e teste de Medicina CD 10 (Vantagem com Kit de Primeiros Socorros).",
			duracaoPadrao = "Até acordar ou sofrer dano",
		},
	},
	{
		id = "condition/exausto",
		kind = "condition",
		sourceId = "exausto",
		sourceRef = {
			path = "src/data/condicoes.ts",
			symbol = "ESTADOS_DE_REGRA",
			selector = "ESTADOS_DE_REGRA[id=exausto]",
		},
		data = {
			id = "exausto",
			nome = "Exausto",
			efeito = "Exaustão de nível 3 ou mais (Cap. 4, §9). O Manto de Touki cai, e todo efeito que diz 'enquanto não Exausto' para.",
			duracaoPadrao = "Até a Exaustão cair abaixo do nível 3",
		},
	},
	{
		id = "condition/inconsciente",
		kind = "condition",
		sourceId = "inconsciente",
		sourceRef = {
			path = "src/data/condicoes.ts",
			symbol = "ESTADOS_DE_REGRA",
			selector = "ESTADOS_DE_REGRA[id=inconsciente]",
		},
		data = {
			id = "inconsciente",
			nome = "Inconsciente",
			efeito = "Incapacitado e Caído. Ataque corpo a corpo de criatura adjacente contra você é crítico. É onde você fica a 0 PV (Cap. 4, §7): nesse caso, sofrer dano dá 1 Marca da Morte (2 se for crítico) e tira o Estabilizado. Inconsciente com PV acima de 0 (sono de veneno, por exemplo) não ganha Marca: dura o que a fonte disser.",
			duracaoPadrao = "Até recuperar PV, ou o que a fonte disser",
		},
	},
})
