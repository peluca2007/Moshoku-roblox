-- Estética "Livro Noite" (pedido do Pedro, 09/10/2026): o jogo veste o tema
-- Livro Noite do site e o livro folheado. Fonte: `src/app/livro/folhear/folhear.css`
-- (paleta noite e cores de capítulo) e `src/components/book/folhear/fontes.ts`
-- (vozes da letra). A identidade de cada árvore vem gerada em Livro/Identidade.
-- Só apresentação: nada aqui é regra. Ver docs/VISUAL.md.
local Identidade = require(script.Parent:WaitForChild("Livro"):WaitForChild("Identidade"))

local Estilo = {}

local function hex(valor: string): Color3
	return Color3.fromHex(valor)
end

-- Paleta noite do livro.
Estilo.PAPEL = hex("#141418") -- página
Estilo.PAPEL_2 = hex("#1e1e24") -- cartões e caixas
Estilo.TINTA = hex("#e8e3d9") -- texto
Estilo.TINTA_SUAVE = hex("#aca79d") -- texto secundário
Estilo.FIO_TRANSPARENCIA = 0.87 -- fios e grade: a tinta a 13%
Estilo.SOBRE_COR = hex("#111114") -- texto sobre fundo colorido
Estilo.MESA = hex("#101013") -- a mesa onde o livro está
Estilo.MESA_FUNDO = hex("#070709")

-- Cores de capítulo (0 a 5) e dos apêndices. A abertura do livro e as abas.
Estilo.CAPITULOS = {
	hex("#ffa94d"),
	hex("#5eb1ff"),
	hex("#b197fc"),
	hex("#38d9a9"),
	hex("#ff6b6b"),
	hex("#ffd43b"),
}
Estilo.APENDICES = hex("#a5b4c4")

-- Destaque da interface: o roxo do botão principal do site (capítulo 2).
Estilo.DESTAQUE = Estilo.CAPITULOS[3]
Estilo.DESTAQUE_FUNDO = hex("#5b4a9c")
Estilo.PERIGO = Estilo.CAPITULOS[5]
Estilo.ALERTA = Estilo.CAPITULOS[6]
Estilo.SUCESSO = Estilo.CAPITULOS[4]

-- Interface (painel): botão comum, fio das bordas e fundo de ações perigosas.
-- Contraste do texto ≥ 4,5:1 conferido no teste do painel.
Estilo.BOTAO = hex("#26262e")
Estilo.FIO_COR = hex("#3a3a44")
Estilo.PERIGO_FUNDO = hex("#663235")

-- Vozes da letra. O Roblox não tem Barlow, Fraunces nem Literata: usamos as
-- equivalentes mais próximas das fontes nativas (adaptação visual registrada).
--   GRITO: títulos, números, carimbos (Barlow Condensed no livro).
--   ROTULO: rótulos miúdos e botões (Barlow).
--   CORPO: texto corrido (Literata).
--   ELEGANTE: subtítulos e nomes de habilidade (Fraunces itálica).
Estilo.GRITO = Font.fromName("Oswald", Enum.FontWeight.Bold)
Estilo.ROTULO = Font.fromName("RobotoCondensed", Enum.FontWeight.SemiBold)
Estilo.ROTULO_FORTE = Font.fromName("RobotoCondensed", Enum.FontWeight.Bold)
Estilo.CORPO = Font.fromName("Merriweather", Enum.FontWeight.Regular)
Estilo.ELEGANTE = Font.fromName("Merriweather", Enum.FontWeight.Regular, Enum.FontStyle.Italic)

-- Motivos do "caos" do livro, desenhados com texto (sem imagens enviadas).
Estilo.KANJI_CAPITULOS = { "序", "壱", "弐", "参", "肆", "伍" }
Estilo.ESTRELA = "✦"

export type IdentidadeDaArvore = { cor: Color3, kanji: string, selo: string }

-- Identidade de uma árvore pelo id do catálogo ("tree/fogo") ou local ("fogo").
-- Árvore desconhecida: os apêndices (cinza-azulado), sem kanji próprio.
function Estilo.arvore(id: string?): IdentidadeDaArvore
	local chave = if id and string.sub(id, 1, 5) ~= "tree/" then "tree/" .. id else id
	local dados = chave and Identidade[chave]
	if not dados then
		return { cor = Estilo.APENDICES, kanji = "", selo = "" }
	end
	return { cor = hex(dados.cor), kanji = dados.kanji, selo = dados.selo }
end

-- Caixa alta da "voz gritada" que entende acento (string.upper só cobre ASCII).
local MAIUSCULAS = {
	["á"] = "Á", ["à"] = "À", ["â"] = "Â", ["ã"] = "Ã", ["é"] = "É", ["ê"] = "Ê", ["í"] = "Í",
	["ó"] = "Ó", ["ô"] = "Ô", ["õ"] = "Õ", ["ú"] = "Ú", ["ü"] = "Ü", ["ç"] = "Ç",
}
function Estilo.maiusculas(texto: string): string
	local resultado = string.upper(texto)
	for minuscula, maiuscula in MAIUSCULAS do
		resultado = string.gsub(resultado, minuscula, maiuscula)
	end
	return resultado
end

-- Mistura de cor como o color-mix do livro: quanto de "cor" sobre "fundo".
function Estilo.misturar(cor: Color3, fundo: Color3, quanto: number): Color3
	return fundo:Lerp(cor, quanto)
end

return table.freeze(Estilo)
