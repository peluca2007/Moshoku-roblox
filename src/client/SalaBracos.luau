-- Braços de apresentação copiados do avatar. Funciona também com rigs físicos
-- cujas AnimationConstraints não seguem mudanças locais de Motor6D/IK.
local B={}
function B.new(char,pasta,primeiraPessoa)
	local modelo=Instance.new("Model");modelo.Name="Bracos_"..char.Name;modelo.Parent=pasta
	local hum=Instance.new("Humanoid");hum.RequiresNeck=false;hum.EvaluateStateMachine=false;hum.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None;hum.Parent=modelo
	for _,c in char:GetChildren() do if c:IsA("Shirt") or c:IsA("Pants") or c:IsA("BodyColors") then c:Clone().Parent=modelo end end
	local lados={};local originais={}
	local function limpar(lado)
		for _,o in lados[lado] or {} do
			if o.real.Parent then o.real.LocalTransparencyModifier=originais[o.real] or 0 end
			originais[o.real]=nil;o.copia:Destroy()
		end
		lados[lado]={}
	end
	local function montar(lado)
		local reais={char:FindFirstChild(lado.."UpperArm"),char:FindFirstChild(lado.."LowerArm"),char:FindFirstChild(lado.."Hand")}
		if not (reais[1] and reais[2] and reais[3]) then
			local r6=char:FindFirstChild(lado.." Arm");if not r6 then return end;reais={r6}
		end
		local r={}
		for _,real in reais do
			local archivable=real.Archivable;real.Archivable=true;local copia=real:Clone();real.Archivable=archivable
			for _,d in copia:GetDescendants() do if d:IsA("JointInstance") or d:IsA("Constraint") or d:IsA("LuaSourceContainer") then d:Destroy() end end
			copia.Anchored=true;copia.CanCollide=false;copia.CanTouch=false;copia.CanQuery=false;copia.CastShadow=false;copia.LocalTransparencyModifier=0;copia.Transparency=1;copia.Parent=modelo
			table.insert(r,{real=real,copia=copia});originais[real]=real.LocalTransparencyModifier
		end
		lados[lado]=r
	end
	for _,lado in {"Right","Left"} do lados[lado]={};montar(lado) end
	local api={}
	local function segmento(a,b) return CFrame.lookAt((a+b)/2,b)*CFrame.Angles(math.pi/2,0,0) end
	function api.atualizar(direito,esquerdo,alpha)
		local resultado={}
		for lado,r in lados do
			local valido=true;for _,o in r do if not o.real:IsDescendantOf(char) then valido=false;break end end
			if not valido then limpar(lado);r=lados[lado] end
			if #r==0 then montar(lado);r=lados[lado] end
			if #r==0 then continue end
			local alvo=if lado=="Right" then direito else esquerdo
			local upper=r[1].real
			local origem=upper.CFrame:PointToWorldSpace(Vector3.new(0,upper.Size.Y/2,0))
			local delta=alvo-origem;local distancia=math.max(.01,delta.Magnitude);local dir=if delta.Magnitude<.01 then -upper.CFrame.UpVector else delta.Unit
			local u=upper.Size.Y;local l=if #r==3 then r[2].real.Size.Y+r[3].real.Size.Y*.5 else 0
			local escala=math.clamp(distancia/math.max(.1,u+l-.025),1,1.65);u*=escala;l*=escala
			local fim=origem+dir*math.min(distancia,math.max(.1,u+l-.025))
			local frames={}
			if #r==3 then
				local d=(fim-origem).Magnitude;local a=math.clamp((u*u-l*l+d*d)/(2*d),0,u)
				local pole=Vector3.new(0,-1,0)-dir*dir:Dot(Vector3.new(0,-1,0));if pole.Magnitude<.01 then pole=Vector3.xAxis end
				local cotovelo=origem+dir*a+pole.Unit*math.sqrt(math.max(0,u*u-a*a))
				local frente=(fim-cotovelo).Unit;local pulso=cotovelo+frente*r[2].real.Size.Y*escala
				frames[1]=segmento(origem,cotovelo);frames[2]=segmento(cotovelo,pulso);frames[3]=segmento(pulso,pulso+frente*r[3].real.Size.Y*escala)
			else frames[1]=segmento(origem,fim) end
			for i,o in r do
				local largura=if primeiraPessoa then .58 else 1
				o.copia.Size=o.real.Size*Vector3.new(largura,1+(escala-1)*alpha,largura)
				o.copia.Color=o.real.Color;o.copia.Material=o.real.Material
				o.copia.CFrame=o.real.CFrame:Lerp(frames[i],alpha);o.copia.Transparency=1-(1-o.real.Transparency)*alpha
				o.real.LocalTransparencyModifier=if alpha>.01 then 1 else originais[o.real]
			end
			resultado[lado]=r[#r].copia.CFrame
		end
		return resultado.Right
	end
	function api.destruir()
		for p,v in originais do if p.Parent then p.LocalTransparencyModifier=v end end;modelo:Destroy()
	end
	return api
end
return B
