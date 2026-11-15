-- Barras de vida finas sobre cada combatente (LUTA-B): inimigos em vermelho, aliados em verde; o nome
-- só de quem age ou está selecionado; marcadores pequenos de condição ao lado. Posição de tela
-- calculada a partir da casa do token (MesaProtocol.cellCenter). Só lê o snapshot.
-- Enquanto a luta durar, esconde o rótulo+barra antigos do BoardView (BillboardGui com "BarraPV"),
-- para não duplicar; ao fim da luta eles voltam.
-- Instances: ScreenGui "BarrasLuta" > <tokenId> > Nome | Trilho > Cheio | Marcas.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Protocol = require(Shared:WaitForChild("MesaProtocol"))
local T = require(script.Parent.UI.Tema)

local Barras = {}

-- Abreviação curta da condição para o marcador ("em-chamas" -> "Em ").
function Barras.marca(id: string): string
	local limpo = string.gsub(id, "[-_]", " ")
	return string.upper(string.sub(limpo, 1, 1)) .. string.sub(limpo, 2, 3)
end

function Barras.start(state)
	local jogador = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.DisplayOrder, gui.IgnoreGuiInset = "BarrasLuta", false, 3, true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = jogador:WaitForChild("PlayerGui")
	local itens: { [string]: any } = {}
	local escondidos, ultimaContagem = false, -1

	local function criar(id: string)
		local raiz = Instance.new("Frame")
		raiz.Name, raiz.AnchorPoint, raiz.Size, raiz.BackgroundTransparency = id, Vector2.new(0.5, 1), UDim2.fromOffset(72, 40), 1
		raiz.Parent = gui
		local nome = Instance.new("TextLabel")
		nome.Name, nome.BackgroundTransparency, nome.Size = "Nome", 1, UDim2.new(1, 60, 0, 18)
		nome.Position, nome.AnchorPoint = UDim2.fromScale(0.5, 0), Vector2.new(0.5, 0)
		nome.FontFace, nome.TextSize, nome.TextColor3 = T.fontes.titulo, 16, T.sobreEscuro.texto
		nome.TextStrokeColor3, nome.TextStrokeTransparency, nome.TextTruncate = T.cores.fundoTela, 0.15, Enum.TextTruncate.AtEnd
		nome.Parent = raiz
		local trilho = Instance.new("Frame")
		trilho.Name, trilho.Position, trilho.Size = "Trilho", UDim2.fromOffset(0, 22), UDim2.new(1, 0, 0, 6)
		trilho.BackgroundColor3, trilho.BackgroundTransparency, trilho.BorderSizePixel = T.cores.fio, 0.25, 0
		trilho.Parent = raiz
		Instance.new("UICorner", trilho).CornerRadius = UDim.new(1, 0)
		local cheio = Instance.new("Frame")
		cheio.Name, cheio.Size, cheio.BorderSizePixel = "Cheio", UDim2.fromScale(1, 1), 0
		cheio.Parent = trilho
		Instance.new("UICorner", cheio).CornerRadius = UDim.new(1, 0)
		local marcas = Instance.new("Frame")
		marcas.Name, marcas.Position, marcas.Size, marcas.BackgroundTransparency = "Marcas", UDim2.new(1, 6, 0, 16), UDim2.fromOffset(120, 18), 1
		marcas.Parent = raiz
		local lista = Instance.new("UIListLayout")
		lista.FillDirection, lista.Padding = Enum.FillDirection.Horizontal, UDim.new(0, 3)
		lista.Parent = marcas
		local item = { raiz = raiz, nome = nome, cheio = cheio, marcas = marcas, assinatura = "" }
		itens[id] = item
		return item
	end

	local function marcarBillboards(esconder: boolean)
		if esconder == escondidos then return end
		escondidos = esconder
		for _, d in workspace:GetDescendants() do
			if d:IsA("BillboardGui") and d:FindFirstChild("BarraPV") then d.Enabled = not esconder end
		end
	end

	RunService.RenderStepped:Connect(function()
		local snap = state.snapshot()
		if not snap or not snap.combat.active then
			if next(itens) then
				for id, item in itens do item.raiz:Destroy(); itens[id] = nil end
			end
			marcarBillboards(false)
			ultimaContagem = -1
			return
		end
		if #snap.tokens ~= ultimaContagem then
			ultimaContagem = #snap.tokens
			escondidos = false -- token novo pode ter trazido um billboard novo
		end
		marcarBillboards(true)
		local cam = workspace.CurrentCamera
		local selecionado = state.selectedToken()
		local vistos = {}
		for _, t in snap.tokens do
			local caido = t.derrotado or (t.pv ~= nil and t.pv <= 0)
			if not t.hidden and not caido and t.x and t.z and t.pv ~= nil and (t.pvMax or 0) > 0 then
				local p, visivel = cam:WorldToViewportPoint(Protocol.cellCenter(t.x, t.z) + Vector3.new(0, 6.2, 0))
				local item = itens[t.id] or criar(t.id)
				vistos[t.id] = true
				item.raiz.Visible = visivel and p.Z > 0
				if item.raiz.Visible then
					item.raiz.Position = UDim2.fromOffset(p.X, p.Y)
					local r = math.clamp(t.pv / t.pvMax, 0, 1)
					item.cheio.Size = UDim2.fromScale(r, 1)
					item.cheio.BackgroundColor3 = if t.criatura then T.barras.baixa else T.barras.cheia
					local destaque = snap.combat.turnId == t.id or selecionado == t.id
					item.nome.Visible = destaque
					if destaque then item.nome.Text = t.name end
					local ids = {}
					for _, c in t.conditions or {} do table.insert(ids, c.id) end
					local assinatura = table.concat(ids, "|")
					if assinatura ~= item.assinatura then
						item.assinatura = assinatura
						for _, f in item.marcas:GetChildren() do if f:IsA("TextLabel") then f:Destroy() end end
						for i, id in ids do
							if i > 3 then break end
							local chip = Instance.new("TextLabel")
							chip.Name, chip.Text, chip.AutomaticSize, chip.Size = "Marca", Barras.marca(id), Enum.AutomaticSize.X, UDim2.fromOffset(0, 18)
							chip.BackgroundColor3, chip.TextColor3, chip.FontFace, chip.TextSize = T.cores.painel, T.cores.texto, T.fontes.rotulo, 14
							chip.LayoutOrder = i
							Instance.new("UICorner", chip).CornerRadius = UDim.new(0, 4)
							local pad = Instance.new("UIPadding", chip)
							pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 4), UDim.new(0, 4)
							chip.Parent = item.marcas
						end
					end
				end
			end
		end
		for id, item in itens do
			if not vistos[id] then item.raiz:Destroy(); itens[id] = nil end
		end
	end)
	return gui
end

return Barras
