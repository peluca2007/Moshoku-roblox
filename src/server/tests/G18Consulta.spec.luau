local L=require(game:GetService("ReplicatedStorage").Shared.SalaConsultaLayout)
return {
	["consulta do mestre usa retrato em tela estreita"]=function(t)
		local w,h=L.tamanho("mestre",374/666);t.ok(w<h)
		w,h=L.tamanho("mestre",666/374);t.ok(w>h)
		w,h=L.tamanho("ajustes",2);t.ok(w<h)
	end,
	["densidade mantem alvo de toque mesmo com canvas quantizado"]=function(t)
		for _,w in {240,312,400,620,1400} do for _,h in {180,244,311,480,1000} do
			local x,y=L.canvas(w,h);t.ok(math.abs(x-w)<=4 and math.abs(y-h)<=4);t.ok(52*h/y>=48)
		end end
		t.eq(L.texto(45),30);t.eq(L.texto(25),18);t.ok(L.texto(20)>=17)
	end,
}
