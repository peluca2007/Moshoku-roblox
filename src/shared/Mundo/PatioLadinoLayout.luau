-- Contrato visual/físico em XZ. Volumes contínuos impedem frestas nas malhas.
local Shared = game:GetService("ReplicatedStorage").Shared
local L = require(Shared.Mundo.TreinadoresLayout)
local P = { VELOCIDADE = 4, ALTURA_COBERTURA = 5.5 }
P.COBERTURAS = {
 {id="Carga da entrada",tipo="Caixotes",x=55,z=-240,sx=8,sz=4},
 {id="Feno da entrada",tipo="Fardo1",x=75,z=-240,sx=8,sz=4},
 {id="Varal oeste",tipo="Varal",x=55,z=-250,sx=8,sz=4},
 {id="Barris do depósito",tipo="Barril",x=75,z=-250,sx=8,sz=4},
 {id="Carroça carregada",tipo="Carroca",x=55,z=-260,sx=8,sz=4},
 {id="Carga do sino",tipo="Caixotes",x=75,z=-260,sx=8,sz=4},
}
P.ROTAS = {
 {a={x=49,z=-245},b={x=81,z=-245}},
 {a={x=81,z=-255},b={x=49,z=-255}},
 {a={x=65,z=-262},b={x=65,z=-238}},
}
function P.ocupado(x,z,folga)
 for _,c in P.COBERTURAS do
  if math.abs(x-c.x)<=c.sx/2+(folga or 0) and math.abs(z-c.z)<=c.sz/2+(folga or 0) then return true end
 end
 return false
end
-- Mesma interpolação da patrulha visual, incluindo a direção no retorno.
function P.guarda(indice,tempo)
 local r=P.ROTAS[indice]
 local dx,dz=r.b.x-r.a.x,r.b.z-r.a.z
 local d=math.sqrt(dx*dx+dz*dz)
 local fase=tempo*P.VELOCIDADE/d%2
 local ida=fase<1
 local u=if ida then fase else 2-fase
 local sinal=if ida then 1 else -1
 return {x=r.a.x+dx*u,z=r.a.z+dz*u},{x=dx/d*sinal,z=dz/d*sinal}
end
function P.dentro(x,z,folga)
 local r=L.PATIO
 return math.abs(x-r.x)<=r.sx/2-(folga or 0) and math.abs(z-r.z)<=r.sz/2-(folga or 0)
end
return P
