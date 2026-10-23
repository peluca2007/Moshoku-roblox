-- Dados puros da cena de abertura (primeira vez que alguém joga): trajeto da câmera,
-- falas da narração e título. Sem Instances, Vector3 nem serviços: roda também fora do
-- Studio (spec CenaAbertura). O módulo cliente `CenaAbertura` só toca estes dados.
--
-- Tudo é função do tempo da cena `t` (segundos): câmera = `amostrar(t)`, legenda =
-- `falaEm(t)`, título = `tituloEm(t)`, barras = `barrasEm(t)`. Assim o spec amostra a
-- cena inteira e o cliente pode congelar qualquer quadro para conferir enquadramento.
--
-- Âncoras (calculadas dos layouts, não digitadas): pico nevado = ponto mais alto de
-- TerrenoLayout.altura numa janela a sudoeste (a cordilheira é ruído; o pico muda se o
-- relevo mudar e o trajeto acompanha), lago = TerrenoLayout.AGUA[1], clareira =
-- FlorestaLayout.CLAREIRA, praça/chafariz = VilaLayout, portões = PropsPovoamento.
-- Altura de câmera e alvo = relevo no ponto + `acima` (studs); onde há copa de pinheiro
-- (até ~60 studs sobre o chão) a câmera sobe junto, o spec confere folga >= FOLGA_MINIMA.
--
-- Ordem: montanhas nevadas -> lago a oeste -> floresta -> trilha norte até a vila ->
-- praça com chafariz -> parada junto ao portão norte, olhando para fora dele.
local Shared = game:GetService("ReplicatedStorage").Shared
local Terreno = require(Shared.Mundo.TerrenoLayout)
local Vila = require(Shared.Mundo.VilaLayout)
local Floresta = require(Shared.Mundo.FlorestaLayout)
local Povoamento = require(Shared.Mundo.PropsPovoamento)

local D = {}

D.DURACAO = 25 -- s; o spec exige 18..28
D.FOLGA_MINIMA = 8 -- studs entre a câmera e o relevo em qualquer ponto do trajeto
D.FADE_FALA = 0.5 -- s de entrada e de saída de cada legenda
D.FADE_TITULO = 0.8
D.ENTRADA_BARRAS = 1.3 -- s até o letterbox fechar por completo (abre no cliente, na saída)
D.FADE_INICIAL = 1.1 -- s para sair do preto no começo
D.FADE_FINAL = 0.9 -- s finais para voltar ao preto (o cliente devolve a câmera sob o preto)
D.PALAVRAS_POR_SEGUNDO = 2.5 -- limite de leitura/dublagem para uma fala caber

-- Título: ~3 s no meio da cena, sobre a trilha entre a floresta e a vila.
D.TITULO = { texto = "MOSHOKU", subtitulo = "Crônicas de uma nova vida", inicio = 14.6, duracao = 3.2 }

-- Falas (dublagem futura: `audio` recebe o "rbxassetid://" do arquivo `chave`.ogg; ver
-- docs/DUBLAGEM.md). `inicio` e `duracao` em segundos de cena; nenhuma fala se sobrepõe.
D.FALAS = {
	{ chave = "abertura__01", texto = "Dizem que todo mundo ganha uma segunda chance…", inicio = 0.9, duracao = 3.8 },
	{ chave = "abertura__02", texto = "Aqui, a magia respira na água e no vento.", inicio = 5.8, duracao = 3.8 },
	{ chave = "abertura__03", texto = "Ela corre fundo nas árvores de poder.", inicio = 10.8, duracao = 3.2 },
	{ chave = "abertura__04", texto = "Mestres esperam por quem tem coragem de aprender.", inicio = 18.0, duracao = 3.6 },
	{ chave = "abertura__05", texto = "Sua nova vida começa aqui.", inicio = 21.9, duracao = 2.7 },
}

-- Âncoras -------------------------------------------------------------------
local function pontoMaisAlto(x0, x1, z0, z1, passo)
	local melhor = { x = x0, z = z0, h = -math.huge }
	for x = x0, x1, passo do
		for z = z0, z1, passo do
			local h = Terreno.altura(x, z)
			if h > melhor.h then melhor = { x = x, z = z, h = h } end
		end
	end
	return melhor
end

local lago = Terreno.AGUA[1]
D.ANCORAS = {
	-- Janela do maciço nevado a sudoeste (além do fundo da floresta): lá ficam os picos > 200.
	pico = pontoMaisAlto(-500, -250, -950, -700, 20),
	lago = { x = lago.x, z = lago.z },
	clareira = { x = Floresta.CLAREIRA.x, z = Floresta.CLAREIRA.z },
	praca = { x = Vila.PRACA.x, z = Vila.PRACA.z },
	chafariz = { x = Vila.CHAFARIZ.x, z = Vila.CHAFARIZ.z },
	portaoNorte = { x = 0, z = Povoamento.PORTAO_NORTE },
	portaoSul = { x = 0, z = -300 }, -- o cercado da vila fecha em z=-300 (PropsPovoamento.cercado)
}
local A = D.ANCORAS
local L, F, P, G = A.lago, A.clareira, A.praca, { sul = A.portaoSul, norte = A.portaoNorte }

-- Ponto com altura relativa ao relevo.
local function ponto(x, z, acima)
	return { x = x, y = Terreno.altura(x, z) + acima, z = z }
end

-- Quadros-chave: t, câmera, alvo (para onde olha) e campo de visão. A câmera nunca rola
-- (horizonte sempre nivelado): CFrame.lookAt com cima = +Y.
-- nome: leva o spec e a documentação ao plano certo.
local function quadro(t, nome, cx, cz, cAcima, ax, az, aAcima, fov)
	return { t = t, nome = nome, cam = ponto(cx, cz, cAcima), alvo = ponto(ax, az, aAcima), fov = fov }
end

D.QUADROS = {
	-- Montanhas: 400 studs ao norte do pico; o maciço enche o quadro e a câmera sobe devagar.
	quadro(0.0, "montanhas", A.pico.x + 75, A.pico.z + 400, 70, A.pico.x, A.pico.z, -30, 60),
	quadro(2.1, "montanhas", A.pico.x + 60, A.pico.z + 350, 100, A.pico.x, A.pico.z, -20, 62),
	-- Gira o olhar para leste, passando pela borda da mata (o alvo nunca cruza a câmera, para o
	-- giro ficar suave) e pousa na margem sudoeste do lago: água, vila e chaminés ao fundo.
	quadro(4.4, "montanhas", A.pico.x + 70, A.pico.z + 430, 80, -20, F.z + 45, 30, 62),
	quadro(5.6, "lago", L.x - 80, L.z - 120, 38, L.x + 35, L.z, 0, 62),
	quadro(7.6, "lago", L.x - 60, L.z - 85, 38, L.x + 35, L.z, 0, 64),
	-- Órbita em torno da clareira da floresta, 85..75 studs acima do chão, por cima das copas
	-- (pinheiros chegam a ~60): noroeste -> oeste -> sudoeste -> sul, sempre olhando para ela;
	-- no fim a câmera está ao sul e vira o olhar para a trilha que sobe até a vila.
	quadro(10.0, "floresta", F.x - 100, F.z + 100, 85, F.x, F.z, 25, 64),
	quadro(11.5, "floresta", F.x - 135, F.z, 82, F.x, F.z, 25, 64),
	quadro(12.9, "floresta", F.x - 85, F.z - 85, 80, F.x, F.z, 25, 64),
	quadro(14.2, "floresta", F.x, F.z - 95, 78, 0, F.z + 120, 20, 66),
	-- Mergulha até a trilha e voa baixo entre os pinheiros, rumo ao portão sul (vaga-lumes).
	quadro(15.6, "trilha", 0, F.z + 5, 22, 0, -300, 16, 66),
	quadro(17.4, "trilha", 0, -360, 22, 0, -250, 14, 66),
	-- Sobe sobre o portão sul e desce sobre a vila (o dojo, a leste e oeste as casas de palha).
	quadro(18.6, "vila", 6, G.sul.z - 12, 34, 0, P.z - 10, 6, 66),
	quadro(20.4, "vila", 6, -250, 28, 0, P.z, 6, 68),
	-- Sobre a praça, pelo corredor livre das barracas, descendo para a estrada.
	quadro(22.0, "praca", 0, -190, 24, 0, -120, 10, 66),
	quadro(23.6, "estrada", 0, -132, 12, 0, G.norte.z + 20, 12, 64),
	-- Chegada: dentro do portão norte, olhando para fora; o acampamento onde o jogador começa.
	quadro(25.0, "portao", 0, G.norte.z - 26, 8, 0, G.norte.z + 44, 14, 62),
}

-- Interpolação: Hermite cúbica com tangentes de Catmull-Rom para tempos desiguais; as
-- pontas têm tangente nula (partida e chegada suaves) e a velocidade é contínua nos
-- quadros. Sem cortes: o trajeto inteiro é uma única curva.
local function hermite(p0, p1, m0, m1, h, u)
	local u2 = u * u
	local u3 = u2 * u
	return (2 * u3 - 3 * u2 + 1) * p0 + (u3 - 2 * u2 + u) * h * m0
		+ (-2 * u3 + 3 * u2) * p1 + (u3 - u2) * h * m1
end
local function tangente(q, i, campo, eixo)
	local a, b = q[i - 1], q[i + 1]
	if not a or not b then return 0 end
	local va = if eixo then a[campo][eixo] else a[campo]
	local vb = if eixo then b[campo][eixo] else b[campo]
	return (vb - va) / (b.t - a.t)
end
local function valor(i, campo, eixo, u, h)
	local q = D.QUADROS
	local v0 = if eixo then q[i][campo][eixo] else q[i][campo]
	local v1 = if eixo then q[i + 1][campo][eixo] else q[i + 1][campo]
	return hermite(v0, v1, tangente(q, i, campo, eixo), tangente(q, i + 1, campo, eixo), h, u)
end

-- {x,y,z, ax,ay,az, fov, nome} na cena em `t` (fora de 0..DURACAO fica na pose da ponta).
function D.amostrar(t: number)
	local q = D.QUADROS
	t = math.clamp(t, q[1].t, q[#q].t)
	local i = 1
	while i < #q - 1 and t > q[i + 1].t do i += 1 end
	local h = q[i + 1].t - q[i].t
	local u = (t - q[i].t) / h
	return {
		x = valor(i, "cam", "x", u, h), y = valor(i, "cam", "y", u, h), z = valor(i, "cam", "z", u, h),
		ax = valor(i, "alvo", "x", u, h), ay = valor(i, "alvo", "y", u, h), az = valor(i, "alvo", "z", u, h),
		fov = valor(i, "fov", nil, u, h), nome = if u < 0.5 then q[i].nome else q[i + 1].nome,
	}
end

-- Janela com fade linear de entrada/saída: 0..1.
local function janela(t, inicio, duracao, fade)
	return math.clamp((t - inicio) / fade, 0, 1) * math.clamp((inicio + duracao - t) / fade, 0, 1)
end
local function suave(v)
	v = math.clamp(v, 0, 1)
	return v * v * (3 - 2 * v)
end

-- Fala visível em `t`: (fala, opacidade 0..1) ou nil.
function D.falaEm(t: number)
	for _, f in ipairs(D.FALAS) do
		if t >= f.inicio and t <= f.inicio + f.duracao then
			return f, suave(janela(t, f.inicio, f.duracao, D.FADE_FALA))
		end
	end
	return nil, 0
end

-- Opacidade do título em `t` (0 fora da janela).
function D.tituloEm(t: number): number
	local ti = D.TITULO
	return suave(janela(t, ti.inicio, ti.duracao, D.FADE_TITULO))
end

-- Letterbox: 0 (sem barras) .. 1 (barras fechadas); fecha no começo e fica até o preto final.
function D.barrasEm(t: number): number
	return suave(t / D.ENTRADA_BARRAS)
end

-- Opacidade do véu preto (1 = tela preta): sai do preto no começo e volta a ele no fim.
function D.veuEm(t: number): number
	return math.max(1 - suave(t / D.FADE_INICIAL), suave((t - (D.DURACAO - D.FADE_FINAL)) / D.FADE_FINAL))
end

function D.palavras(texto: string): number
	local n = 0
	for _ in string.gmatch(texto, "%S+") do n += 1 end
	return n
end

return D
