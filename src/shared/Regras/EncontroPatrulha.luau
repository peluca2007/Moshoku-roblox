-- Regras puras do encontro por patrulha (PLANO §12, "Encontro estilo Pokémon"; R2b): surpresa, ordem
-- com surpresa, fuga e quem entra na grade. O cone de visão fica em server/Mundo/Patrulha.dentroDoCone. Sem Instances nem rede; o gerador é injetado.
-- Base no livro: "Desprevenido" = o alvo ainda não agiu no combate, está Surpreso ou não sabe onde você
-- está (Condicoes). Constantes marcadas PROVISÓRIO são adaptações do jogo (docs/FIDELIDADE.md "R2b").
local Patrulha = {}

-- Fuga: CD base 10 e +1 por casa (1,5 m) de deslocamento que o perseguidor mais rápido tem a mais. PROVISÓRIO.
Patrulha.CD_FUGA_BASE = 10
Patrulha.METROS_POR_CASA = 1.5
Patrulha.CD_FUGA_MAXIMA = 25

-- Quem surpreende ao começar o encontro? `visto` = a criatura já detectou o jogador (perseguia).
-- Jogador que inicia o contato sem ter sido visto surpreende; grupo liderado por Explorador
-- (Navegação e Liderança) nunca é surpreendido, mas isso só impede surpresa CONTRA o grupo.
-- Devolve "jogadores" (inimigos Desprevenidos), "inimigos" (jogadores Desprevenidos) ou nil.
function Patrulha.surpresa(visto, iniciouPeloJogador, grupoComExplorador, emboscada)
	if emboscada == true and grupoComExplorador ~= true then return "inimigos" end
	if iniciouPeloJogador == true and visto ~= true then return "jogadores" end
	return nil
end

-- ordem = { { id, lado = "jogador"|"criatura" }... } já rolada (RB-13). Com surpresa, o lado que
-- surpreende age primeiro na 1ª rodada; a ordem interna de cada lado é preservada.
-- Devolve nova lista e o conjunto de ids Desprevenidos (o lado surpreendido).
function Patrulha.ordemComSurpresa(ordem, ladoSurpreendido)
	if type(ordem) ~= "table" then return nil, nil, "Ordem inválida." end
	local desprevenidos, primeiros, depois = {}, {}, {}
	for _, ator in ordem do
		if type(ator) ~= "table" or type(ator.id) ~= "string" or (ator.lado ~= "jogador" and ator.lado ~= "criatura") then
			return nil, nil, "Ator inválido."
		end
		if ator.lado == ladoSurpreendido then
			desprevenidos[ator.id] = true
			table.insert(depois, ator)
		else
			table.insert(primeiros, ator)
		end
	end
	if ladoSurpreendido ~= "jogador" and ladoSurpreendido ~= "criatura" then
		return table.clone(ordem), {}
	end
	local nova = {}
	for _, a in primeiros do table.insert(nova, a) end
	for _, a in depois do table.insert(nova, a) end
	return nova, desprevenidos
end

-- Dificuldade da fuga: o perseguidor mais rápido manda. Deslocamentos em metros.
function Patrulha.cdDeFuga(deslocamentoDoFugitivo, deslocamentosDosPerseguidores)
	if type(deslocamentoDoFugitivo) ~= "number" or type(deslocamentosDosPerseguidores) ~= "table"
		or #deslocamentosDosPerseguidores < 1 then return nil end
	local maisRapido = 0
	for _, d in deslocamentosDosPerseguidores do
		if type(d) ~= "number" or d < 0 then return nil end
		maisRapido = math.max(maisRapido, d)
	end
	local casasAMais = math.max(0, math.floor((maisRapido - deslocamentoDoFugitivo) / Patrulha.METROS_POR_CASA))
	return math.min(Patrulha.CD_FUGA_MAXIMA, Patrulha.CD_FUGA_BASE + casasAMais)
end

-- Teste de fuga: d20 + bônus de Atletismo contra o CD; 20 natural foge sempre, 1 natural sempre falha.
-- Falhar custa o turno; fugir encerra o encontro e a criatura volta a patrulhar.
function Patrulha.fuga(rng, bonusAtletismo, deslocamentoDoFugitivo, deslocamentosDosPerseguidores)
	if type(rng) ~= "table" and typeof(rng) ~= "Random" then return nil, "Gerador ausente." end
	if type(bonusAtletismo) ~= "number" or bonusAtletismo % 1 ~= 0 or bonusAtletismo < -50 or bonusAtletismo > 50 then
		return nil, "Bônus inválido."
	end
	local cd = Patrulha.cdDeFuga(deslocamentoDoFugitivo, deslocamentosDosPerseguidores)
	if not cd then return nil, "Dados de fuga inválidos." end
	local natural = rng:NextInteger(1, 20)
	local total = natural + bonusAtletismo
	local fugiu = natural == 20 or (natural ~= 1 and total >= cd)
	return { fugiu = fugiu, natural = natural, total = total, cd = cd, perdeTurno = not fugiu }
end

-- Quem está onde em relação à grade que nasceu no local do encontro. Distâncias em metros no plano.
-- "dentro" entra já; "ao-pisar" entra no começo da rodada seguinte ao pisar na grade; "fora" ainda não.
-- raioDeEntrada = quem está tão perto quanto isso do centro entra no começo. PROVISÓRIO: definido pelo servidor.
function Patrulha.situacaoNaGrade(distanciaAoCentro, raioDaGrade, raioDeEntrada)
	if type(distanciaAoCentro) ~= "number" or type(raioDaGrade) ~= "number" or type(raioDeEntrada) ~= "number"
		or distanciaAoCentro < 0 or raioDeEntrada > raioDaGrade then return nil end
	if distanciaAoCentro <= raioDeEntrada then return "dentro" end
	if distanciaAoCentro <= raioDaGrade then return "ao-pisar" end
	return "fora"
end

return Patrulha
