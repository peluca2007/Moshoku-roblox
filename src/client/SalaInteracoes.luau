-- Prompts nos próprios objetos: E, botão X do controle e toque nativo Roblox.
local I={}
function I.new(pasta,interagir)
	local prompts={};local ligado=false;local api={}
	local titulos={placar="Ler resultados",ficha="Pegar ficha",livro="Pegar livro",ajustes="Abrir caderno",mestre="Preparar sessão",pronto="Confirmar prontidão",assumir="Assumir ficha",dados="Pegar dados",tabuleiro="Consultar sessão",admin="Administração",autonomo="Iniciar encontro autônomo"}
	local function adicionar(p)
		if not p:IsA("BasePart") then return end
		local acao=p:GetAttribute("SalaObjeto");if not titulos[acao] or p.Name=="AbaEscudo" or acao=="ficha" or acao=="livro" or acao=="dados" then return end
		local prompt=Instance.new("ProximityPrompt");prompt.Name="InteragirSala";prompt.ActionText=titulos[acao];prompt.ObjectText=if acao=="ficha" then "Papel de personagem" elseif acao=="livro" then "Volume encadernado" else "Mesa de RPG"
		prompt.KeyboardKeyCode=Enum.KeyCode.E;prompt.GamepadKeyCode=Enum.KeyCode.ButtonX;prompt.MaxActivationDistance=12;prompt.RequiresLineOfSight=false;prompt.ClickablePrompt=true;prompt.Enabled=ligado;prompt.Parent=p
		prompt.Triggered:Connect(function() if ligado and p.Parent then interagir(p) end end);prompts[p]=prompt
	end
	for _,p in pasta:GetDescendants() do adicionar(p) end
	pasta.DescendantAdded:Connect(function(p) task.defer(adicionar,p) end)
	task.spawn(function() local mundo=workspace:WaitForChild("SalaRPG",20);if mundo then for _,p in mundo:GetDescendants() do adicionar(p) end;mundo.DescendantAdded:Connect(function(p) task.defer(adicionar,p) end) end end)
	function api.atualizar(ativo,admitido,admin,pronto)
		ligado=ativo and admitido
		for p,prompt in prompts do
			if not p.Parent then prompts[p]=nil else
				prompt.Enabled=ligado and p.Transparency<1 and (p:GetAttribute("SalaObjeto")~="admin" or admin==true)
				if p:GetAttribute("SalaObjeto")=="pronto" then prompt.ActionText=if pronto then "Cancelar prontidão" else "Confirmar prontidão" end
			end
		end
	end
	return api
end
return I
