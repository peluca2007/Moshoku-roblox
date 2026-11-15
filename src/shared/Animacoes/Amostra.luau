--!strict
-- Amostra (ANIM1): leitura PURA dos clipes de animação por dados (sem Instances, sem serviços).
-- Usado por client/TocadorClipe e pelos specs; o espelho em Python (tools/blender/anim_curvas.py) monta a prévia.
--
-- Formato de um clipe (gerado por tools/blender/anim_exportar.py em Animacoes/Clipes/<Nome>.luau):
--   { nome, origem, fps, duracao, laco?, segurar?, marcos = { impacto = t, soltar = t, ... },
--     juntas = { <nome do Motor6D> = { {t, qx, qy, qz, qw}, ... } },  -- rotação de Motor6D.Transform
--     raiz = { {t, x, y, z}, ... } }                                    -- translação do Transform da junta Root
-- Tempos em segundos, crescentes, de 0 a duracao. Entre dois quadros: slerp pelo caminho curto (rotação) e
-- interpolação linear (raiz). Fora do intervalo: o primeiro/último quadro.

export type Chaves = { { number } }
export type Clipe = {
	nome: string?,
	origem: string?,
	fps: number,
	duracao: number,
	laco: boolean?,
	segurar: boolean?,
	marcos: { [string]: number }?,
	juntas: { [string]: Chaves },
	raiz: Chaves?,
}

local Amostra = {}

Amostra.JUNTAS = {
	"Root", "Waist", "Neck",
	"RightShoulder", "RightElbow", "RightWrist", "LeftShoulder", "LeftElbow", "LeftWrist",
	"RightHip", "RightKnee", "RightAnkle", "LeftHip", "LeftKnee", "LeftAnkle",
}
local VALIDA: { [string]: boolean } = {}
for _, nome in Amostra.JUNTAS do
	VALIDA[nome] = true
end
Amostra.JUNTA_VALIDA = VALIDA

-- Maior índice i com chaves[i][1] <= t (1 se t está antes do primeiro quadro). Busca binária.
function Amostra.indice(chaves: Chaves, t: number): number
	local n = #chaves
	if n <= 1 or t <= chaves[1][1] then
		return 1
	end
	if t >= chaves[n][1] then
		return n
	end
	local lo, hi = 1, n
	while hi - lo > 1 do
		local meio = (lo + hi) // 2
		if chaves[meio][1] <= t then
			lo = meio
		else
			hi = meio
		end
	end
	return lo
end

-- Slerp de quatérnios (x, y, z, w) pelo caminho curto. u em [0, 1]. Devolve um quatérnio unitário.
function Amostra.slerp(ax: number, ay: number, az: number, aw: number, bx: number, by: number, bz: number, bw: number, u: number): (number, number, number, number)
	local d = ax * bx + ay * by + az * bz + aw * bw
	if d < 0 then
		bx, by, bz, bw, d = -bx, -by, -bz, -bw, -d
	end
	local s0, s1
	if d > 0.9995 then
		-- quase iguais: interpolação linear normalizada (evita divisão por seno ~0)
		s0, s1 = 1 - u, u
	else
		local ang = math.acos(math.min(d, 1))
		local sen = math.sin(ang)
		s0, s1 = math.sin((1 - u) * ang) / sen, math.sin(u * ang) / sen
	end
	local x, y, z, w = s0 * ax + s1 * bx, s0 * ay + s1 * by, s0 * az + s1 * bz, s0 * aw + s1 * bw
	local m = math.sqrt(x * x + y * y + z * z + w * w)
	if m < 1e-9 then
		return 0, 0, 0, 1
	end
	return x / m, y / m, z / m, w / m
end

-- Rotação da junta no instante t (segundos do clipe).
function Amostra.junta(chaves: Chaves, t: number): (number, number, number, number)
	local i = Amostra.indice(chaves, t)
	local a = chaves[i]
	local b = chaves[i + 1]
	if not b or t <= a[1] then
		return a[2], a[3], a[4], a[5]
	end
	local u = math.clamp((t - a[1]) / (b[1] - a[1]), 0, 1)
	return Amostra.slerp(a[2], a[3], a[4], a[5], b[2], b[3], b[4], b[5], u)
end

-- Translação da raiz no instante t.
function Amostra.raiz(chaves: Chaves?, t: number): (number, number, number)
	if not chaves or #chaves == 0 then
		return 0, 0, 0
	end
	local i = Amostra.indice(chaves, t)
	local a = chaves[i]
	local b = chaves[i + 1]
	if not b or t <= a[1] then
		return a[2], a[3], a[4]
	end
	local u = math.clamp((t - a[1]) / (b[1] - a[1]), 0, 1)
	return a[2] + (b[2] - a[2]) * u, a[3] + (b[3] - a[3]) * u, a[4] + (b[4] - a[4]) * u
end

-- Tempo de reprodução (pode passar da duração) -> instante dentro do clipe e se já terminou.
-- Laço: volta ao início e nunca termina. Sem laço: para no último quadro.
function Amostra.tempoLocal(clipe: Clipe, tempo: number): (number, boolean)
	local dur = clipe.duracao
	if clipe.laco then
		local t = tempo % dur
		return t, false
	end
	if tempo >= dur then
		return dur, true
	end
	return math.max(tempo, 0), false
end

-- Peso da camada: sobe de 0 a 1 em fadeEntrada segundos (tempo decorrido) e, sem laço, desce a 0 nos últimos
-- fadeSaida segundos do clipe. Com segurar = true, não desce (o clipe fica no último quadro).
function Amostra.peso(tempo: number, duracao: number, fadeEntrada: number?, fadeSaida: number?, laco: boolean?, segurar: boolean?): number
	local w = 1
	local fe = fadeEntrada or 0
	if fe > 0 then
		w = math.clamp(tempo / fe, 0, 1)
	end
	local fs = fadeSaida or 0
	if not laco and not segurar and fs > 0 then
		w = math.min(w, math.clamp((duracao - tempo) / fs, 0, 1))
	elseif not laco and not segurar and tempo >= duracao then
		w = 0
	end
	return w
end

-- Marcos cruzados no intervalo (t0, t1] do tempo de reprodução, em ordem de tempo. No laço, cada volta conta.
-- Para pegar um marco em t = 0 na primeira passada, comece com t0 negativo (o tocador usa -1e-6).
function Amostra.marcosEntre(clipe: Clipe, t0: number, t1: number): { string }
	local saida: { { any } } = {}
	local marcos = clipe.marcos
	if not marcos or t1 <= t0 then
		return {}
	end
	local dur = clipe.duracao
	for nome, m in marcos do
		if clipe.laco then
			local k = math.floor((t0 - m) / dur) + 1 -- primeira volta com m + k*dur > t0
			while m + k * dur <= t1 do
				table.insert(saida, { m + k * dur, nome })
				k += 1
			end
		elseif m > t0 and m <= t1 then
			table.insert(saida, { m, nome })
		end
	end
	table.sort(saida, function(a, b)
		if a[1] == b[1] then
			return a[2] < b[2]
		end
		return a[1] < b[1]
	end)
	local nomes = {}
	for i, par in saida do
		nomes[i] = par[2]
	end
	return nomes
end

-- Confere a forma de um clipe. Devolve true ou false + motivo.
function Amostra.validar(clipe: any): (boolean, string?)
	if type(clipe) ~= "table" then
		return false, "clipe não é tabela"
	end
	if type(clipe.fps) ~= "number" or clipe.fps <= 0 then
		return false, "fps inválido"
	end
	local dur = clipe.duracao
	if type(dur) ~= "number" or dur <= 0 then
		return false, "duração inválida"
	end
	if type(clipe.juntas) ~= "table" then
		return false, "sem juntas"
	end
	local function serie(chaves: any, largura: number, nome: string): (boolean, string?)
		if type(chaves) ~= "table" or #chaves == 0 then
			return false, nome .. ": sem quadros"
		end
		local anterior = -math.huge
		for i, ch in chaves do
			if type(ch) ~= "table" or #ch ~= largura then
				return false, nome .. ": quadro " .. i .. " malformado"
			end
			for _, v in ch do
				if type(v) ~= "number" or v ~= v then
					return false, nome .. ": quadro " .. i .. " com valor não numérico"
				end
			end
			if ch[1] <= anterior then
				return false, nome .. ": tempos não crescentes no quadro " .. i
			end
			if ch[1] < -1e-6 or ch[1] > dur + 1e-6 then
				return false, nome .. ": tempo fora da duração no quadro " .. i
			end
			anterior = ch[1]
			if largura == 5 then
				local m = math.sqrt(ch[2] * ch[2] + ch[3] * ch[3] + ch[4] * ch[4] + ch[5] * ch[5])
				if math.abs(m - 1) > 2e-3 then
					return false, nome .. ": quatérnio não unitário no quadro " .. i
				end
			end
		end
		return true
	end
	for nome, chaves in clipe.juntas do
		if not VALIDA[nome] then
			return false, "junta desconhecida: " .. tostring(nome)
		end
		local ok, erro = serie(chaves, 5, nome)
		if not ok then
			return false, erro
		end
	end
	if clipe.raiz ~= nil then
		local ok, erro = serie(clipe.raiz, 4, "raiz")
		if not ok then
			return false, erro
		end
	end
	if clipe.marcos ~= nil then
		if type(clipe.marcos) ~= "table" then
			return false, "marcos inválidos"
		end
		for nome, t in clipe.marcos do
			if type(nome) ~= "string" or type(t) ~= "number" or t < 0 or t > dur then
				return false, "marco fora da duração: " .. tostring(nome)
			end
		end
	end
	return true
end

return Amostra
