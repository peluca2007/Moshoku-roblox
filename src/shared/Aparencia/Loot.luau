local Shared = game:GetService("ReplicatedStorage").Shared
local Loot={ CHANCE=0.15 }
function Loot.sortear(possuidos,rng)
	if type(possuidos)~="table" or not rng or not rng.NextNumber or rng:NextNumber()>=Loot.CHANCE then return nil end
	local catalogo=require(Shared.Aparencia.Catalogo); local ids={}
	for id,p in catalogo.PECAS do if p.raridade=="rara" and possuidos[id]~=true then table.insert(ids,id) end end
	table.sort(ids); if #ids==0 then return nil end
	return ids[rng:NextInteger(1,#ids)]
end
return Loot
