-- Regra pura de missões da vila. Sem Instances nem rede; o estado nunca é alterado no lugar.
-- Missão (dados): { id, nome, npc, texto, objetivo = { tipo = "vencer-encontro", encontroId, quantidade },
--                   recompensa = { ouro = <PO> } }
-- Estado de uma missão para um jogador: { estado = "aceita" | "cumprida" | "entregue", progresso = <n> }
-- Estado do jogador: { [missaoId] = estadoDaMissao }
local Missao = {}

Missao.TIPOS = table.freeze({ ["vencer-encontro"] = true })
Missao.MAX_ATIVAS = 3

local function inteiro(v, minimo)
	return type(v) == "number" and v == v and v % 1 == 0 and v >= (minimo or 0)
end

function Missao.novoEstado()
	return {}
end

local function clonar(estado)
	local copia = {}
	for id, m in estado do copia[id] = table.clone(m) end
	return copia
end

function Missao.definicaoValida(m)
	return type(m) == "table" and type(m.id) == "string" and m.id ~= "" and type(m.nome) == "string"
		and type(m.npc) == "string" and type(m.objetivo) == "table"
		and Missao.TIPOS[m.objetivo.tipo] == true and type(m.objetivo.encontroId) == "string"
		and inteiro(m.objetivo.quantidade, 1) and type(m.recompensa) == "table" and inteiro(m.recompensa.ouro)
end

function Missao.estadoValido(estado, definicoes)
	if type(estado) ~= "table" then return false end
	for id, m in estado do
		if type(id) ~= "string" or type(m) ~= "table" then return false end
		if m.estado ~= "aceita" and m.estado ~= "cumprida" and m.estado ~= "entregue" then return false end
		if not inteiro(m.progresso) then return false end
		if definicoes and not definicoes[id] then return false end
	end
	return true
end

local function ativas(estado)
	local n = 0
	for _, m in estado do
		if m.estado == "aceita" or m.estado == "cumprida" then n += 1 end
	end
	return n
end

-- Situação para exibir: "disponivel", "aceita", "cumprida" ou "entregue".
function Missao.situacao(estado, missao)
	local m = estado[missao.id]
	return if m then m.estado else "disponivel"
end

-- Aceitar: (novoEstado) ou (nil, motivo). Uma vez por missão na vida do personagem.
function Missao.aceitar(estado, missao)
	if not Missao.estadoValido(estado) or not Missao.definicaoValida(missao) then return nil, "Dados inválidos." end
	if estado[missao.id] then return nil, "Você já aceitou esta missão." end
	if ativas(estado) >= Missao.MAX_ATIVAS then return nil, "Você já tem missões demais em andamento." end
	local novo = clonar(estado)
	novo[missao.id] = { estado = "aceita", progresso = 0 }
	return novo
end

-- Evento "encontro vencido": conta em toda missão aceita cujo objetivo aponta para ele.
-- Devolve (novoEstado, cumpridas) onde cumpridas = ids que passaram a "cumprida" agora.
function Missao.registrar(estado, definicoes, encontroId)
	if not Missao.estadoValido(estado) or type(definicoes) ~= "table" or type(encontroId) ~= "string" then
		return nil, nil
	end
	local novo, cumpridas = clonar(estado), {}
	for id, m in novo do
		local def = definicoes[id]
		if m.estado == "aceita" and def and def.objetivo.encontroId == encontroId then
			m.progresso = math.min(m.progresso + 1, def.objetivo.quantidade)
			if m.progresso >= def.objetivo.quantidade then
				m.estado = "cumprida"
				table.insert(cumpridas, id)
			end
		end
	end
	table.sort(cumpridas)
	return novo, cumpridas
end

-- Entregar: só missão cumprida, uma vez. Devolve (novoEstado, recompensa) ou (nil, nil, motivo).
function Missao.entregar(estado, missao)
	if not Missao.estadoValido(estado) or not Missao.definicaoValida(missao) then return nil, nil, "Dados inválidos." end
	local m = estado[missao.id]
	if not m then return nil, nil, "Você não aceitou esta missão." end
	if m.estado == "entregue" then return nil, nil, "Missão já entregue." end
	if m.estado ~= "cumprida" then return nil, nil, "A missão ainda não foi cumprida." end
	local novo = clonar(estado)
	novo[missao.id].estado = "entregue"
	return novo, { ouro = missao.recompensa.ouro }
end

return table.freeze(Missao)
