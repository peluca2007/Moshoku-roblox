-- Dados da primeira expedição (DIRECAO §4): o esgoto da cidade, 5 salas de combate com escolha de caminho e um chefe.
-- Só dados congelados; o gerador (Regras/ExpedicaoGerador) sorteia os encontros e a sessão consome `custos` (e `descansosMax`, se houver).
-- `criaturas` = ids canônicos para 1 jogador (o servidor escala ao tamanho do grupo). Só criaturas com modelo.
local Esgoto = {}

Esgoto.AREA = table.freeze({
	id = "esgoto", titulo = "Esgoto da cidade", regiao = "esgoto", areaId = "region/encounter/esgoto", passos = 5,
	-- Custos em dias do prazo da run. Entrar = 1; avançar de sala = grátis; descanso = 0,5.
	-- Voltar à cidade custa max(1, passo * voltarPorPasso); retomar um passo já vencido custa entrar + passo * voltarPorPasso.
	custos = table.freeze({ entrar = 1, voltarPorPasso = 0.5, descanso = 0.5 }),
	-- Descanso sem limite fixo (decisão do Pedro, 14/11): o grupo escolhe quando descansar e a Exaustão
	-- (Regras/ExaustaoRun) cobra as lutas seguidas. `descansosMax` opcional: nil = sem limite.
	encontros = table.freeze({
		table.freeze({ id = "ratos", dica = "Guinchos e patinhas na água escura", criaturas = table.freeze({ "creature/rato-gigante" }) }),
		table.freeze({ id = "goblin", dica = "Uma luz de tocha tremula adiante", criaturas = table.freeze({ "creature/goblin-batedor" }) }),
		table.freeze({ id = "aranha", dica = "Teias grossas cobrem o túnel", criaturas = table.freeze({ "creature/aranha-da-floresta" }) }),
		table.freeze({ id = "lobo", dica = "Um rosnado ecoa nos canos", criaturas = table.freeze({ "creature/lobo-cinzento" }) }),
		table.freeze({ id = "bandido", dica = "Passos de botas e conversa baixa", criaturas = table.freeze({ "creature/bandido-de-estrada" }) }),
	}),
	-- PROVISÓRIO: chefe é uma criatura existente mais forte, até haver o desenho próprio.
	chefe = table.freeze({ titulo = "O guardião do esgoto", criaturas = table.freeze({ "creature/golem-de-pedra-menor" }) }),
	recompensa = table.freeze({ ouro = 50 }),
})

return Esgoto
