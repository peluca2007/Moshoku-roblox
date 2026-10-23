-- Objetos já confirmados pelo servidor; recolher continua sendo uma intenção.
local Protocol = require(game.ReplicatedStorage.Shared.MesaProtocol)
local Estilo = require(game.ReplicatedStorage.Shared.Estilo)
local A = {}
function A.start()
	local folder = Instance.new("Folder", workspace); folder.Name = "ArmasNoChao"
	local vistos = {}
	local function criar(id)
		local m = Instance.new("Model"); m.Name = id
		local partes = {}
		for _, d in {
			{"Lamina", Vector3.new(.35, .15, 2.8), CFrame.new(0,0,-.7), Color3.fromRGB(202,213,230)},
			{"Guarda", Vector3.new(1.2,.22,.2), CFrame.new(0,0,.8), Estilo.ALERTA},
			{"Cabo", Vector3.new(.3,.25,1), CFrame.new(0,0,1.4), Color3.fromRGB(85,53,35)},
		} do
			local p = Instance.new("Part")
			p.Name, p.Size, p.Color, p.Material = d[1], d[2], d[4], Enum.Material.Metal
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
			p.Parent = m; table.insert(partes, {p, d[3]})
		end
		m.PrimaryPart = partes[1][1]
		local gui = Instance.new("BillboardGui", m.PrimaryPart)
		gui.Size, gui.StudsOffset, gui.AlwaysOnTop = UDim2.fromOffset(190,40), Vector3.new(0,1.6,0), true
		local label = Instance.new("TextLabel", gui)
		label.Size, label.BackgroundTransparency, label.TextColor3 = UDim2.fromScale(1,1), .2, Estilo.TINTA
		label.BackgroundColor3, label.TextSize, label.FontFace = Estilo.PAPEL, 14, Estilo.ROTULO_FORTE
		label.Text = "Arma no chão\nPegar arma • 1 Ação"
		m.Parent = folder
		return {modelo=m, partes=partes}
	end
	local api = {}
	function api.render(lista)
		local vivos = {}
		for _, o in lista or {} do
			vivos[o.id] = true
			local v = vistos[o.id] or criar(o.id); vistos[o.id] = v
			local base = CFrame.new(Protocol.cellCenter(o.x,o.z) + Vector3.new(0,.3,0)) * CFrame.Angles(0, .6, 0)
			for _, p in v.partes do p[1].CFrame = base * p[2] end
		end
		for id, v in vistos do if not vivos[id] then v.modelo:Destroy(); vistos[id] = nil end end
	end
	return api
end
return A
