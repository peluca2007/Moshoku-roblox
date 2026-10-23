-- Perfis de iluminação por zona, em dados puros (sem Instances nem Color3, roda fora do
-- Studio). Cores são {r, g, b} de 0 a 255. O cliente (client/AmbienteMundo) aplica o
-- perfil da zona onde o personagem está, com transição suave. Só apresentação.
--
-- noite    : sala da Mesa e salão do livro (igual ao que MesaWorld deixa no servidor).
-- dia      : região inicial e vila, fim de tarde ameno.
-- floresta : Floresta Sombria, crepúsculo verde-azulado e névoa densa.
-- ruinas   : Ruínas do Vale, céu violeta encoberto.
--
-- Mundo V2 (16/10): o place passa a usar Lighting.Technology = Future (tools/build-place.ps1),
-- que renderiza mais claro e contrastado que Voxel; por isso brilho e ambiente ficam
-- conservadores. Valores afinados no papel, a confirmar no Play (ver docs/VISUAL.md).
local AmbientePerfis = {}

export type Cor = { number }
-- Texturas do Sky, por face: { bk, dn, ft, lf, rt, up } = "rbxassetid://..." (vazio = céu padrão).
export type Skybox = { bk: string?, dn: string?, ft: string?, lf: string?, rt: string?, up: string? }
export type Perfil = {
	clock: number, -- Lighting.ClockTime
	brilho: number, -- Lighting.Brightness
	difuso: number, -- EnvironmentDiffuseScale
	especular: number, -- EnvironmentSpecularScale
	ambiente: Cor,
	ambienteExterno: Cor, -- OutdoorAmbient
	deslocaCima: Cor, -- ColorShift_Top (cor do sol sobre as superfícies)
	atmDensidade: number,
	atmOffset: number,
	atmGlare: number,
	atmHaze: number,
	atmCor: Cor,
	atmDecay: Cor,
	bloomIntensidade: number,
	bloomTamanho: number,
	bloomLimiar: number,
	ccContraste: number,
	ccSaturacao: number,
	ccTint: Cor,
	raios: number, -- SunRaysEffect.Intensity
	dofLonge: number, -- DepthOfField.FarIntensity (só desfoca ao longe; 0 desliga)
	dofDistancia: number, -- DepthOfField.FocusDistance (studs)
	dofRaio: number, -- DepthOfField.InFocusRadius (studs)
	estrelas: number, -- Sky.StarCount
	solTam: number, -- Sky.SunAngularSize
	luaTam: number, -- Sky.MoonAngularSize
	nuvemCobertura: number, -- Clouds.Cover (0 a 1)
	nuvemDensidade: number, -- Clouds.Density (0 a 1)
	nuvemCor: Cor, -- Clouds.Color
	skybox: Skybox, -- ids das 6 texturas; vazio/incompleto mantém o céu padrão (não é misturado)
}

-- Faces do Sky, na ordem de Skybox{Bk,Dn,Ft,Lf,Rt,Up}.
AmbientePerfis.FACES_SKYBOX = { "bk", "dn", "ft", "lf", "rt", "up" }

AmbientePerfis.PERFIS = {
	noite = {
		clock = 0, brilho = 1, difuso = 0.25, especular = 0.2,
		ambiente = { 58, 58, 68 }, ambienteExterno = { 46, 46, 56 }, deslocaCima = { 0, 0, 0 },
		atmDensidade = 0.32, atmOffset = 0.2, atmGlare = 0, atmHaze = 0.4,
		atmCor = { 16, 16, 19 }, atmDecay = { 7, 7, 9 },
		bloomIntensidade = 0.55, bloomTamanho = 30, bloomLimiar = 1.6,
		ccContraste = 0.12, ccSaturacao = 0.05, ccTint = { 236, 238, 255 },
		raios = 0,
		dofLonge = 0, dofDistancia = 60, dofRaio = 60,
		estrelas = 3000, solTam = 21, luaTam = 11,
		nuvemCobertura = 0, nuvemDensidade = 0, nuvemCor = { 40, 40, 52 },
		skybox = {},
	},
	dia = {
		-- ~16h30 dourado: sol baixo = sombras longas; topo quente contra ambiente externo azulado
		-- frio. Brilho 2.2 (era 2.4 em Voxel) porque Future clareia.
		clock = 16.5, brilho = 2.2, difuso = 0.6, especular = 0.45,
		ambiente = { 88, 92, 108 }, ambienteExterno = { 112, 124, 154 }, deslocaCima = { 255, 212, 148 },
		-- Névoa de distância: Density 0.36 e Haze 2.2 escondem o horizonte; Decay quente no fim.
		atmDensidade = 0.36, atmOffset = 0.25, atmGlare = 0.4, atmHaze = 2.2,
		atmCor = { 206, 204, 222 }, atmDecay = { 246, 190, 128 },
		bloomIntensidade = 0.35, bloomTamanho = 28, bloomLimiar = 1.5,
		ccContraste = 0.1, ccSaturacao = 0.14, ccTint = { 255, 244, 228 },
		raios = 0.07,
		dofLonge = 0.18, dofDistancia = 70, dofRaio = 70,
		estrelas = 800, solTam = 28, luaTam = 12,
		-- Nuvens volumosas e douradas.
		nuvemCobertura = 0.62, nuvemDensidade = 0.6, nuvemCor = { 255, 214, 170 },
		skybox = {},
	},
	floresta = {
		-- Ajustado a olho no Play (15/10): ambiente alto, senão o chão escuro some; ClockTime
		-- acima de ~17,8 já vira noite com lua (17,72 = crepúsculo legível). Névoa (Haze) precisa de valor alto para aparecer.
		-- B1: mais luz de preenchimento, mantendo névoa e tom verde-azulado.
		clock = 17.72, brilho = 1.9, difuso = 0.5, especular = 0.3,
		ambiente = { 144, 172, 166 }, ambienteExterno = { 164, 190, 184 }, deslocaCima = { 214, 196, 130 },
		atmDensidade = 0.64, atmOffset = 0.1, atmGlare = 0, atmHaze = 4.6,
		atmCor = { 112, 140, 132 }, atmDecay = { 60, 86, 80 },
		bloomIntensidade = 0.4, bloomTamanho = 30, bloomLimiar = 1.4,
		ccContraste = 0.12, ccSaturacao = -0.22, ccTint = { 208, 236, 228 },
		raios = 0.04,
		dofLonge = 0.22, dofDistancia = 40, dofRaio = 50,
		estrelas = 300, solTam = 14, luaTam = 9,
		-- Cobertura alta e escura, sob a copa.
		nuvemCobertura = 0.9, nuvemDensidade = 0.55, nuvemCor = { 96, 112, 112 },
		skybox = {},
	},
}

-- Ruínas do Vale (RuinasLayout, x>=480): céu encoberto, névoa violeta e luz fria.
AmbientePerfis.PERFIS.ruinas = {
	clock = 17.45, brilho = 1.8, difuso = 0.5, especular = 0.35,
	ambiente = { 108, 104, 136 }, ambienteExterno = { 128, 126, 164 }, deslocaCima = { 196, 186, 236 },
	atmDensidade = 0.56, atmOffset = 0.12, atmGlare = 0, atmHaze = 4.2,
	atmCor = { 170, 160, 206 }, atmDecay = { 120, 100, 150 },
	bloomIntensidade = 0.5, bloomTamanho = 30, bloomLimiar = 1.4,
	ccContraste = 0.12, ccSaturacao = -0.1, ccTint = { 232, 226, 250 },
	raios = 0,
	dofLonge = 0.2, dofDistancia = 60, dofRaio = 60,
	estrelas = 1200, solTam = 12, luaTam = 18,
	nuvemCobertura = 0.82, nuvemDensidade = 0.65, nuvemCor = { 150, 138, 184 },
	skybox = {},
}
AmbientePerfis.RUINAS_X = 400 -- da vila/floresta (x<=110) e da sala (x~250) à região das ruínas

-- A floresta começa em z=-300 (FlorestaLayout.SOLO). A mistura com a vila corre de
-- z=-270 até z=-320, então a luz muda aos poucos ao descer a trilha.
AmbientePerfis.FLORESTA_INICIO = -270
AmbientePerfis.FLORESTA_FIM = -320
-- Tempo (s) para fechar ~63% da distância ao perfil alvo.
AmbientePerfis.TAU_ZONA = 1.1
AmbientePerfis.TAU_SALA = 0.6

local function suave(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function misturarCor(a: Cor, b: Cor, t: number): Cor
	return { lerp(a[1], b[1], t), lerp(a[2], b[2], t), lerp(a[3], b[3], t) }
end

-- Verdadeiro se as 6 faces têm um id de textura (texto não vazio).
function AmbientePerfis.skyboxCompleto(skybox: Skybox?): boolean
	if not skybox then
		return false
	end
	for _, face in AmbientePerfis.FACES_SKYBOX do
		local id = (skybox :: any)[face]
		if type(id) ~= "string" or id == "" then
			return false
		end
	end
	return true
end

-- Mistura dois perfis; t=0 devolve `a`, t=1 devolve `b`. Sempre cria um perfil novo.
-- Texturas do céu não se misturam: vale a do perfil mais próximo (troca em t=0,5).
function AmbientePerfis.misturar(a: Perfil, b: Perfil, t: number): Perfil
	t = math.clamp(t, 0, 1)
	local resultado = {}
	for chave, valor in a do
		if chave == "skybox" then
			resultado[chave] = if t < 0.5 then valor else (b :: any)[chave]
		elseif type(valor) == "table" then
			resultado[chave] = misturarCor(valor, (b :: any)[chave], t)
		else
			resultado[chave] = lerp(valor, (b :: any)[chave], t)
		end
	end
	return resultado :: any
end

-- Pesos de cada perfil no ponto (x, z) do mundo. `naSala` vale para a sala da Mesa
-- e o salão do livro, que ficam sempre na noite.
function AmbientePerfis.pesos(x: number, z: number, naSala: boolean): { [string]: number }
	if naSala then
		return { noite = 1, dia = 0, floresta = 0, ruinas = 0 }
	end
	if x >= AmbientePerfis.RUINAS_X then
		return { noite = 0, dia = 0, floresta = 0, ruinas = 1 }
	end
	local f = suave((AmbientePerfis.FLORESTA_INICIO - z) / (AmbientePerfis.FLORESTA_INICIO - AmbientePerfis.FLORESTA_FIM))
	return { noite = 0, dia = 1 - f, floresta = f, ruinas = 0 }
end

-- Perfil alvo do ponto: mistura ponderada de noite/dia/floresta.
function AmbientePerfis.alvo(x: number, z: number, naSala: boolean): Perfil
	local pesos = AmbientePerfis.pesos(x, z, naSala)
	if pesos.noite >= 1 then
		return AmbientePerfis.misturar(AmbientePerfis.PERFIS.noite, AmbientePerfis.PERFIS.noite, 0)
	end
	if pesos.ruinas >= 1 then
		return AmbientePerfis.misturar(AmbientePerfis.PERFIS.ruinas, AmbientePerfis.PERFIS.ruinas, 0)
	end
	return AmbientePerfis.misturar(AmbientePerfis.PERFIS.dia, AmbientePerfis.PERFIS.floresta, pesos.floresta)
end

-- Avança `atual` em direção a `alvo` por `dt` segundos (suavização exponencial, estável
-- para qualquer dt). Devolve um perfil novo.
function AmbientePerfis.passo(atual: Perfil, alvo: Perfil, dt: number, tau: number): Perfil
	local t = 1 - math.exp(-math.max(dt, 0) / math.max(tau, 1e-3))
	return AmbientePerfis.misturar(atual, alvo, t)
end

-- A hora modula luz e cores sem substituir a névoa e o céu de cada zona.
function AmbientePerfis.modularHora(perfil, hora)
	if type(hora) ~= "number" then return perfil end
	hora %= 24
	local luz = math.clamp(math.sin((hora - 6) * math.pi / 12), 0, 1)
	local calor = math.max(0, 1 - math.abs(hora - 18) / 3) + math.max(0, 1 - math.abs(hora - 6) / 2)
	local novo = table.clone(perfil)
	novo.clock = hora
	novo.brilho = perfil.brilho * (.38 + .62 * luz)
	for _, chave in { "ambiente", "ambienteExterno", "atmCor", "nuvemCor", "ccTint" } do
		local c = perfil[chave]
		local fator = if chave == "ccTint" then .8 + .2 * luz else .48 + .52 * luz
		novo[chave] = { math.clamp(c[1]*fator + calor*10,0,255), math.clamp(c[2]*fator + calor*3,0,255), math.clamp(c[3]*fator,0,255) }
	end
	novo.raios = perfil.raios * luz
	return novo
end


-- Luz pessoal apenas no mundo: floresta (inclui a trilha) ou noite do relógio.
-- Sem hora replicada usa a hora do perfil local; sala conserva iluminação própria.
function AmbientePerfis.luzPessoal(x: number, z: number, naSala: boolean, hora: number?): boolean
	if naSala then return false end
	local pesos = AmbientePerfis.pesos(x, z, false)
	local h = if type(hora) == "number" then hora % 24 else AmbientePerfis.alvo(x, z, false).clock
	return pesos.floresta >= 0.5 or h < 6 or h >= 18
end

return AmbientePerfis
