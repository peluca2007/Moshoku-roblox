-- Retoque de luz para a arena durante a luta (BELEZA1): dado puro sobre um perfil de AmbientePerfis.
-- Mais contraste e tom quente nas sombras, névoa um pouco mais densa no fundo, brilho suave nas luzes e
-- desfoque leve só ao longe. Devolve um perfil novo; o cliente (AmbienteMundo) volta ao perfil normal
-- quando a luta termina porque simplesmente deixa de aplicar este retoque.
local PerfilLuta = {}

local function misturar(c: { number }, alvo: { number }, t: number): { number }
	return { c[1] + (alvo[1] - c[1]) * t, c[2] + (alvo[2] - c[2]) * t, c[3] + (alvo[3] - c[3]) * t }
end

-- Clima do esgoto (CEN1): sala fechada, escura, névoa verde-acinzentada; o calor vem das tochas.
local function esgoto(p)
	p.ambiente = { 52, 64, 60 }
	p.ambienteExterno = { 52, 64, 60 }
	p.deslocaCima = { 20, 28, 24 }
	p.brilho = 0.5
	p.difuso = 0.5
	p.ccContraste = p.ccContraste + 0.06
	p.ccSaturacao = p.ccSaturacao - 0.08
	p.ccTint = { 215, 238, 222 }
	p.atmDensidade = 0.5
	p.atmHaze = 4
	p.atmCor = { 70, 96, 84 }
	p.atmDecay = { 40, 60, 52 }
	p.raios = 0
	p.dofDistancia = 70
	return p
end

function PerfilLuta.aplicar(perfil, arenaId)
	local p = table.clone(perfil)
	p.ccContraste = perfil.ccContraste + 0.14
	p.ccSaturacao = perfil.ccSaturacao + 0.1
	p.ccTint = misturar(perfil.ccTint, { 255, 232, 205 }, 0.45)
	p.atmDensidade = math.max(perfil.atmDensidade, 0.3) + 0.1
	p.atmHaze = math.max(perfil.atmHaze, 2.2)
	p.atmCor = misturar(perfil.atmCor, { 176, 150, 130 }, 0.35)
	p.bloomIntensidade = math.max(perfil.bloomIntensidade, 0.75)
	p.bloomLimiar = math.min(perfil.bloomLimiar, 1.1)
	p.bloomTamanho = math.max(perfil.bloomTamanho, 36)
	p.dofLonge = math.max(perfil.dofLonge, 0.45)
	p.dofDistancia = 55
	p.dofRaio = 35
	p.brilho = perfil.brilho * 1.08
	return if arenaId == "esgoto" then esgoto(p) else p
end

return PerfilLuta
