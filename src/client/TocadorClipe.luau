-- TocadorClipe (ANIM1): toca os clipes de animação por dados (ReplicatedStorage.Shared.Animacoes) num modelo R15,
-- escrevendo Motor6D.Transform a cada quadro em RunService.PreSimulation. O Animator escreve antes desse evento,
-- então o valor posto aqui prevalece sobre a animação do Roblox nas juntas que o clipe usa. Só apresentação:
-- não muda CFrame do modelo, ficha nem rede. Serve ao avatar do jogador e ao fantasma de client/Corpo.luau
-- (que converte AnimationConstraint em Motor6D); AnimationConstraint.Transform também é aceito.
--
-- API
--   local Tocador = require(Client.TocadorClipe)
--   local t = Tocador.novo(modeloR15, { escalaRaiz = number? })
--       escalaRaiz multiplica a translação da raiz (studs do boneco de referência, R15 padrão); padrão =
--       HumanoidRootPart.Size.Y / 2 (1 no R15 padrão).
--   local c = t:tocar(nomeOuClipe, {
--       velocidade = 1, peso = 1,       -- peso final da camada (0..1)
--       fadeEntrada = 0.12, fadeSaida = 0.18,  -- segundos; o fade de saída ocorre nos últimos segundos do clipe
--       camada = "base" | "acao",       -- padrão: "base" se o clipe tem laço, senão "acao"
--       segurar = boolean?,             -- fica no último quadro até parar() (padrão: campo `segurar` do clipe)
--       aoMarco = function(nome) end,   -- chamado (task.spawn) ao cruzar cada marco: "impacto", "soltar", ...
--       aoFim = function() end,         -- chamado quando a camada sai de cena (fim natural ou parar)
--       manual = boolean?,              -- LUTA-A: o tempo não anda sozinho; quem toca chama c:em(t) a cada
--                                       -- quadro (ex.: relógio da cena da Coreografia, que respeita
--                                       -- CenaTempoFixo e a câmera lenta). Fades e marcos seguem esse tempo.
--   })
--   c:em(t)          -- (manual) põe a camada no instante t do clipe (segundos do clipe, já com a velocidade)
--   c:parar(fade?)   -- tira esta camada com fade (padrão: fadeSaida)
--   c.terminou       -- true depois que a camada saiu de cena
--   t:parar(fade?)   -- para todas as camadas
--   t:destruir()     -- desconecta tudo e devolve os Transform originais (também ocorre se o modelo for destruído)
-- Mistura: as camadas "base" (ex.: PosturaCombate em laço) são aplicadas primeiro e as de "acao" por cima, por
-- slerp com o peso de cada uma. Tocar uma nova camada do mesmo tipo tira a anterior com fade (troca suave).
-- Junta que nenhuma camada usa não é tocada; ao sair de cena, cada junta escrita volta ao Transform que tinha
-- quando o tocador foi criado.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Amostra = require(Shared.Animacoes.Amostra)
local Catalogo = require(Shared.Animacoes.Catalogo)

local Tocador = {}
Tocador.__index = Tocador

local Controle = {}
Controle.__index = Controle

local FADE_ENTRADA = 0.12
local FADE_SAIDA = 0.18

local function chamar(fn: any, ...)
	if fn then
		task.spawn(fn, ...)
	end
end

function Tocador.novo(modelo: Model, opcoes: { escalaRaiz: number? }?)
	assert(typeof(modelo) == "Instance", "TocadorClipe.novo espera um Model")
	local self = setmetatable({
		modelo = modelo,
		juntas = {} :: { [string]: Instance },
		originais = {} :: { [string]: CFrame },
		escritas = {} :: { [string]: boolean },
		camadas = {},
		conexao = nil :: RBXScriptConnection?,
		vivo = true,
	}, Tocador)
	for _, nome in Amostra.JUNTAS do
		local j = modelo:FindFirstChild(nome, true)
		if j and (j:IsA("Motor6D") or j:IsA("AnimationConstraint")) then
			self.juntas[nome] = j
			self.originais[nome] = (j :: any).Transform
		end
	end
	local escala = opcoes and opcoes.escalaRaiz
	if not escala then
		local hrp = modelo:FindFirstChild("HumanoidRootPart")
		escala = if hrp and hrp:IsA("BasePart") then hrp.Size.Y / 2 else 1
	end
	self.escalaRaiz = escala
	self.aoDestruir = modelo.Destroying:Connect(function()
		self:destruir()
	end)
	return self
end

function Tocador:tocar(nomeOuClipe: any, opcoes: { [string]: any }?)
	assert(self.vivo, "TocadorClipe já destruído")
	local clipe = if type(nomeOuClipe) == "string" then Catalogo.CLIPES[nomeOuClipe] else nomeOuClipe
	assert(type(clipe) == "table" and clipe.juntas, "clipe desconhecido: " .. tostring(nomeOuClipe))
	local o = opcoes or {}
	local camada = o.camada or (if clipe.laco then "base" else "acao")
	local c = setmetatable({
		clipe = clipe,
		camada = camada,
		tempo = 0,
		decorrido = 0,
		velocidade = o.velocidade or 1,
		peso = math.clamp(o.peso or 1, 0, 1),
		fadeEntrada = o.fadeEntrada or FADE_ENTRADA,
		fadeSaida = o.fadeSaida or FADE_SAIDA,
		segurar = if o.segurar ~= nil then o.segurar else clipe.segurar == true,
		aoMarco = o.aoMarco,
		aoFim = o.aoFim,
		manual = o.manual == true,
		alvoTempo = 0,
		terminou = false,
		parandoEm = nil :: number?,
		fadeParada = 0,
		pesoAtual = 0,
	}, Controle)
	for _, outra in self.camadas do
		if outra.camada == camada and not outra.parandoEm then
			outra:parar(c.fadeEntrada)
		end
	end
	table.insert(self.camadas, c)
	-- marco em t = 0 (ex.: impacto da reação) dispara já no primeiro quadro
	for _, nome in Amostra.marcosEntre(clipe, -1e-6, 0) do
		chamar(c.aoMarco, nome)
	end
	if not self.conexao then
		self.conexao = RunService.PreSimulation:Connect(function(dt)
			self:_passo(dt)
		end)
	end
	return c
end

function Controle:em(t: number)
	self.alvoTempo = t
end

function Controle:parar(fade: number?)
	if self.terminou then
		return
	end
	local f = fade or self.fadeSaida
	if self.parandoEm and self.fadeParada <= f then
		return
	end
	self.parandoEm = self.decorrido
	self.fadeParada = math.max(f, 0)
end

function Tocador:parar(fade: number?)
	for _, c in self.camadas do
		c:parar(fade)
	end
end

local function finalizar(c)
	if not c.terminou then
		c.terminou = true
		chamar(c.aoFim)
	end
end

function Tocador:_restaurar(nome: string)
	local j = self.juntas[nome]
	if j and j.Parent then
		(j :: any).Transform = self.originais[nome]
	end
	self.escritas[nome] = nil
end

function Tocador:_passo(dt: number)
	-- avança as camadas, dispara marcos e calcula o peso de cada uma
	local vivas = {}
	for _, c in self.camadas do
		local antes = c.tempo
		if c.manual then
			-- relógio externo: o "decorrido" (fades) acompanha o tempo do clipe, não o do quadro
			local passo = math.max(0, c.alvoTempo - c.tempo)
			c.tempo = c.alvoTempo
			-- parando: o fade de saída anda no relógio real (o dono pode já ter parado de chamar em())
			c.decorrido += if c.parandoEm then dt else passo / math.max(c.velocidade, 1e-3)
		else
			c.tempo += dt * c.velocidade
			c.decorrido += dt
		end
		local clipe = c.clipe
		local limite = if clipe.laco or c.segurar then c.tempo else math.min(c.tempo, clipe.duracao)
		for _, nome in Amostra.marcosEntre(clipe, antes, limite) do
			chamar(c.aoMarco, nome)
		end
		local w = c.peso * Amostra.peso(c.tempo, clipe.duracao, nil, c.fadeSaida, clipe.laco, c.segurar)
		w *= if c.fadeEntrada > 0 then math.clamp(c.decorrido / c.fadeEntrada, 0, 1) else 1
		if c.parandoEm then
			w *= if c.fadeParada > 0 then math.clamp(1 - (c.decorrido - c.parandoEm) / c.fadeParada, 0, 1) else 0
		end
		local fimNatural = not clipe.laco and not c.segurar and c.tempo >= clipe.duracao
		if (c.parandoEm and w <= 0) or fimNatural then
			finalizar(c)
		else
			c.pesoAtual = w
			table.insert(vivas, c)
		end
	end
	-- base primeiro, ação por cima (ordem de entrada dentro de cada grupo)
	local ordem = {}
	for _, c in vivas do
		if c.camada == "base" then
			table.insert(ordem, c)
		end
	end
	for _, c in vivas do
		if c.camada ~= "base" then
			table.insert(ordem, c)
		end
	end
	self.camadas = vivas
	local usadas = {}
	for nome, j in self.juntas do
		local x, y, z, w = 0, 0, 0, 1
		local px, py, pz = 0, 0, 0
		local tocada = false
		for _, c in ordem do
			local chaves = c.clipe.juntas[nome]
			if chaves and c.pesoAtual > 0 then
				local t = Amostra.tempoLocal(c.clipe, c.tempo)
				local qx, qy, qz, qw = Amostra.junta(chaves, t)
				x, y, z, w = Amostra.slerp(x, y, z, w, qx, qy, qz, qw, c.pesoAtual)
				if nome == "Root" then
					local rx, ry, rz = Amostra.raiz(c.clipe.raiz, t)
					local e = self.escalaRaiz
					px += (rx * e - px) * c.pesoAtual
					py += (ry * e - py) * c.pesoAtual
					pz += (rz * e - pz) * c.pesoAtual
				end
				tocada = true
			end
		end
		if tocada and j.Parent then
			(j :: any).Transform = CFrame.new(px, py, pz, x, y, z, w)
			self.escritas[nome] = true
			usadas[nome] = true
		end
	end
	for nome in self.escritas do
		if not usadas[nome] then
			self:_restaurar(nome)
		end
	end
	if #vivas == 0 and self.conexao then
		self.conexao:Disconnect()
		self.conexao = nil
	end
end

function Tocador:destruir()
	if not self.vivo then
		return
	end
	self.vivo = false
	if self.conexao then
		self.conexao:Disconnect()
		self.conexao = nil
	end
	if self.aoDestruir then
		self.aoDestruir:Disconnect()
		self.aoDestruir = nil
	end
	for nome in self.escritas do
		self:_restaurar(nome)
	end
	for _, c in self.camadas do
		finalizar(c)
	end
	self.camadas = {}
end

return Tocador
