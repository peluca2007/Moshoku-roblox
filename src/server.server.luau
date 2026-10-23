-- Inicializa a mesa assistida e o encontro autônomo J2; o protótipo antigo
-- CombatService continua pausado.
local Server = script.Parent.Server
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Protocol = require(ReplicatedStorage.Shared.MesaProtocol)
ReplicatedStorage:SetAttribute(Protocol.READY_ATTRIBUTE, false)
-- Os specs no Play levam ~3 min (carregam malhas) e atrasavam o mundo a cada Play do Pedro.
-- Só rodam aqui se a IA marcar ServerScriptService "RodarTestesNoPlay" no Edit antes do Play;
-- também dá para rodar a qualquer momento: require(Server.TestRunner).run(Server.tests).
if game:GetService("RunService"):IsStudio() and script.Parent:GetAttribute("RodarTestesNoPlay") == true then
	require(Server.TestRunner).run(Server.tests)
end
-- Depois dos specs (que criam o próprio escopo) e antes da persistência: Studio sem publicar usa memória.
require(Server.PersistenciaDeEstudio).preparar()
local mesa = require(Server.MesaService).start()
do -- malhas dos modelos prontos criadas em paralelo antes de montar o mundo (era ~15 s em série)
	local quantidade, segundos = require(Server.Mundo.MontarModelo).preaquecer()
	print(string.format("[Mundo] %d malhas pré-carregadas em %.1f s", quantidade, segundos))
end
require(Server.Mundo.Terreno).start()
require(Server.RegiaoInicial).start()
require(Server.Mundo.Vila).start()
require(Server.Mundo.Floresta).start()
require(Server.Mundo.Ruinas).start()
require(Server.Mundo.Ambientacao).start()
local runServico
require(Server.DescansoAcampamentoService).start({
	corpoPessoal = mesa.corpoPessoal,
	descansar = function(player, tipo)
		if runServico and runServico.podeDescansar then
			local pode, motivo = runServico.podeDescansar(player, tipo)
			if not pode then return false, motivo end
		end
		local ok, resultado = mesa.descansarPessoal(player, tipo)
		if ok and runServico then
			local avancou, motivo = runServico.descansar(player, tipo)
			if not avancou then return false, motivo end
		end
		return ok, resultado
	end,
	emCombate = function(player)
		local personagem = player and player.Character
		local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
		return mesa.emCombate() or (raiz ~= nil and raiz:IsA("BasePart") and raiz.Anchored)
	end,
})
local dojoService
local encontro
local missoes = require(Server.MissaoService).start({
	remote = ReplicatedStorage:WaitForChild(Protocol.REMOTE),
	registrarHandler = mesa.registrarHandler,
	consultar = mesa.consultarPerfilPessoal,
	acao = mesa.acaoMissaoPessoal,
	emCombate = function() return mesa.emCombate() or (encontro ~= nil and encontro.emEncontroAtivo()) end,
	conectado = function(player) return player ~= nil and player.Parent == game:GetService("Players") end,
	avisar = mesa.avisarPessoal,
})
encontro = require(Server.EncontroAutonomoService).start({
	corpoPessoal = mesa.corpoPessoal,
	consumirItemPessoal = mesa.consumirItemPessoal,
	recompensarEncontro = function(player, encounterId, moedas, marcoId, pa)
		local sucesso, total, cumpridas = mesa.recompensarEncontroPessoal(player, encounterId, moedas, marcoId, pa)
		if sucesso then missoes.notificarConclusoes(player, cumpridas) end
		return sucesso, total
	end,
	emCombate = function() return mesa.emCombate() or missoes.transacaoAtiva() end,
	aoEncerrar = function(...)
		if dojoService then dojoService.encerrado(...) end
		if runServico then runServico.encerrado(...) end
	end,
	miniaturas = require(Server.EncontroAutonomoMiniaturas).start(),
	avatares = require(Server.EncontroAutonomoAvatares).start(),
})
dojoService = require(Server.DojoService).start({
	consultar = mesa.consultarDojoPessoal,
	atualizar = mesa.atualizarDojoPessoal,
	emCombate = mesa.emCombate,
	encontro = encontro,
})
runServico = require(Server.RunServico).start({
	emEncontro = function() return mesa.emCombate() or encontro.emEncontroAtivo() end,
	corpoPessoal = mesa.fichaParaTestes or mesa.corpoPessoal, -- bônus para os testes dos eventos de viagem (F8); aceita perfil sem árvore
	-- Luta de chefe da run: o encontro J2 é montado pelo EncontroAutonomoService (R7b).
	iniciarLuta = function(jogadores, luta)
		if type(encontro.criarEncontroDaRun) ~= "function" then return nil, "Luta do chefe indisponível." end
		return encontro.criarEncontroDaRun(jogadores, luta)
	end,
	conta = require(Server.ContaServico).start(),
})
local cacadas = require(Server.CacadasService).start({
	runServico = runServico, avisar = mesa.avisarPessoal,
	emCombate = function() return mesa.emCombate() or encontro.emEncontroAtivo() end,
})
encontro.definirCacadas(cacadas)
-- A segunda provação abre o rank na mesma ficha e nas cartas J2; só o servidor concede.
runServico.observar(function(sessao)
	if not sessao or not sessao.run or sessao.run.fim then return end
	for userId, plano in sessao.planos do
		if plano.segunda then
			local player = game:GetService("Players"):GetPlayerByUserId(userId)
			if player then mesa.sincronizarArvoresRun(player, { "tree/" .. plano.segunda }) end
		end
	end
end)
-- Defeitos do personagem pronto da run valem no combate J2 (F1): só quem está na run ativa e no modo "pronto".
encontro.definirProvedorDefeitos(function(userId)
	local sessao = runServico.sessao()
	local run = sessao and sessao.run
	if not run or run.fim or not run.jogadores[userId] then return {} end
	local plano = sessao.planos[userId]
	if not plano or plano.modo ~= "pronto" then return {} end
	return plano.defeitos
end)
require(Server.ContaServico).ligarRemote({ entreRuns = function() local s = runServico.sessao(); return not (s and s.run and not s.run.fim) end })
require(Server.TreinadorServico).start({ runServico = runServico, emCombate = function() return mesa.emCombate() or encontro.emEncontroAtivo() end })
require(Server.Mundo.Npcs).start({ abrirDojo = dojoService.abrir, abrirLoja = mesa.abrirLoja, abrirMissoes = missoes.abrir })
require(Server.AparenciaJogador).start({ mesa = mesa, encontro = encontro })
ReplicatedStorage:SetAttribute(Protocol.READY_ATTRIBUTE, true)
