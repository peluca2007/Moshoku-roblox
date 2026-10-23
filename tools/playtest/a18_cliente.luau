local R={pronto=false,falhas=0,linhas={}}
shared.A18=R
local remote=game.ReplicatedStorage:WaitForChild("Mesa")
local pg=game.Players.LocalPlayer.PlayerGui
local snap
local conn=remote.OnClientEvent:Connect(function(k,d) if k=="snapshot" then snap=d end end)
local function check(nome,ok)
	table.insert(R.linhas,(if ok then "OK " else "FALHA ")..nome)
	if not ok then R.falhas+=1 end
end
local function send(c,p,espera) remote:FireServer(c,p or {}); task.wait(espera or .7) end
task.spawn(function()
	local ok,e=pcall(function()
		send("requestSnapshot")
		check("paginas desafios e PvP",pg.InicioJogo.MenuInicial.Conteudo:FindFirstChild("Pagina_Desafios") and pg.InicioJogo.MenuInicial.Conteudo:FindFirstChild("Pagina_PvP"))
		send("entrarFila",{modo="duelo",equipe=1}); check("equipe confirmada no servidor",snap.sala.equipe==1 and snap.sala.lados[2][1]==game.Players.LocalPlayer.UserId)
		send("entrarFila",{modo="duelo",equipe="2"}); check("payload invalido nao altera lado",snap.sala.equipe==1)
		send("entrarFila",{modo="sair"})
		for n=1,3 do
			send("iniciarLuta",{nivel=n},1.5)
			check("nivel "..n.." inicia",snap.combat.active and snap.encontro.nivel==n)
			if n==3 then
				local boss=snap.encontro.chefe
				check("nome e vida do chefe",boss and boss.nome=="Treant Ancião" and boss.pv==boss.pvMax)
				check("HUD chefe visivel",pg.HudJogo.Chefe.Visible)
				check("arena bosque local",workspace:FindFirstChild("ArenaTreant")~=nil)
				check("letreiro de entrada",pg.EntradaChefe.Letreiro.Visible)
				local corpo=workspace.CorposDeCriatura:FindFirstChild(boss.id)
				check("corpo de tronco e copa",corpo and corpo:FindFirstChild("Tronco") and corpo:FindFirstChild("Coroa"))
				send("entrarFila",{modo="duelo",equipe=2}); check("troca de equipe bloqueada em combate",snap.sala.equipe==1)
			end
			send("combatEnd",{},1)
			check("fim limpa chefe e arena "..n,snap.encontro==nil and not pg.HudJogo.Chefe.Visible and not workspace:FindFirstChild("ArenaTreant"))
		end
	end)
	if not ok then check("execucao: "..tostring(e),false) end
	conn:Disconnect(); R.pronto=true
end)
return "A18 cliente iniciado; consultar shared.A18 após 15 s."
