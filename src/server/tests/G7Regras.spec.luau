local Shared = game:GetService("ReplicatedStorage").Shared
local V=require(Shared.VisaoFurtiva)
local F=require(Shared.VisibilidadeFurtiva)
local M=require(Shared.Regras.Maestrias)
return {
 ["G7 paredes do mapa usam vírgula e impedem visão pela quina"] = function(t)
  local terreno={["6,5"]="parede"};local b=function(x,z) return V.terrenoBloqueia(terreno,x,z) end
  t.ok(b(6,5));t.ok(not b(5,5))
  local a={x=5,z=5,pv=10,olharX=1,olharZ=1}
  t.ok(not V.contem(a,6,6,b));t.ok(not V.contem(a,7,5,b))
  t.ok(V.contem(a,5,6,b))
 end,
 ["G7 Escondido só chega ao próprio dono"] = function(t)
  local a={ownerUserId=1,conditions={{id="escondido"}}}
  t.ok(F.podeVer(1,a));t.ok(not F.podeVer(2,a));t.ok(not F.podeVer(0,a));t.ok(not F.podeVer(1,nil))
  a.conditions={};t.ok(F.podeVer(2,a))
 end,
 ["G7 Esquivar é ação sobre si sem alcance ou alvo inimigo"] = function(t)
  local m=M.BASICAS["mesa/esquivar"];t.eq(m.alvo,"si");t.eq(m.acoes,1);t.eq(m.naoAliados,nil);t.eq(m.alcanceCasas,nil)
 end,
}
