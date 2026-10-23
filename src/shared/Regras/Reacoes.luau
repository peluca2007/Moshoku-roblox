-- Reações do Principiante (A14). Puro: quem pode reagir, a quê, e o que a
-- reação muda no efeito já rolado. O servidor (ReacoesService) pergunta ao
-- jogador e aplica. Não cria Instances nem envia eventos.
--
-- Livro, Cap. 4 §4: "3 Ações por turno e 1 Reação por rodada". A Reação volta
-- no início da sua vez. Desequilibrado tira toda Reação (nota do livro sobre a
-- condição); quem não age (sem Ações) também não reage.
local Progressao = require(game:GetService("ReplicatedStorage").Shared.Regras.Progressao)

local Reacoes = {}

-- Cartas de Reação (id do livro) e as maestrias que reagem sem gastar Reação.
Reacoes.CARTAS = table.freeze({
	aparar = "ability/deus-da-agua-corpo/Principiante/aparar",
	guardaDoCorpo = "ability/deus-da-agua-corpo/Principiante/guarda-do-corpo",
	couraca = "ability/terra/Principiante/couraca-de-barro",
	parede = "ability/teorica/Principiante/parede-de-emergencia",
})
Reacoes.CUSTO_PM = table.freeze({ couraca = 2, parede = 4 })
Reacoes.PV_DA_PAREDE = 15

local FISICOS = { cortante = true, perfurante = true, contundente = true }

-- Ataque físico: com arma ou com parcela cortante/perfurante/contundente.
-- Golpe de criatura (dano fixo sem tipo) conta como físico: adaptação, o
-- Apêndice G não tipa o dano por turno.
function Reacoes.fisico(mec): boolean
	if not mec then
		return false
	end
	if mec.arma or mec.criatura then
		return true
	end
	for _, parte in mec.partes or {} do
		if parte.arma or FISICOS[parte.tipo or ""] then
			return true
		end
	end
	return false
end

function Reacoes.corpoACorpo(mec): boolean
	return mec ~= nil and (mec.corpoACorpo == true or mec.tipo == "investida" or (mec.arma == true and not mec.armaADistancia))
end

-- O que a ficha sabe fazer como reação.
function Reacoes.daFicha(ficha2, catalogo): { [string]: boolean }
	local r = {}
	if not ficha2 or not ficha2.construction then
		return r
	end
	local conhecidas = Progressao.conhecidas(ficha2.construction, catalogo)
	for nome, id in Reacoes.CARTAS do
		if table.find(conhecidas, id) then
			r[nome] = true
		end
	end
	local c = ficha2.construction
	r.fluxo = Progressao.rankAberto(c, "deus-da-agua-corpo", "Principiante") or nil
	r.interpor = Progressao.rankAberto(c, "cavalaria-e-escudos", "Principiante") or nil
	if Reacoes.escudo(ficha2) then
		r.escudo = true
	end
	return r
end

-- Escudo empunhado: item equipado com "escudo" no nome (o inventário exportado
-- não tem tipo próprio para escudo; o kit do livro o exporta como armadura).
function Reacoes.escudo(ficha2): string?
	for _, item in (ficha2 and ficha2.construction and ficha2.construction.inventory) or {} do
		if item.equipped and type(item.name) == "string" and string.find(string.lower(item.name), "escudo", 1, true) then
			return item.name
		end
	end
	return nil
end

-- Proficiência em Escudos (Cap. 1 §4): Cavalaria (Interpor) e Deus do Norte
-- dão toda armadura e escudo. Sem proficiência, o bloqueio dá +2, não +5.
function Reacoes.proficienteEmEscudo(ficha2): boolean
	local c = ficha2 and ficha2.construction
	if not c then
		return false
	end
	return Progressao.rankAberto(c, "cavalaria-e-escudos", "Principiante") or Progressao.rankAberto(c, "deus-do-norte", "Principiante")
end

-- Aparar: soma o Bônus de Rank à CA contra aquele golpe, depois de ver a
-- rolagem. 20 natural acerta sempre; então só vira erro quem não é crítico.
function Reacoes.apararViraErro(ataque, bonusDeRank: number): boolean
	return ataque.acertou and not ataque.critico and ataque.total < ataque.defesa + bonusDeRank
end

-- Bloquear com Escudo (Cap. 4 §4): +5 CA (+2 sem proficiência) contra aquele
-- ataque; se ainda acertar, o dano cai 2 × o maior Bônus de Rank.
function Reacoes.bloqueio(ataque, proficiente: boolean, maiorRank: number): (boolean, number)
	local extra = if proficiente then 5 else 2
	local erra = ataque.acertou and not ataque.critico and ataque.total < ataque.defesa + extra
	return erra, if erra then 0 else 2 * maiorRank
end

-- Um acerto que a reação transformou em erro: nada do acerto acontece.
function Reacoes.anular(efeito, nota: string)
	if efeito.ataque then
		efeito.ataque.acertou = false
		efeito.ataque.critico = false
	end
	efeito.dano, efeito.aplica, efeito.estados, efeito.empurrar = nil, nil, nil, nil
	efeito.resistencia, efeito.quebrantado, efeito.doses = nil, nil, nil
	table.insert(efeito.notas, nota)
end

-- Reduz o dano já rolado (mínimo 0). Devolve quanto reduziu.
function Reacoes.reduzir(efeito, valor: number): number
	if not efeito.dano or valor <= 0 then
		return 0
	end
	local antes = efeito.dano.total
	efeito.dano.total = math.max(0, antes - valor)
	return antes - efeito.dano.total
end

-- Dano físico do golpe (Couraça de Barro: só contundente/cortante/perfurante).
function Reacoes.danoFisico(efeito, mec): boolean
	return efeito.dano ~= nil and efeito.dano.total > 0 and (FISICOS[efeito.dano.tipo or ""] or (efeito.dano.tipo == nil and Reacoes.fisico(mec)))
end

return Reacoes
