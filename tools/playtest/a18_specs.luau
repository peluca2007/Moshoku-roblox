local server=game.ServerScriptService.Server
local ok,falhas=0,0
local t={eq=function(a,b,m) assert(a==b,(m or "").." esperado "..tostring(b).." obtido "..tostring(a)) end,ok=function(a,m) assert(a,m) end}
local linhas={}
for _,nome in {"A18Regras.spec","A18Servico.spec"} do
	for descricao,fn in require(server.tests[nome]) do
		local passou,e=pcall(fn,t)
		if passou then ok+=1 else falhas+=1 end
		table.insert(linhas,(if passou then "OK " else "FALHA ")..descricao..(if passou then "" else ": "..tostring(e)))
	end
end
table.insert(linhas,string.format("A18: %d ok / %d falhas",ok,falhas))
assert(falhas==0,table.concat(linhas,"\n"))
return table.concat(linhas,"\n")
