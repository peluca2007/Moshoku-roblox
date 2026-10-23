-- Eventos de viagem da primeira versão (PLANO §12, R4). PROVISÓRIO: textos e efeitos são marcadores
-- para o Pedro e as IAs reescreverem. Testes e desfechos: dias, caixa de PO da run e flags narrativas.
-- Formato em Regras/RunViagem; os quatro eventos legados preservam dias/flag.
return table.freeze({
	{ id = "mercador-na-estrada", titulo = "Um mercador na estrada", tom = "bom", peso = 3, opcoes = {
		{ id = "comprar-provisoes", texto = "Comprar provisões", dias = 0.25 },
		{ id = "seguir-viagem", texto = "Seguir viagem" },
	} },
	{ id = "ponte-quebrada", titulo = "A ponte está quebrada", tom = "neutro", peso = 3, opcoes = {
		{ id = "atravessar-pulando", texto = "Atravessar pulando entre as vigas", tags = { "forca" } },
		{ id = "contornar-pelo-vau", texto = "Contornar pelo vau", dias = 0.5 },
	} },
	{ id = "bandidos-no-caminho", titulo = "Bandidos no caminho", tom = "ruim", peso = 3, opcoes = {
		{ id = "enfrentar", texto = "Enfrentar os bandidos", tags = { "confronto" } },
		{ id = "pagar-pedagio", texto = "Pagar o pedágio e passar", dias = 0.25 },
		{ id = "esperar-anoitecer", texto = "Esperar o anoitecer e passar escondido", dias = 0.5, tags = { "furtividade" } },
	} },
	{ id = "trilha-de-cavalos", titulo = "Uma trilha de cavalos selvagens", tom = "bom", peso = 1, modo = "cavalo", opcoes = {
		{ id = "seguir-a-trilha", texto = "Seguir a trilha" },
	} },
	-- Conteúdo abaixo é PROVISÓRIO. Testes usam os nomes canônicos das perícias e CD 12.
	{ id = "madeira-na-vila", titulo = "Madeira caída na vila", tom = "bom", peso = 2, regioes = { "vila" }, opcoes = {
		{ id = "ajudar-a-carregar", texto = "Ajudar a levar a madeira", teste = { pericia = "Vigor", cd = 12 }, sucesso = { dias = -0.25, ouro = 0, flag = "ajudou-madeira", texto = "A carga chega depressa." }, falha = { dias = 0.25, ouro = 0, flag = "carga-atrasou", texto = "A madeira cai e atrasa o trabalho." } },
		{ id = "vender-madeira", texto = "Vender uma parte da madeira", sucesso = { dias = 0, ouro = 3, flag = "vendeu-madeira", texto = "Os moradores pagam pela madeira." } },
	} },
	{ id = "pedras-da-muralha", titulo = "Pedras soltas na muralha", tom = "neutro", peso = 2, regioes = { "vila" }, opcoes = {
		{ id = "examinar-muralha", texto = "Examinar as pedras", teste = { pericia = "Investigação", cd = 12 }, sucesso = { dias = 0.25, ouro = 0, flag = "muralha-inspecionada", texto = "Você encontra a causa do dano." }, falha = { dias = 0.5, ouro = 0, flag = "muralha-sem-resposta", texto = "A inspeção não revela a causa." } },
		{ id = "seguir-vila", texto = "Seguir caminho", sucesso = { dias = 0, ouro = 0, flag = "muralha-ignorada", texto = "A viagem continua." } },
	} },
	{ id = "mensagem-na-taverna", titulo = "Uma mensagem na taverna", tom = "bom", peso = 1, regioes = { "vila" }, opcoes = {
		{ id = "convencer-mensageiro", texto = "Convencer o mensageiro a contar mais", teste = { pericia = "Persuasão", cd = 12 }, sucesso = { dias = 0, ouro = 0, flag = "mensagem-completa", texto = "Ele revela um atalho seguro." }, falha = { dias = 0.25, ouro = 0, flag = "mensagem-incompleta", texto = "Ele encerra a conversa." } },
		{ id = "comprar-mapa", texto = "Comprar o mapa", sucesso = { dias = 0, ouro = -2, flag = "mapa-da-vila", texto = "O mapa indica marcos pelo caminho." } },
	} },
	{ id = "cogumelos-sombras", titulo = "Cogumelos entre as sombras", tom = "bom", peso = 2, regioes = { "floresta-sombria" }, opcoes = {
		{ id = "coletar-cogumelos", texto = "Coletar os cogumelos", teste = { pericia = "Furtividade", cd = 12 }, sucesso = { dias = 0, ouro = 2, flag = "cogumelos-colhidos", texto = "A coleta rende algumas moedas." }, falha = { dias = 0.25, ouro = 0, flag = "cogumelos-espalhados", texto = "O ruído espanta a caça." } },
		{ id = "deixar-cogumelos", texto = "Deixar os cogumelos e seguir", sucesso = { dias = 0, ouro = 0, flag = "cogumelos-deixados", texto = "O grupo segue sem se deter." } },
	} },
	{ id = "riacho-escuro", titulo = "Um riacho de água escura", tom = "ruim", peso = 2, regioes = { "floresta-sombria" }, opcoes = {
		{ id = "cruzar-riacho", texto = "Cruzar o riacho pela correnteza", teste = { pericia = "Vigor", cd = 12 }, sucesso = { dias = 0, ouro = 0, flag = "riacho-cruzado", texto = "Todos atravessam com as botas molhadas." }, falha = { dias = 0.5, ouro = 0, flag = "riacho-atraso", texto = "A correnteza obriga o grupo a voltar." } },
		{ id = "contornar-riacho", texto = "Contornar pela margem", sucesso = { dias = 0.5, ouro = 0, flag = "riacho-contornado", texto = "A margem leva a uma passagem rasa." } },
	} },
	{ id = "ruidos-nas-arvores", titulo = "Ruídos entre as árvores", tom = "neutro", peso = 2, regioes = { "floresta-sombria" }, opcoes = {
		{ id = "seguir-ruidos", texto = "Investigar os ruídos", teste = { pericia = "Investigação", cd = 12 }, sucesso = { dias = 0.25, ouro = 0, flag = "ruidos-investigados", texto = "Você encontra rastros de animais." }, falha = { dias = 0.5, ouro = 0, flag = "ruidos-sem-pista", texto = "Os sons se perdem no bosque." } },
		{ id = "manter-trilha", texto = "Manter a trilha", sucesso = { dias = 0, ouro = 0, flag = "ruidos-evitados", texto = "O grupo não se desvia." } },
	} },
	{ id = "selo-fraturado", titulo = "Saqueadores junto ao Selo", tom = "ruim", peso = 2, regioes = { "ruinas-do-vale" }, opcoes = {
		{ id = "reforcar-selo", texto = "Intimidar os saqueadores junto ao Selo", teste = { pericia = "Intimidação", cd = 12 }, sucesso = { dias = 0.25, ouro = 3, flag = "selo-reforcado", texto = "Os saqueadores recuam e deixam três moedas." }, falha = { dias = 0.5, ouro = 0, flag = "selo-instavel", texto = "Os saqueadores não cedem; o grupo dá a volta." } },
		{ id = "afastar-selo", texto = "Evitar os saqueadores", sucesso = { dias = 0.25, ouro = 0, flag = "selo-evitado", texto = "O grupo contorna a câmara." } },
	} },
	{ id = "inscricoes-vale", titulo = "Inscrições nas ruínas", tom = "bom", peso = 2, regioes = { "ruinas-do-vale" }, opcoes = {
		{ id = "ler-inscricoes", texto = "Decifrar as inscrições", teste = { pericia = "Investigação", cd = 12 }, sucesso = { dias = 0, ouro = 0, flag = "inscricoes-decifradas", texto = "As inscrições descrevem o antigo caminho." }, falha = { dias = 0.25, ouro = 0, flag = "inscricoes-ilegiveis", texto = "Os sinais continuam indecifráveis." } },
		{ id = "vender-fragmento", texto = "Vender um fragmento solto", sucesso = { dias = 0, ouro = 2, flag = "fragmento-vendido", texto = "Um viajante compra o fragmento." } },
	} },
	{ id = "barco-a-deriva", titulo = "Um barco à deriva", tom = "neutro", peso = 2, opcoes = {
		{ id = "chamar-tripulacao", texto = "Chamar a tripulação para terra", teste = { pericia = "Persuasão", cd = 12 }, sucesso = { dias = 0.25, ouro = 1, flag = "tripulacao-ajudada", texto = "A tripulação agradece e paga uma moeda." }, falha = { dias = 0.5, ouro = 0, flag = "barco-sem-ajuda", texto = "O barco continua fora de alcance." } },
		{ id = "seguir-costa", texto = "Seguir pela costa", sucesso = { dias = 0.25, ouro = 0, flag = "barco-ignorado", texto = "A costa oferece passagem segura." } },
	} },
	{ id = "caravana-na-estrada", titulo = "Uma caravana na estrada", tom = "bom", peso = 2, opcoes = {
		{ id = "negociar-caravana", texto = "Negociar provisões com a caravana", teste = { pericia = "Persuasão", cd = 12 }, sucesso = { dias = -0.25, ouro = 0, flag = "caravana-negociada", texto = "A caravana indica uma rota mais rápida." }, falha = { dias = 0.25, ouro = -1, flag = "caravana-negocio-ruim", texto = "O negócio custa uma moeda e toma tempo." } },
		{ id = "comprar-provisoes-caravana", texto = "Comprar provisões", sucesso = { dias = 0, ouro = -2, flag = "provisoes-caravana", texto = "O grupo compra provisões para o caminho." } },
	} },
})
