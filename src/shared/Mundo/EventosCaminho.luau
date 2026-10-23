-- W1b: a primeira entrada de cada trecho sorteia um evento F8 compatível com a região.
-- O catálogo ViagemEventosV1 e seus testes/consequências permanecem a fonte canônica.
local Shared = game:GetService("ReplicatedStorage").Shared
local Passagem = require(Shared.Mundo.PassagemLayout)
local Vila = require(Shared.Mundo.VilaLayout)
local Floresta = require(Shared.Mundo.FlorestaLayout)
local Ruinas = require(Shared.Mundo.RuinasLayout)
local C = {}
C.TRECHOS = {
 { id = "trilha-floresta", x = 0, z = -325, raio = 18, regiao = "floresta-sombria" },
 { id = "clareira-floresta", x = 0, z = -455, raio = 18, regiao = "floresta-sombria" },
 -- 17/10: saída norte da vila (era (0,-80), a 10 studs do nascimento: o evento abria um painel na chegada).
 { id = "estrada-vila", x = 0, z = -262, raio = 14, regiao = "vila" },
 { id = "entrada-ruinas", x = 600, z = -130, raio = 18, regiao = "ruinas-do-vale" },
}
for _, p in Passagem.clareiras do table.insert(C.TRECHOS, { id = p.id, x = p.x, z = p.z, raio = p.raio, regiao = "ruinas-do-vale" }) end
local function dentro(x,z,r) return math.abs(x-r.x)<=r.sx/2 and math.abs(z-r.z)<=r.sz/2 end
function C.regiao(x,z)
 if dentro(x,z,Ruinas.SOLO) then return "ruinas-do-vale" end
 if dentro(x,z,Floresta.SOLO) and z <= -350 then return "floresta-sombria" end
 if dentro(x,z,Vila.SOLO) or (math.abs(x)<120 and z >= -120 and z <=120) then return "vila" end
 return nil
end
function C.trecho(x,z,flags)
 for _, t in C.TRECHOS do
  if not flags["caminho/"..t.id] and (x-t.x)^2+(z-t.z)^2<=t.raio^2 then return t end
 end
 return nil
end
return C
