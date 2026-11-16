-- IMP2: golpe colado na parede. Atacante e alvo a ~54 studs do centro do tabuleiro (a parede do esgoto fica em ~64;
-- o raycast não a enxerga, CanQuery=false, então a câmera usa a caixa da sala). Confere que a câmera do golpe
-- (escolhida e misturada) fica dentro da caixa e que trocou de lado/encurtou em vez de colar nos lutadores.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local B = require(Shared.MesaProtocol).BOARD
local IC = require(Players.LocalPlayer.PlayerScripts:FindFirstChild("ImpactoCamera", true))
local meia = B.width * B.cell / 2 + 8
local de = Vector3.new(B.origin.X + 54, B.origin.Y + 2, B.origin.Z + 5)
local para = de + Vector3.new(0, 0, 3)
local cfBase = CFrame.lookAt(Vector3.new(B.origin.X + 54, B.origin.Y + 20, B.origin.Z + 30), de) -- câmera de partida do lado da parede
IC.golpe(de, para, 0.3)
local saida = {}
local estado
for _, t in { 0.35, 0.3 } do
	task.wait(t)
	local cf = IC.aplicar(cfBase)
	estado = IC.estado()
	local dentro = math.abs(cf.Position.X - B.origin.X) <= meia + 0.01 and math.abs(cf.Position.Z - B.origin.Z) <= meia + 0.01
	table.insert(saida, string.format("cam=(%.1f,%.1f,%.1f) dentroDaSala=%s peso=%.2f", cf.Position.X, cf.Position.Y, cf.Position.Z, tostring(dentro), IC.peso()))
end
local e = estado and estado.escolha
-- deixa a câmera real do jogo no mesmo enquadramento por 1 s para a captura
return string.format("caixa meia=%.0f | lutadores x=+54 | folga=%s escolha=%s | %s", meia, tostring(estado and estado.folga),
	e and string.format("lado %.0f abre %.2f escala %.2f", e[1], e[2], e[3]) or "?", table.concat(saida, " | "))
