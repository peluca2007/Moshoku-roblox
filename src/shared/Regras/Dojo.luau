-- Regra pura do Dojo (Cap. 5, §5; fonte: ../Moshoku tensei rpg/src/data/dojos.ts).
-- Sem Instances nem rede. O estado é uma tabela simples e nunca é alterado no lugar:
-- toda função devolve um estado novo. A provação em si (a cena) fica em outro módulo;
-- aqui só se decide quem pode tentar, quanto vale concluir e o que fica registrado.
--
-- estado = {
--   provacoes = { [arvore] = { escolha = "pa" | "marca", patamar = <nome> } },
--   marcaRetorno = { [arvore] = true },   -- a segunda provação da Marca já foi usada
--   paTravado = { [arvore] = <n> },       -- PA travado ganho no dojo, preso à árvore
--   paLivre = <n>,                        -- PA livre acumulado; Progressao ainda usa PA infinito
-- }
local Dojo = {}

Dojo.REQUISITO_DE_PATAMAR = 2

Dojo.PATAMARES = table.freeze({ "Principiante", "Intermediário", "Avançado", "Santo", "Rei", "Imperador", "Deus" })

local INDICE = {}
for i, nome in ipairs(Dojo.PATAMARES) do INDICE[nome] = i end

-- Quanto vale concluir, por patamar do ALUNO (RECOMPENSA_POR_PATAMAR do livro).
local RECOMPENSA = {
	{ ate = 2, travados = 2, livre = 1 },
	{ ate = 4, travados = 3, livre = 2 },
	{ ate = 7, travados = 4, livre = 2 },
}

function Dojo.indice(patamar)
	return INDICE[patamar]
end

function Dojo.novoEstado()
	return { provacoes = {}, marcaRetorno = {}, paTravado = {}, paLivre = 0 }
end

local function clonar(estado)
	local copia = Dojo.novoEstado()
	for arvore, p in estado.provacoes do copia.provacoes[arvore] = table.clone(p) end
	for arvore, v in estado.marcaRetorno do copia.marcaRetorno[arvore] = v end
	for arvore, v in estado.paTravado do copia.paTravado[arvore] = v end
	copia.paLivre = estado.paLivre or 0
	return copia
end

function Dojo.estadoValido(estado)
	if type(estado) ~= "table" or type(estado.provacoes) ~= "table"
		or type(estado.marcaRetorno) ~= "table" or type(estado.paTravado) ~= "table"
		or (estado.paLivre ~= nil and (type(estado.paLivre) ~= "number" or estado.paLivre < 0
			or estado.paLivre % 1 ~= 0)) then
		return false
	end
	for arvore, p in estado.provacoes do
		if type(arvore) ~= "string" or type(p) ~= "table" or (p.escolha ~= "pa" and p.escolha ~= "marca")
			or INDICE[p.patamar] == nil then
			return false
		end
	end
	for arvore, v in estado.paTravado do
		if type(arvore) ~= "string" or type(v) ~= "number" or v < 0 or v % 1 ~= 0 then return false end
	end
	return true
end

-- O mestre precisa estar pelo menos 2 patamares acima do aluno; divindades ensinam qualquer um.
-- `mestre` = { patamar = <nome>, divino = bool?, saltoNarrativo = bool? }.
function Dojo.podeEnsinar(mestre, patamarDoAluno)
	if type(mestre) ~= "table" or INDICE[patamarDoAluno] == nil then return false, "dados inválidos" end
	if mestre.divino then return true end
	local m = INDICE[mestre.patamar]
	if m == nil then return false, "patamar do mestre desconhecido" end
	local folga = m - INDICE[patamarDoAluno]
	if folga >= Dojo.REQUISITO_DE_PATAMAR or (mestre.saltoNarrativo and folga >= 1) then return true end
	return false, "O mestre precisa estar dois patamares acima de você."
end

function Dojo.recompensa(patamarDoAluno)
	local i = INDICE[patamarDoAluno]
	if not i then return nil end
	for _, faixa in ipairs(RECOMPENSA) do
		if i <= faixa.ate then return { travados = faixa.travados, livre = faixa.livre } end
	end
	return nil
end

-- Pode tentar a provação desta árvore agora? Uma por árvore na vida do personagem;
-- a Marca do Mestre garante UMA segunda provação, que só oferece a porta do PA livre.
function Dojo.podeIniciar(estado, arvore, mestre, patamarDoAluno)
	if not Dojo.estadoValido(estado) or type(arvore) ~= "string" or arvore == "" then
		return nil, "dados inválidos"
	end
	local ok, motivo = Dojo.podeEnsinar(mestre, patamarDoAluno)
	if not ok then return nil, motivo end
	local anterior = estado.provacoes[arvore]
	if not anterior then return { modo = "primeira" } end
	if anterior.escolha == "marca" and not estado.marcaRetorno[arvore] then
		return { modo = "retorno" }
	end
	return nil, "Você já passou pela provação desta árvore."
end

-- Conclui a provação e devolve (novoEstado, ganho) ou (nil, nil, motivo). O Dilema do livro
-- tem três portas: "travado" (PA presos à árvore), "livre" (menos PA, usáveis em qualquer
-- árvore) e "marca" (nenhum PA; Maestria do mestre e direito de voltar uma vez).
function Dojo.concluir(estado, arvore, mestre, patamarDoAluno, porta)
	local permissao, motivo = Dojo.podeIniciar(estado, arvore, mestre, patamarDoAluno)
	if not permissao then return nil, nil, motivo end
	local valor = Dojo.recompensa(patamarDoAluno)
	if not valor then return nil, nil, "patamar sem recompensa" end
	local novo = clonar(estado)
	if permissao.modo == "retorno" then
		-- A segunda provação só oferece a porta do PA livre do patamar de então.
		if porta ~= "livre" then return nil, nil, "A segunda provação só oferece PA livre." end
		novo.marcaRetorno[arvore] = true
		novo.paLivre += valor.livre
		return novo, { livre = valor.livre, travados = 0, marca = false }
	end
	if porta == "travado" then
		novo.provacoes[arvore] = { escolha = "pa", patamar = patamarDoAluno }
		novo.paTravado[arvore] = (novo.paTravado[arvore] or 0) + valor.travados
		return novo, { livre = 0, travados = valor.travados, marca = false }
	elseif porta == "livre" then
		novo.provacoes[arvore] = { escolha = "pa", patamar = patamarDoAluno }
		novo.paLivre += valor.livre
		return novo, { livre = valor.livre, travados = 0, marca = false }
	elseif porta == "marca" then
		novo.provacoes[arvore] = { escolha = "marca", patamar = patamarDoAluno }
		return novo, { livre = 0, travados = 0, marca = true }
	end
	return nil, nil, "Escolha inválida."
end

-- PA travado morre com a árvore abandonada (o livro: nunca destrava).
function Dojo.abandonar(estado, arvore)
	local novo = clonar(estado)
	novo.paTravado[arvore] = nil
	return novo
end

return table.freeze(Dojo)
