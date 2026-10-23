-- Valores experimentais. PA de aprimoramento não são pontos de ação.
local Rules = {}
function Rules.attack(rng: Random, magic: boolean)
 local roll = rng:NextInteger(1,20)
 local hit = roll==20 or (roll~=1 and roll+4>=12)
 local damage = 0
 if hit then
  damage=rng:NextInteger(1,magic and 8 or 6)+2
  if roll==20 then damage+=rng:NextInteger(1,magic and 8 or 6) end
 end
 return {roll=roll,hit=hit,damage=damage,critical=roll==20}
end
return Rules
