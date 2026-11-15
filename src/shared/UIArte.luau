-- Kit de arte da interface (estilo Pergaminho, 14/11/2026; ids do kit escuro de 24/10 no git): PNGs gerados por tools/blender/ui_kit.py (escala 2) e enviados
-- como imagens pelo MCP do Studio (upload_image). Dados puros: id, tamanho do PNG e o SliceCenter em
-- pixels do PNG. `ESCALA` é o SliceScale que leva a peça ao tamanho de desenho (PNG em 2x → 0.5).
-- Para trocar a arte: regerar com o script, enviar de novo e atualizar os ids aqui.
local UIArte = {}

local function peca(id, l, a, corte)
	-- corte = { x0, y0, x1, y1 } (SliceCenter); números simples para o módulo seguir puro.
	return table.freeze({ imagem = "rbxassetid://" .. id, largura = l, altura = a, corte = if corte then table.freeze(corte) else nil })
end

UIArte.ESCALA = 0.5 -- PNG em 2x

UIArte.PECAS = table.freeze({
	painel = peca("70830645229365", 512, 512, { 74, 74, 438, 438 }),
	botao = peca("124957475272585", 512, 176, { 40, 40, 472, 136 }),
	botao_ativo = peca("117845847623648", 512, 176, { 40, 40, 472, 136 }),
	botao_principal = peca("100256993397692", 512, 176, { 40, 40, 472, 136 }),
	barra_fundo = peca("130454807654404", 512, 64, { 26, 26, 486, 38 }),
	barra_cheia = peca("85379015708924", 512, 64, { 24, 24, 488, 40 }),
	aro = peca("77914889951252", 512, 512, nil),
	espaco = peca("82176086930797", 256, 256, { 60, 60, 196, 196 }),
	divisor = peca("139410959440373", 1024, 48, nil),
})

function UIArte.peca(nome)
	return UIArte.PECAS[nome]
end

-- SliceScale para que as bordas caibam numa altura `altura` (px de tela): nunca maior que a escala de
-- desenho e nunca deixa as duas bordas somarem mais que a altura disponível.
function UIArte.escalaPara(nome, altura)
	local p = UIArte.PECAS[nome]
	if not p or not p.corte or type(altura) ~= "number" or altura <= 0 then
		return UIArte.ESCALA
	end
	local bordas = p.corte[2] + (p.altura - p.corte[4])
	return math.min(UIArte.ESCALA, altura / bordas)
end

return UIArte
