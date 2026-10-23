local p = game.Players.LocalPlayer
local canal = game.ReplicatedStorage.G4Teste.Canal
local r = { linhas = {}, falhas = 0, envios = {}, callbacks = {} }
shared.G4 = r
function r.check(nome, ok)
	table.insert(r.linhas, (if ok then "OK " else "FALHA ")..nome)
	if not ok then r.falhas += 1 end
end
local state = {
	send = function(k, d) table.insert(r.envios, { kind = k, dados = d }); canal:FireServer(k, d) end,
	onSnapshot = function(f) table.insert(r.callbacks, f) end,
}
function r.mostrar(id, prazo, quantidade, longo)
	local opcoes = {}
	for i = 1, quantidade do
		table.insert(opcoes, { id = "opcao"..i, nome = "Defesa "..i,
			detalhe = if longo then string.rep("Protege o aliado, custa 2 PM e reduz o dano conforme a técnica. ", 5) else "2 PM: protege o aliado." })
	end
	canal:FireServer("visual", { id = id, texto = if longo then string.rep("Uma ameaça se aproxima. Escolha como responder. ", 3) else "Escolha sua resposta.", opcoes = opcoes, prazo = prazo })
	task.wait(.4)
end
function r.fechar(id) canal:FireServer("visual", { id = id, fechar = true }); task.wait(.2) end
function r.recriar()
	r.gui = require(p.PlayerScripts.Client.ReacaoView).start(state, canal); r.gui.Name = "G4ReacaoTeste"
end
r.recriar()
local caixaGui = Instance.new("ScreenGui"); caixaGui.Name = "G4DigitarTeste"; caixaGui.DisplayOrder = 40; caixaGui.Parent = p.PlayerGui
local caixa = Instance.new("TextBox"); caixa.Name = "ChatSimulado"; caixa.Size = UDim2.fromOffset(200,44); caixa.Position = UDim2.fromOffset(8,200); caixa.Visible = false; caixa.Parent = caixaGui
r.digitar, r.caixaGui = caixa, caixaGui
return "Cliente G4 pronto"
