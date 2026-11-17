-- ARTE2: arte pintada do HUD da luta. PNGs gerados por tools/arte/pinceladas.py (peças, escala 2x, com
-- 9-slice) e tools/arte/icones_gameicons.py (atlas de ícones brancos, tinge-se por ImageColor3).
-- Para trocar: regerar, enviar de novo (upload_image) e atualizar os ids abaixo.
-- Ícones: game-icons.net, CC BY 3.0 (Lorc, Delapouite, Skoll, Willdabeast, Carl Olsen, Zeromancer, sbed;
-- crédito completo em docs/ARTE.md e na tela de Ajuda). Dados puros; sem Instances.
local UIArteLuta = {}

local function peca(id, l, a, corte)
	return table.freeze({ imagem = "rbxassetid://" .. id, largura = l, altura = a, corte = if corte then table.freeze(table.clone(corte)) else nil })
end

UIArteLuta.ESCALA = 0.5 -- PNG em 2x

local FAIXA = { 64, 36, 576, 76 }
local BOTAO = { 52, 34, 268, 78 }
local CARTAO = { 90, 60, 422, 132 }

UIArteLuta.PECAS = table.freeze({
	faixa_normal = peca("70378905146605", 640, 112, FAIXA),
	faixa_foco = peca("133406799898812", 640, 112, FAIXA),
	faixa_bloqueada = peca("88416664382335", 640, 112, FAIXA),
	botao_normal = peca("135964877094354", 320, 112, BOTAO),
	botao_foco = peca("83500229681317", 320, 112, BOTAO),
	botao_bloqueado = peca("123819088963934", 320, 112, BOTAO),
	botao_principal = peca("131673517090478", 320, 112, BOTAO),
	tecla_disco = peca("119811840380937", 64, 64, nil),
	tecla_losango = peca("79856165641964", 64, 64, nil),
	mancha_retrato = peca("104789560244950", 256, 256, nil),
	mancha_cartao = peca("98440627878709", 512, 192, CARTAO),
	anel_ativo = peca("77389798167274", 512, 512, nil),
})

function UIArteLuta.peca(nome: string)
	return UIArteLuta.PECAS[nome]
end

-- SliceScale que cabe na altura/largura de tela: nunca passa de ESCALA, e as bordas não se cruzam.
function UIArteLuta.escalaPara(nome: string, largura: number, altura: number): number
	local p = UIArteLuta.PECAS[nome]
	if not p or not p.corte then return UIArteLuta.ESCALA end
	local bv, bh = p.corte[2] + (p.altura - p.corte[4]), p.corte[1] + (p.largura - p.corte[3])
	local e = UIArteLuta.ESCALA
	if altura > 0 then e = math.min(e, altura / bv) end
	if largura > 0 then e = math.min(e, largura / bh) end
	return e
end

-- Atlas de ícones: célula de CELULA px (a arte ocupa 116 no meio), posição { x, y } de cada um.
UIArteLuta.ATLAS = table.freeze({ imagem = "rbxassetid://136094285577510", tamanho = 128 })
UIArteLuta.ICONES = table.freeze({
	["agua"] = { 0, 0 },
	["ajudar"] = { 128, 0 },
	["alvo"] = { 256, 0 },
	["andar"] = { 384, 0 },
	["apoio"] = { 512, 0 },
	["atacar"] = { 640, 0 },
	["caveira"] = { 768, 0 },
	["chamas"] = { 896, 0 },
	["cura"] = { 0, 128 },
	["curativo"] = { 128, 128 },
	["defender"] = { 256, 128 },
	["desarmar"] = { 384, 128 },
	["disparo"] = { 512, 128 },
	["encerrar"] = { 640, 128 },
	["esconder"] = { 768, 128 },
	["espiral"] = { 896, 128 },
	["esquivar"] = { 0, 256 },
	["flecha"] = { 128, 256 },
	["fogo"] = { 256, 256 },
	["fogueira"] = { 384, 256 },
	["gelo"] = { 512, 256 },
	["golem"] = { 640, 256 },
	["golpe"] = { 768, 256 },
	["golpe-baixo"] = { 896, 256 },
	["grito"] = { 0, 384 },
	["guarda"] = { 128, 384 },
	["habilidades"] = { 256, 384 },
	["invocacao"] = { 384, 384 },
	["lamina"] = { 512, 384 },
	["levantar"] = { 640, 384 },
	["luz"] = { 768, 384 },
	["magia"] = { 896, 384 },
	["marcar"] = { 0, 512 },
	["muralha"] = { 128, 512 },
	["musica"] = { 256, 512 },
	["onda"] = { 384, 512 },
	["quebrar-escudo"] = { 512, 512 },
	["raio"] = { 640, 512 },
	["runa"] = { 768, 512 },
	["sangue"] = { 896, 512 },
	["soco"] = { 0, 640 },
	["teorica"] = { 128, 640 },
	["terra"] = { 256, 640 },
	["vazio"] = { 384, 640 },
	["veneno"] = { 512, 640 },
	["vento"] = { 640, 640 },
})

local POR_ARVORE = {
	fogo = "fogo", agua = "agua", terra = "terra", vento = "vento", vendaval = "lamina", cura = "cura",
	desintoxicacao = "veneno", arquearia = "flecha", invocacao = "invocacao", teorica = "teorica",
	bardo_e_interacao = "musica", armas_pesadas = "golpe", cavalaria_e_escudos = "guarda", deus_da_espada = "lamina",
	furtividade_e_armadilhas = "esconder", punho_de_fogo = "soco", deus_da_agua_corpo = "onda", deus_do_norte = "gelo",
	navegacao_e_lideranca = "onda",
}

-- Palavras no id que valem mais que a árvore (primeira que casar).
local POR_PALAVRA = {
	{ "gelo", "gelo" }, { "relampago", "raio" }, { "raio", "raio" }, { "cura", "cura" }, { "muralha", "muralha" },
	{ "muro", "muralha" }, { "golem", "golem" }, { "mare", "onda" }, { "veneno", "veneno" }, { "peconha", "veneno" },
	{ "sangue", "sangue" }, { "sangria", "sangue" }, { "flecha", "flecha" }, { "escudo", "guarda" },
	{ "chama", "chamas" }, { "sinal", "luz" }, { "grito", "grito" }, { "insulto", "grito" }, { "medo", "grito" },
}

local POR_ID_MESA = {
	["mesa/ataque-basico"] = "golpe", ["mesa/ataque-a-distancia"] = "disparo", ["mesa/desarmar"] = "desarmar",
	["mesa/esquivar"] = "esquivar", ["mesa/defender"] = "defender", ["mesa/ajudar"] = "ajudar",
	["mesa/esconder"] = "esconder", ["mesa/golpe-baixo"] = "golpe-baixo", ["mesa/quebrar-escudo"] = "quebrar-escudo",
	["mesa/levantar"] = "levantar", ["mesa/marcar"] = "marcar", ["mesa/andar"] = "andar",
	["mesa/sob-minha-guarda"] = "guarda", ["mesa/desenhar-formula"] = "runa", ["mesa/moldar"] = "espiral",
	["mesa/brisa"] = "vento", ["mesa/molhar"] = "agua",
	["mesa/apagar-fogo"] = "chamas", ["mesa/pacto"] = "runa", -- RODA1: linhas da lista de Ações que não são cartas do livro
}

-- RODA1: ícone de cada fatia da roda de ações (nomes do atlas acima).
UIArteLuta.ICONES_RODA = table.freeze({ golpear = "golpe", habilidades = "magia", acoes = "andar", encerrar = "encerrar" })

-- Nome do ícone de uma habilidade pelo id (e árvore, se souber); sempre devolve um ícone existente.
function UIArteLuta.iconeDe(habilidadeId: string, arvore: string?): string
	local direto = POR_ID_MESA[habilidadeId]
	if direto then return direto end
	if string.sub(habilidadeId, 1, 17) == "mesa/lamina-de-ge" then return "gelo" end
	for _, par in POR_PALAVRA do
		if string.find(habilidadeId, par[1], 1, true) then return par[2] end
	end
	local nome = POR_ARVORE[arvore or string.match(habilidadeId, "^%a+/([^/]+)/") or ""]
	return nome or (if string.sub(habilidadeId, 1, 5) == "mesa/" then "golpe" else "magia")
end

return UIArteLuta
