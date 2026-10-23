-- Progresso da CONTA entre runs (PLANO §12, R6): moeda, desbloqueios, conquistas e códice.
-- Puro e imutável: toda função devolve uma conta nova (ou nil + motivo). Cosméticos entram como desbloqueios
-- do tipo "cosmetico". Valores e catálogo PROVISÓRIOS (docs/FIDELIDADE.md "R6a"); o servidor guarda e valida.
local Shared = game:GetService("ReplicatedStorage").Shared
local Criacao = require(Shared.Regras.RunCriacao)
local Treinadores = require(Shared.Regras.RunTreinadores)

local Beneficios = require(Shared.Regras.RunBeneficiosConta)

local Conta = {}
local AparenciaCatalogo = require(Shared.Aparencia.Catalogo)

Conta.VERSAO = 1

-- Moeda ganha ao fim da run, antes do multiplicador dos defeitos do personagem pronto.
Conta.MOEDA_FINAL = 100
Conta.MOEDA_DERROTA_BASE = 20
Conta.MOEDA_POR_REGIAO = 10
Conta.MOEDA_OBJETIVO_CUMPRIDO = 30

-- id = "<tipo>:<nome>"; tipo: treinador (nome = id da árvore), raca, item, cosmetico.
-- Treinadores raros começam bloqueados e entram no sorteio da taverna só depois de comprados.
Conta.CATALOGO = table.freeze({
	["treinador:agua"] = { custo = 150, tipo = "treinador", titulo = "Treinador de Água", efeito = "Pode aparecer no sorteio da taverna nas runs iniciadas por esta conta; não garante presença." },
	["treinador:desintoxicacao"] = { custo = 150, tipo = "treinador", titulo = "Treinador de Desintoxicação", efeito = "Pode aparecer no sorteio da taverna nas runs iniciadas por esta conta; não garante presença." },
	["treinador:terra"] = { custo = 150, tipo = "treinador", titulo = "Treinador de Terra", efeito = "Pode aparecer no sorteio da taverna nas runs iniciadas por esta conta; não garante presença." },
	["treinador:deus-do-norte"] = { custo = 200, tipo = "treinador", titulo = "Treinador de Deus do Norte", efeito = "Pode aparecer no sorteio da taverna nas runs iniciadas por esta conta; não garante presença." },
	["treinador:deus-da-espada"] = { custo = 200, tipo = "treinador", titulo = "Treinador de Deus da Espada", efeito = "Pode aparecer no sorteio da taverna nas runs iniciadas por esta conta; não garante presença." },
	["raca:rara"] = { custo = 250, tipo = "raca", titulo = "Raças raras", efeito = "Libera Celestial, Superd e Ogro na criação; custos de PA do livro preservados." },
	["item:pocao-menor"] = { custo = 60, tipo = "item", titulo = "Poção Menor de Cura inicial", efeito = "Uma Poção Menor de Cura extra por personagem criado em cada run." },
	["cosmetico:capa-vermelha"] = { custo = 40, tipo = "cosmetico", titulo = "Capa vermelha", efeito = "Registro cosmético na conta; aparência futura, sem efeito mecânico." },
})

-- Conquistas por condição sobre o resumo da run: { campo, igual | minimo }. PROVISÓRIO.
Conta.CONQUISTAS = table.freeze({
	["primeiro-final"] = { titulo = "Primeiro final", campo = "status", igual = "final" },
	["no-prazo"] = { titulo = "No prazo", campo = "objetivoCumprido", igual = true },
	["explorador"] = { titulo = "Cartógrafo", campo = "regioesVisitadas", minimo = 3 },
	["com-defeitos"] = { titulo = "Apesar dos defeitos", campo = "defeitos", minimo = 2, exigeFinal = true },
})

Conta.CATEGORIAS_CODICE = table.freeze({ "lore", "criatura", "final" })

function Conta.nova()
	return { versao = Conta.VERSAO, moeda = 0, desbloqueios = {}, conquistas = {}, codice = { lore = {}, criatura = {}, final = {} } }
end

-- Campo opcional preserva contas antigas: um final antigo também prova uma run encerrada.
function Conta.modosLiberados(conta)
	return type(conta) == "table" and (conta.primeiraRunTerminada == true
		or (type(conta.conquistas) == "table" and conta.conquistas["primeiro-final"] == true))
end

-- A cena de abertura só toca na primeira vez; ver ou pular grava a marca uma única vez (idempotente).
function Conta.aberturaVista(conta)
	return type(conta) == "table" and conta.aberturaVista == true
end

function Conta.marcarAberturaVista(conta)
	if type(conta) ~= "table" or conta.aberturaVista == true then return conta end
	local nova = table.clone(conta)
	nova.aberturaVista = true
	return nova
end

local function clonar(conta)
	local c = table.clone(conta)
	c.desbloqueios = table.clone(conta.desbloqueios)
	c.conquistas = table.clone(conta.conquistas)
	c.codice = { lore = table.clone(conta.codice.lore), criatura = table.clone(conta.codice.criatura), final = table.clone(conta.codice.final) }
	return c
end

function Conta.valida(conta)
	if type(conta) == "table" and ((conta.primeiraRunTerminada ~= nil and type(conta.primeiraRunTerminada) ~= "boolean")
		or (conta.aberturaVista ~= nil and type(conta.aberturaVista) ~= "boolean")) then return false end
	if type(conta) ~= "table" or conta.versao ~= Conta.VERSAO or type(conta.moeda) ~= "number" or conta.moeda < 0
		or conta.moeda % 1 ~= 0 or type(conta.desbloqueios) ~= "table" or type(conta.conquistas) ~= "table"
		or type(conta.codice) ~= "table" then return false end
	for _, categoria in Conta.CATEGORIAS_CODICE do
		if type(conta.codice[categoria]) ~= "table" then return false end
	end
	if conta.cosmeticos ~= nil then
		if type(conta.cosmeticos) ~= "table" then return false end
		for id, valor in conta.cosmeticos do
			local p = AparenciaCatalogo.PECAS[id]
			if not p or p.raridade ~= "rara" or valor ~= true then return false end
		end
	end
	if conta.lootChefes ~= nil then
		if type(conta.lootChefes) ~= "table" or #conta.lootChefes > 128 then return false end
		local n = 0
		for k, id in conta.lootChefes do
			n += 1
			if type(k) ~= "number" or k % 1 ~= 0 or k < 1 or k > #conta.lootChefes or type(id) ~= "string" or #id > 160 then return false end
		end
		if n ~= #conta.lootChefes then return false end
	end
	return true
end

-- resumo = { status = "final"|"derrota", objetivoCumprido = bool, regioesVisitadas = n, plano = plano de RunCriacao|nil }
function Conta.moedaDaRun(resumo)
	if type(resumo) ~= "table" or (resumo.status ~= "final" and resumo.status ~= "derrota") then return nil, "Resumo inválido." end
	local regioes = resumo.regioesVisitadas
	if type(regioes) ~= "number" or regioes < 0 or regioes % 1 ~= 0 then return nil, "Regiões inválidas." end
	local base = if resumo.status == "final" then Conta.MOEDA_FINAL else Conta.MOEDA_DERROTA_BASE
	base += regioes * Conta.MOEDA_POR_REGIAO
	if resumo.objetivoCumprido == true then base += Conta.MOEDA_OBJETIVO_CUMPRIDO end
	if resumo.plano ~= nil then return Criacao.recompensaFinal(base, resumo.plano) end
	return base
end

function Conta.conquistasDoResumo(conta, resumo)
	local novas = {}
	for id, c in Conta.CONQUISTAS do
		if not conta.conquistas[id] and not (c.exigeFinal and resumo.status ~= "final") then
			local valor = if c.campo == "defeitos" then (resumo.plano and resumo.plano.defeitos and #resumo.plano.defeitos or 0) else resumo[c.campo]
			local cumpriu = if c.igual ~= nil then valor == c.igual else (type(valor) == "number" and valor >= c.minimo)
			if cumpriu then table.insert(novas, id) end
		end
	end
	table.sort(novas)
	return novas
end

-- Aplica o fim da run: moeda + conquistas novas + final no códice. Devolve (conta, { moeda, conquistas }).
function Conta.registrarRun(conta, resumo, finalId)
	if not Conta.valida(conta) then return nil, "Conta inválida." end
	local moeda, motivo = Conta.moedaDaRun(resumo)
	if not moeda then return nil, motivo end
	local nova = clonar(conta)
	nova.moeda += moeda
	nova.primeiraRunTerminada = true
	local ganhas = Conta.conquistasDoResumo(conta, resumo)
	for _, id in ganhas do nova.conquistas[id] = true end
	if resumo.status == "final" and type(finalId) == "string" and finalId ~= "" then nova.codice.final[finalId] = true end
	return nova, { moeda = moeda, conquistas = ganhas }
end

function Conta.comprar(conta, id)
	if not Conta.valida(conta) then return nil, "Conta inválida." end
	local item = Conta.CATALOGO[id]
	if not item then return nil, "Item desconhecido." end
	if conta.desbloqueios[id] then return nil, "Já desbloqueado." end
	if conta.moeda < item.custo then return nil, "Moeda insuficiente." end
	local nova = clonar(conta)
	nova.moeda -= item.custo
	nova.desbloqueios[id] = true
	return nova
end

function Conta.registrarNoCodice(conta, categoria, id)
	if not Conta.valida(conta) or conta.codice[categoria] == nil then return nil, "Categoria inválida." end
	if type(id) ~= "string" or id == "" then return nil, "Entrada inválida." end
	local nova = clonar(conta)
	nova.codice[categoria][id] = true
	return nova
end

-- Árvores cujos treinadores podem entrar no sorteio desta conta: as comuns sempre; as raras só se compradas.
function Conta.treinadoresLiberados(conta)
	local liberadas = {}
	for _, c in Treinadores.candidatos() do
		if not c.soTaverna or (conta and conta.desbloqueios and conta.desbloqueios["treinador:" .. c.id]) then
			liberadas[c.id] = true
		end
	end
	return liberadas
end

Conta.racasLiberadas = Beneficios.racasLiberadas

return Conta
