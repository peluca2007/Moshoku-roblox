-- Poses por código dos modelos de criatura (puro: sem Instances, sem relógio, sem sorteio).
-- Frente do modelo = -Z; os ângulos giram cada grupo em volta do pivô de PivosModelos.
-- Pitch positivo balança a ponta do membro para a FRENTE (-Z); yaw positivo gira a cabeça para -X.
--
-- Contexto `c`:
--   tipo        "humanoide" | "quadrupede" | "aranha" | "pesado"
--   fase        fase da passada (rad, avança com a distância andada)
--   mov         0..1 quanto está andando (suavizado por quem chama)
--   t           tempo em segundos (respiração, cauda)
--   golpe       nil ou progresso 0..1 do ataque
--   yawCabeca   rad, para onde a cabeça olha (0 = frente)
--   bracoArma   "BracoD" | "BracoE" | nil (braço que segura a arma)
local AnimacaoCriatura = {}

local AMPLITUDE = {
	humanoide = { perna = 0.6, braco = 0.5, bob = 0.09 },
	quadrupede = { perna = 0.5, braco = 0.5, bob = 0.07 },
	aranha = { perna = 0.4, braco = 0.0, bob = 0.04 },
	pesado = { perna = 0.3, braco = 0.25, bob = 0.06 },
}
local LUNGE = { humanoide = 0.6, quadrupede = 1.0, aranha = 0.8, pesado = 0.8 }

AnimacaoCriatura.DURACAO_GOLPE = 0.9

local function lerp(a, b, k) return a + (b - a) * k end
local function suave(k) return k * k * (3 - 2 * k) end

-- Ângulo do golpe: levanta (0..0.3), desce rápido (0.3..0.5), recupera (0.5..1).
function AnimacaoCriatura.anguloGolpe(p)
	if type(p) ~= "number" then return 0 end
	p = math.clamp(p, 0, 1)
	if p < 0.3 then return -2.0 * suave(p / 0.3) end
	if p < 0.5 then return lerp(-2.0, 1.4, (p - 0.3) / 0.2) end
	return lerp(1.4, 0, suave((p - 0.5) / 0.5))
end

local function amplitude(c) return AMPLITUDE[c.tipo] or AMPLITUDE.humanoide end

-- Deslocamento do corpo inteiro em studs na escala 1: (dy sobe/desce, dz avanço; -Z é frente).
function AnimacaoCriatura.corpo(c)
	local a = amplitude(c)
	local mov = c.mov or 0
	local dy = math.sin((c.t or 0) * 2.4) * 0.035 * (1 - mov) + math.abs(math.sin(c.fase or 0)) * a.bob * mov
	local dz = 0
	if c.golpe then
		local k = math.clamp((c.golpe - 0.25) / 0.4, 0, 1)
		dz = -math.sin(math.pi * k) * (LUNGE[c.tipo] or 0.6)
	end
	return dy, dz
end

-- Rotação (pitch em X, yaw em Y) de um grupo; grupos sem animação devolvem 0, 0.
-- "Arma" acompanha o braço que a segura: o chamador usa o pivô desse braço e a pose dele.
function AnimacaoCriatura.pose(grupo, c)
	local a = amplitude(c)
	local mov = c.mov or 0
	local passo = math.sin(c.fase or 0) * mov
	local golpe = c.golpe
	local g = AnimacaoCriatura.anguloGolpe(golpe)
	local tipo = c.tipo
	if grupo == "PernaE" then
		local extra = if golpe and tipo == "aranha" then -0.5 * math.sin(math.pi * golpe) else 0
		return passo * a.perna + extra, 0
	elseif grupo == "PernaD" then
		local extra = if golpe and tipo == "aranha" then -0.5 * math.sin(math.pi * golpe) else 0
		return -passo * a.perna + extra, 0
	elseif grupo == "BracoE" or grupo == "BracoD" or grupo == "Arma" then
		local dono = if grupo == "Arma" then c.bracoArma else grupo
		if not dono then return 0, 0 end
		local sinal = if dono == "BracoE" then -1 else 1
		local balanco = sinal * passo * a.braco + math.sin((c.t or 0) * 1.7 + (if sinal > 0 then 0 else 1.3)) * 0.04 * (1 - mov)
		if golpe then
			if tipo == "humanoide" then
				if dono == c.bracoArma then return g, 0 end
				return balanco * 0.3 - 0.25 * math.sin(math.pi * golpe), 0
			elseif tipo == "pesado" then
				return g * 0.85, 0
			elseif tipo == "quadrupede" then
				return g * (if dono == "BracoD" then 0.55 else 0.4), 0
			end
		end
		return balanco, 0
	elseif grupo == "Cabeca" then
		local yaw = math.clamp(c.yawCabeca or 0, -1.2, 1.2) + math.sin((c.t or 0) * 0.7) * 0.12 * (1 - mov)
		local pitch = 0
		if golpe then
			local k = golpe
			pitch = if k < 0.3 then -0.35 * suave(k / 0.3) elseif k < 0.5 then lerp(-0.35, 0.5, (k - 0.3) / 0.2) else lerp(0.5, 0, suave((k - 0.5) / 0.5))
		end
		return pitch + math.sin((c.t or 0) * 1.4) * 0.03 * (1 - mov), yaw
	elseif grupo == "Cauda" then
		return 0, math.sin((c.t or 0) * 5 + (c.fase or 0)) * (0.2 + 0.3 * mov)
	end
	return 0, 0
end

-- O grupo (Corpo, PernaE, Arma...) a partir do nome `<Parte>_<Cor>` da MeshPart.
function AnimacaoCriatura.grupo(nome)
	if type(nome) ~= "string" then return nil end
	return string.match(nome, "^(%a+)_") or string.match(nome, "^(%a+)$")
end

-- Qual braço segura a Arma: o de pivô mais próximo (lado do x do pivô da Arma).
function AnimacaoCriatura.bracoDaArma(pivos)
	if type(pivos) ~= "table" or not pivos.Arma then return nil end
	local d, e = pivos.BracoD, pivos.BracoE
	if d and e then
		local dd = math.abs(pivos.Arma[1] - d[1]) + math.abs(pivos.Arma[2] - d[2])
		local de = math.abs(pivos.Arma[1] - e[1]) + math.abs(pivos.Arma[2] - e[2])
		return if dd <= de then "BracoD" else "BracoE"
	end
	return if d then "BracoD" elseif e then "BracoE" else nil
end

return AnimacaoCriatura
