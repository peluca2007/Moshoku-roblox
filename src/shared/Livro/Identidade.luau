-- GERADO por tools/gerar-catalogo.mts a partir do site do livro. Não edite: rode o gerador.
-- Identidade visual das árvores (apresentação, não regra): cor da noite, kanji e selo, como no livro. Chave: id da árvore no catálogo.
local function congelar(t)
	for _, v in t do
		if type(v) == "table" and not table.isfrozen(v) then
			congelar(v)
		end
	end
	return table.freeze(t)
end
return congelar({
	["tree/fogo"] = {
		cor = "#ff6f4a",
		kanji = "火魔術",
		selo = "火",
	},
	["tree/agua"] = {
		cor = "#5a9bff",
		kanji = "水魔術",
		selo = "水",
	},
	["tree/vento"] = {
		cor = "#8be28f",
		kanji = "風魔術",
		selo = "風",
	},
	["tree/terra"] = {
		cor = "#c89a6a",
		kanji = "土魔術",
		selo = "土",
	},
	["tree/cura"] = {
		cor = "#d4e157",
		kanji = "治癒魔術",
		selo = "癒",
	},
	["tree/desintoxicacao"] = {
		cor = "#c07dff",
		kanji = "解毒魔術",
		selo = "解",
	},
	["tree/teorica"] = {
		cor = "#78d5d0",
		kanji = "理論魔術",
		selo = "式",
	},
	["tree/invocacao"] = {
		cor = "#ff7ec4",
		kanji = "召喚魔術",
		selo = "召",
	},
	["tree/deus-da-espada"] = {
		cor = "#ff4d6a",
		kanji = "剣神流",
		selo = "剣",
	},
	["tree/deus-da-agua-corpo"] = {
		cor = "#4fc4ff",
		kanji = "水神流",
		selo = "流",
	},
	["tree/deus-do-norte"] = {
		cor = "#a9bcd6",
		kanji = "北神流",
		selo = "北",
	},
	["tree/armas-pesadas"] = {
		cor = "#e0a86a",
		kanji = "闘士",
		selo = "闘",
	},
	["tree/cavalaria-e-escudos"] = {
		cor = "#7d8cff",
		kanji = "騎士道",
		selo = "盾",
	},
	["tree/vendaval"] = {
		cor = "#33d6b0",
		kanji = "疾風流",
		selo = "嵐",
	},
	["tree/punho-de-fogo"] = {
		cor = "#ff9a3d",
		kanji = "炎拳",
		selo = "拳",
	},
	["tree/arquearia"] = {
		cor = "#a8c46a",
		kanji = "弓術",
		selo = "弓",
	},
	["tree/furtividade-e-armadilhas"] = {
		cor = "#9d8df1",
		kanji = "隠密",
		selo = "影",
	},
	["tree/bardo-e-interacao"] = {
		cor = "#ffab91",
		kanji = "吟遊詩人",
		selo = "詩",
	},
	["tree/navegacao-e-lideranca"] = {
		cor = "#e3c88f",
		kanji = "統率",
		selo = "導",
	},
})
