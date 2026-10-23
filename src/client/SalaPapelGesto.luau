-- Balanço leve da folha. Pegada/largada são de SalaPegada.
local UIS=game:GetService("UserInputService")
local G={}
function G.new(_,pode)
 local deslocamento=Vector2.zero
 return {
  reset=function() deslocamento=Vector2.zero end,
  arrastando=function() return false end,
  offset=function(dt)
   local d=if pode() then UIS:GetMouseDelta() else Vector2.zero
   local alvo=Vector2.new(math.clamp(-d.X*.002,-.12,.12),math.clamp(d.Y*.002,-.08,.08))
   deslocamento=deslocamento:Lerp(alvo,1-math.exp(-dt*12))
   return CFrame.new(deslocamento.X,deslocamento.Y,0)*CFrame.Angles(0,0,-deslocamento.X*.3)
  end,
 }
end
return G
