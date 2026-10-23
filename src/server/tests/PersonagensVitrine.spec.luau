-- SOMENTE STUDIO: a vitrine pública deve corresponder às fichas usadas no servidor.
local HttpService=game:GetService('HttpService')
local Shared=game:GetService('ReplicatedStorage').Shared
local Personagens=require(Shared.PersonagensProntos)
local Premontados=require(script.Parent.Parent.Premontados)
local Execucao=require(Shared.Regras.Execucao)
local Catalogo=require(Shared.Livro.Catalogo)
return {
 ['vitrine individual corresponde as 17 fichas do servidor']=function(t)
  t.eq(#Personagens,17)
  for _,p in Personagens do
   local f=HttpService:JSONDecode(Premontados[p.id])
   t.eq(p.paGasto,f.calculated.paSpent)
   t.eq(p.pv,f.calculated.maxima.pv); t.eq(p.pm,f.calculated.maxima.pm); t.eq(p.pt,f.calculated.maxima.pt)
   t.eq(p.ca,f.calculated.armorClass)
   for _,k in {'forca','agilidade','vigor','intelecto','espirito'} do t.eq(p.atributos[k],f.calculated.attributes[k]) end
   t.eq(#p.ranks,#f.construction.unlockedRankIds)
   for i,id in p.ranks do t.eq(id,f.construction.unlockedRankIds[i]) end
   local vitrine={calculated={attributes=p.atributos},construction={unlockedRankIds=p.ranks}}
   t.eq(8+Execucao.bc(vitrine,p.arvore,Catalogo),8+Execucao.bc(f,p.arvore,Catalogo))
  end
 end,
 ['vitrine preserva diferencas reais de recursos e investimento']=function(t)
  local porId={}; for _,p in Personagens do porId[p.id]=p end
  t.ok(porId.espadachim.pv~=porId['mago-de-fogo'].pv)
  t.ok(porId.espadachim.pm~=porId['mago-de-fogo'].pm)
  t.ok(porId['maga-da-agua'].paGasto~=porId.teorico.paGasto)
  t.eq(porId.espadachim.atributos.forca,2)
  t.eq(porId['mago-de-fogo'].atributos.intelecto,2)
 end,
}
