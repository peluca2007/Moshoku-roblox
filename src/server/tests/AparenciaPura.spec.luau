local Shared = game:GetService("ReplicatedStorage").Shared
local C=require(Shared.Aparencia.Catalogo)
local R=require(Shared.Aparencia.Racas)
local A=require(Shared.Aparencia.Aparencia)
local Loot=require(Shared.Aparencia.Loot)
local Fonte=require(Shared.Livro.Dados.Racas)

local function serializar(v)
	if type(v)~="table" then return type(v)..":"..tostring(v) end
	local chaves={}; for k in v do table.insert(chaves,k) end; table.sort(chaves,function(a,b) return tostring(a)<tostring(b) end)
	local partes={}; for _,k in chaves do table.insert(partes,serializar(k).."="..serializar(v[k])) end
	return "{"..table.concat(partes,";").."}"
end
local function rng(n)
	local r={}; function r:NextInteger(a,b) return a+(n%(b-a+1)) end; function r:NextNumber() return 0 end; return r
end

return {
	["rosto e catálogos mantêm mínimos e contrato das peças"] = function(t)
		local function count(x) local n=0; for _ in x do n+=1 end; return n end
		t.ok(count(C.ROSTO.olhos)>=9); t.ok(count(C.ROSTO.sobrancelhas)>=6); t.ok(count(C.ROSTO.nariz)>=5); t.ok(C.ROSTO.nariz.NarizNenhum~=nil); t.ok(count(C.ROSTO.boca)>=8)
		local papeis={olho=true,iris=true,peleEscura=true,boca=true,dente=true}
		for _,cat in C.ROSTO do for _,blocos in cat do for _,b in blocos do t.ok(papeis[b.papel]); for _,k in {"x","y","z"} do t.eq(type(b.tamanho[k]),"number"); t.eq(type(b.posicao[k]),"number") end end end end
		for _,p in {C.PECAS,C.CABELOS,C.BARBAS} do for id,v in p do t.ok(v.nome and v.raridade and v.slot and v.encaixe.parte and v.encaixe.offset,id); if id:find("Nenhum") then t.eq(v.modulo,nil) else t.eq(v.modulo,id) end end end
	end,
	["todos os estilos e cores do catálogo têm nomes de apresentação"] = function(t)
		for _, categoria in C.ROSTO do
			for id in categoria do
				local nome = C.NOMES.ROSTO[_][id]
				t.eq(type(nome), "string", id)
				t.ok(nome ~= id, id)
			end
		end
	for _, catalogo in { C.PECAS, C.CABELOS, C.BARBAS } do
		for id, estilo in catalogo do
			local nome = if estilo.nome and estilo.nome ~= id then estilo.nome else C.NOMES.PECAS[id] or C.NOMES.ESTILOS[id] or estilo.nome
			t.eq(type(nome), "string", id)
			t.ok(nome ~= id, id)
		end
	end
	for id in C.CORES do
		local nome = C.NOMES.CORES[id]
		t.eq(type(nome), "string", id)
		t.ok(nome ~= id, id)
	end
	end,
	["perfis cobrem exatamente raças do livro e padrões são determinísticos"] = function(t)
		local esperadas={}; for _,r in Fonte do if r.kind=="race" then esperadas[r.id]=true end end
		local n=0; for id in R.POR_ID do t.ok(esperadas[id],id); esperadas[id]=nil; n+=1
			local padrao=A.padrao(id,55); local outro=A.padrao(id,55); t.eq(serializar(padrao),serializar(outro))
			local valido,motivo=A.validar(padrao,id,{}); t.ok(valido,motivo)
			local sorteada=A.aleatoria(id,rng(n)); t.ok(A.validar(sorteada,id,{}))
		end
		t.eq(n,12); t.eq(next(esperadas),nil)
	end,
	["validador rejeita payloads malformados paletas categorias e slots mas aceita posse no slot correto"] = function(t)
		local a=A.padrao("race/humano",1); t.ok(A.validar(a,"race/humano",{}))
		local b=table.clone(a); b.extra=true; t.eq(A.validar(b,"race/humano",{}),false)
		b=A.padrao("race/humano",1); b.rosto=table.clone(b.rosto); b.rosto.extra="x"; t.eq(A.validar(b,"race/humano",{}),false)
		b=A.padrao("race/humano",1); b.cores=table.clone(b.cores); b.cores.olho=12; t.eq(A.validar(b,"race/humano",{}),false)
		b=A.padrao("race/humano",1); b.cores=table.clone(b.cores); b.cores.camisa="PeleClara"; t.eq(A.validar(b,"race/humano",{}),false)
		b=A.padrao("race/humano",1); b.roupas={manto="LadinoCapa"}; t.eq(A.validar(b,"race/humano",{}),false)
		b=A.padrao("race/humano",1); b.roupas={costas="LadinoCapa"}; t.eq(A.validar(b,"race/humano",{}),false)
		t.eq(A.validar(b,"race/humano",{LadinoCapa=true}),true)
		b=A.padrao("race/migurd",2); b.cores=table.clone(b.cores); b.cores.cabelo="CabeloVerde"; t.eq(A.validar(b,"race/migurd",{}),false)
	end,
	["loot usa chance documentada e só termina sem item com catálogo raro esgotado"] = function(t)
		t.eq(Loot.CHANCE,0.15); local id=Loot.sortear({},rng(0)); t.ok(id~=nil)
		local possuidos={}; for k,p in C.PECAS do if p.raridade=="rara" then possuidos[k]=true end end
		t.eq(Loot.sortear(possuidos,rng(0)),nil)
		local uma={[id]=true}; local proxima=Loot.sortear(uma,rng(0)); t.ok(proxima~=nil); t.ok(proxima~=id)
	end,
}
