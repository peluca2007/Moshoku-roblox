-- Contagem por módulo dos specs solicitados; tabelas/asserts do TestRunner.
local pasta=game.ServerScriptService.Server.tests
local t={eq=function(a,b,msg) assert(a==b,(msg or "").." esperado "..tostring(b)..", obtido "..tostring(a)) end,
	ok=function(v,msg) assert(v,msg or "condição falsa") end,
	fails=function(f,msg) assert(not pcall(f),msg or "era esperado erro") end}
local linhas={}
for _,m in pasta:GetChildren() do
	if m.Name:match("^A16") or m.Name:match("^A3") or m.Name:match("^A6") or m.Name:match("^A9") or m.Name:match("^A14") then
		local p,f=0,0
		for nome,teste in require(m) do
			local ok,erro=pcall(teste,t)
			if ok then p+=1 else f+=1;table.insert(linhas,"FALHA "..m.Name..": "..nome.." "..tostring(erro)) end
		end
		table.insert(linhas,m.Name..": "..p.." ok, "..f.." falhas")
	end
end
table.sort(linhas)
return table.concat(linhas," | ")
