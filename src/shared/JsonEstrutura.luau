-- Verificador estrutural de JSON, ANTES do HttpService:JSONDecode
-- (docs/CONTRATOS.md §5.4). O JSONDecode não recusa chaves duplicadas (a
-- última vence), não limita profundidade e transforma null em nil, abrindo
-- buracos em listas. Aqui se percorre o texto uma vez, sem expressões
-- regulares, contando nós e profundidade e recusando null e chaves repetidas.
-- Puro: sem Instances nem rede.
local JsonEstrutura = {}

export type Limites = { profundidade: number, nos: number }

local BRANCO = { [32] = true, [9] = true, [10] = true, [13] = true }

-- Devolve (true, nil) ou (false, motivo).
function JsonEstrutura.verificar(texto: any, limites: Limites): (boolean, string?)
	if type(texto) ~= "string" then
		return false, "o conteúdo não é texto"
	end
	if utf8.len(texto) == nil then
		return false, "texto com UTF-8 inválido"
	end
	local pos, n = 1, #texto
	local nos, profundidade = 0, 0

	local function erro(motivo: string)
		error({ motivo = motivo .. " (posição " .. pos .. ")" }, 0)
	end
	local function pular()
		while pos <= n and BRANCO[string.byte(texto, pos)] do
			pos += 1
		end
	end
	local function contar()
		nos += 1
		if nos > limites.nos then
			erro("mais de " .. limites.nos .. " valores")
		end
	end

	-- Lê uma string JSON e devolve seu valor decodificado (para comparar chaves).
	local function lerString(): string
		pos += 1 -- aspas de abertura
		local partes = {}
		local inicio = pos
		while true do
			if pos > n then
				erro("texto sem aspas de fechamento")
			end
			local c = string.byte(texto, pos)
			if c == 34 then
				table.insert(partes, string.sub(texto, inicio, pos - 1))
				pos += 1
				return table.concat(partes)
			elseif c == 92 then
				table.insert(partes, string.sub(texto, inicio, pos - 1))
				local e = string.sub(texto, pos + 1, pos + 1)
				if e == "u" then
					-- Decodifica de verdade: "a" e "a" são a MESMA chave para o JSONDecode.
					local hex = string.sub(texto, pos + 2, pos + 5)
					if not string.match(hex, "^%x%x%x%x$") then
						erro("escape \\u inválido")
					end
					local codigo = tonumber(hex, 16) :: number
					pos += 6
					if codigo >= 0xD800 and codigo <= 0xDBFF then
						local baixo = string.match(texto, "^\\u(%x%x%x%x)", pos)
						local b = baixo and tonumber(baixo, 16)
						if not b or b < 0xDC00 or b > 0xDFFF then
							erro("surrogate UTF-16 isolado")
						end
						codigo = 0x10000 + (codigo - 0xD800) * 0x400 + (b - 0xDC00)
						pos += 6
					elseif codigo >= 0xDC00 and codigo <= 0xDFFF then
						erro("surrogate UTF-16 isolado")
					end
					table.insert(partes, utf8.char(codigo))
				else
					local simples = ({ ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" })[e]
					if not simples then
						erro("escape inválido")
					end
					table.insert(partes, simples)
					pos += 2
				end
				inicio = pos
			elseif c < 32 then
				erro("caractere de controle dentro de texto")
			else
				pos += 1
			end
		end
	end

	local lerValor

	local function lerNumero()
		local inicio = pos
		if string.sub(texto, pos, pos) == "-" then
			pos += 1
		end
		local digitos = string.match(texto, "^%d+", pos)
		if not digitos then
			erro("número inválido")
		end
		if #digitos > 1 and string.sub(digitos, 1, 1) == "0" then
			erro("número com zero à esquerda")
		end
		pos += #digitos
		if string.sub(texto, pos, pos) == "." then
			local frac = string.match(texto, "^%d+", pos + 1)
			if not frac then
				erro("número inválido")
			end
			pos += 1 + #frac
		end
		local e = string.sub(texto, pos, pos)
		if e == "e" or e == "E" then
			local exp = string.match(texto, "^[eE][+-]?%d+", pos)
			if not exp then
				erro("expoente inválido")
			end
			pos += #exp
		end
		if pos - inicio > 32 then
			erro("número longo demais")
		end
	end

	local function lerContainer(abre: number)
		profundidade += 1
		if profundidade > limites.profundidade then
			erro("aninhamento acima de " .. limites.profundidade)
		end
		pos += 1
		pular()
		local fecha = if abre == 123 then 125 else 93
		if string.byte(texto, pos) == fecha then
			pos += 1
			profundidade -= 1
			return
		end
		local chaves = {}
		while true do
			pular()
			if abre == 123 then
				if string.byte(texto, pos) ~= 34 then
					erro("chave de objeto precisa ser texto")
				end
				local chave = lerString()
				if chaves[chave] then
					erro("chave repetida \"" .. chave .. "\"")
				end
				chaves[chave] = true
				pular()
				if string.byte(texto, pos) ~= 58 then
					erro("faltou ':'")
				end
				pos += 1
			end
			lerValor()
			pular()
			local c = string.byte(texto, pos)
			if c == 44 then
				pos += 1
			elseif c == fecha then
				pos += 1
				profundidade -= 1
				return
			else
				erro("faltou ',' ou fechamento")
			end
		end
	end

	function lerValor()
		pular()
		contar()
		local c = string.byte(texto, pos)
		if c == 123 or c == 91 then
			lerContainer(c)
		elseif c == 34 then
			lerString()
		elseif c == 45 or (c and c >= 48 and c <= 57) then
			lerNumero()
		elseif string.sub(texto, pos, pos + 3) == "true" then
			pos += 4
		elseif string.sub(texto, pos, pos + 4) == "false" then
			pos += 5
		elseif string.sub(texto, pos, pos + 3) == "null" then
			erro("null não é aceito (vira buraco no Roblox)")
		else
			erro("valor inesperado")
		end
	end

	local ok, falha = pcall(function()
		lerValor()
		pular()
		if pos <= n then
			erro("conteúdo depois do fim do JSON")
		end
	end)
	if ok then
		return true, nil
	end
	if type(falha) == "table" then
		return false, falha.motivo
	end
	return false, "erro interno do verificador: " .. tostring(falha)
end

return table.freeze(JsonEstrutura)
