-- HAB2: curvas puras das magias de Água (sem Instances nem eventos). A apresentação (client/MagiasAgua)
-- só pede números daqui; assim o ritmo, o freio da flecha e a câmera lenta têm spec próprio.
local M = {}

-- Paleta em RGB 0-255 (o cliente converte): água viva, brilho, espuma e gelo.
M.PALETA = {
	agua = { 70, 160, 255 },
	profunda = { 28, 96, 200 },
	brilho = { 190, 235, 255 },
	espuma = { 235, 248, 255 },
	gelo = { 170, 225, 250 },
	gelo_escuro = { 96, 170, 225 },
}

-- Fração do caminho percorrida no instante u (0..1). `freio` 0 = reta; 1,2 = freia perto do alvo (ease-out).
-- Monotônica, avanco(0)=0 e avanco(1)=1.
function M.avanco(u: number, freio: number?): number
	u = math.clamp(u, 0, 1)
	return 1 - (1 - u) ^ (1 + math.max(freio or 0, 0))
end

-- Duração do voo (s) a partir da distância (m) e da velocidade (m/s), limitada para não ficar nem instantâneo
-- nem arrastado.
function M.duracaoDoVoo(distancia: number, velocidade: number, minimo: number?, maximo: number?): number
	local v = math.max(velocidade, 1e-3)
	return math.clamp(distancia / v, minimo or 0.25, maximo or 0.9)
end

-- Deslocamento em hélice (par perpendicular ao voo): u 0..1, raio em m, voltas e fase (rad).
function M.helice(u: number, raio: number, voltas: number, fase: number?): (number, number)
	local a = (fase or 0) + u * voltas * 2 * math.pi
	local r = raio * math.sin(math.pi * math.clamp(u, 0, 1)) -- fecha nas pontas
	return math.cos(a) * r, math.sin(a) * r
end

-- Posição em órbita (n gotas igualmente espaçadas) no instante t; retorna dx, dy no plano da órbita.
function M.orbita(t: number, raio: number, n: number, i: number, velocidade: number?): (number, number)
	local a = (i / math.max(n, 1)) * 2 * math.pi + t * (velocidade or 4)
	return math.cos(a) * raio, math.sin(a) * raio
end

-- Ponto de um projétil balístico (gotas e cacos): x = x0 + v*t, y com gravidade.
function M.balistica(x0: number, y0: number, z0: number, vx: number, vy: number, vz: number, t: number, g: number?)
	local gg = g or 55
	return x0 + vx * t, y0 + vy * t - 0.5 * gg * t * t, z0 + vz * t
end

-- Quantas partículas/gotas: movimento reduzido mantém 1/4 (nunca zero); crítico acrescenta 50%.
function M.quantidade(base: number, critico: boolean?, reduzidos: boolean?): number
	local n = base * (if critico then 1.5 else 1)
	if reduzidos then n = n * 0.25 end
	return math.max(1, math.floor(n + 0.5))
end

-- Taxa de tempo da cena (câmera lenta curta, marca da Flecha de Água): `real` s desde o contato.
-- Fica em `minimo` por `duracao` s, depois volta a 1 numa rampa de mesma duração; antes do contato é 1.
function M.taxaDeTempo(real: number, duracao: number, minimo: number): number
	if real < 0 or duracao <= 0 then return 1 end
	if real <= duracao then return minimo end
	local k = (real - duracao) / duracao
	if k >= 1 then return 1 end
	return minimo + (1 - minimo) * k
end

-- Tempo da cena (s) depois de `dt` s reais com a taxa do instante (integração simples; passos pequenos).
function M.integrar(tCena: number, dt: number, taxa: number, escalaQA: number?): number
	return tCena + dt * taxa / math.max(escalaQA or 1, 1)
end

return M
