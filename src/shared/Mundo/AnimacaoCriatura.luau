-- Poses por código dos modelos de criatura (puro: sem Instances, sem relógio, sem sorteio).
-- Frente do modelo = -Z; os ângulos giram cada grupo em volta do pivô de PivosModelos.
-- Pitch positivo balança a ponta do membro para a FRENTE (-Z); yaw positivo gira a cabeça para -X.
--
-- Contexto `c`:
--   tipo        "humanoide" | "quadrupede" | "aranha" | "pesado" | "voador" (asas = BracoE/BracoD batem em roll)
--   fase        fase da passada (rad, avança com a distância andada)
--   mov         0..1 quanto está andando (suavizado por quem chama)
--   t           tempo em segundos (respiração, cauda)
--   golpe       nil ou progresso 0..1 do ataque
--   yawCabeca   rad, para onde a cabeça olha (0 = frente)
--   bracoArma   "BracoD" | "BracoE" | nil (braço que segura a arma)
--
-- ANIM2: clipes por dados (Shared/Animacoes/Criaturas/<Modulo>.luau, gerados do pacote Quaternius). Quando o
-- módulo tem clipes, o chamador toca-os com clipeDe/peca/misturar e cai nas poses por código (`corpo`/`pose`)
-- se `clipeDe` devolver nil. Quadro { t, qx, qy, qz, qw, dx, dy, dz }: a peça vai de p para
-- R * (p - pivô) + pivô + d, no espaço do modelo (escala 1; multiplique d pela escala do modelo montado).
local Amostra = require(game:GetService("ReplicatedStorage").Shared.Animacoes.Amostra)

local AnimacaoCriatura = {}

local AMPLITUDE = {
	humanoide = { perna = 0.6, braco = 0.5, bob = 0.09 },
	quadrupede = { perna = 0.5, braco = 0.5, bob = 0.07 },
	aranha = { perna = 0.4, braco = 0.0, bob = 0.04 },
	pesado = { perna = 0.3, braco = 0.25, bob = 0.06 },
	voador = { perna = 0.15, braco = 0.0, bob = 0.05 },
}
local LUNGE = { humanoide = 0.6, quadrupede = 1.0, aranha = 0.8, pesado = 0.8, voador = 0.7 }

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

-- Rotação (pitch em X, yaw em Y, roll opcional em Z) de um grupo; grupos sem animação devolvem 0, 0.
-- Só o tipo "voador" usa o roll: BracoE (+X) sobe com roll positivo, BracoD (-X) com negativo.
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
	elseif tipo == "voador" and (grupo == "BracoE" or grupo == "BracoD") then
		local ritmo = 7 + 6 * mov + (if golpe then 4 else 0)
		local batida = math.sin((c.t or 0) * ritmo) * (0.45 + 0.15 * mov)
		return 0, 0, if grupo == "BracoE" then batida else -batida
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

-- Estado visual -> clipes candidatos, em ordem de preferência (voadores usam Voar parados e andando).
AnimacaoCriatura.ESTADOS = {
	parado = { "Respirar", "Voar" },
	andando = { "Andar", "Voar", "Respirar" },
	correndo = { "Correr", "Andar", "Voar", "Respirar" },
	ataque = { "Atacar" },
	ataque2 = { "Atacar2", "Atacar" },
	dano = { "LevarGolpe" },
	morte = { "Morrer" },
}

-- Primeiro clipe existente para o estado: devolve (nome, clipe) ou nil (use as poses por código).
function AnimacaoCriatura.clipeDe(dados: any, estado: string): (string?, any?)
	local clipes = type(dados) == "table" and dados.clipes
	local nomes = AnimacaoCriatura.ESTADOS[estado]
	if type(clipes) ~= "table" or not nomes then
		return nil, nil
	end
	for _, nome in nomes do
		if clipes[nome] then
			return nome, clipes[nome]
		end
	end
	return nil, nil
end

-- Instante do golpe que causa o dano (segundos do clipe), ou nil se o clipe não marca.
function AnimacaoCriatura.marcoImpacto(clipe: any): number?
	return clipe and clipe.marcos and clipe.marcos.impacto
end

-- Pose da peça `grupo` no instante t do clipe (use Amostra.tempoLocal para laço/fim): qx, qy, qz, qw, dx, dy, dz.
-- Peça sem curva no clipe: nil (fica parada no repouso).
function AnimacaoCriatura.peca(clipe: any, grupo: string, t: number): (number?, number?, number?, number?, number?, number?, number?)
	local chaves = clipe and clipe.pecas and clipe.pecas[grupo]
	if not chaves then
		return nil
	end
	local i = Amostra.indice(chaves, t)
	local a = chaves[i]
	local b = chaves[i + 1]
	if not b or t <= a[1] then
		return a[2], a[3], a[4], a[5], a[6], a[7], a[8]
	end
	local u = math.clamp((t - a[1]) / (b[1] - a[1]), 0, 1)
	local qx, qy, qz, qw = Amostra.slerp(a[2], a[3], a[4], a[5], b[2], b[3], b[4], b[5], u)
	return qx, qy, qz, qw, lerp(a[6], b[6], u), lerp(a[7], b[7], u), lerp(a[8], b[8], u)
end

-- Mistura de duas poses (w 0 = a, w 1 = b), para trocar de clipe sem salto (parado -> andando). Cada pose: 7 números.
function AnimacaoCriatura.misturar(w: number, ax: number, ay: number, az: number, aw: number, adx: number, ady: number, adz: number,
	bx: number, by: number, bz: number, bw: number, bdx: number, bdy: number, bdz: number): (number, number, number, number, number, number, number)
	w = math.clamp(w, 0, 1)
	local qx, qy, qz, qw = Amostra.slerp(ax, ay, az, aw, bx, by, bz, bw, w)
	return qx, qy, qz, qw, lerp(adx, bdx, w), lerp(ady, bdy, w), lerp(adz, bdz, w)
end

-- Confere a forma dos dados de uma criatura. Devolve true ou false + motivo.
function AnimacaoCriatura.validar(dados: any): (boolean, string?)
	if type(dados) ~= "table" or type(dados.clipes) ~= "table" or next(dados.clipes) == nil then
		return false, "sem clipes"
	end
	for nome, c in dados.clipes do
		if type(c.duracao) ~= "number" or c.duracao <= 0 or type(c.pecas) ~= "table" or next(c.pecas) == nil then
			return false, nome .. ": duração ou peças inválidas"
		end
		for grupo, chaves in c.pecas do
			local anterior = -math.huge
			for i, ch in chaves do
				if #ch ~= 8 then
					return false, nome .. "." .. grupo .. ": quadro " .. i .. " malformado"
				end
				for _, v in ch do
					if type(v) ~= "number" or v ~= v then
						return false, nome .. "." .. grupo .. ": valor não numérico"
					end
				end
				if ch[1] <= anterior or ch[1] < -1e-6 or ch[1] > c.duracao + 1e-6 then
					return false, nome .. "." .. grupo .. ": tempo inválido no quadro " .. i
				end
				anterior = ch[1]
				local m = math.sqrt(ch[2] ^ 2 + ch[3] ^ 2 + ch[4] ^ 2 + ch[5] ^ 2)
				if math.abs(m - 1) > 2e-3 then
					return false, nome .. "." .. grupo .. ": quatérnio não unitário"
				end
			end
		end
		for m, t in c.marcos or {} do
			if type(t) ~= "number" or t < 0 or t > c.duracao + 1e-6 then
				return false, nome .. ": marco " .. m .. " fora da duração"
			end
		end
	end
	return true
end

return AnimacaoCriatura
