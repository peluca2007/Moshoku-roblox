--!strict
-- Fila de apresentação (ANIM3), regra PURA: o servidor resolve o golpe de uma vez, mas o jogador só deve ver o
-- número, a barra de vida e a queda quando o golpe encosta (marco `impacto` do clipe do atacante). A fila guarda,
-- por alvo, "mostre este PV até o instante X"; passado X (ou o teto de segurança) o PV real aparece. Não cria
-- Instance nem envia evento; o relógio vem de fora (tempo em segundos, qualquer origem monotônica).
-- Quem desenha (client/FeedbackCombate, BarrasLuta, AnimacaoLuta) pergunta `pvExibido`/`visto`; a Coreografia
-- registra as retenções (`reter`) com o instante de impacto que ela já calcula a partir do clipe.
local Fila = {}
Fila.__index = Fila

-- Nunca segura mais que isto, mesmo com clipe longo ou relógio parado: a regra do servidor nunca fica escondida.
Fila.SEGURANCA = 1.6
-- O snapshot pode chegar um pouco antes do recibo: valores anteriores mais novos que isto contam como "antes do golpe".
Fila.JANELA_ANTERIOR = 1.0
-- Marco usado quando o clipe do atacante não tem `impacto` (ou não é conhecido): meio caminho de um golpe típico.
Fila.IMPACTO_PADRAO = 0.4

export type Retencao = { pvAntes: number, ate: number, provisoria: boolean? }
-- Espera pelo recibo quando o PV cai sem retenção (snapshot antes do recibo).
Fila.CARENCIA = 0.25

function Fila.nova(seguranca: number?)
	return setmetatable({
		seguranca = seguranca or Fila.SEGURANCA,
		vistos = {} :: { [string]: { atual: number, anterior: number?, mudou: number } },
		retidos = {} :: { [string]: Retencao },
	}, Fila)
end

-- Segundos entre o início do clipe e o contato, com a velocidade de reprodução (>0). Sem marco, o padrão.
function Fila.atrasoDoImpacto(clipe: any, velocidade: number?, padrao: number?): number
	local marco = type(clipe) == "table" and type(clipe.marcos) == "table" and clipe.marcos.impacto
	local v = if type(velocidade) == "number" and velocidade > 0 then velocidade else 1
	if type(marco) == "number" and marco >= 0 then
		return marco / v
	end
	return padrao or Fila.IMPACTO_PADRAO
end

-- Registra o PV que um token tem a cada snapshot (guarda também o valor anterior, para o caso do recibo chegar depois).
-- `carencia` (s, opcional): se o PV caiu e ainda não há retenção, segura o valor antigo por esse tempo à espera do
-- recibo do golpe (que pode chegar um pouco depois do snapshot); `reter` troca esse prazo pelo do impacto.
function Fila:observar(id: string, pv: number?, agora: number, carencia: number?)
	if type(pv) ~= "number" then
		self.vistos[id] = nil
		return
	end
	local v = self.vistos[id]
	if not v then
		self.vistos[id] = { atual = pv, mudou = -math.huge }
	elseif v.atual ~= pv then
		if carencia and carencia > 0 and not self.retidos[id] then
			self.retidos[id] = { pvAntes = v.atual, ate = agora + carencia, provisoria = true }
		end
		v.anterior, v.atual, v.mudou = v.atual, pv, agora
	end
end

-- Segura o PV de `id` em `pvAntes` até `agora + atraso` (limitado pela segurança). Sem `pvAntes`, usa o valor visto
-- antes da última mudança (se recente) ou o atual. Retenções repetidas ficam com o maior prazo e o primeiro PV.
function Fila:reter(id: string, agora: number, atraso: number, pvAntes: number?): Retencao?
	local v = self.vistos[id]
	local antes = pvAntes
	if antes == nil and v then
		antes = if v.anterior ~= nil and agora - v.mudou <= Fila.JANELA_ANTERIOR then v.anterior else v.atual
	end
	if type(antes) ~= "number" then
		return nil
	end
	local ate = agora + math.clamp(atraso, 0, self.seguranca)
	local r = self.retidos[id]
	if r and r.provisoria then
		r.ate, r.provisoria = ate, nil
	elseif r then
		r.ate = math.max(r.ate, ate)
	else
		r = { pvAntes = antes, ate = ate }
		self.retidos[id] = r
	end
	return r
end

function Fila:retido(id: string, agora: number): boolean
	local r = self.retidos[id]
	return r ~= nil and agora < r.ate
end

-- PV a mostrar agora: o de antes do golpe enquanto retido; o real depois (ou se nada mudou).
function Fila:pvExibido(id: string, pvReal: number?, agora: number): number?
	local r = self.retidos[id]
	if r and type(pvReal) == "number" and agora < r.ate then
		return r.pvAntes
	end
	return pvReal
end

-- Cópia rasa do token com PV/derrotado do que deve ser visto agora; o próprio token se não há retenção.
function Fila:visto(token: any, agora: number): any
	local r = self.retidos[token.id]
	if not r or agora >= r.ate or type(token.pv) ~= "number" or token.pv == r.pvAntes then
		return token
	end
	local copia = table.clone(token)
	copia.pv = r.pvAntes
	if r.pvAntes > 0 then
		copia.derrotado = false
	end
	return copia
end

-- Retenções vencidas em `agora`: remove e devolve { {id, pvAntes, pvReal} } para o desenhista soltar número/queda.
function Fila:expirados(agora: number): { { id: string, pvAntes: number, pvReal: number? } }
	local saida = {}
	for id, r in self.retidos do
		if agora >= r.ate then
			self.retidos[id] = nil
			local v = self.vistos[id]
			table.insert(saida, { id = id, pvAntes = r.pvAntes, pvReal = if v then v.atual else nil })
		end
	end
	return saida
end

function Fila:limpar()
	table.clear(self.retidos)
	table.clear(self.vistos)
end

return Fila
