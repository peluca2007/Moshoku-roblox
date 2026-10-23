local Shared = game:GetService("ReplicatedStorage").Shared
local Layout = require(Shared.Mundo.PropsLayout)
return {
 ["vegetação baixa não bloqueia avatares"] = function(t)
  for _, familia in { "tufo", "flores", "samambaia", "cogumelos", "cogumelosluz", "juncos" } do
   t.eq(Layout.colide(familia), false, familia)
  end
 end,
 ["props estruturais conservam colisão"] = function(t)
  for _, familia in { "rocha", "rochedo", "tora", "toramusgo", "carroca", "barril", "casa", "abeto" } do
   t.eq(Layout.colide(familia), true, familia)
  end
 end,
}
