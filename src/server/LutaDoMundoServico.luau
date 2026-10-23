-- Ponte do Modo História (PLANO §13): a patrulha encosta no jogador e o grupo luta na arena da
-- mesa (EncontroService), com o cenário da região onde estava; no fim, volta ao mesmo ponto do mapa.
-- O avatar é a ficha (AvatarFichas): o grupo é posto na entrada da arena, dá os últimos passos até
-- as casas e, no fim, volta ao ponto exato do contato.
-- Servidor decide grupo, inimigos e recompensa; nenhum remoto chega aqui.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EncontrosPorZona = require(ReplicatedStorage.Shared.EncontrosPorZona)
local Elenco = require(ReplicatedStorage.Shared.EncontroAutonomoElenco)
local Recompensa = require(ReplicatedStorage.Shared.Regras.RecompensaEncontro)
local Arenas = require(ReplicatedStorage.Shared.Mundo.ArenasDados)
local Protocol = require(ReplicatedStorage.Shared.MesaProtocol)

local LutaDoMundo = {}

local RAIO_GRUPO = 40 -- studs: quem está perto do contato entra junto
-- Depois de uma luta o grupo volta ao mesmo ponto; sem trégua, a patrulha vizinha o puxava na hora.
LutaDoMundo.TREGUA_SEGUNDOS = 12
LutaDoMundo.LIMITE_GRUPO = 4

local function raiz(player)
	local personagem = player and player.Character
	local r = personagem and personagem:FindFirstChild("HumanoidRootPart")
	local h = personagem and personagem:FindFirstChildOfClass("Humanoid")
	if r and r:IsA("BasePart") and h and h.Health > 0 then return r end
	return nil
end

-- deps: iniciarLuta(grupo, criaturas, opcoes) -> erro?, corpoPessoal(player), recompensar(player, id, moedas, marco, pa),
-- cenario { aplicar(arenaId?) }, jogadores(), aoEncerrar(encontro, estado), rng(), limiteGrupo()
function LutaDoMundo.start(deps)
	local jogadores = deps.jogadores or function() return Players:GetPlayers() end
	local rng = deps.rng or function() return math.random() end
	local agora = deps.agora or os.clock
	local treguaAte = {} -- userId -> instante
	local cacadas
	local ativa = nil -- { patrulha, definicao, grupo, ancorados, encounterId }
	local api = {}

	function api.definirCacadas(c) cacadas = c end
	function api.ativa() return ativa ~= nil end

	local function temFicha(player)
		if not deps.corpoPessoal then return false end
		if (treguaAte[player.UserId] or 0) > agora() then return false end
		local ok, corpo = pcall(deps.corpoPessoal, player)
		local atual = ok and corpo and corpo.session and corpo.session.current
		return ok and corpo ~= nil and (not atual or not atual.pv or atual.pv > 0)
	end

	local function montarGrupo(player)
		local centro = raiz(player)
		if not centro then return nil end
		local limite = (deps.limiteGrupo and deps.limiteGrupo()) or LutaDoMundo.LIMITE_GRUPO
		local grupo = { player }
		local outros = table.clone(jogadores())
		table.sort(outros, function(a, b) return a.UserId < b.UserId end)
		for _, outro in outros do
			if #grupo >= limite then break end
			local r = outro ~= player and raiz(outro)
			if r and (r.Position - centro.Position).Magnitude <= RAIO_GRUPO and temFicha(outro) then
				table.insert(grupo, outro)
			end
		end
		return grupo
	end

	-- Beira sul do tabuleiro, de frente para os inimigos: a caminhada da mesa (14 studs/s) cobre só
	-- alguns passos, em vez dos ~1000 studs entre o mapa e a arena.
	local function entradaDaArena(i)
		local board = Protocol.BOARD
		local ponto = board.origin + Vector3.new((i - 2.5) * board.cell, 3, board.height * board.cell / 2 + board.cell)
		return CFrame.lookAt(ponto, ponto - Vector3.zAxis)
	end

	local function ancorar(grupo)
		local ancorados = {}
		for i, p in grupo do
			local r = raiz(p)
			if r then
				ancorados[p.UserId] = { parte = r, cframe = r.CFrame, antes = r.Anchored }
				r.Anchored = true
				r.CFrame = entradaDaArena(i)
			end
		end
		return ancorados
	end

	local function soltar(ancorados)
		for _, a in ancorados do
			if a.parte.Parent then
				a.parte.CFrame = a.cframe
				a.parte.Anchored = a.antes
			end
		end
	end

	local function pagar(luta)
		local valores = {}
		for _, id in luta.criaturas do
			local valor = Elenco.recompensaDe(id)
			if valor then table.insert(valores, valor) end
		end
		local premio = Recompensa.gerar(valores, rng)
		local moedas = premio.moedas or 0
		for _, tralha in premio.tralhas or {} do
			if type(tralha.preco) == "number" and tralha.preco > 0 then moedas += math.floor(tralha.preco) end
		end
		for _, p in luta.grupo do
			if p.Parent ~= Players then continue end
			local bonus, pa = 0, 0
			local patrulhaId = luta.definicao.id
			if cacadas and patrulhaId then bonus, pa = cacadas.bonus(p, patrulhaId) end
			local ok, sucesso = pcall(deps.recompensar, p, luta.encounterId, moedas + bonus, luta.definicao.marco, pa)
			if ok and sucesso and cacadas and patrulhaId and bonus > 0 then
				cacadas.concluir(p, patrulhaId, luta.encounterId)
			end
		end
	end

	local function terminar(luta, resultado)
		if ativa ~= luta then return end
		ativa = nil
		for _, p in luta.grupo do treguaAte[p.UserId] = agora() + LutaDoMundo.TREGUA_SEGUNDOS end
		if deps.cenario then pcall(deps.cenario.aplicar, nil) end
		soltar(luta.ancorados)
		if resultado == "vitoria" then
			if luta.patrulha.derrotada then luta.patrulha.derrotada() end
			pagar(luta)
		end
		luta.patrulha.ocupar(false)
		if deps.aoEncerrar then
			local porJogador = {}
			for _, p in luta.grupo do porJogador[p.UserId] = true end
			local fase = if resultado == "vitoria" then "victory" elseif resultado == "derrota" then "defeat" else "fled"
			pcall(deps.aoEncerrar, { atoresPorJogador = porJogador }, { phase = fase, encounterId = luta.encounterId })
		end
	end

	-- Chamado pela patrulha no contato. Devolve true se a luta começou (a patrulha fica ocupada).
	function api.iniciar(player, patrulha, definicao)
		if ativa or type(definicao) ~= "table" then return false end
		if not temFicha(player) then return false end
		local grupo = montarGrupo(player)
		if not grupo then return false end
		-- Patrulhas antigas da clareira/ruínas não têm id: um goblin batedor por jogador.
		local criaturas = if definicao.id then EncontrosPorZona.elencoPatrulha(definicao.id, math.min(#grupo, 4)) else nil
		if not definicao.id then
			criaturas = {}
			for _ = 1, math.min(#grupo, 4) do table.insert(criaturas, "creature/goblin-batedor") end
		end
		if not criaturas or #criaturas == 0 then return false end
		local luta = {
			patrulha = patrulha, definicao = definicao, grupo = grupo, criaturas = criaturas,
			encounterId = "mundo-" .. string.gsub(HttpService:GenerateGUID(false), "[^%w]", ""),
		}
		ativa = luta
		luta.ancorados = ancorar(grupo)
		if deps.cenario then pcall(deps.cenario.aplicar, Arenas.daPatrulha(definicao)) end
		local erro = deps.iniciarLuta(grupo, criaturas, {
			nome = definicao.nome,
			aoTerminar = function(resultado) terminar(luta, resultado) end,
		})
		if erro then
			warn("[Luta do mundo] Início recusado: " .. tostring(erro))
			ativa = nil
			if deps.cenario then pcall(deps.cenario.aplicar, nil) end
			soltar(luta.ancorados)
			return false
		end
		return true
	end

	-- Quem sai no meio da luta não deixa o personagem preso na âncora quando voltar.
	Players.PlayerRemoving:Connect(function(player)
		if ativa and ativa.ancorados[player.UserId] then ativa.ancorados[player.UserId] = nil end
		treguaAte[player.UserId] = nil
	end)
	return api
end

return LutaDoMundo
