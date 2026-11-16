--!strict
-- IMP1: regras puras do impacto do golpe na luta (curvas, durações, enquadramento). Sem Instances nem eventos:
-- `client/ImpactoCamera`, `client/ImpactoFx`, `client/Efeitos` e `client/Coreografia` só aplicam estes números.
local M = {}

-- Acessibilidade: tremor de tela ligado por padrão. O jogador desliga com o atributo `SemTremor = true` no
-- LocalPlayer (ver `client/Efeitos.tremorAtivo`); com movimento reduzido (MenuEfeitos) não há tremor nem pausa.
M.TREMOR_PADRAO = true

M.ENTRADA_MAX = 0.5 -- s: antecipação, a câmera vai se aproximando até o impacto (no máximo isto antes dele)
M.SEGURA = 0.22 -- s: fica enquadrada logo após o contato
M.SAIDA = 0.75 -- s: volta ao enquadramento normal
M.FORCA = 0.55 -- 0..1: quanto o enquadramento do golpe domina a câmera de luta no ponto mais forte
M.HITSTOP_MIN, M.HITSTOP_MAX = 0.06, 0.09

local function suave(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end
M.suave = suave

-- Peso do golpe na câmera (0..1) em `t` segundos desde o início da cena, com o contato em `impacto`.
function M.peso(t: number, impacto: number): number
	impacto = math.max(impacto, 0.05)
	local entrada = math.min(impacto, M.ENTRADA_MAX)
	if t <= impacto - entrada then
		return 0
	elseif t < impacto then
		return suave((t - (impacto - entrada)) / entrada)
	elseif t <= impacto + M.SEGURA then
		return 1
	end
	return 1 - suave((t - impacto - M.SEGURA) / M.SAIDA)
end

function M.duracaoTotal(impacto: number): number
	return math.max(impacto, 0.05) + M.SEGURA + M.SAIDA
end

-- Pausa no acerto (s). 0 quando não há dano.
function M.hitStop(dano: number?, critico: boolean?): number
	if (dano or 0) <= 0 then
		return 0
	end
	if critico then
		return M.HITSTOP_MAX
	end
	return M.HITSTOP_MIN + (M.HITSTOP_MAX - M.HITSTOP_MIN) * math.clamp((dano :: number) / 20, 0, 1) * 0.7
end

-- Tremor: amplitude em studs (posição da câmera) e duração. Cresce com o dano, mais forte no crítico.
function M.tremor(dano: number?, critico: boolean?, peso: number?): (number, number)
	local d = math.max(dano or 0, 0)
	if d <= 0 then
		return 0, 0
	end
	local amp = 0.1 + math.min(d, 30) * 0.011 + (peso or 0) * 0.1
	local dur = 0.2 + math.min(d, 30) * 0.003
	if critico then
		amp, dur = amp * 1.6, dur + 0.15
	end
	return math.min(amp, 0.75), dur
end

-- Envoltória do tremor: `resto` = fração restante (1 -> 0). Amortecida (quadrática).
function M.envoltoriaTremor(resto: number): number
	resto = math.clamp(resto, 0, 1)
	return resto * resto
end

-- Número de faíscas no contato.
function M.faiscas(dano: number?, critico: boolean?): number
	local d = math.max(dano or 0, 0)
	local n = 8 + math.floor(math.min(d, 30) * 0.7)
	return if critico then math.floor(n * 1.8) else n
end

-- Enquadramento do golpe (coordenadas planas). `de`/`para`: {x,y,z}. `lado` = +1/-1 (lado da câmera).
-- Devolve posição e ponto de olhar: câmera baixa de lado, acima do meio da dupla, olhando o contato.
function M.enquadre(de: { x: number, y: number, z: number }, para: { x: number, y: number, z: number }, lado: number)
	local dx, dz = para.x - de.x, para.z - de.z
	local dist = math.sqrt(dx * dx + dz * dz)
	if dist < 1e-3 then
		dx, dz, dist = 0, -1, 1
	end
	local fx, fz = dx / dist, dz / dist
	local lx, lz = -fz * lado, fx * lado -- perpendicular
	local mx, mz = (de.x + para.x) / 2, (de.z + para.z) / 2
	local y = (de.y + para.y) / 2
	local afast = 7 + dist * 0.75
	local olhar = { x = mx, y = y + 2, z = mz }
	local pos = { x = mx + lx * afast - fx * 1.5, y = y + 3.6, z = mz + lz * afast - fz * 1.5 }
	return pos, olhar
end

return M
