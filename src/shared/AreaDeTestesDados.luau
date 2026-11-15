-- Catálogo e validação da Área de Testes (sala de administradores no Studio). Puro: sem Instances,
-- sem eventos. As listas vêm das fontes do jogo; só props e gestos (que dependem de servidor ou
-- cliente) chegam por `extra`. Contrato do remoto: docs/MANUTENCAO.md (AreaDeTestes).
local Shared = game:GetService("ReplicatedStorage").Shared
local ModelosCriaturas = require(Shared.Mundo.ModelosCriaturas)
local ArenasDados = require(Shared.Mundo.ArenasDados)
local Sons = require(Shared.Sons)
local Dublagem = require(Shared.DublagemNPCs)

local D = {}

-- Origem da sala: longe do mundo (x -120..229) e da mesa (z 900).
D.ORIGEM = table.freeze({ x = 4000, y = 0, z = 0 })
-- Pontos da sala (studs): piso com topo y=1 (como o tabuleiro), pedestal 1,2 acima, avatar e boneco-alvo
-- lado a lado a 30 de distância (aba Gestos).
D.TOPO_PISO = 1
D.CENTRO = Vector3.new(4000, 2.2, 0)
D.ENTRADA = Vector3.new(3990, 4, 30)
D.BONECO = Vector3.new(4010, 1, 30)
D.INTERVALO = 0.25 -- segundos mínimos entre pedidos de um mesmo jogador

D.CATEGORIAS = table.freeze({
	{ id = "criaturas", nome = "Criaturas", servidor = true },
	{ id = "props", nome = "Props", servidor = true },
	{ id = "arenas", nome = "Arenas", servidor = true },
	{ id = "sons", nome = "Sons" },
	{ id = "vozes", nome = "Vozes" },
	{ id = "gestos", nome = "Gestos" },
	{ id = "interface", nome = "Interface" },
})

-- Animações por código dos modelos de criatura (Mundo/CriaturaAnimada).
D.ANIMACOES = table.freeze({ "parado", "andando", "ataque", "queda" })
D.PECAS_INTERFACE = table.freeze({ "painel", "botoes", "barra", "aviso", "dialogo" })

local function chavesOrdenadas(tabela)
	local c = {}
	for k in tabela do table.insert(c, k) end
	table.sort(c)
	return c
end

local function item(id, nome, extra)
	local t = extra or {}
	t.id, t.nome = id, nome or id
	return t
end

-- Lista de { id, nome, ... } da categoria; `extra` = { props = {nomes}, gestos = {ids} }.
function D.itens(categoria, extra)
	extra = extra or {}
	local lista = {}
	if categoria == "criaturas" then
		for _, id in chavesOrdenadas(ModelosCriaturas.POR_CRIATURA) do
			local e = ModelosCriaturas.POR_CRIATURA[id]
			local nome = string.gsub(id, "^creature/", "")
			table.insert(lista, item(id, nome, { variantes = #e.modulos, tipo = e.tipo }))
		end
	elseif categoria == "props" then
		local nomes = table.clone(extra.props or {})
		table.sort(nomes)
		for _, nome in nomes do table.insert(lista, item(nome)) end
	elseif categoria == "arenas" then
		for _, id in ArenasDados.ids() do table.insert(lista, item(id)) end
	elseif categoria == "sons" then
		for _, id in chavesOrdenadas(Sons.ARQUIVOS) do
			if Sons.IDS[id] then table.insert(lista, item(id, id, { assetId = Sons.IDS[id] })) end
		end
	elseif categoria == "vozes" then
		for _, id in chavesOrdenadas(Dublagem) do
			table.insert(lista, item(id, id, { assetId = Dublagem[id].id, segundos = Dublagem[id].segundos }))
		end
	elseif categoria == "gestos" then
		local ids = table.clone(extra.gestos or {})
		table.sort(ids)
		for _, id in ids do table.insert(lista, item(id, string.match(id, "([^/]+)$"))) end
	elseif categoria == "interface" then
		for _, id in D.PECAS_INTERFACE do table.insert(lista, item(id)) end
	end
	return lista
end

function D.categoriaValida(categoria)
	for _, c in D.CATEGORIAS do
		if c.id == categoria then return true end
	end
	return false
end

function D.existe(categoria, id, extra)
	if type(categoria) ~= "string" or type(id) ~= "string" or #id > 200 then return false end
	for _, it in D.itens(categoria, extra) do
		if it.id == id then return true end
	end
	return false
end

-- Pedido do cliente: devolve (true, limpo) ou (false, motivo).
-- Ações: catalogo | entrar | sair | girar {ligado} | mostrar {categoria,id,variante?,animacao?} | arena {id}
function D.validarPedido(acao, dados, extra)
	if acao == "catalogo" or acao == "entrar" or acao == "sair" then return true, {} end
	if type(dados) ~= "table" then return false, "pedido inválido" end
	if acao == "girar" then
		if type(dados.ligado) ~= "boolean" then return false, "pedido inválido" end
		return true, { ligado = dados.ligado }
	elseif acao == "arena" then
		if not D.existe("arenas", dados.id, extra) then return false, "arena inexistente" end
		return true, { id = dados.id }
	elseif acao == "mostrar" then
		local c = dados.categoria
		if c ~= "criaturas" and c ~= "props" then return false, "categoria inválida" end
		if not D.existe(c, dados.id, extra) then return false, "item inexistente" end
		local limpo = { categoria = c, id = dados.id, animacao = "parado", variante = 0 }
		if dados.animacao ~= nil then
			if c ~= "criaturas" or not table.find(D.ANIMACOES, dados.animacao) then return false, "animação inválida" end
			limpo.animacao = dados.animacao
		end
		if dados.variante ~= nil then
			local v = dados.variante
			if type(v) ~= "number" or v ~= v or v < 0 or v > 20 then return false, "variante inválida" end
			limpo.variante = math.floor(v)
		end
		return true, limpo
	end
	return false, "ação desconhecida"
end

return D
