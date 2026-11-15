-- Quem pode usar o ajuste manual de PV/mana (`adjust` da Mesa) na PRÓPRIA ficha.
-- No modo mesa com mestre o jogador anota o próprio dano/cura (legítimo). Num encontro de jogo sem mestre
-- (luta do mundo: campanha, expedição, dojo, área de testes; ou o PvP) o servidor decide PV e mana, e o
-- ajuste seria trapaça. Mestre e administrador continuam podendo arbitrar.
-- Puro: recebe o que o servidor já sabe e devolve (true) ou (false, motivo).
--   contexto = { mestre: boolean, admin: boolean, encontro = EncontroService.publico() | nil }
local AjusteManual = {}

AjusteManual.MOTIVO = "Nesta luta o servidor decide PV e mana; o ajuste manual está desligado."

function AjusteManual.permitido(contexto)
	if type(contexto) ~= "table" then return false, AjusteManual.MOTIVO end
	if contexto.mestre == true or contexto.admin == true then return true end
	local e = contexto.encontro
	if type(e) == "table" and (e.mundo == true or e.modo == "duelo") then return false, AjusteManual.MOTIVO end
	return true
end

return table.freeze(AjusteManual)
