-- Projeção da ficha importada com o estado autoritativo atual da mesa.
-- Não altera a construção importada, não calcula regras e não usa serviços.
local FichaSessao = {}

local function copiar(valor)
	if type(valor) ~= "table" then return valor end
	local copia = {}
	for chave, item in valor do copia[chave] = copiar(item) end
	return copia
end

-- incluirNotas somente para o mestre ou dono autorizado a ver a ficha.
-- Quem chama continua responsável por validar acesso à ficha inteira.
function FichaSessao.projetar(token, incluirNotas: boolean)
	if not token.ficha2 then return nil end
	local ficha = copiar(token.ficha2)
	ficha.name = token.name
	ficha.calculated.maxima.pv = token.pvMax
	ficha.calculated.maxima.pm = token.manaMax
	ficha.session.current.pv = token.pv
	ficha.session.current.pm = token.mana
	ficha.session.conditions = {}
	for _, condicao in token.conditions or {} do
		table.insert(ficha.session.conditions, {
			conditionId = "condition/" .. condicao.id,
			stacks = condicao.stacks,
			note = if incluirNotas then condicao.note else nil,
		})
	end
	return ficha
end

return FichaSessao
