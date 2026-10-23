-- Estado puro de uma run (PLANO §12; contrato em docs/JOGO.md "Run").
-- Sem Instances nem rede. O estado nunca é alterado no lugar: toda função devolve um estado novo.
--
-- estado = {
--   versao, semente,
--   jogadores = { [id] = { presente = bool, caido = bool, ausenteDesde = dia|nil } },
--   dia = <dias de jogo decorridos; múltiplos de 0,25>,
--   objetivo = { id, prazoFinal = <dia>, status = "ativo"|"expirado"|"cumprido" },
--   objetivosPerdidos = { <id>... },
--   regiao = <id>, galho = <id>,
--   visitadas = { [regiao] = true },   -- regiões já pisadas (conta para a moeda da conta); ausente em saves antigos
--   flags = { [nome] = true },   -- trancas abertas (item, habilidade, escolha, desbloqueio)
--   fim = nil | { motivo = "queda"|"final", final = <id>|nil, dia },
-- }
local Run = {}
local Cacadas = require(game:GetService("ReplicatedStorage").Shared.Regras.Cacadas)

Run.VERSAO = 1
Run.MAX_JOGADORES = 4

-- Custos em dias de jogo. PROVISÓRIOS: balancear com o ritmo real dos eventos.
-- O dojo não aparece aqui: cada treinador informa o próprio custo (1 dia ou mais).
Run.CUSTO_DIAS = table.freeze({
	evento = 0.5,
	viagemAPe = 1,
	viagemACavalo = 0.5,
	descansoCurto = 0.25,
	descansoLongo = 1,
})

local PASSO = 0.25
local STATUS_OBJETIVO = { ativo = true, expirado = true, cumprido = true }

local function diasValidos(n)
	return type(n) == "number" and n == n and n > 0 and n < 1000 and (n / PASSO) % 1 == 0
end

local function clonar(estado)
	local copia = table.clone(estado)
	copia.jogadores = {}
	for id, j in estado.jogadores do copia.jogadores[id] = table.clone(j) end
	copia.objetivo = table.clone(estado.objetivo)
	copia.objetivosPerdidos = table.clone(estado.objetivosPerdidos)
	copia.flags = table.clone(estado.flags)
	if estado.visitadas then copia.visitadas = table.clone(estado.visitadas) end
	copia.fim = estado.fim and table.clone(estado.fim) or nil
	return copia
end

-- opcoes = { semente, jogadores = { id... }, objetivo = { id, prazoDias }, regiao, galho }
function Run.nova(opcoes)
	if type(opcoes) ~= "table" or type(opcoes.jogadores) ~= "table" then return nil, "Opções inválidas." end
	local n = #opcoes.jogadores
	if n < 1 or n > Run.MAX_JOGADORES then return nil, "Uma run tem de 1 a 4 jogadores." end
	local jogadores = {}
	for _, id in opcoes.jogadores do
		if (type(id) ~= "string" and type(id) ~= "number") or jogadores[id] then
			return nil, "Jogador inválido ou repetido."
		end
		jogadores[id] = { presente = true, caido = false }
	end
	local obj = opcoes.objetivo
	if type(obj) ~= "table" or type(obj.id) ~= "string" or not diasValidos(obj.prazoDias) then
		return nil, "Objetivo sem id ou prazo válido."
	end
	return {
		versao = Run.VERSAO,
		semente = opcoes.semente or 0,
		jogadores = jogadores,
		dia = 0,
		objetivo = { id = obj.id, prazoFinal = obj.prazoDias, status = "ativo" },
		objetivosPerdidos = {},
		regiao = opcoes.regiao or "vila",
		galho = opcoes.galho or "inicio",
		visitadas = { [opcoes.regiao or "vila"] = true },
		flags = {},
		fim = nil,
	}
end

function Run.estadoValido(estado)
	if type(estado) ~= "table" or estado.versao ~= Run.VERSAO or type(estado.jogadores) ~= "table"
		or type(estado.dia) ~= "number" or estado.dia ~= estado.dia or estado.dia < 0 or estado.dia == math.huge
		or type(estado.objetivo) ~= "table" or type(estado.flags) ~= "table"
		or type(estado.objetivosPerdidos) ~= "table"
		or type(estado.regiao) ~= "string" or type(estado.galho) ~= "string" then
		return false
	end
	if not Cacadas.estadoValido(estado.cacadas, estado.jogadores)
		or not Cacadas.patrulhasValidas(estado.patrulhasDerrotadas) then return false end
	-- Estado vem de save: campos usados em comparações precisam existir com o tipo certo,
	-- senão gastarDias/diasRestantes falhariam com erro em vez de recusar.
	local obj = estado.objetivo
	if type(obj.id) ~= "string" or not STATUS_OBJETIVO[obj.status] or type(obj.prazoFinal) ~= "number"
		or obj.prazoFinal ~= obj.prazoFinal or obj.prazoFinal < 0 or obj.prazoFinal == math.huge then
		return false
	end
	if estado.fim ~= nil and (type(estado.fim) ~= "table" or (estado.fim.motivo ~= "queda" and estado.fim.motivo ~= "final")) then
		return false
	end
 if estado.ouroViagem ~= nil and (type(estado.ouroViagem) ~= "number" or estado.ouroViagem < 0
  or estado.ouroViagem % 1 ~= 0 or estado.ouroViagem >= 2 ^ 53) then return false end
 if estado.ultimoEvento ~= nil then
  local r = estado.ultimoEvento
  if type(r) ~= "table" or type(r.evento) ~= "string" or type(r.texto) ~= "string" then return false end
  if r.pericia ~= nil and (type(r.pericia) ~= "string" or type(r.total) ~= "number"
   or type(r.cd) ~= "number" or type(r.sucesso) ~= "boolean" or type(r.dados) ~= "table") then return false end
 end
	local n = 0
	for _, j in estado.jogadores do
		if type(j) ~= "table" or type(j.presente) ~= "boolean" or type(j.caido) ~= "boolean" then return false end
		n += 1
	end
	return n >= 1 and n <= Run.MAX_JOGADORES
end

function Run.encerrada(estado)
	return estado.fim ~= nil
end

function Run.diasRestantes(estado)
	return math.max(0, estado.objetivo.prazoFinal - estado.dia)
end

-- Gasta dias. Devolve (novoEstado, expirou). Ao passar do prazo o objetivo vira "expirado";
-- a história escolhe então um objetivo alternativo com `trocarObjetivo` (consequências são dela).
function Run.gastarDias(estado, dias)
	if estado.fim then return nil, nil, "A run já terminou." end
	if not diasValidos(dias) then return nil, nil, "Dias inválidos (múltiplos de 0,25)." end
	local novo = clonar(estado)
	novo.dia += dias
	local expirou = false
	if novo.objetivo.status == "ativo" and novo.dia >= novo.objetivo.prazoFinal then
		novo.objetivo.status = "expirado"
		expirou = true
	end
	return novo, expirou
end

-- Atalho reduz dias decorridos, sem reativar objetivo perdido.
function Run.ajustarDiasViagem(estado, dias)
 if type(dias) ~= "number" or dias ~= dias or math.abs(dias) >= 1000 or (dias / PASSO) % 1 ~= 0 then
  return nil, nil, "Dias de viagem inválidos."
 end
 if dias > 0 then return Run.gastarDias(estado, dias) end
 if estado.fim then return nil, nil, "A run já terminou." end
 local novo = clonar(estado)
 novo.dia = math.max(0, novo.dia + dias)
 return novo, false
end

function Run.cumprirObjetivo(estado)
	if estado.fim or estado.objetivo.status ~= "ativo" then return nil, "Não há objetivo ativo." end
	local novo = clonar(estado)
	novo.objetivo.status = "cumprido"
	return novo
end

-- Só depois de expirar ou cumprir. O prazo novo conta a partir de agora.
function Run.trocarObjetivo(estado, id, prazoDias)
	if estado.fim then return nil, "A run já terminou." end
	if estado.objetivo.status == "ativo" then return nil, "O objetivo atual ainda está ativo." end
	if type(id) ~= "string" or not diasValidos(prazoDias) then return nil, "Objetivo inválido." end
	local novo = clonar(estado)
	if novo.objetivo.status == "expirado" then table.insert(novo.objetivosPerdidos, novo.objetivo.id) end
	novo.objetivo = { id = id, prazoFinal = novo.dia + prazoDias, status = "ativo" }
	return novo
end

function Run.moverPara(estado, regiao, galho)
	if estado.fim then return nil, "A run já terminou." end
	if type(regiao) ~= "string" or type(galho) ~= "string" then return nil, "Destino inválido." end
	local novo = clonar(estado)
	novo.regiao, novo.galho = regiao, galho
	novo.visitadas = novo.visitadas or {}
	novo.visitadas[regiao] = true
	return novo
end

-- Regiões distintas pisadas além da inicial (a vila); saves antigos sem o campo contam 0.
function Run.regioesVisitadas(estado)
	local n = 0
	for regiao in estado.visitadas or {} do
		if regiao ~= "vila" then n += 1 end
	end
	return n
end

function Run.definirFlag(estado, nome)
	if type(nome) ~= "string" or nome == "" then return nil, "Flag inválida." end
	local novo = clonar(estado)
	novo.flags[nome] = true
	return novo
end

function Run.temFlag(estado, nome)
	return estado.flags[nome] == true
end

-- Ausente: o personagem espera no acampamento e não conta para a queda do grupo.
function Run.marcarAusente(estado, id)
	local j = estado.jogadores[id]
	if not j or not j.presente then return nil, "Jogador não está presente." end
	local novo = clonar(estado)
	novo.jogadores[id].presente = false
	novo.jogadores[id].ausenteDesde = estado.dia
	return novo
end

-- Devolve (estado, diasPerdidos): o PA ganho nesse período não vale para quem faltou.
function Run.retornar(estado, id)
	local j = estado.jogadores[id]
	if not j or j.presente then return nil, nil, "Jogador não estava ausente." end
	local novo = clonar(estado)
	novo.jogadores[id].presente = true
	novo.jogadores[id].ausenteDesde = nil
	return novo, estado.dia - (j.ausenteDesde or estado.dia)
end

function Run.marcarCaido(estado, id, caido)
	if not estado.jogadores[id] then return nil, "Jogador desconhecido." end
	local novo = clonar(estado)
	novo.jogadores[id].caido = caido ~= false
	return novo
end

function Run.grupoCaiu(estado)
	local algum = false
	for _, j in estado.jogadores do
		if j.presente then
			algum = true
			if not j.caido then return false end
		end
	end
	return algum
end

-- Encerra por queda do grupo (se for o caso); senão devolve o mesmo estado.
function Run.encerrarPorQueda(estado)
	if estado.fim or not Run.grupoCaiu(estado) then return estado end
	local novo = clonar(estado)
	novo.fim = { motivo = "queda", dia = estado.dia }
	return novo
end

-- Chegar a uma folha da árvore encerra a run com um final.
function Run.encerrarComFinal(estado, finalId)
	if estado.fim then return nil, "A run já terminou." end
	if type(finalId) ~= "string" then return nil, "Final inválido." end
	local novo = clonar(estado)
	novo.fim = { motivo = "final", final = finalId, dia = estado.dia }
	return novo
end

return Run
