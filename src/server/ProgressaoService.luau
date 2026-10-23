-- Progressão nas árvores do livro, no servidor (pedido do Pedro, 09/10/2026: a
-- árvore do site no jogo, PA infinito por enquanto, até o Intermediário).
-- Comandos (despachante único):
--   abrirRank { tokenId, arvore, rank }   abre o patamar (regras de Progressao)
--   aprender  { tokenId, habilidadeId }   compra habilidade ou talento
-- Quem pode: o dono da ficha ou o mestre, fora de combate.
-- Limite declarado: os valores calculados da ficha (PV, PM, atributos) não são
-- recalculados aqui; isso é o motor de personagem (J1). O BC das habilidades
-- usa o rank aberto na hora, então ele já acompanha.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Progressao = require(ReplicatedStorage.Shared.Regras.Progressao)

local ProgressaoService = {}

-- deps: handlers, tokens, combat, catalogo, canSee(player, token), logAboutToken(token, texto)
function ProgressaoService.start(deps)
	local handlers, tokens = deps.handlers, deps.tokens

	local function fichaControlada(player, payload, master): (any?, string?)
		local token = type(payload.tokenId) == "string" and tokens[payload.tokenId]
		if not token or not deps.canSee(player, token) then
			return nil, "Ficha não encontrada."
		end
		if not master and token.ownerUserId ~= player.UserId then
			return nil, "Você só mexe na árvore da sua ficha."
		end
		if not token.ficha2 then
			return nil, "Esta ficha não tem os dados do livro (importe a ficha completa do site)."
		end
		if deps.combat.active and not deps.emTreino() then
			return nil, "Aprender e abrir patamares só fora de combate."
		end
		return token, nil
	end

	handlers.abrirRank = function(player, payload, master)
		local token, falha = fichaControlada(player, payload, master)
		if not token then
			return falha
		end
		local arvore, rank = payload.arvore, payload.rank
		if type(arvore) ~= "string" or type(rank) ~= "string" or #arvore > 64 or #rank > 32 then
			return "Pedido inválido."
		end
		local ok, motivo = Progressao.podeAbrir(token.ficha2.construction, deps.catalogo, arvore, rank)
		if not ok then
			return motivo
		end
		table.insert(token.ficha2.construction.unlockedRankIds, Progressao.idDoRank(arvore, rank))
		token.version += 1
		local entrada = deps.catalogo.POR_ID["tree/" .. Progressao.segmento(arvore)]
		deps.logAboutToken(token, string.format("%s abre %s • %s.", token.name, entrada and entrada.data.name or arvore, rank))
		return nil
	end

	handlers.aprender = function(player, payload, master)
		local token, falha = fichaControlada(player, payload, master)
		if not token then
			return falha
		end
		local id = payload.habilidadeId
		if type(id) ~= "string" or #id > 256 then
			return "Pedido inválido."
		end
		local ok, motivo = Progressao.podeComprar(token.ficha2.construction, deps.catalogo, id)
		if not ok then
			return motivo
		end
		table.insert(token.ficha2.construction.purchasedIds, id)
		token.version += 1
		local entrada = deps.catalogo.POR_ID[id]
		deps.logAboutToken(token, string.format("%s aprende %s (%s • %s).", token.name, entrada.data.name, entrada.data.treeId, entrada.data.rank))
		return nil
	end

	return {}
end

return ProgressaoService
