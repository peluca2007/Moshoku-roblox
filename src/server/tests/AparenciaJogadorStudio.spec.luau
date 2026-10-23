-- SOMENTE STUDIO: usa Instances, HumanoidDescription e soldas reais.
local Server=game:GetService("ServerScriptService").Server
local Shared=game:GetService("ReplicatedStorage").Shared
local S=require(Server.AparenciaJogador)
local A=require(Shared.Aparencia.Aparencia)

local function criarR15()
	local m=Instance.new("Model"); m.Name="AparenciaSpec"
	for _,nome in {"Head","UpperTorso","LowerTorso","LeftArm","RightArm","LeftLeg","RightLeg","LeftFoot","RightFoot","RightHand"} do
		local p=Instance.new("Part"); p.Name=nome; p.Size=Vector3.new(2,1,1); p.Parent=m
	end
	local hum=Instance.new("Humanoid"); hum.Parent=m
	return m
end
local function possuidos(a)
	local p={}; for _,id in a.roupas do p[id]=true end; return p
end
local function deps(opts)
	local agora=0; local perfil={construcao={raceId="race/humano"},aparencia=A.padrao("race/humano",2)}
	local contexto=true; local combate=false; local conta={obter=function() return opts and opts.conta or {cosmeticos={}} end}
	local d={autenticado=function(p) return not (opts and opts.naoAutenticado) end,relogio=function() agora+=1; return agora end,
		emCombate=function() return combate end,contexto=function() return contexto end,consultar=function() return perfil end,conta=if opts and opts.conta then opts.conta else conta,
		alterar=function(_,a,poss,autorizado) if opts and opts.mudarContextoNoAlterar then contexto=false end; if not autorizado() then return false,"contexto mudou" end; perfil.aparencia=a; return true,"salvo" end}
	return S.criarHandler(d),function(v) contexto=v end,function(v) combate=v end,function() return perfil end,function(v) agora=v end
end

return {
	["descrição R15 remove roupa e acessórios e aplica escalas raciais"] = function(t)
		local a=A.padrao("race/anao",123); local d=S.descrever(a,"race/anao")
		for _,k in {"Head","Torso","LeftArm","RightArm","LeftLeg","RightLeg","Face","Shirt","Pants","GraphicTShirt"} do t.eq(d[k],0,k) end
		for _,k in {"HatAccessory","HairAccessory","FaceAccessory","NeckAccessory","ShouldersAccessory","FrontAccessory","BackAccessory","WaistAccessory"} do t.eq(d[k],"",k) end
		-- propriedades do Humanoid são float32: compara com tolerância
		for k,v in {HeightScale=0.85,WidthScale=1.12,DepthScale=1.1,HeadScale=0.95} do t.ok(math.abs(d[k]-v)<1e-4,k) end
		 t.eq(d.BodyTypeScale,0); t.eq(d.ProportionScale,0)
		d:Destroy()
	end,
	["decorar duas vezes deixa uma pasta, remove face e malha e solda rosto sem colisão/massa"] = function(t)
		local m=criarR15(); local head=m.Head
		local decal=Instance.new("Decal"); decal.Name="face"; decal.Parent=head
		local mesh=Instance.new("SpecialMesh"); mesh.Parent=head
		local a=A.padrao("race/humano",23); a.cabelo="CabeloNenhum"; a.barba="BarbaNenhum"
		S.decorar(m,a,"race/humano"); S.decorar(m,a,"race/humano")
		local pastas=0; for _,x in m:GetChildren() do if x.Name=="AparenciaMoshoku" then pastas+=1 end end
		t.eq(pastas,1); t.eq(head.Size,Vector3.new(1,1,1)); t.eq(head:FindFirstChild("face"),nil); t.eq(head:FindFirstChildOfClass("SpecialMesh"),nil)
		local p=m.AparenciaMoshoku; local total=0
		for _,x in p:GetDescendants() do if x:IsA("BasePart") then total+=1; t.eq(x.Anchored,false); t.eq(x.CanCollide,false); t.eq(x.CanQuery,false); t.eq(x.CanTouch,false); t.eq(x.Massless,true); t.ok(x:FindFirstChildOfClass("WeldConstraint")~=nil) end end
		t.ok(total>0); m:Destroy()
	end,
	["handler exige autenticação contexto fora de combate e limita frequência"] = function(t)
		local h,setContext,setCombat,_,setClock=deps(); local p={UserId=901}; local valid=A.padrao("race/humano",3)
		setContext(false); local ok=h(p,{acao="consultar"}); t.eq(ok,false)
		setContext(true); setCombat(true); ok=h(p,{acao="consultar"}); t.eq(ok,false)
		setCombat(false); local ok=h(p,{acao="salvar",aparencia=valid}); t.eq(ok,true)
		setClock(2.4); local rapido,motivo=h(p,{acao="consultar"}); t.eq(rapido,false); t.eq(motivo,"Aguarde.")
	end,
	["handler rejeita payloads inválidos posse ausente falha de conta e contexto mutável durante salvar"] = function(t)
		local h=deps({naoAutenticado=true}); local ok=h({UserId=902},{acao="consultar"}); t.eq(ok,false)
		h=deps(); local p={UserId=903}; ok=h(p,setmetatable({acao="consultar"},{})); t.eq(ok,false)
		ok=h(p,{acao="salvar",aparencia=A.padrao("race/humano",1),surpresa=true}); t.eq(ok,false)
		local rara=A.padrao("race/humano",1); rara.roupas={costas="LadinoCapa"}; ok=h(p,{acao="salvar",aparencia=rara}); t.eq(ok,false)
		local comPosse=deps({conta={obter=function() return {cosmeticos={LadinoCapa=true}} end}}); ok=comPosse(p,{acao="salvar",aparencia=rara}); t.eq(ok,true)
		local falha=deps({conta={obter=function() return nil end}}); ok=falha(p,{acao="consultar"}); t.eq(ok,false)
		local mutavel=deps({mudarContextoNoAlterar=true}); local ok,why=mutavel(p,{acao="salvar",aparencia=A.padrao("race/humano",5)}); t.eq(ok,false); t.eq(why,"contexto mudou")
	end,
}
