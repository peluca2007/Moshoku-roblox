-- Mecânicas executáveis da Magia de Fogo, rank Principiante (fatia jogável A1).
-- O catálogo traz o TEXTO do livro; a máquina precisa de estrutura. Cada entrada
-- cita o texto de origem (`livro`) e declara o que foi adaptado (`adaptacoes`),
-- para revisão de fidelidade (docs/FIDELIDADE.md). Só dados: o resolvedor é
-- genérico (Regras/Habilidades).
--
-- Campos:
--   tipo: "ataque" (d20 + BC contra a CA), "efeito" (teste de resistência de
--         cada alvo), "zona" (cria casas persistentes).
--   alcanceCasas, corpoACorpo, raioCasas, comprimentoCasas: geometria na grade.
--   dados: fórmulas de dano (sem o BC); somaBc: soma o BC ao dano.
--   condicional: dados extras e quando valem.
--   acoes, pm: custo (Ações do turno de 3; PM da reserva).
--   umaVezPorTurno, truque: limites.
--   aplica: condição aplicada ao acertar (ataque) ou ao falhar o teste (área).
local Fogo = {}

Fogo.ARVORE = "tree/fogo"
Fogo.RANK_PRINCIPIANTE = "rank/fogo/Principiante"

-- Em Chamas (condição do livro, Cap. 4): 1d6 ígneo no início de cada turno de
-- quem queima. O Intermediário (maestria Propagação) troca por 1d8: fora desta fatia.
Fogo.EM_CHAMAS = "em-chamas"
Fogo.DANO_EM_CHAMAS = "1d6"

Fogo.TIPO = "ígneo"

-- Maestria Chama Viva (Principiante): magia de Fogo causa dano CHEIO contra alvo
-- Em Chamas mesmo se ele passar no teste. O servidor passa isto ao resolvedor
-- (conjurador.danoCheioEmChamas). Nenhuma magia desta fatia é "metade no
-- sucesso" com dano, então hoje a regra só aparece no spec.
function Fogo.danoCheioEmChamas(ficha2): boolean
	return ficha2 ~= nil and table.find(ficha2.construction.unlockedRankIds, Fogo.RANK_PRINCIPIANTE) ~= nil
end

Fogo.MECANICAS = table.freeze({
	["ability/fogo/Principiante/brasa"] = table.freeze({
		tipo = "ataque",
		tipoDano = "ígneo",
		alcanceCasas = 6,
		dados = { "1d6" },
		somaBc = true,
		condicional = table.freeze({ dados = "1d4", quando = "alvoEmChamas" }),
		descricao = "1d6 + BC ígneo; +1d4 contra alvo Em Chamas. Prepare com Bola de Fogo ou Toque Escaldante e aproveite a Brasa na mesma vez. Uma vez por turno.",
		acoes = 1,
		pm = 0,
		umaVezPorTurno = true,
		truque = true,
		livro = "9 metros; 1 Ação; 0 PM; 1d6 + BC (ígneo); uma vez por turno; ataque mágico à distância. Truque da escola: vem com o Principiante.",
		adaptacoes = { "9 m = 6 casas de 1,5 m", "G5, autorização Pedro 10/10/2026: +1d4 ígneo contra alvo já Em Chamas ao acertar; parcela também dobra no crítico" },
	}),
	["ability/fogo/Principiante/bola-de-fogo"] = table.freeze({
		tipo = "ataque",
		tipoDano = "ígneo",
		alcanceCasas = 12,
		dados = { "1d8" },
		somaBc = true,
		acoes = 2,
		pm = 1,
		aplica = "em-chamas",
		livro = "18 metros; 2 Ações (Principiante); 1 PM; 1d8 + BC (ígneo); ataque mágico à distância; se acertar, o alvo fica Em Chamas.",
		adaptacoes = { "18 m = 12 casas", "Encurtada/Silenciosa não entram nesta fatia (sempre a forma normal)" },
	}),
	["ability/fogo/Principiante/fagulha"] = table.freeze({
		tipo = "zona",
		forma = "casa",
		estilo = "braseiro",
		alcanceCasas = 6,
		acoes = 1,
		pm = 1,
		duracaoRodadas = 2,
		danoAoAtravessar = { "1d4" },
		tipoDano = "ígneo",
		descricao = "Acende uma casa visível a até 6 casas por 2 rodadas. Entrar ou ser empurrado através dela causa 1d4 ígneo por movimento, inclusive em aliados. Não causa dano ao surgir nem aplica Em Chamas. Combine com empurrões; não bloqueia passagem ou visão.",
		livro = "9 metros; 1 Ação; 1 PM; sem dano direto: um ponto de calor acende qualquer coisa inflamável que você consiga ver.",
		adaptacoes = { "G5, autorização Pedro 10/10/2026: sem objetos inflamáveis, cria perigo de uma casa visível a até 6 casas por 2 rodadas", "1d4 ígneo ao entrar, uma vez por movimento, inclusive movimento forçado e aliados; sem dano na criação ou ao permanecer, sem Em Chamas, sem bloqueio; expira na troca de vez da rodada limite ou ao encerrar combate" },
	}),
	["ability/fogo/Principiante/toque-escaldante"] = table.freeze({
		tipo = "ataque",
		tipoDano = "ígneo",
		corpoACorpo = true,
		alcanceCasas = 1,
		dados = { "2d6" },
		somaBc = true,
		condicional = table.freeze({ dados = "1d6", quando = "metadePv" }),
		acoes = 2,
		pm = 2,
		aplica = "em-chamas",
		livro = "Toque; 2 Ações; 2 PM; 2d6 + BC (ígneo); ataque corpo a corpo mágico; aplica Em Chamas; +1d6 se você estiver com metade ou menos dos PV.",
		adaptacoes = { "Toque = casa vizinha, diagonal inclusive", "Em Chamas aplicada ao acertar" },
	}),
	["ability/fogo/Principiante/muro-de-chamas"] = table.freeze({
		moldavel = true,
		tipo = "zona",
		forma = "linhaDoConjurador",
		estilo = "fogo",
		comprimentoCasas = 6,
		acoes = 2,
		pm = 3,
		duracaoRodadas = 10,
		danoAoAtravessar = { "3d6" },
		tipoDano = "ígneo",
		aplica = "em-chamas",
		bloqueiaVisao = true,
		livro = "Linha de 9 metros; 2 Ações; 3 PM; parede de fogo de 3 m de altura por 1 minuto; 3d6 de dano ígneo a quem atravessa; atravessar aplica Em Chamas; bloqueia visão.",
		adaptacoes = {
			"G12, Pedro 10/10/2026: linha reta ajustável de 1 a 6 casas, começando numa casa vizinha ao conjurador, nas 8 direções; prévia, escolha do fim e confirmação; não atravessa terreno de parede; pode cruzar outro muro. Pedido antigo só com x,z mantém linha de 6 casas na direção escolhida, cortada na borda/parede",
			"1 minuto = 10 rodadas",
			"Entrar numa casa do muro = atravessar: cobra uma vez por movimento, e de novo a cada movimento que entrar outra vez; quem já está na linha ao erguê-la não sofre dano",
			"Dura até a primeira troca de vez na rodada em que se completam 10 rodadas; some ao fim do combate",
		},
	}),
	["ability/fogo/Principiante/clarao"] = table.freeze({
		tipo = "efeito",
		alvo = "esferaNoConjurador",
		raioCasas = 4,
		acoes = 1,
		pm = 1,
		resistencia = table.freeze({ atributo = "vigor", cdBase = 8 }),
		aplica = "cego",
		duracao = { de = "alvo" },
		livro = "Esfera de 6 m de raio; 1 Ação; 1 PM; Teste de Resistência de Vigor (CD 8 + BC) ou o alvo fica Cego até o fim do próximo turno. Sem dano.",
		adaptacoes = {
			"Esfera centrada no conjurador, que não é atingido; 6 m = raio de 4 casas, medido em linha reta entre centros (círculo na grade)",
			"Atinge todas as outras fichas no raio com linha de visão do conjurador (parede e muro bloqueiam a luz), aliados inclusive",
			"Cego dura até o fim do próximo turno do alvo que começar depois da aplicação; o fim do combate encerra",
		},
	}),
})

-- Habilidades de Fogo que a ficha v2 pode usar: o truque vem com o rank
-- Principiante; as demais precisam estar compradas (construction.purchasedIds).
function Fogo.habilidadesDe(ficha2): { string }
	local lista = {}
	if not ficha2 or not ficha2.construction then
		return lista
	end
	local construcao = ficha2.construction
	if table.find(construcao.unlockedRankIds, Fogo.RANK_PRINCIPIANTE) then
		table.insert(lista, "ability/fogo/Principiante/brasa")
	end
	for _, id in construcao.purchasedIds do
		if Fogo.MECANICAS[id] and not table.find(lista, id) then
			table.insert(lista, id)
		end
	end
	return lista
end

return Fogo
