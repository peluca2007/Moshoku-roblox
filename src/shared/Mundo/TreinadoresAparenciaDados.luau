-- Aparência racial fixa dos treinadores; trajes raros são montados à parte.
local TreinadoresAparenciaDados = {}

local function aparencia(rosto, pele, olho, cabeloCor, cabelo, barba, camisa, calca, roupas)
	return {
		versao = 1,
		rosto = { olhos = rosto[1], sobrancelhas = rosto[2], nariz = rosto[3], boca = rosto[4] },
		cores = { pele = pele, olho = olho, cabelo = cabeloCor, camisa = camisa, calca = calca },
		cabelo = cabelo, barba = barba, roupas = roupas or {},
	}
end

TreinadoresAparenciaDados.POR_ARVORE = {
	["furtividade-e-armadilhas"] = {
		raceId = "race/humano", pose = "cruzados",
		aparencia = aparencia({ "OlhoRetangular", "SobrancelhaSeria", "NarizPequeno", "BocaReta" }, "PeleOliva", "OlhoCastanho", "CabeloPreto", "CabeloNenhum", "BarbaNenhum", "CamisaPreta", "CalcaPreta"),
	},
	agua = {
		raceId = "race/elfo", pose = "canalizar",
		-- O traje da Mestra usa tiara; o cabelo trançado mantém a silhueta livre.
		aparencia = aparencia({ "OlhoFeliz", "SobrancelhaArqueada", "NarizPequeno", "BocaSorriso" }, "PeleClara", "OlhoAzul", "CabeloBranco", "CabeloTrancado1", "BarbaNenhum", "CamisaAzul", "CalcaAzul"),
	},
}

TreinadoresAparenciaDados.TRAJES = {
	["furtividade-e-armadilhas"] = { "LadinoCapuz", "LadinoMascara", "LadinoCapa", "LadinoCinto" },
	agua = { "MestraTiara", "MestraManto", "MestraObi", "MestraCajado" },
}

return TreinadoresAparenciaDados
