-- Esqueleto da história da primeira versão jogável (PLANO §12 "Primeira versão"; R7): vila → viagem →
-- 2 regiões à escolha, cada uma com um chefe → 1 final. PROVISÓRIO: títulos e textos são marcadores de
-- posição para o Pedro e as IAs reescreverem; a estrutura (trancas, prazo, finais) é o que está em teste.
-- Objetivo da run: levar de volta à vila o Selo do guardião de uma das regiões.
--
-- Trancas desta história (flags da run; o jogo as abre):
--   "passagem-aberta"  câmara do chefe das Ruínas; hoje abre pela escolha "forçar a passagem" (1 dia); habilidade de
--                      Terra e item-chave virão e abrirão a mesma flag sem gastar o dia.
--   "vencido/<no>"    marcada ao vencer a luta do chefe daquele nó (R7b); o Selo só pode ser pego depois.
--   "selo-obtido"      marcada ao pegar o Selo do chefe.
-- `luta` de um nó chefe = { criaturas = { id canônico... }, areaId }: o servidor monta o encontro J2 (para 1
-- jogador; o servidor escala a quantidade ao tamanho do grupo pelo orçamento do Apêndice G).
local Historia = {}

Historia.OBJETIVO = table.freeze({ id = "levar-o-selo-a-vila", prazoDias = 12 })

Historia.HISTORIA = table.freeze({
	id = "v1-selo-do-guardiao",
	inicio = "vila",
	nos = {
		["vila"] = { tipo = "vila", regiao = "vila", titulo = "A vila", opcoes = {
			{ id = "rumo-a-floresta", texto = "Seguir para a Floresta Sombria", para = "floresta-sombria", dias = 1 },
			{ id = "rumo-as-ruinas", texto = "Seguir para as Ruínas do Vale", para = "ruinas-do-vale", dias = 1 },
		} },
		["floresta-sombria"] = { tipo = "regiao", regiao = "floresta-sombria", titulo = "Floresta Sombria", opcoes = {
			{ id = "enfrentar-o-guardiao", texto = "Enfrentar o guardião da floresta", para = "chefe-floresta" },
			{ id = "voltar", texto = "Voltar à vila", para = "vila", dias = 1 },
		} },
		["ruinas-do-vale"] = { tipo = "regiao", regiao = "ruinas-do-vale", titulo = "Ruínas do Vale", opcoes = {
			{ id = "forcar-a-passagem", texto = "Forçar a passagem sob a pedra (escolha da história)", para = "ruinas-do-vale", dias = 1, marca = "passagem-aberta" },
			{ id = "entrar-na-camara", texto = "Entrar na câmara do guardião", para = "chefe-ruinas", exige = { flag = "passagem-aberta" } },
			{ id = "voltar", texto = "Voltar à vila", para = "vila", dias = 1 },
		} },
		["chefe-floresta"] = { tipo = "chefe", regiao = "floresta-sombria", titulo = "O guardião da floresta",
			luta = { criaturas = { "creature/urso-de-presas-vermelhas" }, areaId = "region/encounter/dark-forest" },
			opcoes = {
			{ id = "pegar-o-selo", texto = "Pegar o Selo e voltar", para = "retorno", marca = "selo-obtido", dias = 1, exige = { flag = "vencido/chefe-floresta" } },
		} },
		["chefe-ruinas"] = { tipo = "chefe", regiao = "ruinas-do-vale", titulo = "O bando que guarda as ruínas",
			luta = { criaturas = { "creature/goblin-batedor" }, areaId = "region/encounter/ruinas" },
			opcoes = {
			{ id = "pegar-o-selo", texto = "Pegar o Selo e voltar", para = "retorno", marca = "selo-obtido", dias = 1, exige = { flag = "vencido/chefe-ruinas" } },
		} },
		["retorno"] = { tipo = "viagem", regiao = "vila", titulo = "A volta para casa", opcoes = {
			{ id = "entregar-o-selo", texto = "Entregar o Selo na vila", para = "final-selo", exige = { flag = "selo-obtido" } },
		} },
		["final-selo"] = { tipo = "final", regiao = "vila", titulo = "O Selo volta para casa", cumpreObjetivo = true },
	},
})

return Historia
