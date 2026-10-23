-- SOMENTE STUDIO: corpos, alcance, visão e transferência atômica.
local Entrega=require(script.Parent.Parent.SalaEntrega)
local function bancada(fn)
	local pasta=Instance.new("Folder");pasta.Name="G16EntregaTeste";pasta.Parent=workspace
	local pessoas={};local maos={[1]="ficha"};local ofertas={};local bloqueados={};local agora=1
	for i=1,2 do
		local char=Instance.new("Model");char.Name="Pessoa"..i;char.Parent=pasta
		local root=Instance.new("Part");root.Name="HumanoidRootPart";root.Anchored=true;root.Position=Vector3.new(11000+i*3,50,0);root.Parent=char
		local h=Instance.new("Humanoid");h.RequiresNeck=false;h.Parent=char
		pessoas[i]={UserId=i,Character=char}
	end
	local r={maos=maos,ofertas=ofertas,pessoas=pessoas,pasta=pasta,bloqueados=bloqueados}
	r.api=Entrega.new({maos=maos,ofertas=ofertas,fichas={ficha=true},jogador=function(id) return pessoas[id] end,permitido=function(p) return if bloqueados[p.UserId] then "bloqueado" else nil end,agora=function() return agora end})
	function r.tempo(v) agora=v end
	local ok,err=xpcall(function() fn(r) end,debug.traceback);pasta:Destroy();if not ok then error(err) end
end
return {
	["entrega confirma ambas as maos sem novo pedido do alvo"] = function(t) bancada(function(r)
		r.ofertas[1]={id="antiga"};t.eq(r.api.entregar(r.pessoas[1],"ficha",2),nil)
		t.eq(r.maos[1],nil);t.eq(r.maos[2],"ficha");t.eq(r.ofertas[1],nil);t.eq(r.ofertas[2].id,"ficha");t.eq(r.ofertas[2].de,1);t.eq(r.ofertas[2].serial,1)
	end) end,
	["tipos posse e alvo invalidos preservam a ficha"] = function(t) bancada(function(r)
		for _,id in {"2",0/0,math.huge,2.5,1,99} do t.ok(r.api.entregar(r.pessoas[1],"ficha",id));t.eq(r.maos[1],"ficha");t.eq(r.maos[2],nil) end
		t.ok(r.api.entregar(r.pessoas[1],"livro",2));r.maos[1]=nil;t.ok(r.api.entregar(r.pessoas[1],"ficha",2))
	end) end,
	["maos ocupadas e contexto nao recebem oferta"] = function(t) bancada(function(r)
		for _,mao in {"dados-brotos","jogador:3","livro","ficha"} do r.maos[2]=mao;t.ok(r.api.entregar(r.pessoas[1],"ficha",2));t.eq(r.maos[2],mao);t.eq(r.maos[1],"ficha");t.eq(r.ofertas[2],nil) end
		r.maos[2]=nil;r.bloqueados[2]=true;t.ok(r.api.entregar(r.pessoas[1],"ficha",2));r.bloqueados[2]=nil;r.bloqueados[1]=true;t.ok(r.api.entregar(r.pessoas[1],"ficha",2));t.eq(r.maos[1],"ficha")
	end) end,
	["distancia parede morte e carregamento bloqueiam entrega"] = function(t) bancada(function(r)
		local root=r.pessoas[2].Character.HumanoidRootPart;local base=root.Position;root.Position+=Vector3.new(10,0,0);t.ok(r.api.entregar(r.pessoas[1],"ficha",2));root.Position=base
		local parede=Instance.new("Part");parede.Anchored=true;parede.Size=Vector3.new(1,8,8);parede.Position=(root.Position+r.pessoas[1].Character.HumanoidRootPart.Position)/2;parede.Parent=r.pasta;t.ok(r.api.entregar(r.pessoas[1],"ficha",2));parede:Destroy()
		root:SetAttribute("CarregadoPor",3);t.ok(r.api.entregar(r.pessoas[1],"ficha",2));root:SetAttribute("CarregadoPor",nil)
		r.pessoas[2].Character.Humanoid.Health=0;t.ok(r.api.entregar(r.pessoas[1],"ficha",2));t.eq(r.maos[1],"ficha");t.eq(r.ofertas[2],nil)
	end) end,
	["intervalo limita reentrega e sair limpa somente o remetente"] = function(t) bancada(function(r)
		t.eq(r.api.entregar(r.pessoas[1],"ficha",2),nil);r.maos[1]="ficha";r.maos[2]=nil;t.ok(r.api.entregar(r.pessoas[1],"ficha",2));t.eq(r.maos[1],"ficha")
		r.tempo(2);t.eq(r.api.entregar(r.pessoas[1],"ficha",2),nil);t.eq(r.ofertas[2].serial,2)
		r.maos[1]="ficha";r.maos[2]=nil;r.api.sair(1);t.eq(r.api.entregar(r.pessoas[1],"ficha",2),nil);t.eq(r.ofertas[2].serial,3)
	end) end,
}
