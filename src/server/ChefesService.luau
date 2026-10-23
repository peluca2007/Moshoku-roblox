-- Um aviso ocupa a vez do chefe; resolve na próxima vez dele. Sem dano paralelo.
local Shared = game:GetService("ReplicatedStorage").Shared
local Regras = require(Shared.Regras.Chefes)
local Protocol = require(Shared.MesaProtocol)
local Catalogo = require(Shared.Livro.Catalogo)
local ChefesService = {}
function ChefesService.start(deps)
	local pendentes = {}
	local secreto = deps.secreto or function(t) return t.hidden == true end
	local serial = 0
	local versao = 0
	local semAcoes = { inconsciente = true }
	for _, c in (deps.catalogo or Catalogo).POR_ESPECIE.condition or {} do
		if c.data.mecanica and c.data.mecanica.semAcoes then semAcoes[c.sourceId or c.data.id] = true end
	end
	local api = {}
	function api.limpar() versao += 1; table.clear(pendentes) end
	function api.publico(chefe)
		if not chefe or secreto(chefe) or chefe.showStats == false then return nil end
		return { id = chefe.id, nome = chefe.name, pv = chefe.pv, pvMax = chefe.pvMax,
			fase = Regras.fase(chefe.pv, chefe.pvMax), aviso = pendentes[chefe.id],
			areaAtiva = type(deps.habilidades().golpeDeCriatura) == "function" }
	end
	function api.turno(chefe)
		local atual = versao
		local h = deps.habilidades()
		if chefe.derrotado or chefe.pv <= 0 then pendentes[chefe.id] = nil; return false end
		if secreto(chefe) then pendentes[chefe.id] = nil; return h.turnoDoInimigo(chefe) end
		for _, c in chefe.conditions or {} do
			if semAcoes[c.id] then pendentes[chefe.id] = nil; return h.turnoDoInimigo(chefe) end
		end
		-- Reduções de Ação transitórias também são calculadas pelo motor.
		local estado = h.estado and h.estado()
		if estado and estado.acoes and estado.acoes.tokenId == chefe.id and estado.acoes.total <= 0 then
			pendentes[chefe.id] = nil; return h.turnoDoInimigo(chefe)
		end
		local aviso = pendentes[chefe.id]
		if aviso then
			pendentes[chefe.id] = nil
			local integrado = type(h.golpeDeCriatura) == "function"
			local agiu
			if integrado then
				local alvos = Regras.alvos(aviso, deps.tokens)
				agiu = h.golpeDeCriatura(chefe, alvos, {
					tipo = "ataque", criatura = true, area = true, corpoACorpo = false,
					alcanceCasas = 20, partes = { { fixo = chefe.criatura.danoPorTurno, tipo = "contundente" } },
				}, { estilo = "raizes", nome = aviso.nome, casas = aviso.casas })
			else
				agiu = h.turnoDoInimigo(chefe)
			end
			if atual == versao and not secreto(chefe) then deps.remote:FireAllClients("chefeEfeito", { id = chefe.id, aviso = aviso, integrado = integrado, agiu = agiu == true }) end
			return agiu
		end
		local alvo
		for _, t in deps.tokens do
			if t.kind == "jogador" and t.ownerUserId and t.ownerUserId ~= 0 and not t.ia and not t.boneco and not t.derrotado and t.pv > 0 and not secreto(t) then
				if not alvo or t.pv < alvo.pv or (t.pv == alvo.pv and t.id < alvo.id) then alvo = t end
			end
		end
		if not alvo then return false end
		serial += 1
		aviso = Regras.preparar(chefe, alvo, serial, Protocol.BOARD.width, Protocol.BOARD.height)
		pendentes[chefe.id] = aviso
		deps.logAll(chefe.name .. ": " .. aviso.nome .. ". Área marcada até a próxima vez do chefe." .. (if h.golpeDeCriatura then " Saia dela!" else " Prévia visual; o golpe ainda é corpo a corpo."), "sistema")
		return true
	end
	return api
end
return ChefesService
