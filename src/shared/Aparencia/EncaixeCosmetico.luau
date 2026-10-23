-- Montagem comum de cosméticos em rigs R15; dados opcionais, sem autoridade de regra.
local Montar = require(script.Parent.MontarModelo)
local Encaixe = {}
function Encaixe.configurarPecas(modelo: Model, alvo: BasePart, modulo: string)
	for _, objeto in modelo:GetDescendants() do
		if objeto:IsA("BasePart") then
			objeto.Anchored = false
			objeto.CanCollide = false
			objeto.CanQuery = false
			objeto.CanTouch = false
			objeto.Massless = true
			local solda = Instance.new("WeldConstraint")
			solda.Part0 = alvo
			solda.Part1 = objeto
			solda.Parent = objeto
			local orbe = if objeto.Name == "Orbe" then objeto else objeto:FindFirstAncestor("Orbe")
			local gota = if objeto.Name == "Gota" then objeto else objeto:FindFirstAncestor("Gota")
			if orbe then
				objeto.Material = Enum.Material.Neon
				if modulo == "MestraCajado" then
					local temLuz = orbe:FindFirstChild("BrilhoOrbe", true) ~= nil
					if not temLuz then
						local luz = Instance.new("PointLight")
						luz.Name = "BrilhoOrbe"
						luz.Color = Color3.fromRGB(110, 226, 240)
						luz.Brightness = 0.35
						luz.Range = 8
						luz.Shadows = false
						luz.Parent = objeto
					end
				end
			elseif gota then
				objeto.Material = Enum.Material.Glass
			elseif objeto.Name == "Ferro" or string.find(string.lower(objeto.Name), "lamina", 1, true) or string.find(string.lower(objeto.Name), "lâmina", 1, true) then
				objeto.Material = Enum.Material.Metal
			elseif string.find(string.lower(objeto.Name), "dourad", 1, true) or string.find(string.lower(objeto.Name), "ouro", 1, true) then
				objeto.Material = Enum.Material.SmoothPlastic
				objeto.Reflectance = 0.1
			else
				objeto.Material = Enum.Material.SmoothPlastic
			end
		end
	end
end

function Encaixe.montar(corpo, contrato, pai, escala, cor)
 local alvo = corpo:FindFirstChild(contrato.parte)
 if not alvo or not alvo:IsA("BasePart") or not Montar.existe(contrato.modulo) then return nil end
 local e = escala or 1
 local offset = contrato.offset or CFrame.new()
 if type(offset) == "table" then offset = CFrame.new(offset[1] or offset.x or 0, offset[2] or offset.y or 0, offset[3] or offset.z or 0) end
 local modelo = Montar.montar(contrato.modulo, pai or corpo, alvo.CFrame * offset, e)
 Encaixe.configurarPecas(modelo, alvo, contrato.modulo)
 if cor then
  for _, p in modelo:GetDescendants() do if p:IsA("BasePart") then p.Color = cor end end
 end
 return modelo
end
return Encaixe
