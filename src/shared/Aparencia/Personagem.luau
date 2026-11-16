-- PERS2: regras puras do personagem "R15 padrão + roupa do jogo" (sem Instances, sem rede).
-- Dados que dependem de envio à Roblox (moldes de camisa/calça, cabelos nossos) ficam vazios até serem enviados:
-- vazio = fallback para o desenho antigo (cor de torso/pernas + peças de blocos). Ver tools/blender/personagem/README.md.
local Personagem = {}

-- true restaura a cabeça de cubo do boneco antigo (volta rápida se a cabeça redonda falhar no Studio).
Personagem.CABECA_CUBICA = false
-- O cabelo do avatar do jogador só entra quando houver campo próprio no perfil e a verificação no Studio (PERS2 pendente).
Personagem.CABELO_DO_AVATAR = false

-- Moldes clássicos 585x559 enviados como Decal pela rota do Studio (MOSHOKU_VIA_STUDIO=1); o id guardado é o da IMAGEM do Decal (InsertService:LoadAsset -> Decal.Texture), que o Shirt/Pants aceita. Tons: aventureiro/ladino médio, mago claro.
Personagem.CONJUNTOS = {
	aventureiro = { camisa = "rbxassetid://85431028511988", calca = "rbxassetid://99488561642255" },
	ladino = { camisa = "rbxassetid://133825146027567", calca = "rbxassetid://92405611086416" },
	mago = { camisa = "rbxassetid://135491093277014", calca = "rbxassetid://82815866746308" },
}

local LADINO = { LadinoCapuz = true, LadinoMascara = true, LadinoCapa = true, LadinoCinto = true }
local MAGO = { MestraTiara = true, MestraManto = true, MestraObi = true, MestraCajado = true }

-- Escolhe o conjunto de roupa do jogo pelas peças equipadas (trajes raros mandam; senão aventureiro).
function Personagem.conjuntoDe(aparencia): string
	for _, id in aparencia.roupas or {} do
		if LADINO[id] then return "ladino" end
		if MAGO[id] then return "mago" end
	end
	return "aventureiro"
end

function Personagem.moldes(conjunto: string): (string?, string?)
	local c = Personagem.CONJUNTOS[conjunto] or Personagem.CONJUNTOS.aventureiro
	return c.camisa, c.calca
end

-- Medidas visíveis de uma cabeça (Size e escala do SpecialMesh, se houver). Cabeça redonda: largura = altura.
function Personagem.medidasCabeca(tamanho: Vector3, escalaMalha: Vector3?)
	local e = escalaMalha or Vector3.new(1, 1, 1)
	local altura = tamanho.Y * e.Y
	return { largura = altura, altura = altura, profundidade = tamanho.Z * e.Z }
end

-- Posição de um bloco do rosto (coordenadas do Catalogo.ROSTO, cabeça de referência cúbica de lado `escala`)
-- sobre a cabeça real: x/y proporcionais, z recuado/avançado a partir da frente verdadeira.
function Personagem.blocoDoRosto(bloco, m, escala: number)
	local t, v = bloco.tamanho, bloco.posicao
	local tamanho = Vector3.new(t.x * m.largura / 2, t.y * m.altura, t.z * escala)
	local z = -(m.profundidade / 2 + (math.abs(v.z) - 0.5) * escala)
	return tamanho, Vector3.new(v.x * m.largura / 2, v.y * m.altura, z)
end

-- Como recolorir um cabelo de acessório (README PERS1 b): SpecialMesh -> VertexColor; MeshPart sem SurfaceAppearance
-- -> limpar textura e usar Color; com SurfaceAppearance -> não recolorível (usa cabelo padrão nosso).
function Personagem.estrategiaCabelo(classe: string, temSurfaceAppearance: boolean): string
	if classe == "SpecialMesh" then return "vertex" end
	if classe == "MeshPart" and not temSurfaceAppearance then return "cor" end
	return "nenhuma"
end

return Personagem
