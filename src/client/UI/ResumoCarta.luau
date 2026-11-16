-- Linha curta de efeito para as cartas da luta (HUD2). Só apresentação: não altera dados de regra do
-- livro nem o texto completo (Tooltip/Detalhe continuam usando Descricao.texto e o catálogo).
-- Regra: usa a primeira frase da descrição da mecânica ou do efeito do livro, sem texto técnico de
-- implementação ("O servidor valida..."), e corta em LIMITE caracteres.
local R = {}

R.LIMITE = 64

local CONTROLES = {
	escapar = "Solta-se de quem o prende",
	soltar = "Solta o agarrão, sem custo",
	arrastar = "Arrasta o alvo por 3 m",
	["pegar-arma"] = "Recolhe uma arma caída",
	desarmar = "Tenta tirar a arma do alvo",
	levantar = "Levanta-se e remove Caído",
}

local function primeiraFrase(texto: string): string
	local t = string.gsub(texto, "%s+", " ")
	t = string.gsub(t, "^%s+", "")
	local fim = string.find(t, "[%.!?] ")
	if fim then t = string.sub(t, 1, fim) end
	return t
end

local function cortar(t: string): string
	if #t <= R.LIMITE then return t end
	local c = string.sub(t, 1, R.LIMITE - 1)
	c = string.gsub(c, "[%s,;:%-]+[^%s]*$", "")
	return c .. "…"
end

local function tecnico(t: string): boolean
	return string.find(string.lower(t), "servidor", 1, true) ~= nil
end

-- mec: mecânica executável; dados: entrada do catálogo (pode ser {}); indisponivel: texto ou nil.
function R.curto(mec, dados, indisponivel: string?, id: string?): string
	if indisponivel then return cortar(primeiraFrase(indisponivel)) end
	local controle = mec.controleA16 or (if id then string.match(id, "^mesa/(.+)$") else nil)
	if controle and CONTROLES[controle] then return CONTROLES[controle] end
	local fonte = mec.descricao
	if type(fonte) ~= "string" or fonte == "" or tecnico(fonte) then
		fonte = if type(dados.effect) == "string" then dados.effect else ""
	end
	if tecnico(fonte) then fonte = "" end
	if fonte == "" and dados.damage and type(dados.damage.normal) == "string" then fonte = "Dano: " .. dados.damage.normal end
	-- "1 Ação, em você: assume..." -> "Assume...": o custo já aparece no canto da carta.
	local resto = string.match(fonte, "^%d+ A[^:]-:%s*(.+)$")
	local doisPontos = string.find(fonte, ":", 1, true)
	if resto and doisPontos and doisPontos <= 40 then fonte = string.upper(string.sub(resto, 1, 1)) .. string.sub(resto, 2) end
	return cortar(primeiraFrase(fonte))
end

return R
