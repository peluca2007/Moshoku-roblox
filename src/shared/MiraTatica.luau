-- Prévia geométrica sobre o snapshot visível. O servidor revalida o pedido.
local Protocol = require(game:GetService("ReplicatedStorage").Shared.MesaProtocol)
local Combate = require(game:GetService("ReplicatedStorage").Shared.Regras.Combate)
local M = {}

function M.avaliar(snap, mira, x, z)
	if not snap or not mira or not Protocol.isCell(x, z) then return nil end
	local fonte, alvo, barreira
	for _, t in snap.tokens do
		if t.id == mira.tokenId then fonte = t end
		if t.x == x and t.z == z then alvo = t end
	end
	if not fonte then return nil end
	local atacaBarreira = mira.habilidadeId == "mesa/ataque-basico" or mira.habilidadeId == "mesa/ataque-a-distancia"
	if atacaBarreira then
		for _, muro in (snap.jogo and snap.jogo.muros) or {} do
			if muro.pv then for _, c in muro.casas do if c[1] == x and c[2] == z then barreira = muro end end end
		end
	end
	local alcance = mira.alcanceCasas or mira.raioCasas or mira.comprimentoCasas or 1
	local distancia = Protocol.distance(fonte.x, fonte.z, x, z)
	local motivo = if distancia > alcance then "Fora do alcance" else nil
	if not motivo and mira.modo ~= "confirmar" and mira.tipo ~= "mover" then
		local function bloqueia(cx, cz)
			if snap.map and (snap.map.terrain or {})[cx .. "," .. cz] == "parede" then return true end
			for _, muro in (snap.jogo and snap.jogo.muros) or {} do
				if muro ~= barreira and muro.bloqueiaVisao and not (atacaBarreira and muro.pv) then
					for _, c in muro.casas do if c[1] == cx and c[2] == cz then return true end end
				end
			end
			return false
		end
		if not Combate.temVisao(fonte.x, fonte.z, x, z, bloqueia) then motivo = "Visão bloqueada" end
	end
	if not motivo and (mira.modo == "ficha" or mira.modo == "lista") then
		if not alvo and not barreira then
			motivo = if mira.habilidadeId == "mesa/ataque-basico" or mira.habilidadeId == "mesa/ataque-a-distancia" then "Escolha uma ficha ou barreira" else "Escolha uma ficha"
		elseif alvo and alvo.id == fonte.id and mira.tipo ~= "cura" and not mira.permiteSi then
			motivo = "Escolha outra ficha"
		end
	end
	return { alvo = alvo, barreira = barreira, distancia = distancia, alcance = alcance, motivo = motivo,
		selecionado = alvo ~= nil and table.find(mira.alvoIds or {}, alvo.id) ~= nil }
end

return table.freeze(M)
