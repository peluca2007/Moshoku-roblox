-- Vida e mana entre as salas da expedição (decisão do Pedro, 15/11/2026): o que foi gasto numa luta segue
-- para a próxima sala. Ao fim de uma luta DA EXPEDIÇÃO (vitória, derrota ou fuga) os recursos da ficha na
-- mesa voltam para a ficha pessoal (`perfil.descanso.atuais`), que monta `session.current` da próxima luta.
-- Puro: sem Instances nem rede. O servidor lê os tokens, chama `resolver` e grava o resultado.
--
-- ADAPTAÇÃO (Cap. 4, §7): quem terminou a 0 PV conta como Estabilizado e acorda com 1 PV — o livro dá 1 PV
-- a quem estabiliza ("acorda com 1 PV em 1d4 horas"); as horas são absorvidas pela volta ao acampamento
-- ou à cidade, e não rolamos o Fio da Vida nem as Marcas da Morte fora da luta. Vale também na derrota:
-- o grupo inteiro volta à cidade com 1 PV (a cidade tem descanso próprio). Sem isso o grupo ficaria travado
-- (a sala seguinte recusa quem está com 0 PV). O livro também diz que acordar do Fio da Vida custa 1 nível
-- de Exaustão: `caiu = true` informa isso a ExaustaoRun.
local Recursos = {}

Recursos.CAMPOS = table.freeze({ "pv", "pm", "pt", "pp" })

local function inteiro(v)
	return type(v) == "number" and v == v and math.abs(v) < math.huge
end

-- Lê os recursos de uma ficha da mesa (token): pv, mana -> pm, pt, pp (pt/pp só existem depois de usados).
function Recursos.doToken(token)
	if type(token) ~= "table" then return nil end
	return { pv = token.pv, pm = token.mana, pt = token.pt, pp = token.pp }
end

-- entrada = { luta = {pv, pm, pt?, pp?} (fim da luta), anteriores = {pv,pm,pt,pp} | nil, maximos = {pv,pm,pt,pp} }
-- Devolve ({ atuais = {pv,pm,pt,pp}, caiu = bool }) ou (nil, motivo). Campo ausente na luta mantém o anterior
-- (ou o máximo); tudo inteiro entre 0 e o máximo; 0 PV vira 1 PV com `caiu = true`.
function Recursos.resolver(entrada)
	if type(entrada) ~= "table" or type(entrada.luta) ~= "table" or type(entrada.maximos) ~= "table" then
		return nil, "entrada inválida"
	end
	local anteriores = if type(entrada.anteriores) == "table" then entrada.anteriores else entrada.maximos
	local atuais = {}
	for _, k in Recursos.CAMPOS do
		local maximo = entrada.maximos[k]
		if not inteiro(maximo) or maximo < 0 then return nil, "máximos inválidos" end
		maximo = math.floor(maximo)
		local valor = entrada.luta[k]
		if not inteiro(valor) then valor = anteriores[k] end
		if not inteiro(valor) then valor = maximo end
		atuais[k] = math.clamp(math.floor(valor), 0, maximo)
	end
	local caiu = atuais.pv <= 0
	if caiu then atuais.pv = math.min(1, entrada.maximos.pv) end
	return { atuais = atuais, caiu = caiu }
end

-- Descanso do acampamento (decisão do Pedro, 14–15/11/2026): recupera TUDO. ADAPTAÇÃO: o livro (Cap. 4, §7)
-- separa Curto (25% de PM/PP, todo PT, PV só com Cuidar dos Ferimentos) e Longo (PM/PP/PT cheios e
-- Vigor + 2 × Bônus de Rank de PV); o acampamento da expedição devolve PV, PM, PT e PP ao máximo.
function Recursos.descansoCompleto(maximos)
	if type(maximos) ~= "table" then return nil, "máximos inválidos" end
	local atuais = {}
	for _, k in Recursos.CAMPOS do
		if not inteiro(maximos[k]) or maximos[k] < 0 then return nil, "máximos inválidos" end
		atuais[k] = math.floor(maximos[k])
	end
	return atuais
end

return table.freeze(Recursos)
