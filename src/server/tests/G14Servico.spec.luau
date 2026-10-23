-- SOMENTE STUDIO: validação de arremesso, recolhimento, limites e permissão ADM.
local S=require(script.Parent.Parent.SalaPapeis)
local A=require(script.Parent.Parent.AdminService)
return {
	["ADM nao anuncia troca de papel recusada pela sala"] = function(t)
		local respostas=0
		local a=A.start({isAdmin=function() return true end,agora=function() return 2 end,combat={},tokens={},remote={FireClient=function() respostas+=1 end},definirModoJogador=function() return "transferencia consentida" end})
		t.eq(a.executar({UserId=1},"/adm mestre"),"transferencia consentida");t.eq(respostas,0)
	end,
	["papeis validam posse alcance frequencia e teto"] = function(t)
		local char=Instance.new("Model");local root=Instance.new("Part");root.Name="HumanoidRootPart";root.Position=Vector3.new(250,4,-12);root.Parent=char
		local jogador={UserId=1,Character=char};local maos={};local agora=0;local bloqueado=false
		local r=S.new({maos=maos,agora=function() return agora end,permitido=function() return if bloqueado then "bloqueado" else nil end})
		local d={id="a",direcao={x=0,y=0,z=1},forca=1}
		t.ok(r.arremessar(jogador,d));maos[1]="a";bloqueado=true;t.eq(r.arremessar(jogador,d),"bloqueado");bloqueado=false
		t.eq(r.arremessar(jogador,d),nil);t.eq(maos[1],nil);t.eq(#r.publico(),1)
		maos[1]="a";t.ok(r.arremessar(jogador,d));agora=1;t.eq(r.recolher(jogador,"b",1),"Esse papel já foi recolhido.")
		root.Position=Vector3.new(0,4,0);t.ok(r.recolher(jogador,"a",1));t.ok(r.arremessar(jogador,d));root.Position=Vector3.new(250,4,-12)
		t.eq(r.recolher(jogador,"a",1),nil);t.eq(#r.publico(),0)
		for i=1,25 do agora=i;maos[1]="a";t.eq(r.arremessar(jogador,d),nil) end
		t.eq(#r.publico(),18);agora=71;t.eq(#r.publico(),0);char:Destroy()
	end,
	["ADM de sala exige permissao e propaga recusa"] = function(t)
		local vezes=0;local agora=0
		local a=A.start({isAdmin=function(p) return p.UserId==1 end,agora=function() agora+=2;return agora end,combat={},tokens={},remote={FireClient=function() end},sala=function(_,id) vezes+=1;return if id=="arrumar" then "recusa" else nil end})
		t.ok(a.executar({UserId=2},"/adm brotos"));t.eq(vezes,0)
		t.eq(a.executar({UserId=1},"/adm brotos"),nil);t.eq(vezes,1)
		t.eq(a.executar({UserId=1},"/adm arrumar"),"recusa");t.eq(vezes,2)
	end,
}
