-- Organização de escolhas no cliente. Não autoriza ações nem calcula efeitos.
local Condicoes = require(game:GetService("ReplicatedStorage").Shared.Livro.Dados.Condicoes)
local porId = {}
for _, e in Condicoes do porId[e.data.id] = e end
local A = {}
function A.grupo(mec, indisponivel): string
	if indisponivel then return "Consulta" end
	if mec.tipo == "ataque" or mec.tipo == "area" or mec.tipo == "disparos" then return "Golpes" end
	if mec.tipo == "zona" and (mec.dano or mec.dados or mec.danoAoAtravessar) then return "Golpes" end
	return "Apoio"
end
function A.motivo(mec, indisponivel, token, jogo, id): string?
	if indisponivel then return "Consulte a ficha" end
	if token.derrotado or (token.pv ~= nil and token.pv <= 0) then return "0 PV • precisa de cura" end
	for _, c in token.conditions or {} do
		local e = porId[c.id]
		if c.id == "inconsciente" or (e and e.data.mecanica and e.data.mecanica.semAcoes) then return (e and e.data.nome or c.id) .. " • sem Ações" end
	end
	local daVez = jogo and jogo.tokenId == token.id
	local restantes = if daVez then math.max(0, (jogo.total or 3) - (jogo.usadas or 0)) else 3
	if (mec.acoes or 0) > restantes then return "Sem Ações" end
	if (mec.pm or 0) > (token.mana or 0) then return "Sem PM" end
	if (mec.pt or 0) > (token.pt or 0) then return "Sem PT" end
	if mec.umaVezPorTurno and daVez and table.find(jogo.usos or {}, id) then return "Já usada neste turno" end
	return nil
end
return A
