-- SOMENTE STUDIO: física, autoridade, soltura/limpeza de jogadores e faces dos dados.
local S=script.Parent.Parent
local D=require(S.SalaDados);local C=require(S.SalaCarregarJogadores);local Modelo=require(S.DadosModelo)
local function fixture(fn)
	local pasta=Instance.new("Folder");pasta.Name="G15Fixture";pasta.Parent=workspace
	local f={pasta=pasta,maos={},tempo=0,bloqueado=false,rolagens=0,mudancas=0,jogadores={}}
	for id=1,3 do
		local char=Instance.new("Model");char.Name="Teste"..id;char.Parent=pasta
		local root=Instance.new("Part");root.Name="HumanoidRootPart";root.CanCollide=true;root.CFrame=CFrame.new(237+id*2,8,12);root.Parent=char
		local h=Instance.new("Humanoid");h.RequiresNeck=false;h.Parent=char
		f.jogadores[id]={UserId=id,Character=char}
	end
	f.deps={parent=pasta,maos=f.maos,agora=function() return f.tempo end,permitido=function() return if f.bloqueado then "bloqueado" else nil end,jogador=function(id) return f.jogadores[id] end,jogadores=function() return f.jogadores end,mudou=function() f.mudancas+=1 end,rolar=function() f.rolagens+=1;return {2,4,6} end}
	f.dados=D.new(f.deps);f.carregar=C.new(f.deps)
	local ok,erro=pcall(fn,f);f.carregar.arrumar();f.dados.destruir();pasta:Destroy();if not ok then error(erro,0) end
end
local function root(p) return p.Character.HumanoidRootPart end
local tiro={direcao={x=0,y=.1,z=1},forca=.6}
return {
	["todas as faces pousadas mostram o resultado autoritativo para cima"]=function(t)
		local faces={Vector3.yAxis,-Vector3.zAxis,-Vector3.xAxis,Vector3.xAxis,Vector3.zAxis,-Vector3.yAxis}
		for i,v in faces do t.ok(Modelo.rotacao(i):VectorToWorldSpace(v):Dot(Vector3.yAxis)>.999) end
	end,
	["dados exigem contexto alcance mao livre e vetor valido sem consumir RNG"]=function(t) fixture(function(f)
		local p=f.jogadores[1];t.ok(f.dados.pegar(p));root(p).CFrame=CFrame.new(250,6,-6)
		f.bloqueado=true;t.eq(f.dados.pegar(p),"bloqueado");f.bloqueado=false;f.maos[1]="papel";t.ok(f.dados.pegar(p));f.maos[1]=nil
		t.eq(f.dados.pegar(p),nil);t.eq(f.maos[1],"dados-brotos");t.ok(f.dados.lancar(f.jogadores[2],tiro));t.ok(f.dados.lancar(p,{}));t.eq(f.rolagens,0)
		local m=f.pasta.SalaDadosFisicos.Dados_1;t.ok((m.Dado1.Position-root(p).Position).Magnitude<4);t.ok(m.Dado1:FindFirstChildOfClass("SurfaceGui"))
		local nc=m:FindFirstChildOfClass("NoCollisionConstraint");t.ok(nc and nc.Part1~=nil)
	end) end,
	["dados usam impulso nativo dono servidor e alinham resultado sem rerrolar"]=function(t) fixture(function(f)
		local p=f.jogadores[1];root(p).CFrame=CFrame.new(250,6,-6);t.eq(f.dados.pegar(p),nil);t.eq(f.dados.lancar(p,tiro),nil)
		local m=f.pasta.SalaDadosFisicos.Dados_1;t.eq(f.maos[1],nil);t.eq(m.Dado1.Anchored,false);t.eq(m.Dado1:GetNetworkOwner(),nil);t.eq(f.rolagens,1);t.ok(f.dados.lancar(p,tiro));t.eq(f.rolagens,1)
		f.tempo=2.5;f.dados.atualizar(0);t.eq(m:GetAttribute("Pousou"),nil);t.eq(m.Dado1:GetAttribute("Valor"),nil);t.eq(m.Dado1.Anchored,true)
		task.wait(.25);f.tempo=2.8;f.dados.atualizar(0);t.eq(m:GetAttribute("Pousou"),true);t.eq(m.Dado1:GetAttribute("Valor"),2);t.eq(m.Dado2:GetAttribute("Valor"),4);t.eq(m.Dado3:GetAttribute("Valor"),6)
		f.tempo=13;f.dados.atualizar(0);t.eq(m.Parent,nil)
	end) end,
	["dados limpam mao por timeout respawn e saida"]=function(t) fixture(function(f)
		local p=f.jogadores[1];root(p).CFrame=CFrame.new(250,6,-6);f.dados.pegar(p);f.tempo=21;f.dados.atualizar(0);t.eq(f.maos[1],nil)
		f.dados.pegar(p);local old=p.Character;p.Character=f.jogadores[2].Character;f.dados.atualizar(0);t.eq(f.maos[1],nil);p.Character=old
		f.tempo+=1.1;t.eq(f.dados.pegar(p),nil);f.dados.sair(1);t.eq(f.maos[1],nil);t.eq(#f.pasta.SalaDadosFisicos:GetChildren(),0)
	end) end,
	["pegar liberar pegar respeita intervalo e limpeza notifica"]=function(t) fixture(function(f)
		local p=f.jogadores[1];root(p).CFrame=CFrame.new(250,6,-6);t.eq(f.dados.pegar(p),nil);f.maos[1]=nil;f.dados.atualizar(0);t.eq(f.mudancas,1);t.ok(f.dados.pegar(p));f.tempo=1.1;t.eq(f.dados.pegar(p),nil)
	end) end,
	["rolagem fisica confirma uma vez apos pouso ou recolhimento"]=function(t) fixture(function(f)
		local vezes=0;f.deps.rolar=function() return {2,4,6},nil,function() vezes+=1 end end
		local p=f.jogadores[1];root(p).CFrame=CFrame.new(250,6,-6);f.dados.pegar(p);f.dados.lancar(p,tiro);t.eq(vezes,0);t.ok(f.dados.pendente(1));t.ok(f.dados.pendentes());t.ok(f.dados.pegar(p))
		f.tempo=2.5;f.dados.atualizar(0);t.eq(vezes,0);t.ok(f.dados.pendentes());task.wait(.25);f.tempo=2.8;f.dados.atualizar(0);t.eq(vezes,1);t.eq(f.dados.pendentes(),false);f.dados.atualizar(0);f.dados.arrumar();t.eq(vezes,1)
		f.dados.pegar(p);f.dados.lancar(p,tiro);f.dados.arrumar();t.eq(vezes,2);t.eq(f.dados.pendentes(),false)
	end) end,
	["alvo escapa e recupera movimento colisoes e protecao contra recaptura"]=function(t) fixture(function(f)
		local p,a=f.jogadores[1],f.jogadores[2];local h=a.Character.Humanoid
		t.eq(f.carregar.aplicar(p,{userId=2}),nil);t.eq(root(a).Anchored,true);t.eq(root(a).CanCollide,false);t.eq(h.PlatformStand,true);t.eq(f.maos[1],"jogador:2")
		f.carregar.atualizar();t.ok((root(a).Position-root(p).Position).Magnitude<4)
		f.bloqueado=true;t.eq(f.carregar.aplicar(a,{soltar=true}),nil);t.eq(root(a).Anchored,false);t.eq(root(a).CanCollide,true);t.eq(root(a):GetAttribute("CarregadoPor"),nil);t.eq(h.PlatformStand,false);t.eq(h.AutoRotate,true);t.eq(f.maos[1],nil)
		f.bloqueado=false;t.ok(f.carregar.aplicar(p,{userId=2}));f.tempo=3.1;t.eq(f.carregar.aplicar(p,{userId=2}),nil)
	end) end,
	["carregar rejeita cadeia distancia paredes alvo ocupado e fora do lobby"]=function(t) fixture(function(f)
		local p,a,b=f.jogadores[1],f.jogadores[2],f.jogadores[3]
		t.ok(f.carregar.aplicar(p,{userId=1}));t.ok(f.carregar.aplicar(p,{userId=0/0}));t.ok(f.carregar.aplicar(p,{userId="2"}));t.ok(f.carregar.aplicar(p,{}))
		f.maos[2]="dados-brotos";t.ok(f.carregar.aplicar(p,{userId=2}));f.maos[2]=nil
		local muro=Instance.new("Part");muro.Size=Vector3.new(.5,4,4);muro.Anchored=true;muro.Position=(root(p).Position+root(a).Position)/2;muro.Parent=f.pasta;t.ok(f.carregar.aplicar(p,{userId=2}));muro:Destroy()
		root(a).CFrame=CFrame.new(250,8,12);t.ok(f.carregar.aplicar(p,{userId=2}));root(a).CFrame=CFrame.new(241,8,12)
		t.eq(f.carregar.aplicar(p,{userId=2}),nil);t.ok(f.carregar.aplicar(b,{userId=1}));t.ok(f.carregar.aplicar(a,{userId=3}));t.ok(f.carregar.aplicar(b,{userId=2}))
	end) end,
	["carregar restaura no timeout morte inicio e saida"]=function(t) fixture(function(f)
		local p,a=f.jogadores[1],f.jogadores[2]
		for _,caso in {"timeout","morte","inicio","saida","respawn"} do
			f.tempo+=10;root(a).CFrame=CFrame.new(241,8,12);t.eq(f.carregar.aplicar(p,{userId=2}),nil)
			local old=p.Character
			if caso=="timeout" then f.tempo+=4.1 elseif caso=="morte" then p.Character.Humanoid.Health=0 elseif caso=="inicio" then f.bloqueado=true elseif caso=="saida" then f.carregar.sair(2) elseif caso=="respawn" then p.Character=f.jogadores[3].Character end
			f.carregar.atualizar();t.eq(root(a).Anchored,false);t.eq(f.maos[1],nil);t.eq(a.Character.Humanoid.AutoRotate,true)
			p.Character=old;old.Humanoid.Health=100;f.bloqueado=false
		end
	end) end,
}
