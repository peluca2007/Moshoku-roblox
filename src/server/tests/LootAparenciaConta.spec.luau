local Shared = game:GetService("ReplicatedStorage").Shared
local Conta=require(Shared.Regras.RunConta)
local Transacoes=require(Shared.Regras.ContaTransacoes)
local Catalogo=require(Shared.Aparencia.Catalogo)

local function storeFake(initial, repeats)
	local data=initial or {}; local calls=0
	return {dados=data,atualizar=function(key,transformar)
		calls+=1; local current=data[key]
		local original=current
		for _=1,(repeats or 1) do local nova=transformar(original); if nova~=nil then current=nova end end
		data[key]=current; return current
	end,quantidade=function() return calls end}
end
local function rng(chance,choice)
	local r={next=0,ints=0}; function r:NextNumber() self.next+=1; return if self.next==1 then chance else choice end
	function r:NextInteger(a,b) self.ints+=1; return a+math.min(b-a,math.floor(choice*(b-a+1))) end; return r
end
return {
	["loot de chefe registra posse e recibo atomicamente apesar de retry do transform"] = function(t)
		local store=storeFake(nil,3); local api=Transacoes.start({store=store}); local aleatorio=rng(0,0)
		local c,id=api.registrarLootChefe(81,"chefe/f6",aleatorio); t.ok(c~=nil); t.eq(id~=nil,true); t.eq(c.cosmeticos[id],true)
		t.eq(c.lootChefes[1],"chefe/f6"); t.eq(aleatorio.next,2); t.eq(store:quantidade(),1)
		local repetido,semId=api.registrarLootChefe(81,"chefe/f6",rng(0,0)); t.eq(semId,nil); t.eq(#repetido.lootChefes,1); t.eq(repetido.cosmeticos[id],true)
	end,
	["sem prêmio também grava recibo com chance de loot 15 por cento"] = function(t)
		local store=storeFake(); local api=Transacoes.start({store=store}); local c,id=api.registrarLootChefe(82,"chefe/sem-drop",rng(0.15,0))
		t.eq(id,nil); t.eq(#c.lootChefes,1); t.eq(c.lootChefes[1],"chefe/sem-drop"); t.eq(Conta.valida(c),true)
	end,
	["conta antiga sem campos de loot migra sem apagar grants de compra e run"] = function(t)
		local old=Conta.nova(); old.moeda=500; local store=storeFake({["conta/83"]=old}); local api=Transacoes.start({store=store})
		local c=assert(api.obter(83)); t.eq(c.cosmeticos,nil); t.eq(c.lootChefes,nil); t.eq(Conta.valida(c),true)
		c=assert(api.comprar(83,"cosmetico:capa-vermelha","grant-83")); t.eq(c.desbloqueios["cosmetico:capa-vermelha"],true)
		local rngComPremio=rng(0,0); c=assert(api.registrarLootChefe(83,"chefe/grant",rngComPremio)); local premio
		for id in c.cosmeticos do premio=id end
		t.ok(c.cosmeticos[premio]); t.ok(table.find(c.lootChefes,"chefe/grant"))
		local resumo={status="final",regioesVisitadas=1,objetivoCumprido=true}; local depois=assert(api.registrarRun(83,resumo,"final-teste"))
		t.eq(depois.desbloqueios["cosmetico:capa-vermelha"],true); t.eq(depois.cosmeticos[premio],true); t.ok(table.find(depois.lootChefes,"chefe/grant")); t.eq(Conta.valida(depois),true)
	end,
	["loot recusa identidade e fonte inválidas sem gravar recibo"] = function(t)
		local api=Transacoes.start({store=storeFake()}); local r=rng(0,0)
		t.eq(api.registrarLootChefe(0,"x",r),nil); t.eq(api.registrarLootChefe(84,"",r),nil); t.eq(api.registrarLootChefe(84,string.rep("x",161),r),nil)
	end,
}
