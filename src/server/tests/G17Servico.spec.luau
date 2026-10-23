-- SOMENTE STUDIO: largada rápida mantém autoridade e não fica presa no cooldown.
local S=require(script.Parent.Parent.SalaPapeis)
return {
	["largada apos arremesso e nova pegada nao fica presa no intervalo"]=function(t)
		local char=Instance.new("Model");local r=Instance.new("Part");r.Name="HumanoidRootPart";r.CFrame=CFrame.new(250,4,-6);r.Parent=char
		local p={UserId=1,Character=char};local maos={[1]="mago-de-fogo"};local agora=0
		local api=S.new({maos=maos,agora=function() return agora end,permitido=function() return nil end})
		local ok,erro=pcall(function()
			t.eq(api.arremessar(p,{id="mago-de-fogo",direcao={x=0,y=0,z=1},forca=.65}),nil)
			for i=1,3 do
				maos[1]="mago-de-fogo";agora+=.05
				t.eq(api.arremessar(p,{id="mago-de-fogo",direcao={x=0,y=0,z=1},forca=0,soltar=true}),nil);t.eq(maos[1],nil)
				local d=api.publico()[i+1];t.eq(d.velocidade.x,0);t.eq(d.velocidade.y,0);t.eq(d.velocidade.z,0)
			end
			maos[1]="mago-de-fogo";t.ok(api.arremessar(p,{id="mago-de-fogo",direcao={x=0,y=0,z=1},forca=1}));t.eq(maos[1],"mago-de-fogo")
			t.ok(api.arremessar(p,{id="mago-de-fogo",direcao={x=0,y=0,z=1},forca=0,soltar="sim"}));t.eq(maos[1],"mago-de-fogo")
		end);char:Destroy();if not ok then error(erro,0) end
	end,
}
