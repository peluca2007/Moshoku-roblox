-- SOMENTE STUDIO: valida a fronteira remota de missão com NPC e perfil simulados.
local Service = require(script.Parent.Parent.MissaoService)
local Missao = require(game:GetService("ReplicatedStorage").Shared.Regras.Missao)
local Dados = require(game:GetService("ReplicatedStorage").Shared.Mundo.MissoesDados)

local function montar()
	local npc = Instance.new("Part")
	local personagem = Instance.new("Model")
	local raiz = Instance.new("Part")
	raiz.Name, raiz.Position, raiz.Parent = "HumanoidRootPart", Vector3.new(2, 0, 0), personagem
	local humanoide = Instance.new("Humanoid")
	humanoide.Parent = personagem
	local player = { UserId = 990201, Character = personagem, Parent = game:GetService("Players") }
	local handlers, eventos, avisos = {}, {}, {}
	local perfil = { missoes = Missao.novoEstado() }
	local combate, agora = false, 0
	local service = Service.start({
		registrarHandler = function(nome, handler) handlers[nome] = handler; return true end,
		remote = { FireClient = function(_, alvo, tipo, dados) table.insert(eventos, { player = alvo, tipo = tipo, dados = dados }) end },
		consultar = function(alvo) return if alvo == player then perfil else nil end,
		acao = function(alvo, acao, missaoId)
			if alvo ~= player then return false, "Ficha indisponível." end
			local missao = Dados.porId()[missaoId]
			local estado, recompensa, erro
			if acao == "aceitar" then estado, erro = Missao.aceitar(perfil.missoes, missao)
			else estado, recompensa, erro = Missao.entregar(perfil.missoes, missao) end
			if not estado then return false, erro end
			perfil.missoes = estado
			return true, perfil, recompensa and recompensa.ouro or 0
		end,
		avisar = function(alvo, texto) table.insert(avisos, texto) end,
		conectado = function(alvo) return alvo == player and alvo.Parent ~= nil end,
		emCombate = function() return combate end,
		obterNpcRaiz = function() return npc end,
		relogio = function() return agora end,
	})
	return service, handlers, eventos, avisos, player, personagem, raiz, npc,
		function(dt) agora += dt end, function(valor) combate = valor end
end

return {
	["abre apenas perto e lista estado privado com ação server-side fechada"] = function(t)
		local service, handlers, eventos, _, player, personagem, raiz, npc, avancar = montar()
		t.eq(service.abrir(player), true)
		t.eq(eventos[#eventos].tipo, "missoes")
		t.eq(#eventos[#eventos].dados, #Dados.LISTA)
		t.eq(eventos[#eventos].dados[1].situacao, "disponivel")
		t.ok(handlers.missaoAcao(player, { acao = "aceitar", missaoId = "cacada-do-bosque", progresso = 2 }))
		avancar(0.5)
		t.eq(handlers.missaoAcao(player, { acao = "aceitar", missaoId = "cacada-do-bosque" }), nil)
		t.eq(eventos[#eventos].dados[1].situacao, "aceita")
		personagem.HumanoidRootPart.Position = Vector3.new(30, 0, 0)
		t.ok(handlers.missaoAcao(player, { acao = "entregar", missaoId = "cacada-do-bosque" }))
		personagem:Destroy(); raiz:Destroy(); npc:Destroy()
	end,
	["evento de vitória avisa somente o jogador que ficou elegível"] = function(t)
		local service, _, _, avisos, player, personagem, raiz, npc = montar()
		t.eq(service.notificarConclusoes(player, { "cacada-do-bosque" }), true)
		t.eq(avisos[1], "Missão cumprida: Caçada no Bosque")
		personagem:Destroy(); raiz:Destroy(); npc:Destroy()
	end,
}
