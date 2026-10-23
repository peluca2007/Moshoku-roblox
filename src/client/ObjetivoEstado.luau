-- G1: espelho local dos canais já existentes; nunca decide elegibilidade no servidor.
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local L = require(RS.Shared.Mundo.TreinadoresLayout)
local F = require(RS.Shared.Mundo.FlorestaLayout)
local R = require(RS.Shared.Mundo.RuinasLayout)
local DadosMissoes = require(RS.Shared.Mundo.MissoesDados)
local E = {}
local function ponto(p) return { x=p.x, y=p.y or 0, z=p.z } end
function E.start(mesa)
	local e = { conversados={}, ofertas={}, lojasVistas={}, missoes={}, run=nil, treinadores={}, npcs={} }
	local conexoes = {}
	local vivo = true
	local function conectar(sinal, fn) table.insert(conexoes, sinal:Connect(fn)) end
	local remoto = RS:WaitForChild("RunJogo")
	conectar(remoto.OnClientEvent, function(tipo, dado)
		if not vivo or tipo ~= "run" or type(dado) ~= "table" or dado.erro then return end
		if dado.semRun or (e.run and (e.run.fim and not dado.fim or (dado.dia or 0)<(e.run.dia or 0))) then
			e.conversados, e.ofertas, e.provacao = {}, {}, nil
		end
		e.run = dado
	end)
	conectar(RS:WaitForChild("TreinadorJogo").OnClientEvent, function(r)
		if not vivo or type(r) ~= "table" then return end
		if r.provacao then e.provacao=r
		elseif r.oferta then e.conversados[r.oferta.npcId]=true; e.ofertas[r.oferta.npcId]=r.oferta end
	end)
	mesa.onLoja(function(d) if vivo and d then e.lojasVistas[d.npcId]=true end end)
	mesa.onMissoes(function(d) if vivo then for _, m in d do e.missoes[m.id]=m.situacao end end end)
	mesa.onLog(function(d)
		if not vivo or type(d)~="table" or d.tone~="sistema" then return end
		for _, m in DadosMissoes.LISTA do
			if d.text=="Missão cumprida: "..m.nome then e.missoes[m.id]="cumprida"
			end -- Entrega chega no snapshot de missões, não é inferida pelo valor em PO do log.
		end
	end)
	-- Consulta única após conectar; sem polling de rede e sem abrir tela.
	remoto:FireServer({acao="consultar"})
	function e:atualizar()
		local jogador=Players.LocalPlayer
		local raiz=jogador.Character and jogador.Character:FindFirstChild("HumanoidRootPart")
		self.posicao=raiz and {x=raiz.Position.X,y=raiz.Position.Y,z=raiz.Position.Z} or nil
		self.emEncontro=jogador:GetAttribute("InterfaceCombate")==true
		self.destinos={sino=ponto(L.SINO),portao=ponto(L.PORTAO),agua=ponto(L.grade()),
			["floresta-sombria"]=ponto(F.MARCO),["chefe-floresta"]=ponto(F.MARCO),
			["chefe-ruinas"]=ponto(R.ARENA),vila={x=0,y=0,z=-175}}
		self.treinadores, self.npcs = {}, {}
		local vila=workspace:FindFirstChild("Vila")
		for _, nome in {"TreinadoresRun","Npcs"} do
			local pasta=vila and vila:FindFirstChild(nome)
			for _, modelo in if pasta then pasta:GetChildren() else {} do
				local base=modelo:FindFirstChild("HumanoidRootPart")
				if not base then continue end
				local id=modelo:GetAttribute("TreinadorId")
				local area=modelo:GetAttribute("AreaId") or ""
				local npc={id=id or area:match("region/vila/npc/(.+)"),modelo=modelo,base=base,
					posicao={x=base.Position.X,y=base.Position.Y,z=base.Position.Z}}
				if not npc.id then continue end
				if id then
					npc.tipo="treinador"
					npc.disponivel=not self.ofertas[id] or self.ofertas[id].podeComprar==true
					table.insert(self.treinadores,npc)
				elseif base:FindFirstChild("AbrirMissoes") then
					npc.tipo="missao"; npc.novo=false
					for _, m in DadosMissoes.LISTA do
						if m.npc==npc.id then
							npc.concluir=npc.concluir or self.missoes[m.id]=="cumprida"
							npc.novo=npc.novo or self.missoes[m.id]=="disponivel"
						end
					end
					-- Sem snapshot de missão, só anunciar a loja ainda não visitada.
					npc.novo=npc.novo or (base:FindFirstChild("AbrirLoja")~=nil and not self.lojasVistas[npc.id])
				elseif base:FindFirstChild("AbrirLoja") then npc.tipo="loja"; npc.novo=not self.lojasVistas[npc.id] end
				table.insert(self.npcs,npc)
			end
		end
	end
	function e:destruir() vivo=false; for _, c in conexoes do c:Disconnect() end end
	return e
end
return E
