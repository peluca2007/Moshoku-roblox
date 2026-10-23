-- Execute no Server durante Play, após instalar max1_personagem em um Script temporário.
local b=game.ServerStorage.CodexMax1Fixture
local inv=b:Invoke("inventario")
local targets={
 ["cura"]="max1",["vigor-emprestado"]="max1",["lamina-de-gelo"]="max1",["nevoa-densa"]="max1",["defender"]="max1",
 ["fagulha"]="casa:11:10",["clarao"]="clarao:10:11",["muro-de-chamas"]="muro:11:10:1:0:3",
 ["muro-de-terra"]="muro-terra:12:10",["anteparo-teorico"]="anteparo:11:10",
 ["escudo-de-agua"]="escudo-agua:11:10",["sopro-de-poeira"]="sopro-poeira:10:11",
 ["passo-de-vento"]="passo-vento:12:10",["atoleiro"]="area:atoleiro",["lanca-de-pedra"]="lista:alvo",
}
local out={ranks=inv.ranks,compras=inv.compras,resultados={},ok=0,falhas=0}
for _,id in ipairs(inv.disponiveis) do
 b:Invoke("abrir")
 task.wait(.12)
 local slug=id:match("([^/]+)$")
 local ok,r=pcall(function() return b:Invoke("usar",id,targets[slug] or "alvo") end)
 local erros={}
 if ok then for _,e in ipairs(r.eventos or {}) do if e.tipo=="recusado" then table.insert(erros,e.dados.mensagem) end end end
 local result=ok and r.recibo and r.recibo.result
 local entry={id=id,ok=ok and r.ok==true,erros=erros,excecao=not ok and tostring(r) or nil,
  damage=result and result.damageDealt,healing=result and result.healing,actions=result and result.actionsCost,pm=result and result.pmCost}
 table.insert(out.resultados,entry)
 if entry.ok then out.ok+=1 else out.falhas+=1 end
 task.wait(.18)
end
b:Invoke("fechar")
return out
