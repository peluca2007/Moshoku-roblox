local E = require(game:GetService("ReplicatedStorage").Shared.EnquadramentoMesa)
local board = { width = 20, height = 20, cell = 5 }
return {
	["camera inicial centraliza somente participantes visiveis"] = function(t)
		local tokens = {{ id="eu",x=10,z=15 },{ id="a",x=10,z=8 },{ id="b",x=6,z=10 },{ id="c",x=14,z=10 },{ id="fora",x=1,z=1 }}
		local box = E.limites(tokens, {"eu","a","b","c","oculto"}, board)
		t.eq(box.x,-2.5);t.eq(box.z,5);t.eq(box.largura,65);t.eq(box.profundidade,60)
		local sem = E.limites(tokens, {}, board)
		t.eq(sem.x,0);t.eq(sem.z,0);t.eq(sem.largura,100)
	end,
	["enquadramento de borda permanece no tabuleiro com margem minima"] = function(t)
		for _,x in {1,20} do for _,z in {1,20} do
			local box = E.limites({{id="eu",x=x,z=z}}, {"eu"}, board)
			t.ok(box.x-box.largura/2>=-50 and box.x+box.largura/2<=50)
			t.ok(box.z-box.profundidade/2>=-50 and box.z+box.profundidade/2<=50)
			t.eq(box.largura,40);t.eq(box.profundidade,40)
		end end
	end,
	["zoom inicial adapta largura da tela e HUD em vez de altura fixa148"] = function(t)
		local box = {largura=65,profundidade=60}
		local desktop = E.altura(box,{x=1280,y=720},{x1=0,y1=64,x2=1280,y2=550},70)
		local portrait = E.altura(box,{x=374,y=666},{x1=0,y1=64,x2=374,y2=480},70)
		local painel = E.altura(box,{x=1280,y=720},{x1=0,y1=64,x2=780,y2=550},70)
		t.ok(desktop<110 and desktop>35);t.ok(portrait>desktop and portrait<300)
		t.ok(painel>=desktop)
		local fechado = E.altura(box,{x=1280,y=720},{x1=0,y1=64,x2=1280,y2=550},40)
		t.ok(fechado>desktop)
	end,
}
