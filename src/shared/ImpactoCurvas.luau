--!strict
-- IMP1: regras puras do impacto do golpe na luta (curvas, durações, enquadramento). Sem Instances nem eventos:
-- `client/ImpactoCamera`, `client/ImpactoFx`, `client/Efeitos` e `client/Coreografia` só aplicam estes números.
local M = {}

-- Acessibilidade: tremor de tela ligado por padrão. O jogador desliga com o atributo `SemTremor = true` no
-- LocalPlayer (ver `client/Efeitos.tremorAtivo`); com movimento reduzido (MenuEfeitos) não há tremor nem pausa.
M.TREMOR_PADRAO = true

M.ENTRADA_MAX = 0.8 -- s: antecipação, a câmera vai se aproximando até o impacto (no máximo isto antes dele)
M.SEGURA = 0.22 -- s: fica enquadrada logo após o contato
M.SAIDA = 0.75 -- s: volta ao enquadramento normal
M.FORCA = 0.9 -- 0..1: quanto o enquadramento do golpe domina a câmera de luta no ponto mais forte
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

-- Ângulo (rad) entre o eixo atacante->alvo e a direção da câmera: 3/4, mais aberto quando a dupla está colada
-- (assim o atacante nunca tampa o alvo). `dist` em studs, plano.
function M.anguloCamera(dist: number): number
	return math.rad(math.clamp(90 - dist * 2, 70, 86))
end

-- Quanto o alvo fica deslocado, de lado, da linha de visão câmera->atacante (studs). Tem de ser >= SEPARACAO_MIN.
M.SEPARACAO_MIN = 1.8
function M.separacaoLateral(dist: number): number
	return dist * math.sin(M.anguloCamera(dist))
end

-- Enquadramento do golpe (coordenadas planas). `de`/`para`: {x,y,z}. `lado` = +1/-1 (lado da câmera);
-- `abre` = rad extra no ângulo; `escala` encurta a distância (candidatos contra parede).
-- Devolve posição e ponto de olhar: câmera 3/4 atrás e ao lado do atacante, vendo os dois lutadores.
function M.enquadre(de: { x: number, y: number, z: number }, para: { x: number, y: number, z: number }, lado: number, abre: number?, escala: number?)
	local dx, dz = para.x - de.x, para.z - de.z
	local dist = math.sqrt(dx * dx + dz * dz)
	if dist < 1e-3 then
		dx, dz, dist = 0, -1, 1
	end
	local fx, fz = dx / dist, dz / dist
	local lx, lz = -fz * lado, fx * lado -- perpendicular
	local th = math.min(M.anguloCamera(dist) + (abre or 0), math.rad(88))
	local mx, mz = (de.x + para.x) / 2, (de.z + para.z) / 2
	local y = (de.y + para.y) / 2
	local afast = math.max((4.6 + dist * 0.95) * (escala or 1), 3.5) -- perto: a dupla ocupa o quadro (separação em tela >= ~12%)
	local dirx, dirz = lx * math.sin(th) - fx * math.cos(th), lz * math.sin(th) - fz * math.cos(th)
	local olhar = { x = mx, y = y + 1.8, z = mz }
	local pos = { x = mx + dirx * afast, y = y + 2.4 * (escala or 1) + 1, z = mz + dirz * afast }
	return pos, olhar
end

-- Tentativas de enquadramento, da preferida à mais conservadora: { lado relativo, abre (rad), escala }.
M.CANDIDATOS = {
	{ 1, 0, 1 }, { -1, 0, 1 }, { 1, 0.3, 0.8 }, { -1, 0.3, 0.8 }, { 1, 0.5, 0.6 }, { -1, 0.5, 0.6 }, { 1, 0.6, 0.45 }, { -1, 0.6, 0.45 },
}

-- Caixa da sala (as paredes do esgoto não são consultáveis por raycast: CanQuery=false): a câmera do golpe
-- fica dentro dela. `c` = { x, z, meia, teto }. Devolve a maior fração (0..1) do caminho olhar->pos que cabe na caixa.
M.SALA_MARGEM = 8 -- studs entre a borda do tabuleiro e a caixa (as paredes ficam ~14 depois da borda)
M.SALA_TETO = 30 -- teto do esgoto em 36
function M.fracaoDentro(olhar: { x: number, y: number, z: number }, pos: { x: number, y: number, z: number }, c: { x: number, z: number, meia: number, teto: number }): number
	local t = 1
	local function eixo(o: number, p: number, lo: number, hi: number)
		local d = p - o
		if d > 1e-6 and p > hi then
			t = math.min(t, math.max((hi - o) / d, 0))
		elseif d < -1e-6 and p < lo then
			t = math.min(t, math.max((lo - o) / d, 0))
		end
	end
	eixo(olhar.x, pos.x, c.x - c.meia, c.x + c.meia)
	eixo(olhar.z, pos.z, c.z - c.meia, c.z + c.meia)
	eixo(olhar.y, pos.y, -1e9, c.teto)
	return t
end

-- Câmera lenta: (duração real em s, taxa do relógio da cena) após o contato. Crítico e golpe final.
function M.lento(critico: boolean?, final: boolean?): (number, number)
	if final then return 0.7, 0.22 end
	if critico then return 0.4, 0.3 end
	return 0, 1
end

-- Empurrão direcional da câmera: `u` = fração decorrida (0..1). Começa no máximo no sentido do golpe,
-- volta oscilando e amortecido (multiplica a amplitude e a direção em espaço da câmera).
function M.empurrao(u: number): number
	if u <= 0 or u >= 1 then return 0 end
	return (1 - u) ^ 2 * math.cos(u * math.pi * 2.2)
end

-- Janelas do relógio de uma cena: `pausa` (hit-stop, taxa 0) e depois `lento`. Devolve quanto tempo de cena
-- passa entre dois instantes reais, dado `base` = taxa normal. janelas = { {ini, fim, taxa} } sem sobreposição.
function M.avanco(de: number, ate: number, base: number, janelas: { { number } }): number
	if ate <= de then return 0 end
	local total, coberto = 0, 0
	for _, j in janelas do
		local ini, fim = math.max(de, j[1]), math.min(ate, j[2])
		if fim > ini then
			total += (fim - ini) * j[3]
			coberto += fim - ini
		end
	end
	return total + (ate - de - coberto) * base
end

return M
