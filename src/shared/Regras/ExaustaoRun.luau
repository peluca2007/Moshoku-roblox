-- Exaustão na expedição (decisão do Pedro, 14/11/2026): "Cada luta sem descanso depois dá 1 nível de
-- Exaustão do livro; descansar zera." Guardada por personagem na run (RunSessao salva com `serializar`).
-- Puro: sem Instances nem rede; nenhum dado é rolado aqui.
--
-- estado = { [userId] = { nivel = 0..MAX, lutas = lutas seguidas desde o último descanso ou a entrada na área } }
--
-- Regras:
-- - A primeira luta depois de descansar ou de entrar na área não dá exaustão; cada luta seguinte, +1 nível.
-- - Cair a 0 PV na luta dá +1 nível (livro, Cap. 4, §7: "acordar do Fio da Vida cobra 1 nível de Exaustão";
--   §"Trauma": "cair já cobra pela Exaustão"). Soma com a regra acima.
-- - Descansar (acampamento ou cidade) zera nível e sequência. ADAPTAÇÃO: no livro um Descanso Longo tira só
--   1 nível; aqui vale a decisão do Pedro (zera).
-- - Teto MAX = 5. PENDENTE (livro, Cap. 4, §9): o nível 6 é a morte, com "a última rolagem" (Vigor CD 15;
--   sucesso fica no 5). Sem essa rolagem implementada, a contagem para no 5 em vez de matar.
local Exaustao = {}

Exaustao.MAX = 5

-- Penalidades do livro (Cap. 4, §9), por nível; os efeitos somam.
Exaustao.PENALIDADES = table.freeze({
	"Desvantagem em testes de atributo e de perícia.",
	"Deslocamento reduzido à metade.",
	"Desvantagem em rolagens de ataque e em testes de resistência; Exausto (o Manto de Touki cai).",
	"PV Máximos reduzidos à metade.",
	"Deslocamento reduzido a 0.",
})

local function idValido(id)
	return (type(id) == "number" and id == id and id % 1 == 0) or (type(id) == "string" and id ~= "" and #id <= 64)
end

local function copiar(estado)
	local novo = {}
	for id, e in estado or {} do novo[id] = { nivel = e.nivel, lutas = e.lutas } end
	return novo
end

function Exaustao.nivel(estado, id)
	local e = estado and estado[id]
	return if e then e.nivel else 0
end

-- participantes = { [userId] = { caiu = bool } } (quem lutou). Devolve o novo estado.
function Exaustao.aoFimDaLuta(estado, participantes)
	local novo = copiar(estado)
	for id, p in participantes or {} do
		if idValido(id) then
			local e = novo[id] or { nivel = 0, lutas = 0 }
			e.lutas += 1
			local ganho = (if e.lutas >= 2 then 1 else 0) + (if type(p) == "table" and p.caiu == true then 1 else 0)
			e.nivel = math.min(Exaustao.MAX, e.nivel + ganho)
			novo[id] = e
		end
	end
	return novo
end

-- Descanso dos `ids` (lista): zera nível e sequência.
function Exaustao.descansar(estado, ids)
	local novo = copiar(estado)
	for _, id in ids or {} do novo[id] = nil end
	return novo
end

-- Entrar na área ou voltar à cidade recomeça a sequência de lutas (o nível fica até descansar).
function Exaustao.zerarSequencia(estado)
	local novo = copiar(estado)
	for id, e in novo do
		if e.nivel <= 0 then novo[id] = nil else e.lutas = 0 end
	end
	return novo
end

-- Texto plano para os extras do save (RunSave só aceita texto/número/booleano): "id=nivel/lutas;...".
-- Ids numéricos com prefixo "n", de texto com "s" (o tipo volta igual na leitura).
function Exaustao.serializar(estado)
	local partes = {}
	for id, e in estado or {} do
		if idValido(id) and (e.nivel > 0 or e.lutas > 0) then
			table.insert(partes, string.format("%s%s=%d/%d", if type(id) == "number" then "n" else "s", tostring(id), e.nivel, e.lutas))
		end
	end
	table.sort(partes)
	return table.concat(partes, ";")
end

-- Devolve (estado) ou (nil, motivo). `jogadores` (opcional) = run.jogadores: ignora quem não está na run.
function Exaustao.restaurar(texto, jogadores)
	if texto == nil or texto == "" then return {} end
	if type(texto) ~= "string" or #texto > 4096 then return nil, "Exaustão salva inválida." end
	local estado = {}
	for parte in string.gmatch(texto, "[^;]+") do
		local tipo, id, nivel, lutas = string.match(parte, "^([ns])([^=]+)=(%d+)/(%d+)$")
		if not tipo then return nil, "Exaustão salva inválida." end
		local chave = if tipo == "n" then tonumber(id) else id
		nivel, lutas = tonumber(nivel), tonumber(lutas)
		if not idValido(chave) or nivel > Exaustao.MAX or lutas > 1000 then return nil, "Exaustão salva inválida." end
		if jogadores == nil or jogadores[chave] ~= nil then estado[chave] = { nivel = nivel, lutas = lutas } end
	end
	return estado
end

-- Efeitos do nível no INÍCIO da luta, pelo mecanismo de condições que a mesa já tem.
-- A mesa só conhece a condição "exausto" (nível 3 ou mais, sem nível; ver Shared/Condicoes): ela é aplicada.
-- PENDENTE: efeitos do livro (Cap. 4, §9) que a mesa ainda não representa — Desvantagem em testes (1) e em
-- ataques/resistências (3), Deslocamento à metade (2) e 0 (5), PV Máximos à metade (4). Ficam em `pendentes`
-- (texto para o registro da luta) até a mesa ter a condição com níveis.
function Exaustao.efeitosNaLuta(nivel)
	local n = if type(nivel) == "number" then math.clamp(math.floor(nivel), 0, Exaustao.MAX) else 0
	local efeitos = { nivel = n, condicoes = {}, pendentes = {} }
	if n >= 3 then table.insert(efeitos.condicoes, "exausto") end
	for i = 1, n do table.insert(efeitos.pendentes, Exaustao.PENALIDADES[i]) end
	return efeitos
end

return table.freeze(Exaustao)
