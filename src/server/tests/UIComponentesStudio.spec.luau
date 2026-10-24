-- SOMENTE STUDIO: construção real exige CLIENTE; servidor verifica a proteção.
-- Para a suíte completa: servidor clona este ModuleScript e TestRunner para
-- ReplicatedStorage.UIV2Testes; CLIENTE require(pasta.TestRunner).run(pasta).
-- Remover a pasta após rodar. Nenhum LocalScript extra é necessário.
local cliente = game:GetService("RunService"):IsClient()
local scripts = if cliente then game.Players.LocalPlayer.PlayerScripts else game.StarterPlayer.StarterPlayerScripts
local C = require(scripts.Client.UI.Componentes)
local T = require(scripts.Client.UI.Tema)
if not cliente then
	return { ["servidor não pode construir UI; suite visual requer execução cliente"] = function(t)
		local pasta = Instance.new("Folder")
		local ok, err = pcall(function() t.fails(function() C.painel({ parent = pasta }) end); t.eq(#pasta:GetChildren(), 0) end)
		pasta:Destroy(); if not ok then error(err, 0) end
	end }
end
local function fixture(corpo)
	local pg = game.Players.LocalPlayer.PlayerGui
	local antes = #pg:GetChildren()
	local gui = Instance.new("ScreenGui"); gui.Name = "TesteUIV2"; gui.Parent = pg
	local ok, err = pcall(corpo, gui)
	gui:Destroy()
	assert(#pg:GetChildren() == antes, "ScreenGui vazou")
	if not ok then error(err, 0) end
end
return {
 ["rotulos HUD cabem na faixa em larguras moveis"] = function(t) fixture(function(gui)
  local E=require(scripts.Client.UI.ExtraTelas)
  local TextService=game:GetService("TextService")
  for _,largura in {320,374,666,1647} do
   local passo=math.min(360,largura-16)/5
   for i,nome in {"MENU","RUN","CONTA","VIAGEM","AJUDA"} do
    local b=E.atalho(gui,nome,"run",nome,i)
    b.Size=UDim2.fromOffset(passo-8,64)
    local medida=TextService:GetTextSize(nome,b.Rotulo.TextSize,Enum.Font.SourceSansSemibold,Vector2.new(1000,64))
    t.ok(medida.X<=passo-10,nome.." cortado em "..largura)
    b:Destroy()
   end
  end
 end) end,

	["ícones isolados e fontes aprovadas em todos os componentes"] = function(t) fixture(function(gui)
		for nome, glifo in T.ICONES do
			local b = C.botao({ parent=gui, texto="Legenda", icone=nome })
			t.eq(b.Icone.Text, glifo); t.eq(b.Icone.FontFace, T.FONTE_ICONE); t.eq(b.Rotulo.FontFace, T.fontes.rotulo)
			local a = C.iconeBotao({ parent=gui, icone=glifo }); t.eq(a.Icone.FontFace, T.FONTE_ICONE)
		end
		C.titulo({ parent=gui, texto="Título", ornamento=true })
		C.texto({ parent=gui, texto="Subtítulo", subtitulo=true })
		for _, tipo in { "sucesso", "perigo", "alerta", "info" } do
			local canal = Instance.new("Frame"); canal.Parent=gui
			local cancelar = C.aviso({ parent=canal, tipo=tipo, destaque=true, duracao=20 })
			local banner = canal.AvisoUIV2
			t.eq(banner.UISizeConstraint.MaxSize.X, 520)
			t.eq(banner.Banner.Conteudo.CirculoIcone.Icone.FontFace, T.FONTE_ICONE)
			cancelar() -- fila única: o próximo canal só mostra depois deste
		end
		for _, obj in gui:GetDescendants() do
			if obj:IsA("TextLabel") or obj:IsA("TextButton") then
				t.ok(not string.find(obj.FontFace.Family, "Grenze")); t.ok(not string.find(obj.FontFace.Family, "Cinzel"))
				if obj.Name == "Icone" or obj.Name == "Ornamento" then t.eq(obj.FontFace, T.FONTE_ICONE) end
			end
		end
	end) end,
	["painel cartao titulo e texto criam decoração esperada"] = function(t) fixture(function(gui)
		local p = C.painel({ parent = gui, losangos = true })
		t.ok(p:FindFirstChildOfClass("UIStroke")); t.ok(p:FindFirstChildOfClass("UICorner"))
		t.ok(p.FioInterno:FindFirstChildOfClass("UIStroke")); t.ok(p.Sombra); t.ok(p.Losango4)
		t.ok(p.Conteudo:FindFirstChildOfClass("UIPadding"))
		t.ok(C.cartao({ parent = gui }).Conteudo)
		local titulo = C.titulo({ parent = p.Conteudo, texto = "Teste", ornamento = true })
		t.ok(not string.find(titulo.Text, "✦", 1, true)); t.eq(titulo.FaixaCabecalho.Ornamento.FontFace, T.FONTE_ICONE)
		t.eq(p.Losango4.Size, UDim2.fromOffset(10, 10)); t.ok(p.UIStroke:FindFirstChildOfClass("UIGradient"))
		local txt = C.texto({ parent = p.Conteudo, texto = "Corpo" }); t.ok(txt.TextWrapped); t.eq(txt.AutomaticSize, Enum.AutomaticSize.Y)
	end) end,
	["variantes ícones desabilitado e escala preservam toque"] = function(t) fixture(function(gui)
		local root = Instance.new("Frame"); root.Size = UDim2.fromScale(1,1); root.Parent = gui
		local camera = Instance.new("Camera")
		local ui = C.aplicarEscala(root, camera)
		ui.Scale = 0.85
		for _, variante in { "principal", "secundario", "perigo", "fantasma" } do
			local b = C.botao({ parent = root, variante = variante, icone = "✦", desabilitado = true })
			t.ok(b.Icone); t.ok(not b.Active); t.ok(not b.Selectable)
			t.ok(b.ToqueMinimo.MinSize.Y * 0.85 >= 44)
			b:SetAttribute("Desabilitado", false); task.wait(); t.ok(b.Active)
			task.wait(); t.ok(b.AbsoluteSize.Y >= 44)
		end
		local b = C.iconeBotao({ parent = root, icone = "?", rotulo = "Ajuda" }); t.ok(b.Icone); t.eq(b.Rotulo.Text, "Ajuda")
		camera:Destroy()
	end) end,
	["barra diálogo lista grade e ordem explícita"] = function(t) fixture(function(gui)
		local barra, atualizar = C.barra({ parent = gui, valor = 0.2 }); atualizar(2, "60s"); task.wait(0.2)
		t.eq(barra.Trilho.Preenchimento.Size.X.Scale, 1); t.eq(barra.Numero.Text, "60s")
		local dialogo = C.dialogoNpc({ parent = gui, nomeNpc = "Hanzo", fala = "Bem-vindo.", opcoes = {{texto="Treinar"},{texto="Sair"}} })
		local botoes = 0; for _, obj in dialogo:GetDescendants() do if obj:IsA("TextButton") then botoes += 1; t.ok(obj.LayoutOrder >= 3) end end
		t.eq(botoes, 2)
		local lista = C.lista({ parent = gui }); t.eq(lista.UIListLayout.SortOrder, Enum.SortOrder.LayoutOrder)
		local grade = C.grade({ parent = gui }); t.eq(grade.UIGridLayout.SortOrder, Enum.SortOrder.LayoutOrder)
		local a = C.texto({ parent = lista, nome = "Z", ordem = 1 }); local b = C.texto({ parent = lista, nome = "A", ordem = 2 }); t.ok(a.LayoutOrder < b.LayoutOrder)
	end) end,
	["avisos somem em fila e cancelam sem criar ScreenGui"] = function(t) fixture(function(gui)
		local function contar() local n=0; for _, obj in gui:GetChildren() do if obj.Name=="AvisoUIV2" then n+=1 end end; return n end
		C.aviso({ parent=gui, titulo="Primeiro", duracao=0.1 })
		local cancelar = C.aviso({ parent=gui, titulo="Segundo", duracao=0.1 })
		t.eq(contar(),1); task.wait(0.35); t.eq(contar(),1)
		cancelar(); cancelar(); task.wait(0.15); t.eq(contar(),0)
		C.aviso({ parent=gui, duracao=0.01 }); task.wait(0.3); t.eq(contar(),0)
		for _, tipo in { "info", "sucesso", "perigo", "alerta" } do C.aviso({ parent=gui, tipo=tipo, duracao=20 }) end
		t.eq(contar(),1)
		-- Outra tela espera a vez: banners de telas diferentes não se sobrepõem.
		local outra = Instance.new("Frame"); outra.Parent = gui
		C.aviso({ parent=outra, titulo="Outra tela", duracao=20 })
		t.eq(outra:FindFirstChild("AvisoUIV2"), nil)
		t.eq(contar(),1) -- fixture destrói também aviso ativo e fila pendente.
	end) end,
}
