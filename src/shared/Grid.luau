-- Geometria pura: nenhuma dependência de Instances ou rede.
local Grid = {}
function Grid.distance(x: number, z: number, a: number, b: number): number
 return math.abs(x-a)+math.abs(z-b)
end
function Grid.isCell(x: any, z: any): boolean
 return type(x)=="number" and type(z)=="number" and x==x and z==z
  and x%1==0 and z%1==0 and x>=1 and x<=7 and z>=1 and z<=7
end
return Grid
