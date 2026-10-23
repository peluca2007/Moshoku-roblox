-- Porte das cartas Principiante. Fonte: Livro/Dados/Arvores e sourceRef de cada
-- ID. Custos são conferidos contra o catálogo. Reações/passivas não são ações.
local T = { MECANICAS = {}, INDISPONIVEIS = {} }
local function carta(arvore, id, m)
	local chave = "ability/" .. arvore .. "/Principiante/" .. id
	m.livro = chave
	m.pm, m.pt = m.pm or 0, m.pt or 0
	T.MECANICAS[chave] = table.freeze(m)
end
local function indisponivel(arvore, ids, motivo)
	for _, id in ids do T.INDISPONIVEIS["ability/" .. arvore .. "/Principiante/" .. id] = motivo end
end
local function ataque(arvore, id, dados, tipo, alcance, pm, acoes, extra)
	local m = { tipo = "ataque", partes = { { dados = dados, tipo = tipo, bc = true } }, alcanceCasas = alcance, pm = pm, acoes = acoes }
	for k, v in extra or {} do m[k] = v end
	carta(arvore, id, m)
end
local function teste(atributo, cdAtributo, extra)
	return { atributo = atributo, cdBase = 8, cdAtributo = cdAtributo, extra = extra }
end
local fimAlvo = { de = "alvo" }
local function estado(nome, valor, duracao)
	return { nome = nome, valor = valor, duracao = duracao or fimAlvo }
end
local armaNormal = { { arma = true, bc = true } }

ataque("agua", "respingo", "1d6", "contundente", 6, 0, 1, { umaVezPorTurno = true, aplica = "molhado", duracao = { de = "conjurador" } })
ataque("agua", "bola-de-agua", "1d6", "contundente", 12, 1, 2, { aplica = "molhado", duracao = { rodadas = 10 }, empurraCasas = 1 })
ataque("agua", "flecha-de-agua", "1d8", "perfurante", 18, 1, 2, { aplica = "molhado", duracao = { rodadas = 10 } })
carta("agua", "impacto-de-gelo", { tipo = "efeito", acoes = 2, pm = 2, alcanceCasas = 12,
	partes = { { dados = "1d8", tipo = "frio" }, { bc = true, tipo = "contundente" } }, danoSempre = true,
	resistencia = teste("agilidade"), estados = { estado("reduzMovimento", 2) } })
carta("agua", "lamina-de-gelo", { tipo = "efeito", acoes = 2, pm = 2, alvo = "si", armaTemporaria = true })
carta("agua", "escudo-de-agua", { tipo = "zona", acoes = 2, pm = 2, forma = "linhaTransversal", alcanceCasas = 4,
	comprimentoCasas = 2, duracaoRodadas = 2, estilo = "agua", cobertura = 5, reduzIgneo = true })
carta("agua", "nevoa-densa", { tipo = "zona", acoes = 2, pm = 1, forma = "esferaNoConjurador", raioCasas = 4,
	duracaoRodadas = 50, estilo = "nevoa", obscurece = true, bloqueiaVisao = true })

ataque("vento", "rajada-curta", "1d6", "cortante", 6, 0, 1, { umaVezPorTurno = true })
ataque("vento", "lamina-de-vento", "1d10", "cortante", 18, 1, 2, { aplica = "desequilibrado", duracao = fimAlvo })
carta("vento", "empurrao", { tipo = "efeito", acoes = 2, pm = 1, alcanceCasas = 12, resistencia = teste("forca"),
	aplica = "desequilibrado", duracao = fimAlvo, empurraCasas = 4,
	aviso = "Na grade, empurra para longe de você.", adaptacoes = { "Direção do empurrão: radial, para longe do conjurador." } })
carta("vento", "passo-de-vento", { tipo = "deslocamento", acoes = 2, pm = 2, alcanceCasas = 12,
	aviso = "Movimento no plano da mesa, com caminho livre.", adaptacoes = { "Voo vertical não representado na grade." } })
carta("vento", "sopro-de-poeira", { tipo = "efeito", alvo = "cone", comprimentoCasas = 4, acoes = 1, pm = 1,
	resistencia = teste("vigor"), aplica = { "cego", "desequilibrado" }, duracao = fimAlvo })
carta("vento", "vacuo-localizado", { tipo = "efeito", acoes = 2, pm = 2, alcanceCasas = 6,
	partes = { { dados = "1d6", tipo = "sufocamento" } }, exigeRespirar = true, testeSoContraRankMaior = true,
	resistencia = teste("vigor"), estados = { estado("silenciado", true) }, naoConsecutivo = true })

ataque("terra", "pedrisco", "1d6", "contundente", 6, 0, 1, { umaVezPorTurno = true })
ataque("terra", "bala-de-pedra", "1d10", "contundente", 18, 1, 2, { acertoAutomaticoContra = "atolado" })
carta("terra", "atoleiro", { tipo = "efeito", alvo = "esferaNoConjurador", raioCasas = 4, acoes = 2, pm = 2,
	resistencia = teste("agilidade"), aplica = "atolado", duracao = fimAlvo, zonaApos = { estilo = "atoleiro", terrenoDificil = true, duracaoRodadas = 100 } })
carta("terra", "muro-de-terra", { tipo = "zona", forma = "linhaTransversal", acoes = 3, pm = 2, alcanceCasas = 6,
	comprimentoCasas = 4, duracaoRodadas = 100, estilo = "terra", bloqueiaMovimento = true, bloqueiaVisao = true, bloqueiaProjeteis = true, pvZona = 40 })
carta("terra", "lanca-de-pedra", { tipo = "efeito", alvo = "lista", maxAlvos = 3, alcanceCasas = 6, acoes = 2, pm = 2,
	partes = { { dados = "2d6", tipo = "perfurante" } }, resistencia = teste("agilidade"), aplica = "atolado", duracao = fimAlvo })
carta("terra", "mao-de-terra", { tipo = "efeito", alcanceCasas = 12, acoes = 2, pm = 2, resistencia = teste("forca"),
	aplica = { "agarrado", "atolado" }, sustenta = true, escape = "forca", arrasta = true })
indisponivel("terra", { "couraca-de-barro" }, "Reação (2 PM): o jogo pergunta quando um golpe físico te causar dano.")

carta("cura", "cura", { tipo = "cura", acoes = 2, pm = 2, corpoACorpo = true, partes = { { dados = "1d8", bc = true } },
	dobraComFeridaFresca = true, removeMarcasDaMorte = true })
carta("cura", "estancar", { tipo = "efeito", acoes = 2, pm = 2, corpoACorpo = true, permiteSi = true, estancar = true })
carta("cura", "selar-a-ferida", { tipo = "efeito", acoes = 2, pm = 3, corpoACorpo = true, permiteSi = true,
	marca = "feridaSelada", marcaTexto = "Ferida Fresca selada", aviso = "Selo por 600 rodadas, até encerrar combate." })
carta("cura", "vigor-emprestado", { tipo = "cura", acoes = 2, pm = 3, corpoACorpo = true,
	partes = { { dados = "2d8", bc = true } }, dobraComFeridaFresca = true, pvTemporarios = true, duracaoRodadas = 100 })
indisponivel("cura", { "mao-que-acalma" }, "Indisponível: Exaustão tem apenas a marca Exausto (nível 3+), sem nível nem causa. Não é possível remover um nível de ferimento sem também apagar fome/marcha.")

carta("desintoxicacao", "purgar", { tipo = "efeito", acoes = 1, pm = 3, alcanceCasas = 6, permiteSi = true,
	inverteDoses = "2d6", purga = 1 })
carta("desintoxicacao", "antidoto", { tipo = "efeito", alvo = "lista", maxAlvos = 3, alcanceCasas = 1, permiteSi = true,
	acoes = 2, pm = 2, estados = { estado("antidoto", true, { rodadas = 600 }) } })
carta("desintoxicacao", "peconha", { tipo = "efeito", alcanceCasas = 12, acoes = 1, pm = 3, exigeRespirar = true,
	partes = { { dados = "2d6", bc = true, tipo = "veneno" } }, resistencia = teste("vigor"), metadeNoSucesso = true, doses = 1 })
carta("desintoxicacao", "rosa-preta", { tipo = "efeito", corpoACorpo = true, acoes = 2, pm = 3, exigeRespirar = true,
	resistencia = teste("vigor"), aplica = "inconsciente", sono = true, duracao = { rodadas = 10 } })
carta("desintoxicacao", "sangria", { tipo = "efeito", acoes = 2, pm = 3, corpoACorpo = true, permiteSi = true,
 sangria = true, partes = { { dados = "3d6" } }, danoSempre = true,
 aviso = "Aflição até um rank acima, com origem conhecida. 3d6 irredutíveis; 1 vez por aflição por combate (descanso automático)." })
indisponivel("desintoxicacao", { "agua-limpa", "estomago-de-ferro" }, "Efeito de exploração: consulte a ficha.")

ataque("teorica", "dardo-arcano", "1d8", "arcano", 6, 1, 2)
carta("teorica", "anteparo-teorico", { tipo = "zona", acoes = 2, pm = 2, forma = "linhaTransversal", alcanceCasas = 1,
	comprimentoCasas = 2, duracaoRodadas = 10, estilo = "anteparo", bloqueiaMovimento = true, bloqueiaProjeteis = true, pvZona = 30 })
indisponivel("teorica", { "sinal-arcano" }, "Sinal sem efeito de combate: consulte a ficha.")
indisponivel("teorica", { "parede-de-emergencia" }, "Reação (4 PM): o jogo pergunta quando você ou um aliado a até 3 m for alvo de ataque físico.")
carta("invocacao", "chamado", { tipo = "invocacao", acoes = 3, pm = 7, alvo = "si", escolhasPacto = true })

carta("deus-da-espada", "corte-de-braco", { corteBraco = true, tipo = "ataque", acoes = 1, arma = true, corpoACorpo = true, partes = armaNormal,
	efeitoNoAcerto = { resistencia = teste("vigor", "forca"), desarmar = true },
	aviso = "Larga a arma; braço inútil até o fim do próximo turno (Santo+: só desarme). Conjuração contínua ainda ausente." })
carta("deus-da-espada", "investida-espada", { tipo = "investida", acoes = 1, arma = true, dobraDeslocamento = true,
	alcanceCasas = 12, partes = armaNormal, bonusSeCorrerCasas = 6, partesExtraNaCorrida = { { arma = true } }, semReacoes = true })
carta("deus-da-espada", "golpe-continuo", { tipo = "ataque", acoes = 1, pt = 1, arma = true, corpoACorpo = true,
	partes = armaNormal, bonusSeJaAcertou = 4 })
indisponivel("deus-da-espada", { "roupa-leve", "sem-recuo" }, "Passiva: consulte a ficha.")

carta("deus-da-agua-corpo", "provocar", { tipo = "efeito", acoes = 1, alcanceCasas = 32, umaVezPorTurno = true,
	resistencia = teste("espirito", "espirito"), estados = { estado("provocado", true) } })
indisponivel("deus-da-agua-corpo", { "aparar" }, "Reação: o jogo pergunta quando um golpe corpo a corpo te acertar e o Aparar o faria errar.")
indisponivel("deus-da-agua-corpo", { "guarda-do-corpo" }, "Reação: o jogo pergunta quando um aliado ao seu lado for atacado.")
indisponivel("deus-da-agua-corpo", { "peso-nao-atrapalha", "base-firme" }, "Passiva: consulte a ficha.")

carta("deus-do-norte", "forma-quadrupede", { tipo = "investida", acoes = 1, arma = true, dobraDeslocamento = true,
	alcanceCasas = 12, partes = { { arma = true, bc = true }, { dados = "1d6" } } })
carta("deus-do-norte", "arremesso-de-espada", { tipo = "ataque", acoes = 1, arma = true, armaADistancia = true, alcanceCasas = 12,
	partes = armaNormal, atributoAcerto = "agilidade", desarmaConjurador = true, aviso = "Arremessa sua espada contra um alvo distante e deixa você desarmado até recuperá-la." })
carta("deus-do-norte", "bala-de-lagrimas", { tipo = "efeito", alvo = "cone", comprimentoCasas = 2, acoes = 1,
	resistencia = teste("vigor", "agilidade"), aplica = "cego", duracao = fimAlvo, consumivel = "tempero" })
carta("deus-do-norte", "primeiros-socorros-de-campo", { tipo = "cura", acoes = 1, corpoACorpo = true,
	partes = {}, curaAtributo = "vigor", curaRank = true, primeirosSocorros = true, permiteSi = true, soAliados = true, umaVezPorCriaturaCombate = true, aviso = "Vigor + Rank PV; 1 vez por criatura por combate (descanso automático)." })
carta("deus-do-norte", "golpe-baixo", { tipo = "ataque", acoes = 1, arma = true, corpoACorpo = true,
	partes = { { arma = true, metade = true } }, efeitoNoAcerto = { resistencia = teste("forcaOuAgilidade", "forca"), aplica = "caido" } })
indisponivel("deus-do-norte", { "leitura-de-rastro-norte" }, "Passiva: consulte a ficha.")

carta("armas-pesadas", "investida-devastadora", { tipo = "investida", acoes = 1, arma = true, alcanceCasas = 6,
	exigeCorridaCasas = 4, partes = { { arma = true, bc = true }, { arma = true }, { arma = true } },
	efeitoNoAcerto = { resistencia = teste("forca", "forca"), aplica = "caido", quebrantado = true } })
carta("armas-pesadas", "agarrao", { tipo = "efeito", acoes = 1, corpoACorpo = true, disputa = "forca", aplica = "agarrado", escape = "forcaOuAgilidade", arrasta = true })
carta("armas-pesadas", "golpe-circular", { tipo = "ataque", acoes = 1, arma = true, corpoACorpo = true,
	alvo = "adjacentes", partes = { { arma = true, degrau = -1 } } })
carta("armas-pesadas", "cabecada", { tipo = "ataque", acoes = 1, arma = true, corpoACorpo = true,
	partes = { { arma = true, metade = true } }, danoConjurador = "1d4", umaVezPorCombateAlvo = true,
	efeitoNoAcerto = { resistencia = teste("vigor", "forca"), estados = { estado("perdeAcao", 1) } } })
carta("armas-pesadas", "quebrar-equipamento", { tipo = "efeito", acoes = 1, corpoACorpo = true,
 resistencia = teste("forca", "forca"), quebrarEquipamento = true,
 aviso = "Mundano: quebra até o descanso automático. Inimigo humanoide: dano pela metade. Sem tipo mágico no inventário: só itens mundanos reconhecidos." })

carta("cavalaria-e-escudos", "muralha-de-um", { tipo = "efeito", acoes = 1, pt = 1, alvo = "esferaNoConjurador", raioCasas = 2,
	soAliados = true, estados = { estado("cobertura", 5, { de = "conjurador", inicio = true }), estado("resisteArea", true, { de = "conjurador", inicio = true }) },
	estadosConjurador = { estado("imovel", true, { de = "conjurador", inicio = true }) } })
local escudo = { tipo = "ataque", acoes = 1, corpoACorpo = true, exigeEscudo = true,
	partes = { { dados = "2d8", atributo = "forca", rank = true, tipo = "contundente" } },
	efeitoNoAcerto = { resistencia = teste("forca", "vigor"), aplica = "caido", empurraCasas = 2 } }
carta("cavalaria-e-escudos", "golpe-de-escudo", escudo)
local soberano = table.clone(escudo)
soberano.exigeTalento = "talent/cavalaria-e-escudos/Principiante/puro-escudo"
soberano.ultimaPosicao = true
soberano.efeitoNoAcerto = { resistencia = teste("forca", "vigor", 2), aplica = "caido", empurraCasas = 4 }
carta("cavalaria-e-escudos", "golpe-de-escudo-soberano", soberano)
carta("cavalaria-e-escudos", "puxar", { tipo = "efeito", acoes = 1, alcanceCasas = 6, soAliados = true, puxar = true, guarda = true })
carta("cavalaria-e-escudos", "provocar-odio", { tipo = "efeito", acoes = 1, alcanceCasas = 32,
	resistencia = teste("espirito", "vigor"), estados = { estado("odio", true) } })
carta("cavalaria-e-escudos", "provocar-odio-soberano", { tipo = "efeito", acoes = 1, alcanceCasas = 32,
	exigeTalento = "talent/cavalaria-e-escudos/Principiante/puro-escudo", resistencia = teste("espirito", "vigor", 2),
	estados = { estado("odio", true, { de = "alvo", turnos = 2 }) } })

carta("arquearia", "disparo-duplo", { tipo = "ataque", acoes = 1, arma = true, armaADistancia = true, alcanceCasas = 12,
	alvo = "disparos", maxAlvos = 2, umaVezPorTurno = true, partes = armaNormal,
	segundoDisparo = { { arma = true, degrau = -1 } }, aplicaSeAmbos = "marcado",
	efeitoNoAcerto = { resistencia = teste("vigor", "agilidade"), estados = { estado("imovel", true) } },
	aviso = "Alcance de disparo desta fatia: 18 m (12 casas).", adaptacoes = { "Ficha v2 não exporta alcance da arma: 18 m provisórios." } })
carta("arquearia", "tiro-de-contencao", { tipo = "ataque", acoes = 1, arma = true, armaADistancia = true, alcanceCasas = 12,
	partes = { { arma = true, metade = true } }, efeitoNoAcerto = { resistencia = teste("vigor", "agilidade"), estados = { estado("metadeMovimento", true, { de = "alvo", turnos = 2 }) } },
	aviso = "Alcance de disparo desta fatia: 18 m (12 casas)." })
indisponivel("arquearia", { "tiro-de-objeto" }, "A grade ainda não representa objetos pequenos como alvos.")
indisponivel("arquearia", { "flecha-de-sinal" }, "Passiva: consulte a ficha.")
-- Árvores de utilidade (A20). Cartas "mesa/*" e números em Regras/Utilidades.
carta("furtividade-e-armadilhas", "primeiro-golpe", { tipo = "ataque", acoes = 1, arma = true, corpoACorpo = true, partes = armaNormal,
	primeiroGolpe = true, umaVezPorCombate = true,
	aviso = "Exige alvo Desprevenido (ainda não agiu, Surpreso ou você Escondido); Dano Furtivo triplicado." })
carta("bardo-e-interacao", "inspiracao", { tipo = "especial", especial = "inspirar", acoes = 1, alcanceCasas = 12, soAliados = true })
indisponivel("bardo-e-interacao", { "refrao-da-retomada" }, "Reação (1 PP): o jogo pergunta quando um aliado a até 9 m errar um ataque.")
indisponivel("navegacao-e-lideranca", { "primeiro-a-ver" }, "Passiva: no começo do Desafio, aliados somam seu Bônus de Rank na Iniciativa.")
return T
