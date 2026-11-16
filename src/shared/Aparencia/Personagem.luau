-- PERS2: regras puras do personagem "R15 padrão + roupa do jogo" (sem Instances, sem rede).
-- Dados que dependem de envio à Roblox (moldes de camisa/calça, cabelos nossos) ficam vazios até serem enviados:
-- vazio = fallback para o desenho antigo (cor de torso/pernas + peças de blocos). Ver tools/blender/personagem/README.md.
local Personagem = {}

-- true restaura a cabeça de cubo do boneco antigo (volta rápida se a cabeça redonda falhar no Studio).
Personagem.CABECA_CUBICA = false
-- PERS3b: as peças em malha (Blender) foram feitas para a cabeça R15 de 1,2 stud; o fator é altura real / 1,2.
Personagem.CABECA_MALHA = 1.2
-- O cabelo do avatar do jogador só entra quando houver campo próprio no perfil e a verificação no Studio (PERS2 pendente).
Personagem.CABELO_DO_AVATAR = false

-- PERS4: corpo do personagem. "caixas" = R15 padrão de blocos (reserva); outro nome = pacote oficial e gratuito
-- da Roblox (dono Roblox, preço 0) aplicado pela HumanoidDescription, com nossa roupa/peças/rosto por cima. Candidatos e
-- avaliação em docs/ARTE.md (PERS4). O Pedro escolheu "homem" (bundle 238 "Man") em 16/11/2026 pela prancha corpos_comparacao.jpg.
Personagem.CORPO = "homem"
-- Ids dos membros (Torso, Braços, Pernas e cabeça dinâmica; 0 = mantém a cabeça R15 padrão). Fonte: catalog.roblox.com/v1/bundles/details.
Personagem.CORPOS = {
	homem = { Torso = 86500008, RightArm = 86500036, LeftArm = 86500054, LeftLeg = 86500064, RightLeg = 86500078, Head = 0 }, -- bundle 238 "Man"
	mulher = { Torso = 86499666, RightArm = 86499698, LeftArm = 86499716, LeftLeg = 86499753, RightLeg = 86499793, Head = 0 }, -- bundle 239 "Woman"
	menino = { Torso = 376532000, RightArm = 376531012, LeftArm = 376530220, LeftLeg = 376531300, RightLeg = 376531703, Head = 0 }, -- bundle 109 "ROBLOX Boy"
}

-- Moldes clássicos 585x559 enviados como Decal pela rota do Studio (MOSHOKU_VIA_STUDIO=1); o id guardado é o da IMAGEM do Decal (InsertService:LoadAsset -> Decal.Texture), que o Shirt/Pants aceita. Tons: aventureiro/ladino médio, mago claro.
Personagem.CONJUNTOS = {
	aventureiro = { camisa = "rbxassetid://85431028511988", calca = "rbxassetid://99488561642255" },
	ladino = { camisa = "rbxassetid://133825146027567", calca = "rbxassetid://92405611086416" },
	mago = { camisa = "rbxassetid://135491093277014", calca = "rbxassetid://82815866746308" },
}

-- PERS3: rostos pintados (PNG 512x512 com transparência, Decal na cabeça) em 3 estilos x 8 cores de olho, enviados como
-- Decal pela rota do Studio; id = Texture da imagem. Vazio = rosto de blocos (Catalogo.ROSTO), como antes.
-- Ex.: Personagem.ROSTOS.neutro.OlhoAzul = "rbxassetid://123". Arquivos: build/personagem/rostos/rosto_<estilo>_<OlhoXxx>.png
Personagem.ROSTOS = {
	neutro = {
		OlhoAzul = "rbxassetid://134199048162915",
		OlhoCastanho = "rbxassetid://112311815656153",
		OlhoDourado = "rbxassetid://128408527998825",
		OlhoNegro = "rbxassetid://116722672480538",
		OlhoTurquesa = "rbxassetid://85903743548214",
		OlhoVerde = "rbxassetid://76840367671652",
		OlhoVermelho = "rbxassetid://84294286224261",
		OlhoVioleta = "rbxassetid://99703153368601",
	},
	alegre = {
		OlhoAzul = "rbxassetid://81348637708344",
		OlhoCastanho = "rbxassetid://128796447536381",
		OlhoDourado = "rbxassetid://105272146359165",
		OlhoNegro = "rbxassetid://84133276620541",
		OlhoTurquesa = "rbxassetid://139772441692989",
		OlhoVerde = "rbxassetid://105957369499988",
		OlhoVermelho = "rbxassetid://126232782917635",
		OlhoVioleta = "rbxassetid://81028372429631",
	},
	serio = {
		OlhoAzul = "rbxassetid://78858948914571",
		OlhoCastanho = "rbxassetid://89588070570103",
		OlhoDourado = "rbxassetid://134178187599281",
		OlhoNegro = "rbxassetid://78485290631751",
		OlhoTurquesa = "rbxassetid://93695126949528",
		OlhoVerde = "rbxassetid://129294689952051",
		OlhoVermelho = "rbxassetid://92059996535444",
		OlhoVioleta = "rbxassetid://77878014070848",
	},
}

-- Estilo do rosto pintado que mais se aproxima das escolhas do jogador (olhos/sobrancelhas/boca do catálogo de blocos).
local SERIO = { OlhoBravo = true, OlhoSonolento = true, SobrancelhaSeria = true, BocaTriste = true, BocaPresas = true }
local ALEGRE = { OlhoFeliz = true, OlhoBrilho = true, BocaSorriso = true, BocaDentes = true, BocaAberta = true }
function Personagem.estiloDoRosto(rosto): string
	local r = rosto or {}
	for _, id in { r.olhos, r.sobrancelhas, r.boca } do
		if id and SERIO[id] then return "serio" end
	end
	for _, id in { r.olhos, r.boca } do
		if id and ALEGRE[id] then return "alegre" end
	end
	return "neutro"
end

-- Id do Decal do rosto (ou nil se ainda não enviado).
function Personagem.rostoDecal(rosto, corOlhoId: string?): string?
	local porCor = Personagem.ROSTOS[Personagem.estiloDoRosto(rosto)]
	local id = porCor and corOlhoId and porCor[corOlhoId]
	if type(id) == "string" and id ~= "" then return id end
	return nil
end

-- Módulo a montar de um item do catálogo: a malha (Blender) quando já enviada; senão o reserva de blocos (ou nada).
function Personagem.moduloDe(item, existe: (string) -> boolean): string?
	if not item then return nil end
	if item.malha and existe(item.malha) then return item.malha end
	if item.soMalha then return nil end
	return item.modulo
end

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
