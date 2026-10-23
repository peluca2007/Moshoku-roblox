-- Ações da ficha por teclado/controle. Dicas em SalaMaoDicas.
local UIS=game:GetService("UserInputService")
local C={}
function C.new(_,pg,acao)
 local ativo=false;local livro=false
 local lista={{"Ler",Enum.KeyCode.R,Enum.KeyCode.ButtonY},{"Folhear",Enum.KeyCode.V,Enum.KeyCode.ButtonR1},{"Arma",Enum.KeyCode.B,Enum.KeyCode.ButtonL1},{"Assumir",Enum.KeyCode.Return,Enum.KeyCode.DPadUp},{"Anterior",Enum.KeyCode.Z,Enum.KeyCode.DPadLeft},{"Proxima",Enum.KeyCode.X,Enum.KeyCode.DPadRight},{"Entregar",Enum.KeyCode.T,Enum.KeyCode.DPadDown},{"Soltar",Enum.KeyCode.Q,Enum.KeyCode.ButtonB}}
 local function entrada(input)
  for _,a in lista do if input.KeyCode==a[2] or input.KeyCode==a[3] then if not livro or a[1]=="Ler" or a[1]=="Soltar" then acao(a[1]) end;break end end
 end
 UIS.InputBegan:Connect(function(input,processed) if not processed and ativo and not UIS:GetFocusedTextBox() and input.UserInputType==Enum.UserInputType.Keyboard then entrada(input) end end)
 local botoes={};for _,a in lista do table.insert(botoes,a[3]) end
 game:GetService("ContextActionService"):BindActionAtPriority("SalaObjetoControle",function(_,estado,input)
  if not ativo or UIS:GetFocusedTextBox() or game:GetService("GuiService").MenuIsOpen then return Enum.ContextActionResult.Pass end
  if estado==Enum.UserInputState.Begin then entrada(input) end;return Enum.ContextActionResult.Sink
 end,false,Enum.ContextActionPriority.High.Value,unpack(botoes))
 return {visivel=function(v) ativo=v end,posicionar=function() end,status=function(_,ler,l) livro=l==true end}
end
return C
