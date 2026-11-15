-- Decide o que a interface da expedição mostra a partir da `visao` do RunSessao e do estado local.
-- Módulo puro: não cria Instances nem envia eventos; a ExpedicaoView só monta o que isto devolve.
--
-- estado local = { emCombate?, portaAberta?, levantadoEm? (galho cujo acampamento já foi levantado) }
-- decidir(visao, estado, nomeDe?) -> { faixa?, tela, ... }
--   tela: "nenhuma" | "luta" | "porta" | "acampamento" | "escolhas"
local ExpedicaoTela = {}

local ID_VOLTAR = "voltar-a-cidade"

-- 0.5 -> "meio dia"; 1 -> "1 dia"; 1.5 -> "1,5 dia"; 2 -> "2 dias". nil se não custa nada.
function ExpedicaoTela.custoEmDias(dias)
	if type(dias) ~= "number" or dias <= 0 then return nil end
	if dias == 0.5 then return "meio dia" end
	if dias == 1 then return "1 dia" end
	if dias == math.floor(dias) then return string.format("%d dias", dias) end
	return (string.format("%.1f", dias):gsub("%.", ",")) .. " dias"
end

function ExpedicaoTela.nomeDaArea(area)
	if type(area) ~= "string" or area == "" then return nil end
	local nome = area:gsub("[-_]", " ")
	return nome:sub(1, 1):upper() .. nome:sub(2)
end

local function restantes(dias)
	if type(dias) ~= "number" then return nil end
	local texto = if dias == math.floor(dias) then string.format("%d", dias) else (string.format("%.1f", dias):gsub("%.", ","))
	return if dias == 1 then "falta 1 dia" else "faltam " .. texto .. " dias"
end

-- Faixa do topo: "Dia 3 · faltam 9 dias" e, dentro da área, "Sala 2/5 · Esgoto".
function ExpedicaoTela.faixa(visao)
	if type(visao) ~= "table" or visao.semRun or visao.erro or type(visao.dia) ~= "number" then return nil end
	local partes = { string.format("Dia %d", math.floor(visao.dia) + 1) }
	local falta = restantes(visao.diasRestantes)
	if falta then table.insert(partes, falta) end
	local contador
	if visao.area and type(visao.passo) == "number" and type(visao.totalPassos) == "number" then
		contador = string.format("Sala %d/%d · %s", visao.passo, visao.totalPassos, ExpedicaoTela.nomeDaArea(visao.area) or "")
	end
	return { dia = table.concat(partes, " · "), contador = contador }
end

local function ehHub(visao) return visao.tipoDoNo == "hub" end

local function lugar(visao)
	return { galho = visao.galho, luta = visao.fase == "luta" }
end

-- Tela "Viajando…": o nó mudou ou a fase entrou/saiu de "luta". Devolve (viajar, nova memória).
function ExpedicaoTela.viajar(anterior, visao)
	if type(visao) ~= "table" or visao.semRun or visao.erro or visao.galho == nil then return false, anterior end
	local agora = lugar(visao)
	if anterior == nil then return false, agora end
	return anterior.galho ~= agora.galho or anterior.luta ~= agora.luta, agora
end

local function cartao(op, visao, grupoGrande)
	local votos = visao.contagem and visao.contagem[op.id] or 0
	return {
		id = op.id, titulo = op.texto, dica = op.dica, custo = ExpedicaoTela.custoEmDias(op.dias),
		liberada = op.liberada == true, motivo = op.motivo, votada = visao.votei == op.id,
		votos = if grupoGrande and votos > 0 then votos else nil,
	}
end

local function opcoes(visao, filtro)
	local grupoGrande = #(visao.grupo or {}) > 1
	local cartoes = {}
	for _, op in visao.opcoes or {} do
		if filtro(op) then table.insert(cartoes, cartao(op, visao, grupoGrande)) end
	end
	return cartoes
end

-- Quem falta votar, só em grupo; em jogo solo o voto resolve na hora.
local function votacao(visao, nomeDe)
	if #(visao.grupo or {}) <= 1 or not visao.aguardando or #visao.aguardando == 0 then return nil end
	local nomes = {}
	for _, id in visao.aguardando do table.insert(nomes, if nomeDe then nomeDe(id) else tostring(id)) end
	return "Aguardando voto: " .. table.concat(nomes, ", ")
end

local function membros(visao, nomeDe)
	local lista = {}
	for _, m in visao.grupo or {} do
		local nome = if nomeDe then nomeDe(m.userId) else tostring(m.userId)
		table.insert(lista, if m.presente == false then nome .. " (ausente)" elseif m.caido then nome .. " (caído)" else nome)
	end
	return lista
end

function ExpedicaoTela.decidir(visao, estado, nomeDe)
	estado = estado or {}
	local faixa = ExpedicaoTela.faixa(visao)
	local saida = { faixa = faixa, tela = "nenhuma" }
	if not faixa or visao.fim then return saida end
	if estado.emCombate == true or visao.fase == "luta" or visao.luta then saida.tela = "luta"; return saida end
	saida.votacao = votacao(visao, nomeDe)
	if ehHub(visao) then
		if estado.portaAberta == true then
			saida.tela = "porta"
			saida.cartoes = opcoes(visao, function(op) return op.id ~= ID_VOLTAR end)
		end
		return saida
	end
	if not visao.area then return saida end
	local voltar
	for _, op in visao.opcoes or {} do
		if op.id == ID_VOLTAR then
			local custo = ExpedicaoTela.custoEmDias(op.dias)
			voltar = { id = op.id, texto = if custo then "Voltar à cidade (" .. custo .. ")" else "Voltar à cidade", liberada = op.liberada == true }
		end
	end
	saida.voltar = voltar
	if visao.fase == "acampamento" and estado.levantadoEm ~= visao.galho then
		saida.tela = "acampamento"
		saida.grupo = membros(visao, nomeDe)
		local d = visao.descansos
		if d then
			saida.descansar = { texto = string.format("Descansar · meio dia · %d/%d", d.usados, d.max), desabilitado = d.usados >= d.max }
		end
		return saida
	end
	saida.tela = "escolhas"
	saida.cartoes = opcoes(visao, function(op) return op.id ~= ID_VOLTAR end)
	return saida
end

function ExpedicaoTela.avisoConcluida(dado)
	local ouro = type(dado) == "table" and type(dado.ouro) == "number" and dado.ouro or 0
	return { titulo = "Expedição concluída", detalhe = if ouro > 0 then string.format("+%d de ouro", ouro) else "De volta à cidade." }
end

return ExpedicaoTela
