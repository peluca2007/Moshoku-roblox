-- Posicoes dos treinadores fixos da vila. Geometria pura em XZ.
local Shared = game:GetService("ReplicatedStorage").Shared
local Terreno = require(Shared.Mundo.TerrenoLayout)

local Layout = {}
Layout.PATIO = { x = 65, z = -250, sx = 40, sz = 40 }
Layout.PORTAO = { x = 65, z = -230 }
Layout.ENTRADA = { x = 65, z = -233 }
Layout.SINO = { x = 65, z = -266 }
Layout.LADINO = { x = 65, z = -226, sx = 8, sz = 8 }
Layout.ZONA_PLANA_NECESSARIA = { id="patio-ladino", x=65, z=-252, sx=44, sz=56, material="Grass" }

-- Clareira definida pelo terreno para evitar dependencia circular.
function Layout.grade()
 local p = Terreno.PROVACAO_AGUA
 return { x=p.x-4.25, z=p.z+4, sx=24, sz=24 }
end
function Layout.mestra()
 local p = Layout.grade()
 return { x=p.x, z=p.z-16, sx=4, sz=4 }
end
function Layout.nivelAgua() return .6 end
-- Trajeto externo à paliçada, com passagem pelo portão sul existente.
function Layout.acessoAgua()
 local m=Layout.mestra()
 return {{x=0,z=-300},{x=0,z=-310},{x=-100,z=-310},{x=-100,z=m.z},{x=m.x,z=m.z}}
end
function Layout.captacao()
 local g=Layout.grade()
 return {x=g.x-15.85,z=g.z}, {x=g.x-10,z=g.z}
end
return Layout
