-- Céu do mundo: Sky (Lighting) e Clouds (workspace.Terrain) conforme o perfil da zona.
-- Chamado por AmbienteMundo a cada passo da transição; os valores vêm de
-- shared/Mundo/AmbientePerfis. Só apresentação local.
--
-- Skybox: o perfil traz as 6 texturas em `skybox` ({ bk, dn, ft, lf, rt, up }). Enquanto o
-- campo estiver vazio ou incompleto, o Sky mantém as texturas padrão do Roblox e o clima
-- vem só de Clouds, estrelas, sol e lua. Se uma zona sem skybox vem depois de uma com
-- skybox, as texturas padrão voltam.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Perfis = require(ReplicatedStorage.Shared.Mundo.AmbientePerfis)

local CeuMundo = {}

-- Face do perfil -> propriedade do Sky.
local PROPRIEDADE_FACE = {
	bk = "SkyboxBk", dn = "SkyboxDn", ft = "SkyboxFt",
	lf = "SkyboxLf", rt = "SkyboxRt", up = "SkyboxUp",
}

-- `converterCor` transforma {r, g, b} de 0 a 255 em Color3 (o mesmo de AmbienteMundo).
function CeuMundo.criar(converterCor: ({ number }) -> Color3)
	local ceu = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
	ceu.Name = "CeuMundo"
	ceu.Parent = Lighting
	ceu.CelestialBodiesShown = true

	local padrao = {}
	for _, propriedade in PROPRIEDADE_FACE do
		padrao[propriedade] = (ceu :: any)[propriedade]
	end

	local terreno = workspace.Terrain
	local nuvens = terreno:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	nuvens.Parent = terreno
	nuvens.Enabled = true

	local chaveSkybox = ""

	local function aplicarSkybox(skybox)
		local completo = Perfis.skyboxCompleto(skybox)
		local chave = ""
		if completo then
			local partes = {}
			for _, face in Perfis.FACES_SKYBOX do
				table.insert(partes, skybox[face])
			end
			chave = table.concat(partes, "|")
		end
		-- Texturas só mudam quando o conjunto muda: reatribuir a cada quadro recarregaria o céu.
		if chave == chaveSkybox then
			return
		end
		chaveSkybox = chave
		for face, propriedade in PROPRIEDADE_FACE do
			(ceu :: any)[propriedade] = if completo then skybox[face] else padrao[propriedade]
		end
	end

	local ceuMundo = {}

	function ceuMundo.aplicar(p)
		ceu.StarCount = math.clamp(math.round(p.estrelas), 0, 5000)
		ceu.SunAngularSize = math.clamp(p.solTam, 0, 100)
		ceu.MoonAngularSize = math.clamp(p.luaTam, 0, 100)
		nuvens.Cover = math.clamp(p.nuvemCobertura, 0, 1)
		nuvens.Density = math.clamp(p.nuvemDensidade, 0, 1)
		nuvens.Color = converterCor(p.nuvemCor)
		aplicarSkybox(p.skybox)
	end

	return ceuMundo
end

return CeuMundo
