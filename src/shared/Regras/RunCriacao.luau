-- Criação do personagem a cada run (PLANO §12). Pura: o gerador é injetado, nada é gravado.
-- Três modos, que o jogador escolhe antes de sortear:
--   zero      raça/antecedente à mão e uma OFERTA de árvores sorteada (peso pela força, ver RunArvoresForca);
--   semArvore começa sem árvore e ganha PA extra para comprar uma com um treinador depois;
--   pronto    uma ficha pronta (PersonagensProntos), mais PA, defeitos sorteados e recompensa maior no fim.
-- Os valores de PA e de recompensa são PROVISÓRIOS (balancear com jogo real). Hoje a Progressao usa
-- PA infinito, então o PA extra só é registrado, como o do dojo. Adaptação em docs/FIDELIDADE.md.
local Shared = game:GetService("ReplicatedStorage").Shared
local Sorteios = require(Shared.Regras.RunSorteios)
local Defeitos = require(Shared.Regras.RunDefeitos)
local Forca = require(Shared.Regras.RunArvoresForca)

local Criacao = {}

Criacao.MODOS = table.freeze({ "zero", "semArvore", "pronto" })

Criacao.PA_EXTRA_SEM_ARVORE = 2
Criacao.PA_EXTRA_PRONTO_BASE = 3
Criacao.PA_EXTRA_POR_DEFEITO = 1
Criacao.DEFEITOS_DO_PRONTO = 2
Criacao.RECOMPENSA_POR_DEFEITO = 0.25 -- multiplicador final = 1 + 0,25 por defeito

-- prontos = lista de PersonagensProntos ({ id, arvore, ... }). Só entram os de árvore elegível.
local function prontosElegiveis(prontos)
	local lista = {}
	for _, p in prontos do
		if type(p) == "table" and type(p.id) == "string" and Forca.elegivel(p.arvore) then
			table.insert(lista, { id = p.id, peso = Sorteios.pesoDeForca(Forca.forca(p.arvore)), arvore = p.arvore })
		end
	end
	table.sort(lista, function(a, b) return a.id < b.id end)
	return lista
end

function Criacao.paExtraDoPronto(quantidadeDeDefeitos)
	return Criacao.PA_EXTRA_PRONTO_BASE + Criacao.PA_EXTRA_POR_DEFEITO * quantidadeDeDefeitos
end

function Criacao.multiplicadorDeRecompensa(quantidadeDeDefeitos)
	return 1 + Criacao.RECOMPENSA_POR_DEFEITO * quantidadeDeDefeitos
end

-- Devolve o plano da criação, sem escolher nada pelo jogador:
--   zero      { modo, oferta = { idArvore... }, paExtra = 0, multiplicador = 1 }
--   semArvore { modo, paExtra, multiplicador = 1 }
--   pronto    { modo, prontoId, arvore, defeitos = { id... }, paExtra, multiplicador }
function Criacao.planejar(modo, rng, prontos)
	if type(rng) ~= "table" and typeof(rng) ~= "Random" then return nil, "Gerador ausente." end
	if modo == "zero" then
		local oferta, motivo = Sorteios.ofertaDeArvores(Forca.candidatas(), rng)
		if not oferta then return nil, motivo end
		return { modo = modo, oferta = oferta, paExtra = 0, multiplicador = 1 }
	elseif modo == "semArvore" then
		return { modo = modo, paExtra = Criacao.PA_EXTRA_SEM_ARVORE, multiplicador = 1 }
	elseif modo == "pronto" then
		if type(prontos) ~= "table" then return nil, "Fichas prontas ausentes." end
		local candidatos = prontosElegiveis(prontos)
		local sorteado = Sorteios.ponderado(candidatos, 1, rng)
		if not sorteado or sorteado[1] == nil then return nil, "Nenhuma ficha pronta elegível." end
		local escolhido
		for _, c in candidatos do
			if c.id == sorteado[1] then escolhido = c end
		end
		local defeitos, motivo = Defeitos.sortear(Criacao.DEFEITOS_DO_PRONTO, rng)
		if not defeitos then return nil, motivo end
		return {
			modo = modo, prontoId = escolhido.id, arvore = escolhido.arvore, defeitos = defeitos,
			paExtra = Criacao.paExtraDoPronto(#defeitos),
			multiplicador = Criacao.multiplicadorDeRecompensa(#defeitos),
		}
	end
	return nil, "Modo de criação desconhecido."
end

-- O jogador escolhe uma árvore da oferta. Fora dela, ou em outro modo, é recusado.
-- No modo "zero" o PA extra continua 0; a escolha só fixa a árvore inicial.
function Criacao.escolherArvore(plano, idArvore)
	if type(plano) ~= "table" or plano.modo ~= "zero" or type(plano.oferta) ~= "table" then
		return nil, "Só o modo 'zero' escolhe árvore da oferta."
	end
	for _, id in plano.oferta do
		if id == idArvore then return { arvore = id } end
	end
	return nil, "A árvore não está na oferta."
end

-- Efeitos dos defeitos do plano (Desvantagem, deslocamento, opções bloqueadas); vazio fora do modo pronto.
function Criacao.efeitos(plano)
	if type(plano) ~= "table" then return nil, "Plano inválido." end
	return Defeitos.efeitos(plano.defeitos or {})
end

-- Recompensa final da run ajustada pelo plano (arredonda para baixo; nunca menor que a base).
function Criacao.recompensaFinal(base, plano)
	if type(base) ~= "number" or base < 0 or type(plano) ~= "table" or type(plano.multiplicador) ~= "number" then
		return nil, "Recompensa inválida."
	end
	return math.max(base, math.floor(base * plano.multiplicador))
end

return Criacao
