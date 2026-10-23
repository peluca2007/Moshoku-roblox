local pg=game.Players.LocalPlayer.PlayerGui
local gui=pg.EscolhaDePersonagem
assert(gui.Enabled,'escolha aberta pelo menu')
local personagens=require(game.ReplicatedStorage.Shared.PersonagensProntos)
local linhas={}
for _,p in personagens do
 local card=gui:FindFirstChild('Personagem_'..p.id,true)
 assert(card,p.id)
 assert(card.PaGasto.Text==string.format('PA gasto\n%d',p.paGasto),p.id..' PA')
 assert(card.PaGasto.TextFits,p.id..' PA legivel')
 assert(card.Atributos.TextFits,p.id..' atributos legiveis')
 assert(card.Recursos.TextFits,p.id..' recursos legiveis')
 table.insert(linhas,p.id..': '..card.Recursos.Text:gsub('\n',' / ')..' / PA '..p.paGasto)
end
return '14 cartoes verificados\n'..table.concat(linhas,'\n')
