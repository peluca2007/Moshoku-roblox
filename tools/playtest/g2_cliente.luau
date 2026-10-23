local p = game.Players.LocalPlayer
local R = { linhas = {}, falhas = 0 }
shared.G2 = R
function R.check(n, b)
	table.insert(R.linhas, (if b then "OK " else "FALHA ") .. n)
	if not b then R.falhas += 1 end
end
local tokens, ordem = {}, {}
for i = 1, 32 do
	local id = "g2_"..i
	table.insert(ordem, id)
	table.insert(tokens, { id = id, name = "Aventureiro "..i, kind = "jogador", pv = 25, pvMax = 40,
		mana = 6, manaMax = 12, pt = 2, ptMax = 3, ownerUserId = if i == 20 then p.UserId else -i })
end
local snap = { tokens = tokens, combat = { active = true, order = ordem, turnId = "g2_20" } }
local callbacks = {}
local state = { snapshot = function() return snap end, onSnapshot = function(f) table.insert(callbacks, f) end }
function R.atualizar() for _, f in callbacks do f(snap) end; task.wait(.4) end
local menu = p.PlayerGui.InicioJogo.MenuInicial
R.menu, R.menuAnterior = menu, menu.Visible; menu.Visible = false
local g = require(p.PlayerScripts.Client.Hud).start(state); g.Name = "G2HudTeste"
R.gui, R.snap = g, snap
task.wait(.5)
R.check("snapshot inicial aparece sem novo evento", g.Ordem.Visible and g.Cartao.Visible)
R.check("32 participantes acessiveis", #g.Ordem:GetChildren() == 35)
R.check("ator atual primeiro", g.Ordem.g2_20.LayoutOrder == 1 and g.Ordem.g2_20.Vez.Text == "AGORA")
R.check("proximo explicito", g.Ordem.g2_21.LayoutOrder == 2 and g.Ordem.g2_21.Vez.Text == "DEPOIS")
R.check("volta da iniciativa preservada", g.Ordem.g2_1.LayoutOrder == 14)
R.check("fila limitada a janela", g.Ordem.AbsolutePosition.X >= 0 and g.Ordem.AbsolutePosition.X + g.Ordem.AbsoluteSize.X <= g.AbsoluteSize.X)
R.check("conteudo longo tem canvas navegavel", g.Ordem.AbsoluteCanvasSize.X > g.Ordem.AbsoluteSize.X)
g.Ordem.CanvasPosition = Vector2.new(600, 0); task.wait(.2)
R.check("rolagem alcanca outros participantes", g.Ordem.CanvasPosition.X > 0)
tokens[20].pv = 24; R.atualizar()
R.check("atualizar recurso preserva navegacao", g.Ordem.CanvasPosition.X > 0)
snap.combat.turnId = "g2_21"; R.atualizar()
R.check("novo turno volta ao ator atual", g.Ordem.CanvasPosition.X == 0 and g.Ordem.g2_21.LayoutOrder == 1)
R.check("ator anterior perde agora", g.Ordem.g2_20.Vez.Text ~= "AGORA")
table.remove(tokens, 21); R.atualizar()
R.check("ator oculto nao gera ficha", g.Ordem:FindFirstChild("g2_21") == nil)
R.check("proximo visivel nao finge ser ator atual", g.Ordem.g2_22.LayoutOrder == 1 and g.Ordem.g2_22.Vez.Text == "PRÓXIMO VISÍVEL")
snap.combat.turnId = "g2_20"; R.atualizar()
g.Ordem.UISizeConstraint.MaxSize = Vector2.new(375, 52); task.wait(.5)
R.check("fila compacta cabe em 375 px", g.Ordem.AbsoluteSize.X <= 375)
R.check("cartas compactas", g.Ordem.g2_20.AbsoluteSize.X == 104)
R.check("instrucao de rolagem visivel", string.find(g.Prazo.Text, "deslize", 1, true) ~= nil and g.Prazo.TextFits)
snap.encontro = { prazoFim = workspace:GetServerTimeNow() + 8, prazoId = "g2_20" }; task.wait(.4)
R.check("contador real do snapshot preservado", string.find(g.Prazo.Text, "SUA VEZ", 1, true) ~= nil)
R.check("urgencia final preservada", g.Prazo.TextColor3 == require(game.ReplicatedStorage.Shared.Estilo).PERIGO)
snap.encontro = nil
return "G2 preparado: "..#R.linhas.." verificações"
