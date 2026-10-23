-- Aprendizagem interna da run: ranks adicionais usam a mesma progressão da ficha inicial.
local Shared = game:GetService("ReplicatedStorage").Shared
local Progressao = require(Shared.Regras.Progressao)
local Pericias = require(Shared.Regras.PericiasPersonagem)
local Estatisticas = require(Shared.Regras.EstatisticasPersonagem)
local Regras = require(Shared.Livro.Regras)
local Arvores = {}
function Arvores.aplicar(perfil, ids, catalogo)
	if type(ids) ~= "table" or #ids > 8 then return nil, "Árvores aprendidas inválidas." end
	local novo = table.clone(perfil)
	novo.construcao = table.clone(perfil.construcao)
	local inicial = catalogo.POR_ID[perfil.construcao.startingTreeId]
	if #ids > 0 and not inicial then return nil, "Aprenda a primeira árvore antes das adicionais." end
	novo.construcao.unlockedRankIds = if inicial then { Progressao.idDoRank(inicial.data.id, "Principiante") } else {}
	novo.arvoresAprendidas = {}
	local vistas = { [perfil.construcao.startingTreeId or ""] = true }
	for indice, id in ids do
		if type(indice) ~= "number" or indice % 1 ~= 0 or indice < 1 or indice > #ids then return nil, "Lista de árvores inválida." end
		local arvore = type(id) == "string" and catalogo.POR_ID[id]
		if not arvore or arvore.kind ~= "tree" or vistas[id] then return nil, "Árvore adicional inválida ou repetida." end
		local rank = Progressao.idDoRank(arvore.data.id, "Principiante")
		if not catalogo.POR_ID[rank] then return nil, "Rank adicional ausente." end
		vistas[id] = true
		table.insert(novo.arvoresAprendidas, id)
		if not table.find(novo.construcao.unlockedRankIds, rank) then table.insert(novo.construcao.unlockedRankIds, rank) end
	end
	novo.pericias = Pericias.calcularTodas(novo.construcao, catalogo, novo.atributos, Regras.bonusDeRank)
	-- PV continuam os da primeira árvore. Recursos de outra categoria usam a fórmula
	-- já existente, sem somar duas vezes os recursos de árvores da mesma categoria.
	local base = table.clone(novo.construcao)
	base.unlockedRankIds = if inicial then { Progressao.idDoRank(inicial.data.id, "Principiante") } else {}
	novo.estatisticas = Estatisticas.calcular(base, catalogo, novo.atributos)
	if not novo.estatisticas then return nil, "Estatísticas iniciais inválidas." end
	for _, id in novo.arvoresAprendidas do
		local c = table.clone(novo.construcao)
		c.unlockedRankIds = { Progressao.idDoRank(catalogo.POR_ID[id].data.id, "Principiante") }
		local stats, erro = Estatisticas.calcular(c, catalogo, novo.atributos)
		if not stats then return nil, erro end
		for _, recurso in { "pm", "pt", "pp" } do novo.estatisticas.maxima[recurso] = math.max(novo.estatisticas.maxima[recurso], stats.maxima[recurso]) end
	end
	return novo
end
return Arvores
