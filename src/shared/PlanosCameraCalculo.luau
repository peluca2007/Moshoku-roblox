--!strict
-- CAM1: matemática pura dos planos de câmera por habilidade (sem Instances, sem Vector3). Um plano é uma lista de
-- tomadas { t, f, ang, dist, alt, mira } com `t` em segundos RELATIVOS AO CONTATO (negativo = antes). `f` é o ponto
-- de interesse ("de" atacante, "para" alvo, "meio" entre os dois, "proj" ponto que viaja de um ao outro até o contato).
-- `ang` (graus) gira a câmera em volta do ponto: 0 = de lado, + = para trás do atacante, - = pela frente do alvo.
-- `client/ImpactoCamera` resolve os pontos no mundo, desocluiu e aplica; `client/PlanosCamera` guarda a tabela.
local M = {}

M.ENTRA = 0.35 -- s: a câmera da luta passa ao plano antes da primeira tomada
M.SAI = 0.55 -- s: volta à câmera da luta depois da última tomada
M.FOCOS = { de = true, para = true, meio = true, proj = true }

local function suave(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

export type Tomada = { t: number, f: string, ang: number, dist: number, alt: number?, mira: number? }
export type Plano = { tomadas: { Tomada }, entra: number?, sai: number?, zona: boolean? }

-- Devolve nil se o plano está bem formado; senão o motivo.
function M.validar(plano: Plano): string?
	local n = #plano.tomadas
	if n < 1 then return "sem tomadas" end
	local ant = -math.huge
	for i, k in plano.tomadas do
		if not M.FOCOS[k.f] then return "foco inválido na tomada " .. i end
		if k.t < ant then return "tempos fora de ordem na tomada " .. i end
		if k.dist < 3 or k.dist > 40 then return "distância fora de 3..40 na tomada " .. i end
		if math.abs(k.ang) > 120 then return "ângulo fora de -120..120 na tomada " .. i end
		ant = k.t
	end
	return nil
end

-- Instante (desde o início da cena) em que o plano acaba de vez.
function M.fim(plano: Plano, impacto: number): number
	local ult = plano.tomadas[#plano.tomadas]
	return math.max(impacto + ult.t, 0) + (plano.sai or M.SAI)
end

-- Estado do plano em `t` (s desde o início da cena): peso 0..1 sobre a câmera da luta e a tomada interpolada.
-- Devolve { w, f1, f2, u, ang, dist, alt, mira }: o ponto de interesse é a mistura de f1 e f2 por `u`.
function M.amostrar(plano: Plano, t: number, impacto: number)
	local ks = plano.tomadas
	local ta = {}
	for i, k in ks do ta[i] = math.max(impacto + k.t, 0) end
	local n = #ks
	local entra, sai = plano.entra or M.ENTRA, plano.sai or M.SAI
	local w = suave((t - (ta[1] - entra)) / math.max(entra, 1e-3)) * (1 - suave((t - ta[n]) / math.max(sai, 1e-3)))
	local i = 1
	while i < n and t >= ta[i + 1] do i += 1 end
	local a, b = ks[i], ks[math.min(i + 1, n)]
	local u = 0
	if i < n then u = suave((t - ta[i]) / math.max(ta[i + 1] - ta[i], 1e-3)) end
	local function mis(x: number, y: number): number return x + (y - x) * u end
	return {
		w = w, f1 = a.f, f2 = b.f, u = u,
		ang = mis(a.ang, b.ang), dist = mis(a.dist, b.dist),
		alt = mis(a.alt or 1, b.alt or 1), mira = mis(a.mira or 0, b.mira or 0),
	}
end

return M
