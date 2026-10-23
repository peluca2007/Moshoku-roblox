-- Corpo real na primeira pessoa e alcance suave dos braços, só durante o lobby.
-- Cada cliente apresenta o mesmo gesto a partir das mãos confirmadas no snapshot.
local Players=game:GetService("Players")
local O=require(script.Parent.SalaObjetos)
local Efeitos=require(script.Parent.Efeitos)
local C={}
function C.new(pasta,listarJogadores)
	local caches={};local localPlayer=Players.LocalPlayer;local api={}
	local function cache(char)
		if caches[char] then return caches[char] end
		local r={juntas={},partes={},alpha=0,papel=nil,bracos=nil}
		local function adicionar(d)
			if d:IsA("BasePart") then r.partes[d]=d.LocalTransparencyModifier end
			local nome=d.Name:gsub(" ","")
			if nome=="Neck" or nome=="RightShoulder" or nome=="LeftShoulder" or nome=="RightElbow" then
				if d:IsA("Motor6D") then r.juntas[nome]={obj=d,key="C0",base=d.C0}
				elseif d:IsA("AnimationConstraint") and d.Attachment0 then r.juntas[nome]={obj=d.Attachment0,key="CFrame",base=d.Attachment0.CFrame,final=d.Attachment1} end
			end
		end
		for _,d in char:GetDescendants() do adicionar(d) end
		r.con=char.DescendantAdded:Connect(adicionar);caches[char]=r;return r
	end
	local function junta(r,nome,alvo)
		local j=r.juntas[nome];if j and j.obj.Parent then j.obj[j.key]=j.base*alvo end
	end
	local function cabeca(p,char)
		if p.Name=="Head" or p.Name=="HumanoidRootPart" then return true end
		local ac=p:FindFirstAncestorWhichIsA("Accessory")
		local head=char:FindFirstChild("Head")
		if ac and head then
			for _,a in p:GetChildren() do if a:IsA("Attachment") and head:FindFirstChild(a.Name) then return true end end
		end
		return false
	end
	function api.atualizar(sala,dt,papel)
		for _,p in (if listarJogadores then listarJogadores() else Players:GetPlayers()) do
			local char=p.Character;if not char then continue end
			local r=cache(char);local mao=sala.maos[p.UserId] or sala.maos[tostring(p.UserId)]
			r.alpha+=( (if mao then 1 else 0)-r.alpha)*math.min(1,dt*12)
			junta(r,"Neck",CFrame.Angles(char:GetAttribute("SalaOlharX") or 0,char:GetAttribute("SalaOlharY") or 0,0))
			local root=char:FindFirstChild("HumanoidRootPart")
			local cf=if p==localPlayer then workspace.CurrentCamera.CFrame elseif root then root.CFrame*CFrame.new(0,1.4,0)*CFrame.Angles(char:GetAttribute("SalaOlharX") or 0,char:GetAttribute("SalaOlharY") or 0,0) else char:GetPivot()
			local alvoDireito=if p==localPlayer and papel then papel.CFrame:PointToWorldSpace(Vector3.new(-papel.Size.X*.52,-papel.Size.Y*.62,.04)) else cf:PointToWorldSpace(Vector3.new(.8,-.8,-1.6))
			local alvoEsquerdo=if p==localPlayer and papel then papel.CFrame:PointToWorldSpace(Vector3.new(papel.Size.X*.52,-papel.Size.Y*.62,.04)) else cf:PointToWorldSpace(Vector3.new(-.4,-1.1,-1.25))
			local fisico=mao=="dados-brotos" or (type(mao)=="string" and mao:sub(1,8)=="jogador:")
			if fisico then
				local alvo
				if mao=="dados-brotos" then local folder=workspace:FindFirstChild("SalaDadosFisicos");local m=if p==localPlayer then workspace:FindFirstChild("SalaDadosEmMaos") else folder and folder:FindFirstChild("Dados_"..p.UserId);alvo=m and (p==localPlayer or m:GetAttribute("EmMaos")) and m:FindFirstChild("Dado2")
				else local other=Players:GetPlayerByUserId(tonumber(mao:sub(9)) or 0);alvo=other and other.Character and other.Character:FindFirstChild("HumanoidRootPart") end
				if alvo then
					local escala=if mao=="dados-brotos" then alvo.Size.X/.48 else 1
					local baixo=if mao=="dados-brotos" then cf.UpVector*-.45*escala+cf.LookVector*.1 else Vector3.zero
					local lado=cf.RightVector*(if mao=="dados-brotos" then 1.05*escala else .65)
					alvoDireito=alvo.Position+lado+baixo;alvoEsquerdo=alvo.Position-lado+baixo
				end
			end

			if p==localPlayer then
				Efeitos.offsetCamera(Vector3.new(0,.12,-.65))
				for part in r.partes do if part.Parent then part.LocalTransparencyModifier=if cabeca(part,char) then 1 else 0 end end
			end
			if mao and not r.bracos then r.bracos=require(script.Parent.SalaBracos).new(char,pasta,p==localPlayer) end
			local maoVisual=r.bracos and r.bracos.atualizar(alvoDireito,alvoEsquerdo,r.alpha)
			if p~=localPlayer then
				local hand=char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
				if mao and not fisico and hand then
					if not r.papel then local papel,g=O.papel(pasta,"PapelDoJogador"..p.UserId,CFrame.new());O.texto(g,"MOSHOKU\nFicha de personagem",UDim2.fromScale(.08,.08),UDim2.fromScale(.84,.7),45);r.papel=papel end
					local livro=require(game.ReplicatedStorage.Shared.SalaItens).livros[mao]
					r.papel.Size=if livro then Vector3.new(1.65,2.3,.24) else Vector3.new(1.65,2.3,.025)
					r.papel.Color=if livro then Color3.fromRGB(unpack(livro.cor)) else Color3.fromRGB(239,225,190)
					r.papel.CFrame=(maoVisual or hand.CFrame)*CFrame.new(-.4,-.25,-.6)*CFrame.Angles(.35,0,0)
				elseif r.papel then r.papel:Destroy();r.papel=nil end
			end
		end
		for char,r in caches do if not char.Parent then if r.papel then r.papel:Destroy() end;if r.bracos then r.bracos.destruir() end;r.con:Disconnect();caches[char]=nil end end
	end
	function api.restaurar()
		Efeitos.offsetCamera(Vector3.zero)
		for _,r in caches do
			if r.bracos then r.bracos.destruir() end
			for _,j in r.juntas do if j.obj.Parent then j.obj[j.key]=j.base end end
			for p,valor in r.partes do if p.Parent then p.LocalTransparencyModifier=valor end end
			if r.papel then r.papel:Destroy() end;r.con:Disconnect()
		end
		table.clear(caches)
	end
	return api
end
return C
