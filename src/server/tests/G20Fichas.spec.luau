local Shared = game:GetService("ReplicatedStorage").Shared
local F=require(Shared.SalaFichas)
return {
	["papel unico sai da pilha enquanto esta na mao ou solto"]=function(t)
		local s={maos={},copias={},papeisSoltos={}}
		t.eq(F.disponiveis(s,"a"),1)
		s.maos[1]="a";t.eq(F.disponiveis(s,"a"),0);t.eq(F.disponiveis(s,"a",1),1)
		s.maos[1]=nil;s.papeisSoltos={{id="a"}};t.eq(F.disponiveis(s,"a"),0)
		table.clear(s.papeisSoltos);t.eq(F.disponiveis(s,"a"),1)
	end,
	["somente copias autorizadas liberam outro papel"]=function(t)
		local s={maos={[1]="a"},copias={a=2},papeisSoltos={}}
		t.eq(F.disponiveis(s,"a"),1);s.maos[2]="a";t.eq(F.disponiveis(s,"a"),0)
		s.maos[3]="a";t.eq(F.disponiveis(s,"a"),0)
	end,
	["snapshot com chaves string preserva a mesma posse"]=function(t)
		t.eq(F.disponiveis({maos={["12"]="a"}},"a",12),1)
		t.eq(F.disponiveis({maos={["12"]="a"}},"a",13),0)
	end,
}
