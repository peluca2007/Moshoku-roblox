-- Apenas efeitos do site. Vozes, assobio e buff ("gooo") não entram.
local Sons = {}
Sons.IDS = require(game:GetService("ReplicatedStorage").Shared.SonsIds)
Sons.ARQUIVOS = {
	["espada-corte"] = true, ["espada-metal"] = true, ["espada-combo"] = true,
	aparar = true, ["flecha-impacto-1"] = true, ["flecha-impacto-2"] = true,
	lanca = true, soco = true, moedas = true, brilho = true,
	fogo = true, ["fogo-impacto"] = true, gelo = true, agua = true,
	vento = true, ["vento-impacto"] = true, terra = true,
	["cura-1"] = true, ["cura-2"] = true,
}

local ELEMENTOS = {
	agua = "agua", vento = "vento", terra = "terra", cura = "cura-1",
	desintoxicacao = "cura-2", teorica = "brilho", invocacao = "brilho", fogo = "fogo",
}
-- Mixagem por categoria; caudas longas são limitadas sem alterar os MP3.
Sons.VOLUMES = { ["espada-corte"] = 0.38, ["espada-metal"] = 0.38, ["espada-combo"] = 0.42,
	soco = 0.42, ["fogo-impacto"] = 0.4, ["vento-impacto"] = 0.36, brilho = 0.28,
	["cura-1"] = 0.32, ["cura-2"] = 0.32 }

-- Recebe o gesto que a animação realmente usa, sem decidir regras de combate.
function Sons.lancamento(id: string, arvore: string?, gesto): string?
	local g = gesto and gesto.g
	if g == "grito" then return nil end
	if g == "conjuro" then
		if arvore == "cura" then return nil end -- toca uma vez no resultado da cura
		if string.find(id, "gelo", 1, true) then return "gelo" end
		return ELEMENTOS[arvore]
	end
	if g == "cabecada" or g == "escudada" or (gesto and gesto.semArma) then return nil end
	if g == "disparo" then return nil end -- temos o impacto, não a corda do arco
	if g == "corrente" then return "espada-metal" end
	if g == "golpe" or g == "giro" or g == "investida" or g == "arremesso" then
		return if string.find(id, "golpe-continuo", 1, true) then "espada-combo" else "espada-corte"
	end
	return ELEMENTOS[arvore]
end

function Sons.impacto(id: string, arvore: string?, gesto, alvo): string?
	if not alvo or alvo.acertou == false then return nil end
	if (alvo.cura or 0) > 0 then return if arvore == "desintoxicacao" then "cura-2" else "cura-1" end
	if (alvo.dano or 0) <= 0 then return nil end
	local g = gesto and gesto.g
	if g == "grito" then return nil end
	if g == "disparo" then return "flecha-impacto-1" end
	if g == "cabecada" or g == "escudada" or (gesto and gesto.semArma) then return "soco" end
	if string.find(id, "gelo", 1, true) then return "vento-impacto" end
	if arvore == "fogo" then return "fogo-impacto" end
	if arvore == "vento" then return "vento-impacto" end
	if g == "golpe" or g == "giro" or g == "investida" or g == "arremesso" or g == "corrente" then return "espada-metal" end
	return nil
end

return Sons
