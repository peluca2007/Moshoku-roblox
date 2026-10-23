-- Apresentação ampliada de aprovação; fila/tempo/transição continuam em UI/Avisos.
local C = require(script.Parent.Componentes)
local T = require(script.Parent.Tema)
local E = {}
function E.aprovacao(gui, identidade, mensagem)
	-- Canal separado somente para a celebração, para não redimensionar um item anterior da fila.
	local canal = Instance.new("Frame")
	canal.Name, canal.Size, canal.BackgroundTransparency = "Aprovacao", UDim2.fromScale(1, 1), 1
	canal.Parent = gui
	local visual = T.arvore(identidade.arvore)
	C.aviso({ parent = canal, tipo = "sucesso", titulo = "Aprovado!", icone = visual.selo, corDestaque = visual.cor, destaque = true,
		detalhe = identidade.nome .. " · 1 dia de treino\n" .. (mensagem or ""), duracao = 6 })
	task.delay(6 + T.tween * 3, function() canal:Destroy() end)
end
return E
